import SwiftUI

struct TimezoneSettingsView: View {
    @StateObject private var userPreferenceManager = UserPreferenceManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTimezone: String
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showWarningAlert = false

    // 常用時區列表
    let commonTimezones = [
        TimezoneOption(id: "Asia/Taipei", name: "台北 (GMT+8)", offset: "+08:00"),
        TimezoneOption(id: "Asia/Tokyo", name: "東京 (GMT+9)", offset: "+09:00"),
        TimezoneOption(id: "Asia/Hong_Kong", name: "香港 (GMT+8)", offset: "+08:00"),
        TimezoneOption(id: "Asia/Singapore", name: "新加坡 (GMT+8)", offset: "+08:00"),
        TimezoneOption(id: "America/New_York", name: "紐約 (GMT-5/-4)", offset: "-05:00"),
        TimezoneOption(id: "America/Los_Angeles", name: "洛杉磯 (GMT-8/-7)", offset: "-08:00"),
        TimezoneOption(id: "Europe/London", name: "倫敦 (GMT+0/+1)", offset: "+00:00"),
        TimezoneOption(id: "Australia/Sydney", name: "雪梨 (GMT+10/+11)", offset: "+10:00")
    ]

    init() {
        let currentTimezone = UserPreferenceManager.shared.timezonePreference ?? UserPreferenceManager.getDeviceTimezone()
        _selectedTimezone = State(initialValue: currentTimezone)
    }

    var body: some View {
        NavigationView {
            List {
                // Current Timezone Section
                Section(header: Text(L10n.Timezone.current.localized)) {
                    Text(UserPreferenceManager.getTimezoneDisplayName(for: selectedTimezone))
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                // Common Timezones Section
                Section(header: Text(L10n.Timezone.commonTimezones.localized)) {
                    ForEach(commonTimezones, id: \.id) { timezone in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(timezone.name)
                                    .font(.body)
                                Text(timezone.id)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedTimezone == timezone.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedTimezone != timezone.id {
                                selectedTimezone = timezone.id
                            }
                        }
                    }
                }

                // Info Section
                Section(footer: timezoneInfoFooter) {
                    EmptyView()
                }
            }
            .navigationTitle(L10n.Timezone.title.localized)
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
                    .disabled(isLoading || selectedTimezone == userPreferenceManager.timezonePreference)
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
        .alert(L10n.Timezone.changeConfirm.localized, isPresented: $showWarningAlert) {
            Button(L10n.Common.cancel.localized, role: .cancel) {
                // Reset selection
                selectedTimezone = userPreferenceManager.timezonePreference ?? UserPreferenceManager.getDeviceTimezone()
            }
            Button(L10n.Common.confirm.localized) {
                Task {
                    await performTimezoneChange()
                }
            }
        } message: {
            Text(L10n.Timezone.changeWarningMessage.localized)
        }
        .alert(L10n.Error.unknown.localized, isPresented: $showError) {
            Button(L10n.Common.done.localized) { }
        } message: {
            Text(errorMessage)
        }
    }

    private var timezoneInfoFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Timezone.syncMessage.localized)
                .font(.footnote)
                .foregroundColor(.secondary)

            if selectedTimezone != userPreferenceManager.timezonePreference {
                Text(L10n.Timezone.changeWarningMessage.localized)
                    .font(.footnote)
                    .foregroundColor(.orange)
            }
        }
    }

    private func saveSettings() {
        // Check if timezone is changing
        if selectedTimezone != userPreferenceManager.timezonePreference {
            showWarningAlert = true
        }
    }

    private func performTimezoneChange() async {
        isLoading = true

        do {
            // Sync with backend first
            try await UserPreferencesService.shared.updateTimezone(selectedTimezone)

            // Update local preference
            await MainActor.run {
                userPreferenceManager.timezonePreference = selectedTimezone
                isLoading = false
                dismiss()
            }

            Logger.firebase("時區已更新: \(selectedTimezone)", level: .info)

        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }

            Logger.firebase("時區更新失敗: \(error.localizedDescription)", level: .error)
        }
    }
}

// MARK: - Timezone Option Model
struct TimezoneOption: Identifiable {
    let id: String
    let name: String
    let offset: String
}

// MARK: - Preview
struct TimezoneSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        TimezoneSettingsView()
    }
}
