//
//  TimezoneSettingsView.swift
//  Havital
//
//  時區設定視圖
//
//  ⚠️ MERGE CONFLICT NOTICE ⚠️
//  此檔案在 dev_strava 分支已存在版本
//  合併時請比對差異，主要改進：
//  - 使用 TimezoneOption 模型（在 UserPreferencesService 中定義）
//  - 改進的 UI 佈局和錯誤處理
//  - 與新架構 UserPreferencesService 整合
//

import SwiftUI

struct TimezoneSettingsView: View {
    @StateObject private var userPreferenceManager = UserPreferenceManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTimezone: String
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    init() {
        // 初始化：優先使用本地保存的時區，否則使用裝置時區
        let initialTimezone = UserPreferenceManager.shared.timezonePreference ?? TimeZone.current.identifier
        _selectedTimezone = State(initialValue: initialTimezone)
    }

    var body: some View {
        NavigationView {
            List {
                // 當前時區資訊
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("timezone.current_device", comment: "裝置時區"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(deviceTimezoneDisplayName)
                                .font(.body)
                        }
                        Spacer()
                        Button(NSLocalizedString("timezone.use_device", comment: "使用裝置時區")) {
                            selectedTimezone = TimeZone.current.identifier
                        }
                        .font(.caption)
                        .disabled(selectedTimezone == TimeZone.current.identifier)
                    }
                } header: {
                    Text(NSLocalizedString("timezone.device_timezone", comment: "裝置時區"))
                }

                // 常用時區列表
                Section(header: Text(NSLocalizedString("timezone.common_timezones", comment: "常用時區"))) {
                    ForEach(TimezoneOption.commonTimezones) { timezone in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(timezone.displayName)
                                    .font(.body)
                                Text(timezone.offset)
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
                            selectedTimezone = timezone.id
                        }
                    }
                }

                // 說明資訊
                Section(footer: timezoneInfoFooter) {
                    EmptyView()
                }
            }
            .navigationTitle(NSLocalizedString("timezone.title", comment: "時區設定"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("common.cancel", comment: "取消")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.save", comment: "儲存")) {
                        saveTimezone()
                    }
                    .disabled(isLoading || selectedTimezone == userPreferenceManager.timezonePreference)
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView(NSLocalizedString("common.loading", comment: "載入中..."))
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
            }
        }
        .alert(NSLocalizedString("error.unknown", comment: "錯誤"), isPresented: $showError) {
            Button(NSLocalizedString("common.done", comment: "完成")) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Computed Properties

    private var deviceTimezoneDisplayName: String {
        let tz = TimeZone.current
        let displayName = tz.localizedName(for: .standard, locale: Locale.current) ?? tz.identifier
        let offsetSeconds = tz.secondsFromGMT()
        let offsetHours = offsetSeconds / 3600
        let offsetString = String(format: "GMT%+d", offsetHours)
        return "\(displayName) (\(offsetString))"
    }

    private var timezoneInfoFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("timezone.sync_message", comment: "時區設定會同步到伺服器，影響訓練計劃的週數計算"))
                .font(.footnote)
                .foregroundColor(.secondary)

            if selectedTimezone != userPreferenceManager.timezonePreference {
                Text(NSLocalizedString("timezone.change_warning", comment: "變更時區可能影響訓練週數計算"))
                    .font(.footnote)
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Actions

    private func saveTimezone() {
        Task {
            isLoading = true

            do {
                // 同步到後端
                try await UserPreferencesService.shared.updateTimezone(selectedTimezone)

                // 更新本地設定
                await MainActor.run {
                    userPreferenceManager.timezonePreference = selectedTimezone
                    isLoading = false
                    dismiss()
                }

                Logger.info("時區已更新: \(selectedTimezone)")
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
                Logger.error("時區更新失敗: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Preview
struct TimezoneSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        TimezoneSettingsView()
    }
}
