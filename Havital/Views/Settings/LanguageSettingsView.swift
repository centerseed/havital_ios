import SwiftUI

struct LanguageSettingsView: View {
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var userPreferenceManager = UserPreferenceManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedLanguage: SupportedLanguage
    // Note: Unit preference removed until backend supports imperial units
    // @State private var selectedUnit: UnitPreference
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showRestartAlert = false
    
    init() {
        _selectedLanguage = State(initialValue: LanguageManager.shared.currentLanguage)
        // Note: Unit preference initialization removed until backend supports imperial units
        // _selectedUnit = State(initialValue: UserPreferenceManager.shared.unitPreference)
    }
    
    var body: some View {
        NavigationView {
            List {
                // Language Section
                Section(header: Text(L10n.Settings.language.localized)) {
                    ForEach(SupportedLanguage.allCases, id: \.self) { language in
                        HStack {
                            Text(language.displayName)
                            Spacer()
                            if selectedLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedLanguage != language {
                                selectedLanguage = language
                            }
                        }
                    }
                }
                
                // Unit Section - Currently disabled as backend only supports metric
                /*
                Section(header: Text(L10n.Settings.units.localized)) {
                    ForEach(UnitPreference.allCases, id: \.self) { unit in
                        HStack {
                            Text(unit.displayName)
                            Spacer()
                            if selectedUnit == unit {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedUnit != unit {
                                selectedUnit = unit
                            }
                        }
                    }
                }
                */
                
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
                    .disabled(isLoading || selectedLanguage == languageManager.currentLanguage)
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
        .alert(L10n.Language.changeConfirm.localized, isPresented: $showRestartAlert) {
            Button(L10n.Common.cancel.localized, role: .cancel) {
                // Reset selection
                selectedLanguage = languageManager.currentLanguage
            }
            Button(L10n.Common.confirm.localized) {
                Task {
                    await performLanguageChange()
                }
            }
        } message: {
            Text("The app will restart to apply the language change.")
        }
        .alert(L10n.Error.unknown.localized, isPresented: $showError) {
            Button(L10n.Common.done.localized) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var languageInfoFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Language preference will be synced with your account.")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            Text("Currently only metric units (km, min/km) are supported.")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            if selectedLanguage != languageManager.currentLanguage {
                Text("Changing the language requires app restart.")
                    .font(.footnote)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private func saveSettings() {
        // Check if language is changing
        if selectedLanguage != languageManager.currentLanguage {
            showRestartAlert = true
        }
        // Note: Unit preference changes removed until backend supports imperial units
    }
    
    private func performLanguageChange() async {
        isLoading = true
        
        do {
            // Update language preference
            languageManager.currentLanguage = selectedLanguage
            
            // Note: Unit preference update removed until backend supports imperial units
            
            // Sync with backend
            try await updateBackendPreferences()
            
            // Show success message
            await MainActor.run {
                isLoading = false
                dismiss()
                
                // The app will need to be restarted for full language change
                // In production, you might want to trigger an app restart here
                NotificationCenter.default.post(
                    name: NSNotification.Name("LanguageChanged"),
                    object: selectedLanguage
                )
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    // Note: Unit preference methods removed until backend supports imperial units
    
    private func updateBackendPreferences() async throws {
        // Create request to update preferences
        var request = URLRequest(url: URL(string: "\(APIConfig.baseURL)/user/preferences")!)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication token if available
        do {
            let token = try await AuthenticationService.shared.getIdToken()
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