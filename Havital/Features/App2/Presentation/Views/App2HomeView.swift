import SwiftUI

// MARK: - App2HomeView
/// 2.0 首頁（`DESIGN-app2-decision-chain-api.md` §3.1／§3.1a／§3.2 race_run 變體）。
struct App2HomeView: View {

    @StateObject private var viewModel = App2HomeViewModel()

    private let insightColumns = [
        GridItem(.flexible(), spacing: PacerizTokens.spacing.s),
        GridItem(.flexible(), spacing: PacerizTokens.spacing.s)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: App2Theme.sectionSpacing) {
                header
                goalSection
                trainingStatusSection
                todaySection
                intentSection
                entryPoints
            }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.bottom, PacerizTokens.spacing.xxl)
        }
        .background(App2Theme.pageBackground.ignoresSafeArea())
        .accessibilityIdentifier("App2_HomeView")
        .task { await viewModel.load() }
    }

    // MARK: - Header（greeting ＋ LV 徽章）

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.App2.Home.greeting.localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(App2Theme.inkTertiary)
                Text(verbatim: "Paceriz")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(App2Theme.inkPrimary)
            }
            Spacer()
            // §7-1：等級語意在設計稿裡沒有定義，已裁決為「徽章佔位」。
            levelBadge
        }
        .padding(.top, PacerizTokens.spacing.s)
    }

    private var levelBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [App2Theme.accentBlue, App2Theme.trackAhead],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
            VStack(spacing: -2) {
                Text(verbatim: "LV")
                    .font(.system(size: 8, weight: .bold))
                Text(verbatim: "—")
                    .font(.app2Numeric(15))
            }
            .foregroundStyle(.white)
        }
        .accessibilityIdentifier("App2_LevelBadge")
    }

    // MARK: - §3.1 目標賽事卡

    @ViewBuilder
    private var goalSection: some View {
        if let sourced = viewModel.goalCard {
            let goal = sourced.value
            App2Card(background: App2Theme.goalCardBackground) {
                HStack {
                    App2SectionLabel(text: L10n.App2.Home.goalSection.localized)
                    Spacer()
                    if let stage = goal.stageLabel {
                        App2Pill(text: stage)
                    }
                    App2StubBadge(origin: sourced.origin)
                }

                HStack(alignment: .firstTextBaseline, spacing: PacerizTokens.spacing.s) {
                    Text(goal.raceName)
                        .font(.app2CardTitle)
                        .foregroundStyle(App2Theme.inkPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(goal.raceDate)
                        .font(.app2Caption)
                        .foregroundStyle(App2Theme.inkTertiary)
                    Spacer()
                    App2Pill(
                        text: goal.distanceLabel,
                        foreground: App2Theme.accentBlue,
                        background: .white
                    )
                }

                HStack(alignment: .top, spacing: PacerizTokens.spacing.s) {
                    App2FieldColumn(
                        label: L10n.App2.Home.goalTarget.localized,
                        value: goal.targetTime ?? "—",
                        valueColor: App2Theme.accentBlue
                    )
                    App2FieldColumn(
                        label: L10n.App2.Home.goalEstimate.localized,
                        value: goal.estimatedFinish ?? "—",
                        valueColor: App2Theme.accentOrange
                    )
                    App2FieldColumn(
                        label: L10n.App2.Home.goalWeek.localized,
                        value: goal.currentWeek.map(String.init) ?? "—",
                        valueColor: App2Theme.inkPrimary,
                        suffix: goal.totalWeeks.map { "/\($0)" }
                    )
                }
            }
            .accessibilityIdentifier("App2_GoalCard")
        } else if viewModel.isLoading {
            loadingCard
        }
    }

    // MARK: - §3.1a 訓練狀況卡

    @ViewBuilder
    private var trainingStatusSection: some View {
        if let sourced = viewModel.trainingStatus {
            let status = sourced.value
            App2Card {
                HStack {
                    Text(L10n.App2.Home.statusSection.localized)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(App2Theme.inkPrimary)
                    Spacer()
                    App2StubBadge(origin: sourced.origin)
                }

                VStack(alignment: .leading, spacing: PacerizTokens.spacing.s) {
                    Text(status.headline)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(App2Theme.accentBlue)
                        .fixedSize(horizontal: false, vertical: true)

                    if let narrative = status.narrative {
                        Text(narrative)
                            .font(.app2Body)
                            .foregroundStyle(App2Theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    App2TrackBar(position: status.trackPosition)
                        .padding(.top, PacerizTokens.spacing.xs)
                }
                .padding(PacerizTokens.spacing.m)
                .background(
                    RoundedRectangle(cornerRadius: App2Theme.insetCornerRadius, style: .continuous)
                        .fill(App2Theme.insetBackground)
                )

                trajectoryBlock(status: status)
                insightsGrid
            }
            .accessibilityIdentifier("App2_TrainingStatusCard")
        }
    }

    private func trajectoryBlock(status: App2TrainingStatus) -> some View {
        VStack(alignment: .leading, spacing: PacerizTokens.spacing.xs) {
            HStack {
                App2StubBadge(origin: viewModel.trajectoryOrigin)
                Spacer()
                if let current = status.currentWeek, let total = status.totalWeeks {
                    Text(verbatim: "\(current)/\(total)")
                        .font(.app2Caption)
                        .foregroundStyle(App2Theme.inkTertiary)
                }
            }
            App2TrajectoryChart(
                points: viewModel.trajectoryPoints,
                currentWeek: status.currentWeek
            )
        }
    }

    @ViewBuilder
    private var insightsGrid: some View {
        if let sourced = viewModel.insights {
            VStack(alignment: .leading, spacing: PacerizTokens.spacing.s) {
                HStack {
                    App2SectionLabel(
                        text: L10n.App2.Home.insightsSection.localized,
                        color: App2Theme.inkTertiary
                    )
                    Spacer()
                    App2StubBadge(origin: sourced.origin)
                }
                LazyVGrid(columns: insightColumns, spacing: PacerizTokens.spacing.s) {
                    ForEach(sourced.value) { insight in
                        App2InsightCell(insight: insight)
                    }
                }
            }
            .accessibilityIdentifier("App2_InsightsGrid")
        }
    }

    // MARK: - §3.1 今日課表卡

    @ViewBuilder
    private var todaySection: some View {
        if let sourced = viewModel.todaySession {
            let session = sourced.value
            App2Card {
                HStack {
                    App2SectionLabel(
                        text: L10n.App2.Home.todaySection.localized,
                        color: App2Theme.inkTertiary
                    )
                    Spacer()
                    Text(session.dayLabel)
                        .font(.app2Caption)
                        .foregroundStyle(App2Theme.inkTertiary)
                    App2StubBadge(origin: sourced.origin)
                }
                HStack(alignment: .center, spacing: PacerizTokens.spacing.s) {
                    Text(session.title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(App2Theme.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let intensity = session.intensityLabel {
                        App2Pill(
                            text: intensity,
                            foreground: App2Theme.accentOrange,
                            background: App2Theme.accentOrange.opacity(0.12)
                        )
                    }
                    Spacer()
                }
                if let summary = session.summary {
                    Text(summary)
                        .font(.app2Body)
                        .foregroundStyle(App2Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityIdentifier("App2_TodaySessionCard")
        }
    }

    // MARK: - §3.10／§4.1 意圖確認卡（端點未落地，永遠是樣本）

    private var intentSection: some View {
        let intent = viewModel.intentCard.value
        return App2Card {
            HStack {
                App2SectionLabel(text: L10n.App2.Home.intentSection.localized)
                Spacer()
                App2StubBadge(origin: viewModel.intentCard.origin)
            }
            intentRow(label: L10n.App2.Home.intentPursuing.localized,
                      text: intent.pursuing,
                      color: App2Theme.accentBlue)
            intentRow(label: L10n.App2.Home.intentMaintaining.localized,
                      text: intent.maintaining,
                      color: App2Theme.accentGreen)
            intentRow(label: L10n.App2.Home.intentDeferring.localized,
                      text: intent.deferring,
                      color: App2Theme.inkTertiary)
            App2InlineNotice(
                text: String(
                    format: L10n.App2.Common.stubFooter.localized,
                    App2StubFixtures.Section.intent
                )
            )
        }
        .accessibilityIdentifier("App2_IntentCard")
    }

    private func intentRow(label: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: PacerizTokens.spacing.s) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.app2FieldLabel)
                    .foregroundStyle(color)
                Text(text)
                    .font(.app2Body)
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Rizo ／週回顧入口（§3.1 末兩列）

    private var entryPoints: some View {
        HStack(spacing: PacerizTokens.spacing.m) {
            entryButton(
                title: L10n.App2.Home.rizoEntry.localized,
                systemImage: "bubble.left.and.text.bubble.right",
                identifier: "App2_RizoEntry"
            )
            entryButton(
                title: L10n.App2.Home.weekReviewEntry.localized,
                systemImage: "chart.bar.doc.horizontal",
                identifier: "App2_WeekReviewEntry"
            )
        }
    }

    private func entryButton(title: String, systemImage: String, identifier: String) -> some View {
        HStack(spacing: PacerizTokens.spacing.s) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(App2Theme.accentBlue)
        .frame(maxWidth: .infinity)
        .padding(.vertical, PacerizTokens.spacing.m)
        .background(
            RoundedRectangle(cornerRadius: App2Theme.insetCornerRadius, style: .continuous)
                .fill(App2Theme.cardBackground)
        )
        .shadow(color: App2Theme.shadowColor, radius: App2Theme.shadowRadius, x: 0, y: App2Theme.shadowY)
        .accessibilityIdentifier(identifier)
    }

    private var loadingCard: some View {
        App2Card {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .frame(height: 80)
        }
    }
}
