import SwiftUI

// MARK: - App2SystemSettingsView
/// 2.0「系統」（設計 frame-28）：語言、時區、距離單位。
///
/// 三條寫入全部落在既有出口，沒有第二份：
/// - 語言 → `LanguageManager.performLanguageChangeWithRestart`（先 PUT `/user/preferences`
///   成功才套用本地並重啟；App 顯示語言是 authority，backend 只保存同步結果）。
/// - 時區 → `UserProfileFeatureViewModel.updateTimezone`（`UserPreferencesRepository`）。
/// - 距離單位 → `UserProfileFeatureViewModel.updateUnitSystem` ＋ `UnitManager`。
///
/// 時區清單直接用既有的 `TimezoneSettingsView`（1.4 那一頁就是搜尋 ＋ 常用清單），
/// 不在 2.0 再做一份選單。
struct App2SystemSettingsView: View {

    let onClose: () -> Void
    @ObservedObject var viewModel: App2SettingsViewModel

    @ObservedObject private var languageManager = LanguageManager.shared
    @ObservedObject private var unitManager = UnitManager.shared
    @ObservedObject private var appearanceStore = App2AppearanceStore.shared

    @State private var isShowingTimezone = false
    @State private var isChangingLanguage = false
    @State private var languageError: String?

    var body: some View {
        App2SettingsPageScaffold(
            title: L10n.App2.Settings.systemSection.localized,
            onBack: onClose,
            backIdentifier: "App2_SystemSettingsClose",
            titleIdentifier: "App2_SystemSettingsView"
        ) {
            VStack(alignment: .leading, spacing: 20) {
                languageSection
                appearanceSection
                timezoneSection
                unitSection
            }
        }
        // 時區用 `fullScreenCover` 而不是 `sheet`：這一整條設定頁本身就開在
        // `fullScreenCover` 裡，巢狀的 sheet 不會進 accessibility tree（repo 既有坑）。
        .fullScreenCover(isPresented: $isShowingTimezone) {
            TimezoneSettingsView(currentTimezone: viewModel.profile.timezonePreference)
        }
        .onReceive(languageManager.$lastSyncError) { error in
            languageError = error
        }
        .alert(
            NSLocalizedString("error.unknown", comment: ""),
            isPresented: Binding(
                get: { languageError != nil },
                set: { if !$0 { languageError = nil; languageManager.lastSyncError = nil } }
            )
        ) {
            Button(NSLocalizedString("common.ok", comment: "OK")) {
                languageError = nil
                languageManager.lastSyncError = nil
            }
        } message: {
            Text(languageError ?? "")
        }
    }

    // MARK: - 語言

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: NSLocalizedString("settings.language", comment: "Language"))

            App2GroupedList {
                ForEach(Array(SupportedLanguage.allCases.enumerated()), id: \.element) { index, language in
                    languageRow(
                        language,
                        showsDivider: index < SupportedLanguage.allCases.count - 1
                    )
                }
            }
            .opacity(isChangingLanguage ? 0.5 : 1)
            .allowsHitTesting(!isChangingLanguage)
        }
    }

    private func languageRow(_ language: SupportedLanguage, showsDivider: Bool) -> some View {
        let isSelected = languageManager.currentLanguage == language
        return VStack(spacing: 0) {
            HStack {
                Text(language.displayName)
                    .font(.system(size: 16, weight: isSelected ? .black : .semibold))
                    .foregroundStyle(App2Theme.inkPrimary)
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(App2Theme.accentBlue)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
            .onTapGesture { select(language) }

            if showsDivider {
                Rectangle()
                    .fill(App2Theme.insetBorder)
                    .frame(height: 1)
                    .padding(.horizontal, 15)
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("App2_SystemLanguage_\(language.rawValue)")
    }

    private func select(_ language: SupportedLanguage) {
        guard !isChangingLanguage, languageManager.currentLanguage != language else { return }
        isChangingLanguage = true
        Task {
            // 唯一的語言切換入口：先同步後端，成功才套用本地並重啟。
            _ = await languageManager.performLanguageChangeWithRestart(to: language)
            isChangingLanguage = false
        }
    }

    // MARK: - 外觀

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: L10n.App2.Settings.appearance.localized)

            App2GroupedList {
                ForEach(Array(App2AppearancePreference.allCases.enumerated()), id: \.element) { index, option in
                    appearanceRow(
                        option,
                        showsDivider: index < App2AppearancePreference.allCases.count - 1
                    )
                }
            }
        }
    }

    private func appearanceRow(_ option: App2AppearancePreference, showsDivider: Bool) -> some View {
        let isSelected = appearanceStore.preference == option
        return VStack(spacing: 0) {
            HStack {
                Text(option.displayName)
                    .font(.system(size: 16, weight: isSelected ? .black : .semibold))
                    .foregroundStyle(App2Theme.inkPrimary)
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(App2Theme.accentBlue)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
            .onTapGesture { appearanceStore.preference = option }

            if showsDivider {
                Rectangle()
                    .fill(App2Theme.insetBorder)
                    .frame(height: 1)
                    .padding(.horizontal, 15)
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("App2_SystemAppearance_\(option.rawValue)")
    }

    // MARK: - 時區

    private var timezoneSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: NSLocalizedString("settings.timezone", comment: "Timezone"))

            App2GroupedList {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timezoneName)
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(App2Theme.inkPrimary)
                        Text(timezoneDetail)
                            .font(.app2Mono(12, weight: .bold))
                            .foregroundStyle(App2Theme.inkMuted)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(App2Theme.chevron)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 14)
            }
            .contentShape(Rectangle())
            .onTapGesture { isShowingTimezone = true }
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("App2_SystemTimezoneRow")
        }
    }

    private var timezoneIdentifier: String {
        viewModel.profile.timezonePreference ?? TimezoneOption.getDeviceTimezoneId()
    }

    private var timezoneName: String {
        TimezoneOption.getDisplayName(for: timezoneIdentifier)
    }

    private var timezoneDetail: String {
        "\(TimezoneOption.getCurrentOffset(for: timezoneIdentifier)) · \(timezoneIdentifier)"
    }

    // MARK: - 距離單位

    private var unitSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: L10n.App2.Settings.unitSection.localized)

            App2Card(spacing: 10) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(App2Theme.accentBlue.opacity(0.1))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "ruler")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(App2Theme.accentBlueDeep)
                        )
                    Text(L10n.App2.Settings.distanceUnit.localized)
                        .font(.app2RowTitle)
                        .foregroundStyle(App2Theme.inkPrimary)
                    Spacer(minLength: 8)
                    unitToggle
                }

                Text(L10n.App2.Settings.unitNote.localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(App2Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("App2_SystemUnitCard")
        }
    }

    private var unitToggle: some View {
        HStack(spacing: 2) {
            ForEach(UnitSystem.allCases, id: \.rawValue) { system in
                let isSelected = unitManager.currentUnitSystem == system
                Text(shortLabel(system))
                    .font(.system(size: 13, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(isSelected ? App2Theme.inkPrimary : App2Theme.inkMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(App2Theme.cardBackground)
                                .shadow(color: App2Theme.shadowInk.opacity(0.1), radius: 3, y: 2)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { select(system) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("App2_SystemUnit_\(system.rawValue)")
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(App2Theme.insetBackground)
        )
    }

    /// `UnitSystem.displayName` 是「公制（公里）」這種長標，塞不進膠囊 → 用短標。
    private func shortLabel(_ system: UnitSystem) -> String {
        switch system {
        case .metric: return L10n.App2.Settings.unitMetric.localized
        case .imperial: return L10n.App2.Settings.unitImperial.localized
        }
    }

    private func select(_ system: UnitSystem) {
        guard unitManager.currentUnitSystem != system else { return }
        let previous = unitManager.currentUnitSystem
        unitManager.currentUnitSystem = system
        Task {
            do {
                try await viewModel.profile.updateUnitSystem(system)
            } catch {
                // 後端寫入失敗就回滾，畫面不留一個沒同步的值。
                unitManager.currentUnitSystem = previous
                Logger.error("[App2SystemSettings] 單位同步失敗: \(error.localizedDescription)")
            }
        }
    }
}
