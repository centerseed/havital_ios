import SwiftUI

struct TimezoneSettingsView: View {
    @StateObject private var viewModel = UserProfileFeatureViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTimezone: String
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showWarningAlert = false

    /// Initialize with current timezone
    /// - Parameter currentTimezone: The user's current timezone (pass from parent view)
    init(currentTimezone: String? = nil) {
        // Use provided timezone, or fall back to device timezone
        let initialTimezone = currentTimezone ?? TimezoneOption.getDeviceTimezoneId()
        _selectedTimezone = State(initialValue: initialTimezone)
    }

    var body: some View {
        NavigationView {
            List {
                // Current Timezone Section
                Section(header: Text(L10n.Timezone.current.localized)) {
                    Text(TimezoneOption.getDisplayName(for: selectedTimezone))
                        .font(AppFont.headline())
                        .foregroundColor(.primary)
                }

                // Common Timezones Section
                Section(header: Text(L10n.Timezone.commonTimezones.localized)) {
                    ForEach(TimezoneOption.commonTimezones, id: \.id) { timezone in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(timezone.displayName)
                                    .font(AppFont.body())
                                Text(timezone.offset)
                                    .font(AppFont.caption())
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
                    .disabled(isLoading || selectedTimezone == viewModel.timezonePreference)
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
                // Reset selection to current saved preference or device default
                selectedTimezone = viewModel.timezonePreference ?? TimezoneOption.getDeviceTimezoneId()
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
                .font(AppFont.footnote())
                .foregroundColor(.secondary)

            if selectedTimezone != viewModel.timezonePreference {
                Text(L10n.Timezone.changeWarningMessage.localized)
                    .font(AppFont.footnote())
                    .foregroundColor(.orange)
            }
        }
    }

    private func saveSettings() {
        // Check if timezone is changing
        if selectedTimezone != viewModel.timezonePreference {
            showWarningAlert = true
        }
    }

    private func performTimezoneChange() async {
        isLoading = true

        do {
            // Use new ViewModel to sync timezone to backend
            try await viewModel.updateTimezone(selectedTimezone)

            await MainActor.run {
                isLoading = false
                dismiss()
            }

            Logger.firebase("時區已更新: \(selectedTimezone)", level: .info)

        } catch {
            // 任務取消是正常行為，不記錄錯誤
            if error.isCancellationError {
                Logger.debug("時區更新任務被取消，忽略錯誤")
                return
            }

            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }

            Logger.firebase("時區更新失敗: \(error.localizedDescription)", level: .error)
        }
    }
}

// MARK: - Preview
struct TimezoneSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        TimezoneSettingsView()
    }
}
