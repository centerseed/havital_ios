import SwiftUI

// MARK: - App2SettingsView
/// 2.0 設定頁（`DESIGN-app2-decision-chain-api.md` §3.9a）。
struct App2SettingsView: View {

    @StateObject private var viewModel = App2SettingsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: App2Theme.sectionSpacing) {
                if let sourced = viewModel.snapshot {
                    accountCard(sourced)
                    dataSourceCard(sourced)
                    trainingCard(sourced)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.vertical, PacerizTokens.spacing.m)
        }
        .background(App2Theme.pageBackground.ignoresSafeArea())
        .accessibilityIdentifier("App2_SettingsView")
        .onAppear { viewModel.load() }
    }

    // MARK: - 帳號 ＋ 訂閱

    private func accountCard(_ sourced: App2Sourced<App2SettingsSnapshot>) -> some View {
        let snapshot = sourced.value
        return App2Card {
            HStack {
                App2SectionLabel(text: L10n.App2.Settings.accountSection.localized)
                Spacer()
                App2StubBadge(origin: sourced.origin)
            }
            Text(snapshot.accountEmail ?? "—")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(App2Theme.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Divider()

            HStack {
                Text(L10n.App2.Settings.subscriptionSection.localized)
                    .font(.app2Body)
                    .foregroundStyle(App2Theme.inkSecondary)
                Spacer()
                Text(snapshot.subscriptionLabel ?? "—")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(App2Theme.accentBlue)
            }
        }
        .accessibilityIdentifier("App2_SettingsAccountCard")
    }

    // MARK: - 數據來源

    private func dataSourceCard(_ sourced: App2Sourced<App2SettingsSnapshot>) -> some View {
        App2Card {
            HStack {
                App2SectionLabel(text: L10n.App2.Settings.dataSourceSection.localized)
                Spacer()
                App2StubBadge(origin: sourced.origin)
            }
            VStack(spacing: PacerizTokens.spacing.s) {
                ForEach(sourced.value.dataSources) { source in
                    HStack(spacing: PacerizTokens.spacing.m) {
                        Circle()
                            .fill(source.isConnected ? App2Theme.accentGreen : App2Theme.inkTertiary)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(source.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(App2Theme.inkPrimary)
                            Text(source.statusLabel)
                                .font(.app2Caption)
                                .foregroundStyle(App2Theme.inkTertiary)
                        }
                        Spacer()
                        App2Pill(
                            text: source.isConnected
                                ? L10n.App2.Settings.connected.localized
                                : L10n.App2.Settings.notConnected.localized,
                            foreground: source.isConnected ? App2Theme.accentGreen : App2Theme.accentBlue,
                            background: (source.isConnected ? App2Theme.accentGreen : App2Theme.accentBlue)
                                .opacity(0.12)
                        )
                    }
                    .padding(.vertical, PacerizTokens.spacing.s)
                    .padding(.horizontal, PacerizTokens.spacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: App2Theme.insetCornerRadius, style: .continuous)
                            .fill(App2Theme.insetBackground)
                    )
                }
            }
        }
        .accessibilityIdentifier("App2_SettingsDataSourceCard")
    }

    // MARK: - 訓練設定

    private func trainingCard(_ sourced: App2Sourced<App2SettingsSnapshot>) -> some View {
        let snapshot = sourced.value
        return App2Card {
            HStack {
                App2SectionLabel(text: L10n.App2.Settings.trainingSection.localized)
                Spacer()
                App2StubBadge(origin: sourced.origin)
            }

            settingRow(
                label: L10n.App2.Settings.weeklyDistance.localized,
                value: snapshot.weeklyDistanceKm.map { String(format: "%.0f km", $0) } ?? "—"
            )
            settingRow(
                label: L10n.App2.Settings.trainingDays.localized,
                value: snapshot.trainingDays.isEmpty
                    ? "—"
                    : snapshot.trainingDays.joined(separator: " · ")
            )
            settingRow(
                label: L10n.App2.Settings.raceCountdown.localized,
                value: "\(snapshot.raceCountdownDays)d"
            )

            App2InlineNotice(
                text: String(
                    format: L10n.App2.Common.stubFooter.localized,
                    App2StubFixtures.Section.raceCountdownPref
                )
            )
        }
        .accessibilityIdentifier("App2_SettingsTrainingCard")
    }

    private func settingRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.app2Body)
                .foregroundStyle(App2Theme.inkSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(App2Theme.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
