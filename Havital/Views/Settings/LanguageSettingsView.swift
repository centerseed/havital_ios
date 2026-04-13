import SwiftUI

struct LanguageSettingsView: View {
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var unitManager = UnitManager.shared
    @StateObject private var viewModel = UserProfileFeatureViewModel()
    // Clean Architecture: Use AuthenticationViewModel from environment
    @EnvironmentObject private var authViewModel: AuthenticationViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedLanguage: SupportedLanguage
    @State private var selectedUnit: UnitSystem
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    // showRestartAlert removed — using UIKit UIAlertController (iOS 26 SwiftUI alert bug)

    init() {
        _selectedLanguage = State(initialValue: LanguageManager.shared.currentLanguage)
        _selectedUnit = State(initialValue: UnitManager.shared.currentUnitSystem)
    }
    
    var body: some View {
        NavigationView {
            List {
                // Language Section
                Section(header: Text(L10n.Settings.language.localized)) {
                    Picker(L10n.Settings.language.localized, selection: $selectedLanguage) {
                        ForEach(SupportedLanguage.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                // Unit Section
                Section(header: Text(L10n.Settings.units.localized)) {
                    Picker(L10n.Settings.units.localized, selection: $selectedUnit) {
                        ForEach(UnitSystem.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                
                // Info Section
                Section(footer: languageInfoFooter) {
                    EmptyView()
                }
            }
            .navigationTitle(L10n.Language.title.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Common.cancel.localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.save.localized) {
                        saveSettings()
                    }
                    .disabled(isLoading || (selectedLanguage == languageManager.currentLanguage && selectedUnit == unitManager.currentUnitSystem))
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView(L10n.Common.loading.localized)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
            }
        }
        // Note: showRestartAlert is handled by showLanguageChangeAlert() using UIKit
        // because SwiftUI .alert button actions don't fire in iOS 26 sheet context
        .alert(L10n.Error.unknown.localized, isPresented: $showError) {
            Button(L10n.Common.done.localized) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var languageInfoFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Language.syncMessage.localized)
                .font(.footnote)
                .foregroundColor(.secondary)

            if selectedLanguage != languageManager.currentLanguage {
                Text(L10n.Language.restartRequiredMessage.localized)
                    .font(.footnote)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private func saveSettings() {
        // iOS 26 sheet + UIKit alert 容易出現確認彈窗未觸發，導致語言實際未套用。
        // 這裡改為直接執行語言切換流程，避免使用者（與自動測試）卡在未生效狀態。
        if selectedLanguage != languageManager.currentLanguage {
            performLanguageChange()
            return
        }
        // Unit change does not require restart
        if selectedUnit != unitManager.currentUnitSystem {
            Task {
                await performUnitChange()
            }
            return
        }
        // Nothing changed — dismiss on next runloop to avoid NavigationView dismiss conflict
        let dismissAction = dismiss
        Task { @MainActor in dismissAction() }
    }

    // UIKit alert workaround: SwiftUI .alert button actions don't fire in iOS 26 sheet context
    private func showLanguageChangeAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        let alert = UIAlertController(
            title: L10n.Language.changeConfirm.localized,
            message: L10n.Language.restartMessage.localized,
            preferredStyle: .alert
        )
        let mgr = languageManager
        alert.addAction(UIAlertAction(title: L10n.Common.cancel.localized, style: .cancel) { _ in
            self.selectedLanguage = mgr.currentLanguage
        })
        alert.addAction(UIAlertAction(title: L10n.Common.confirm.localized, style: .default) { _ in
            Task {
                await self.performLanguageChange()
            }
        })
        topVC.present(alert, animated: true)
    }

    private func performUnitChange() async {
        isLoading = true
        do {
            try await viewModel.updateUnitSystem(selectedUnit)
            await MainActor.run {
                isLoading = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func performLanguageChange() {
        isLoading = true
        let languageToApply = selectedLanguage

        // 先套用本地語言，避免等待網路導致 UI 長時間停在舊語言
        self.isLoading = false
        self.dismiss()
        LanguageManager.shared.performLanguageChangeWithRestart(to: languageToApply)

        // 後端同步改為背景執行，不阻塞本地體驗
        Task {
            do {
                try await self.updateBackendPreferences()
            } catch {
                Logger.firebase("Language backend sync failed after local apply: \(error.localizedDescription)", level: .warn)
            }
        }
    }
    
    // Note: Unit preference methods removed until backend supports imperial units
    
    private func updateBackendPreferences() async throws {
        // Create request to update preferences
        guard let url = URL(string: "\(APIConfig.baseURL)/user/preferences") else {
            Logger.firebase("無效的 URL", level: .error, labels: [
                "module": "LanguageSettingsView",
                "action": "updateBackendPreferences"
            ])
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication token if available
        do {
            // Clean Architecture: Use AuthenticationViewModel instead of AuthenticationService
            let token = try await authViewModel.getIdToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } catch {
            Logger.firebase("Failed to get auth token: \(error.localizedDescription)", level: .warn)
        }
        
        // Prepare request body
        let body: [String: Any] = [
            "language": selectedLanguage.apiCode
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Send request
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(
                domain: "LanguageSettings",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: L10n.Error.server.localized]
            )
        }
    }
}

// MARK: - Preview
struct LanguageSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        LanguageSettingsView()
    }
}
