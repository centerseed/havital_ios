import SwiftUI

struct LanguageSettingsView: View {
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var unitManager = UnitManager.shared
    @StateObject private var viewModel = UserProfileFeatureViewModel()
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
                .font(AppFont.footnote())
                .foregroundColor(.secondary)

            if selectedLanguage != languageManager.currentLanguage {
                Text(L10n.Language.restartRequiredMessage.localized)
                    .font(AppFont.footnote())
                    .foregroundColor(.orange)
            }
        }
    }
    
    private func saveSettings() {
        if selectedLanguage != languageManager.currentLanguage {
            performLanguageChange()
            return
        }
        // Unit change does not require restart
        if selectedUnit != unitManager.currentUnitSystem {
            Task { await performUnitChange() }
            return
        }
        // Nothing changed
        let dismissAction = dismiss
        Task { @MainActor in dismissAction() }
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

    /// 單一路徑：await 後端 200 → 套用本地 → restart。失敗則回滾並顯示 alert。
    private func performLanguageChange() {
        isLoading = true
        let languageToApply = selectedLanguage

        Task {
            let success = await languageManager.performLanguageChangeWithRestart(to: languageToApply)
            await MainActor.run {
                isLoading = false
                if !success {
                    // 回滾 picker 選擇
                    selectedLanguage = languageManager.currentLanguage
                    errorMessage = languageManager.lastSyncError ?? L10n.Error.server.localized
                    languageManager.lastSyncError = nil
                    showError = true
                }
                // success 時 LanguageManager 已觸發 restart，不需 dismiss
            }
        }
    }
}

// MARK: - Preview
struct LanguageSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        LanguageSettingsView()
    }
}
