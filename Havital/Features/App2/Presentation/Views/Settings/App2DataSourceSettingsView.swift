import SwiftUI

// MARK: - App2DataSourceSettingsView
/// 2.0「數據來源」（設計 frame-24 已連接／frame-25 未綁定警示，同一頁的兩種狀態）。
///
/// 切換與解綁**整段走 `DataSourceSwitchCoordinator`** —— 那支是從 1.4 設定頁抽出來的
/// 同一段流程（解綁另一端 → HealthKit 授權／OAuth → 寫回偏好與後端），兩個版面共用。
/// 這一頁只負責版面與確認對話框。
///
/// 設計與現況的差距（不硬造）：設計的「已連接 · 5 分鐘前同步」需要最後同步時間，
/// `GarminManager` 沒有這個狀態、後端也沒有這個讀口 → 只顯示「已連接」。
struct App2DataSourceSettingsView: View {

    let onClose: () -> Void
    @ObservedObject var viewModel: App2SettingsViewModel

    @ObservedObject private var garmin = GarminManager.shared
    @State private var pendingSwitch: DataSourceType?
    @State private var showsDisconnectConfirm = false
    @State private var isWorking = false

    private var current: DataSourceType { viewModel.currentDataSource }
    private var isUnbound: Bool { current == .unbound }

    var body: some View {
        App2SettingsPageScaffold(
            title: L10n.App2.Settings.dataSourceSection.localized,
            onBack: onClose,
            backIdentifier: "App2_DataSourceClose",
            titleIdentifier: "App2_DataSourceView"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if isUnbound {
                    unboundWarning
                } else {
                    Text(L10n.App2.Settings.dataSourceIntro.localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(App2Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                garminRow
                appleHealthRow

                if !isUnbound {
                    App2OnboardingNotice(
                        systemImage: "lock",
                        text: L10n.App2.Settings.dataSourcePrivacy.localized
                    )
                }
            }
        }
        .task { await garmin.checkConnectionStatusIfNeeded() }
        .alert(
            NSLocalizedString("datasource.switch.title", comment: "Switch Data Source"),
            isPresented: Binding(
                get: { pendingSwitch != nil },
                set: { if !$0 { pendingSwitch = nil } }
            )
        ) {
            Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {
                pendingSwitch = nil
            }
            Button(NSLocalizedString("common.confirm", comment: "")) {
                if let target = pendingSwitch {
                    pendingSwitch = nil
                    perform { await coordinator.switchDataSource(to: target) }
                }
            }
        } message: {
            Text(switchMessage)
        }
        .alert(
            L10n.App2.Settings.disconnect.localized,
            isPresented: $showsDisconnectConfirm
        ) {
            Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("common.confirm", comment: ""), role: .destructive) {
                perform { await coordinator.disconnectCurrentSource() }
            }
        } message: {
            Text(NSLocalizedString("datasource.switch.to_unbound", comment: ""))
        }
    }

    // MARK: - 列

    private var garminRow: some View {
        App2DataSourceRow(
            leading: { App2DataSourceTile.garmin },
            title: "Garmin Connect",
            subtitle: NSLocalizedString("datasource.garmin_subtitle", comment: ""),
            isConnected: current == .garmin,
            actionTitle: current == .garmin
                ? L10n.App2.Settings.disconnect.localized
                : NSLocalizedString("datasource.connect", comment: ""),
            actionIdentifier: "App2_DataSourceGarminAction",
            action: {
                if current == .garmin {
                    showsDisconnectConfirm = true
                } else {
                    pendingSwitch = .garmin
                }
            }
        )
        .accessibilityIdentifier("App2_DataSourceGarminRow")
    }

    private var appleHealthRow: some View {
        App2DataSourceRow(
            leading: { App2DataSourceTile.appleHealth },
            title: "Apple Health",
            subtitle: NSLocalizedString("datasource.apple_health_subtitle", comment: ""),
            isConnected: current == .appleHealth,
            actionTitle: current == .appleHealth
                ? L10n.App2.Settings.disconnect.localized
                : NSLocalizedString("datasource.connect", comment: ""),
            actionIdentifier: "App2_DataSourceAppleHealthAction",
            action: {
                if current == .appleHealth {
                    showsDisconnectConfirm = true
                } else {
                    pendingSwitch = .appleHealth
                }
            }
        )
        .accessibilityIdentifier("App2_DataSourceAppleHealthRow")
    }

    private var unboundWarning: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(App2Theme.accentOrange)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.App2.Settings.noSourceTitle.localized)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(App2Theme.accentOrangeText)
                Text(L10n.App2.Settings.noSourceBody.localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(App2Theme.accentOrangeBright.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(App2Theme.accentOrangeBright.opacity(0.4), lineWidth: 1)
        )
        .accessibilityIdentifier("App2_DataSourceUnboundWarning")
    }

    // MARK: - 動作

    private var coordinator: DataSourceSwitchCoordinator {
        DataSourceSwitchCoordinator(profileViewModel: viewModel.profile)
    }

    private func perform(_ work: @escaping () async -> Void) {
        guard !isWorking else { return }
        isWorking = true
        Task {
            await work()
            viewModel.refresh()
            isWorking = false
        }
    }

    /// 確認文案沿用 1.4 的 `datasource.switch.*`（同一組轉場，不另寫一套）。
    private var switchMessage: String {
        switch (current, pendingSwitch) {
        case (.unbound, .garmin):
            return NSLocalizedString("datasource.switch.garmin.select_auth", comment: "")
        case (.unbound, .appleHealth):
            return NSLocalizedString("datasource.switch.apple_health.select", comment: "")
        case (.garmin, .appleHealth):
            return NSLocalizedString("datasource.switch.garmin_to_apple", comment: "")
        case (.appleHealth, .garmin):
            return NSLocalizedString("datasource.switch.apple_to_garmin", comment: "")
        case (.strava, .appleHealth):
            return NSLocalizedString("datasource.switch.strava_to_apple", comment: "")
        case (.strava, .garmin):
            return NSLocalizedString("datasource.switch.strava_to_garmin", comment: "")
        default:
            return NSLocalizedString("datasource.switch.default", comment: "")
        }
    }
}
