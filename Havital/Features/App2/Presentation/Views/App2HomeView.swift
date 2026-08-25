import SwiftUI

// MARK: - App2HomeView
/// 2.0 首頁 —— 設計 **frame-00「狀態 · 首頁」**。
///
/// 版面順序與設計一致：字標 ＋ LV 六角徽章 → 目標賽事卡（藍）→ 訓練狀況卡
/// （headline 句 ＋ 軌跡圖 ＋ 指標膠囊列／網格）→ 今日課表卡 → 意圖卡 → 週回顧入口。
/// 語意／端點對照仍是 `DESIGN-app2-decision-chain-api.md` §3.1／§3.1a／§3.2。
struct App2HomeView: View {

    /// 設定入口 —— 首頁是右上角的 LV 六角徽章（其他頁是頭像）。
    let onOpenSettings: () -> Void
    /// 由 `App2RootView` 持有 —— 切 tab 不重建、不重打 API（見 `App2Revalidating`）。
    @ObservedObject var viewModel: App2HomeViewModel
    /// 指標網格預設收合（設計的收合列就是一排彩色膠囊），點一下展開成 2 欄。
    @State private var isGridExpanded = false
    /// 內嵌 Rizo 卡點下去開的既有對話（`RizoChatView`，不另寫一份）。
    @State private var isShowingRizoChat = false
    @State private var rizoChatViewModel: StateRizoChatViewModel?

    private let insightColumns = [
        GridItem(.flexible(), spacing: 9),
        GridItem(.flexible(), spacing: 9)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                goalSection
                trainingStatusSection
                todaySection
                rizoCard
                weeklyReviewRow
            }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.top, 4)
            .padding(.bottom, App2Theme.tabBarClearance)
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        .accessibilityIdentifier("App2_HomeView")
        .task { await viewModel.loadIfNeeded() }
        // 下拉刷新＝強制重驗（跳過 60 秒門檻）。不清畫面、不進 loading。
        .refreshable { await viewModel.forceRefresh() }
        .sheet(isPresented: $isShowingRizoChat) {
            if let rizoChatViewModel {
                NavigationView {
                    ScrollView {
                        // 既有的對話元件，不另寫一份 2.0 版。
                        RizoChatView(viewModel: rizoChatViewModel)
                            .padding(16)
                    }
                    .background(App2Theme.pageGradient.ignoresSafeArea())
                }
            }
        }
    }

    private func openRizoChat() {
        let viewModelToUse = rizoChatViewModel
            ?? StateRizoChatViewModel(scenario: viewModel.rizoScenario ?? "body_status")
        rizoChatViewModel = viewModelToUse
        isShowingRizoChat = true
        Task { await viewModelToUse.startOpening() }
    }

    // MARK: - Header（字標 ＋ LV 六角徽章）

    private var header: some View {
        HStack(alignment: .center) {
            Text(verbatim: "Paceriz")
                .font(.system(size: 24, weight: .black))
                .tracking(0.5)
                .foregroundStyle(App2Theme.inkPrimary)
            Spacer()
            // §7-1：backend 沒有等級讀口 → 徽章只留字標，不顯示數字（票面剩餘差異）。
            // 徽章同時是首頁的**設定入口**（其他頁是頭像）。
            // Button 會吃掉 label 上的 identifier（同頁 insightHandle 的註解），
            // 所以用容器 ＋ onTapGesture。
            App2LevelBadge()
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpenSettings)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(L10n.App2.Tab.settings.localized)
                .accessibilityIdentifier("App2_HomeSettingsEntry")
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 0)
    }

    // MARK: - §3.1 目標賽事卡（設計：藍漸層卡）

    @ViewBuilder
    private var goalSection: some View {
        if let sourced = viewModel.goalCard {
            let goal = sourced.value
            App2AccentCard(padding: 18, spacing: 12) {
                HStack(spacing: 8) {
                    App2SectionLabel(text: L10n.App2.Home.goalSection.localized)
                    Spacer(minLength: 4)
                    App2StubBadge(origin: sourced.origin)
                    App2Pill(
                        text: goal.distanceLabel,
                        foreground: App2Theme.accentBlueDeep,
                        background: App2Theme.accentBlue.opacity(0.1),
                        border: App2Theme.accentBlue.opacity(0.22)
                    )
                    if let stage = goal.stageLabel {
                        App2Pill(text: stage)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(goal.raceName)
                        .font(.system(size: 23, weight: .black))
                        .foregroundStyle(App2Theme.inkPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(goal.raceDate)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(App2Theme.inkSubtle)
                }

                HStack(alignment: .bottom, spacing: 22) {
                    App2FieldColumn(
                        label: L10n.App2.Home.goalTarget.localized,
                        value: goal.targetTime ?? "—",
                        valueColor: App2Theme.accentBlueDark
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
                    Spacer(minLength: 0)
                }
            }
            .accessibilityIdentifier("App2_GoalCard")
        } else if viewModel.isLoading {
            loadingCard
        } else {
            // 沒有目標賽事就明說沒有 —— 不拿設計稿的示範賽事假裝成用戶的資料。
            App2AccentCard(padding: 18, spacing: 8) {
                App2SectionLabel(text: L10n.App2.Home.goalSection.localized)
                Text(L10n.App2.Home.noGoalTitle.localized)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                Text(L10n.App2.Home.noGoalBody.localized)
                    .font(.system(size: 14, weight: .medium))
                    .lineSpacing(2)
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("App2_GoalCard")
        }
    }

    // MARK: - §3.1a 訓練狀況卡

    @ViewBuilder
    private var trainingStatusSection: some View {
        if let sourced = viewModel.trainingStatus {
            let status = sourced.value
            App2Card(padding: 15, spacing: 13) {
                HStack {
                    Text(L10n.App2.Home.statusSection.localized)
                        .font(.app2CardTitle)
                        .tracking(0.5)
                        .foregroundStyle(App2Theme.inkPrimary)
                    Spacer()
                    App2StubBadge(origin: sourced.origin)
                }

                statusBanner(status)
                insightHandle
                if isGridExpanded { insightsGrid }
            }
            .accessibilityIdentifier("App2_TrainingStatusCard")
        }
    }

    /// 設計的 headline 區塊：淺藍底 inset，內含 headline 句、敘事句、軌跡圖、圖例。
    private func statusBanner(_ status: App2TrainingStatus) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(status.headline)
                .font(.system(size: 16, weight: .black))
                .tracking(0.3)
                .foregroundStyle(App2Theme.accentBlueDeep)
                .fixedSize(horizontal: false, vertical: true)

            if let narrative = status.narrative {
                Text(narrative)
                    .font(.system(size: 14, weight: .semibold))
                    .lineSpacing(3)
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            App2TrajectoryChart(
                points: viewModel.trajectoryPoints,
                currentWeek: status.currentWeek
            )
            .padding(.top, 12)

            HStack {
                App2TrajectoryLegend(
                    currentWeek: status.currentWeek,
                    totalWeeks: status.totalWeeks
                )
            }
            .padding(.top, 8)

            HStack {
                App2StubBadge(origin: viewModel.trajectoryOrigin)
                Spacer()
            }
            .padding(.top, 6)
        }
        .padding(EdgeInsets(top: 12, leading: 13, bottom: 12, trailing: 13))
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(App2Theme.accentBlue.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(App2Theme.accentBlue.opacity(0.16), lineWidth: 1)
        )
    }

    /// 收合列：一排彩色指標膠囊 ＋ 展開箭頭（設計 frame-00 那一排）。
    @ViewBuilder
    private var insightHandle: some View {
        if let sourced = viewModel.insights {
            // 用容器＋onTapGesture 而不是 Button：Button 會吃掉 label 上的
            // accessibilityIdentifier，maestro 在 accessibility tree 抓不到
            // （2026-08-25 實測，同頁的非 Button 卡片 id 都抓得到）。
            Group {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        ForEach(sourced.value) { insight in
                            App2InsightChip(insight: insight)
                        }
                    }
                    Spacer(minLength: 4)
                    // 收合態也要標樣本來源 —— 否則只有展開後才看得出這排膠囊不是真值。
                    App2StubBadge(origin: sourced.origin)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(App2Theme.inkMuted)
                        .rotationEffect(.degrees(isGridExpanded ? 180 : 0))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .app2InsetSurface(cornerRadius: 13)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) { isGridExpanded.toggle() }
            }
            // 做成單一 accessibility 葉節點：這一列全是彩色膠囊（SF Symbol ＋ 箭頭符號），
            // 沒有可讀文字，`.combine` 併出來的元素標籤是空的會被丟掉，identifier 也跟著
            // 不出現在 tree 上（2026-08-25 用 maestro 的 hierarchy dump 確認）。
            // 改成 `.ignore` ＋ 明確 label。
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(L10n.App2.Home.insightsSection.localized)
            .accessibilityIdentifier("App2_InsightHandle")
        }
    }

    @ViewBuilder
    private var insightsGrid: some View {
        if let sourced = viewModel.insights {
            VStack(alignment: .leading, spacing: 9) {
                LazyVGrid(columns: insightColumns, spacing: 9) {
                    ForEach(sourced.value) { insight in
                        App2InsightCell(insight: insight)
                    }
                }
                HStack {
                    Spacer()
                    App2StubBadge(origin: sourced.origin)
                }
            }
            .accessibilityIdentifier("App2_InsightsGrid")
        }
    }

    // MARK: - §3.1 今日課表卡（設計 frame-00 下半，完整版）

    @ViewBuilder
    private var todaySection: some View {
        switch viewModel.todayState {
        case .session(let session):
            todaySessionCard(session)
        case .notGenerated:
            todayEmptyCard(L10n.App2.Home.noPlanBody.localized)
        case .noSessionToday:
            todayEmptyCard(L10n.App2.Home.noSessionTodayBody.localized)
        case .unavailable:
            // **讀不到 ≠ 尚未產生。** 說錯這句話的代價是用戶以為課表沒生成
            // （2026-08-25 用戶截圖：首頁說沒有、課表頁一整週都在）。
            todayEmptyCard(L10n.App2.Home.planUnavailableBody.localized)
        case .none:
            if viewModel.isLoading { loadingCard }
        }
    }

    private func todaySessionCard(_ session: App2TodaySession) -> some View {
        App2Card(padding: 16, spacing: 11) {
            HStack {
                Text(L10n.App2.Home.todaySection.localized)
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(App2Theme.inkMuted)
                Spacer()
                Text(session.dayLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(App2Theme.inkTertiary)
            }

            HStack(alignment: .center, spacing: 9) {
                Text(session.title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                if let intensity = session.intensityLabel {
                    App2Chip(
                        text: intensity,
                        foreground: App2Theme.accentOrangeText,
                        background: App2Theme.accentOrangeSoft.opacity(0.16)
                    )
                }
                Spacer(minLength: 4)
                todayStatusPill
            }

            if let summary = session.summary {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(L10n.App2.Home.planRow.localized)
                        .font(.system(size: 13, weight: .heavy))
                        .tracking(0.5)
                        .foregroundStyle(App2Theme.inkMuted)
                    Text(summary)
                        .font(.app2Mono(15, weight: .bold))
                        .foregroundStyle(App2Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // 分段表 ＋ 右側結構預覽。payload 沒有結構就整段不出現。
            if !session.segments.isEmpty || !session.structureBars.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    if !session.segments.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(session.segments) { segment in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(segment.name)
                                        .font(.system(size: 13, weight: .heavy))
                                        .foregroundStyle(
                                            segment.isWork
                                                ? App2Theme.accentOrangeText
                                                : App2Theme.inkMuted
                                        )
                                    Spacer(minLength: 8)
                                    Text(segment.detail)
                                        .font(.app2Mono(13, weight: .bold))
                                        .foregroundStyle(App2Theme.inkSecondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("App2_TodaySegments")
                    }
                    if !session.structureBars.isEmpty {
                        App2SessionStructureChart(bars: session.structureBars)
                            .frame(width: 96)
                    }
                }
                .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                .app2InsetSurface(cornerRadius: 13)
            }

            if let strength = session.strengthLabel {
                HStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(App2Theme.accentBlueDeep)
                    Text(strength)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(App2Theme.inkPrimary)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(App2Theme.chevron)
                }
                .accessibilityIdentifier("App2_TodayStrengthRow")
            }
        }
        .accessibilityIdentifier("App2_TodaySessionCard")
    }

    private func todayEmptyCard(_ body: String) -> some View {
        App2Card(padding: 16, spacing: 11) {
            Text(L10n.App2.Home.todaySection.localized)
                .font(.system(size: 13, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(App2Theme.inkMuted)
            Text(body)
                .font(.system(size: 14, weight: .medium))
                .lineSpacing(2)
                .foregroundStyle(App2Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("App2_TodaySessionCard")
    }

    /// 「今天還沒跑 / 今天已跑」狀態點。完成與否目前沒有 producer
    /// （`/v2/state/today` 不帶當日完成旗標），一律顯示未完成態。
    private var todayStatusPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(App2Theme.accentOrangeBright)
                .frame(width: 6, height: 6)
            Text(L10n.App2.Home.todayTodo.localized)
                .font(.system(size: 13, weight: .heavy))
        }
        .foregroundStyle(App2Theme.accentOrangeText)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(App2Theme.accentOrangeSoft.opacity(0.16)))
    }

    // MARK: - 內嵌 Rizo 卡（設計 frame-00 今日課表卡下方）

    private var rizoCard: some View {
        App2Card(padding: 15, spacing: 11) {
            HStack(spacing: 10) {
                App2Avatar(initial: "R", size: 34, showsRing: false)
                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.App2.Home.rizoEntry.localized)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(App2Theme.inkPrimary)
                    Text(L10n.App2.Home.rizoCoachTitle.localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(App2Theme.inkTertiary)
                }
                Spacer(minLength: 4)
            }

            // 泡泡只在「組得出狀態句」時出現 —— 組不出來就退成純入口，不寫假對話。
            if let line = viewModel.rizoOpeningLine {
                Text(line)
                    .font(.system(size: 14, weight: .medium))
                    .lineSpacing(3)
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: 11, leading: 13, bottom: 11, trailing: 13))
                    .app2InsetSurface(cornerRadius: 14)
                    .accessibilityIdentifier("App2_RizoBubble")
            }

            HStack(spacing: 8) {
                Text(L10n.App2.Home.rizoInputPlaceholder.localized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(App2Theme.inkMuted)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Circle()
                    .fill(App2Theme.accentBlue)
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.white)
                    }
            }
            .padding(EdgeInsets(top: 7, leading: 13, bottom: 7, trailing: 7))
            .app2InsetSurface(cornerRadius: 20)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: openRizoChat)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("App2_RizoEntry")
    }

    // MARK: - 週回顧 CTA（設計 dc.html:272／5112 的狀態驅動時機卡）

    @ViewBuilder
    private var weeklyReviewRow: some View {
        switch viewModel.weekReview {
        case .notGenerated(let isCurrentWeek):
            entryRow(
                symbol: "chart.line.uptrend.xyaxis",
                title: isCurrentWeek
                    ? L10n.App2.Home.weekReviewGenerateCurrent.localized
                    : L10n.App2.Home.weekReviewGenerateLast.localized,
                subtitle: isCurrentWeek
                    ? L10n.App2.Home.weekReviewSubCurrent.localized
                    : L10n.App2.Home.weekReviewSubLast.localized,
                identifier: "App2_WeekReviewEntry"
            )
        case .available:
            entryRow(
                symbol: "chart.line.uptrend.xyaxis",
                title: L10n.App2.Home.weekReviewView.localized,
                subtitle: L10n.App2.Home.weekReviewViewSub.localized,
                identifier: "App2_WeekReviewEntry"
            )
        case .none:
            EmptyView()
        }
    }

    private func entryRow(symbol: String, title: String, subtitle: String, identifier: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [App2Theme.accentBlueLight, App2Theme.accentBlueDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: App2Theme.accentBlue.opacity(0.5), radius: 7, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(App2Theme.inkTertiary)
            }
            Spacer(minLength: 8)

            Circle()
                .fill(App2Theme.accentBlue.opacity(0.1))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(App2Theme.accentBlue)
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .app2CardSurface()
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
