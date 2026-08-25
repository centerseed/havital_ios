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
    /// 訓練計畫總覽（設計 frame-20）。
    ///
    /// **入口是目標賽事卡。** 設計包沒有替 frame-20 定義入口（它的頁首是返回鍵，
    /// 表示是被推出來的頁），而首頁的目標賽事卡就是這份計畫在首頁的臉 —— 期別、
    /// 第 N / M 週都在這張卡上，點它看完整期程是最短的路徑。卡片右側加了一個
    /// chevron，不然這是一個看不出來的點擊區。
    @State private var isShowingPlanOverview = false
    /// 今日課表卡點下去開的訓練詳情（設計 frame-02）。nil = 沒開。
    @State private var detailSession: App2SessionDetail?
    /// 模態頁的 ViewModel 在這裡持有（tab 才由 `App2RootView` 持有）——
    /// 沒被打開過就不會 fetch（載入在被呈現那一頁的 `.task`）。
    @StateObject private var planOverviewViewModel = App2PlanOverviewViewModel()

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
        .fullScreenCover(isPresented: $isShowingPlanOverview) {
            App2PlanOverviewView(
                onClose: {
                    isShowingPlanOverview = false
                    // 在計畫頁改過賽事／重設目標時，首頁的目標卡與週次要跟著換。
                    Task { await viewModel.forceRefresh() }
                },
                viewModel: planOverviewViewModel
            )
        }
        .fullScreenCover(item: $detailSession) { detail in
            App2SessionDetailView(detail: detail) { detailSession = nil }
        }
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
                // 併成單一葉節點，否則 identifier 掛在容器上、a11y tree 只看得到
                // 裡面的 "LV" 字（同頁 insightHandle 踩過同一個坑）。
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(L10n.App2.Tab.settings.localized)
                // 併節點會蓋掉徽章自己掛的 identifier，所以整個入口就叫
                // `App2_LevelBadge`（設定入口＝這顆徽章，只有一個名字）。
                .accessibilityIdentifier("App2_LevelBadge")
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
                    // 點整張卡進訓練計畫總覽（frame-20）。沒有這顆 chevron 的話，
                    // 這個點擊區在畫面上看不出來。
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(App2Theme.chevron)
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
            .contentShape(Rectangle())
            .onTapGesture { isShowingPlanOverview = true }
            .accessibilityAddTraits(.isButton)
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

    /// 今日課表卡是**一張卡**：課表內容 ＋（分隔）＋ 卡內的 Rizo 對話帶
    /// （2026-08-25 用戶更正：Rizo 不是下面另一張卡）。
    @ViewBuilder
    private var todaySection: some View {
        if viewModel.todayState == nil {
            if viewModel.isLoading { loadingCard }
        } else {
            App2Card(padding: 16, spacing: 11) {
                switch viewModel.todayState {
                case .session(let session):
                    // 點課表內容進訓練詳情（frame-02）。**只有課表那一段可點** ——
                    // 卡片下半的 Rizo 對話帶有自己的目的地，整張卡一起可點會互吃。
                    // 休息日沒有詳情（`todayDetail` 為 nil），那時就只是靜態內容。
                    todaySessionContent(session)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard let detail = viewModel.todayDetail else { return }
                            detailSession = detail
                        }
                case .notGenerated:
                    todayEmptyContent(L10n.App2.Home.noPlanBody.localized)
                case .noSessionToday:
                    todayEmptyContent(L10n.App2.Home.noSessionTodayBody.localized)
                case .unavailable:
                    // **讀不到 ≠ 尚未產生。** 說錯這句話的代價是用戶以為課表沒生成
                    // （2026-08-25 用戶截圖：首頁說沒有、課表頁一整週都在）。
                    todayEmptyContent(L10n.App2.Home.planUnavailableBody.localized)
                case .none:
                    EmptyView()
                }

                Rectangle()
                    .fill(App2Theme.insetBorder)
                    .frame(height: 1)
                    .padding(.top, 2)

                rizoBand
            }
            .accessibilityIdentifier("App2_TodaySessionCard")
        }
    }

    /// 今日課表卡的內容（設計 dc.html「今日課表 · 輕鬆跑／節奏跑／長距離／休息日卡片」）。
    ///
    /// 四張卡是**同一個版式的四種課型**，不是四支 view：課型標題 ＋ 強度 chip ＋ 狀態 chip
    /// → 課表摘要行 → 分段列 →（長距離）補給建議框 → Rizo。休息日換成月亮回充帶 ＋
    /// 「想動一下？」交叉訓練列。
    ///
    /// **設計的「體感強度 n/10 · Z 區」那張卡沒有做**：週課表 payload 沒有 RPE 也沒有
    /// 訓練區間欄位（只有 `heart_rate_range` 的心率上下限與 `climate_meta`），
    /// 本機推一個 3/10 出來就是編的。缺口已記在票面。
    @ViewBuilder
    private func todaySessionContent(_ session: App2TodaySession) -> some View {
        Group {
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
                        foreground: sessionAccent(session).app2Darkened,
                        background: sessionAccent(session).opacity(0.14)
                    )
                }
                Spacer(minLength: 4)
                todayStatusPill(isRest: session.isRest)
            }

            if session.isRest {
                restBand
                crossTrainingRow
            } else {
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

                // 分段列。payload 組不出任何一段就整段不出現（不用 placeholder 補行）。
                if !session.segments.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(session.segments) { segment in
                            App2PhaseRow(
                                name: segment.name,
                                detail: segment.detail,
                                accent: sessionAccent(session),
                                isMain: segment.isWork
                            )
                        }
                    }
                    .accessibilityIdentifier("App2_TodaySegments")
                }

                if session.showsFuelingNote {
                    App2NoteBox(symbol: "cup.and.saucer.fill") {
                        Text(L10n.App2.Session.fuelingNote.localized)
                            .font(.system(size: 13, weight: .semibold))
                            .lineSpacing(3)
                            .foregroundStyle(App2Theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityIdentifier("App2_TodayFuelingNote")
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
        }
    }

    private func sessionAccent(_ session: App2TodaySession) -> Color {
        session.dayType?.app2StripColor ?? App2Theme.accentGreenBright
    }

    /// 休息日的月亮回充帶（設計 dc.html「今日課表 · 休息日卡片」）。
    private var restBand: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(App2Theme.inkSubtle)
            Text(L10n.App2.Home.restTitle.localized)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(App2Theme.inkPrimary)
            Text(L10n.App2.Home.restBody.localized)
                .font(.system(size: 13, weight: .semibold))
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .foregroundStyle(App2Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .app2InsetSurface(cornerRadius: 14)
        .accessibilityIdentifier("App2_TodayRestBand")
    }

    /// 「想動一下？」交叉訓練列。
    /// **目前沒有目的地**：交叉訓練的挑選／記錄在 2.0 還沒有出口，所以這一列不可點
    /// （設計的 chevron 保留為視覺，不做按下去什麼都不發生的鈕）。
    private var crossTrainingRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.mixed.cardio")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(App2Theme.inkSubtle)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.App2.Home.crossTitle.localized)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(App2Theme.inkPrimary)
                Text(L10n.App2.Home.crossBody.localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(App2Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .app2InsetSurface(cornerRadius: 13)
        .accessibilityIdentifier("App2_TodayCrossRow")
    }

    @ViewBuilder
    private func todayEmptyContent(_ body: String) -> some View {
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

    /// 狀態 chip：有課的日子是「今天還沒跑」（橘點），休息日是「安排休息」（綠勾）。
    /// 完成與否目前沒有 producer（`/v2/state/today` 不帶當日完成旗標），
    /// 有課的日子一律顯示未完成態。
    private func todayStatusPill(isRest: Bool) -> some View {
        HStack(spacing: 5) {
            if isRest {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .black))
            } else {
                Circle()
                    .fill(App2Theme.accentOrangeBright)
                    .frame(width: 6, height: 6)
            }
            Text(isRest
                 ? L10n.App2.Home.todayRest.localized
                 : L10n.App2.Home.todayTodo.localized)
                .font(.system(size: 13, weight: .heavy))
        }
        .foregroundStyle(isRest ? App2Theme.accentGreen : App2Theme.accentOrangeText)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(
                (isRest ? App2Theme.accentGreenBright : App2Theme.accentOrangeSoft).opacity(0.16)
            )
        )
    }

    // MARK: - 卡內 Rizo 對話帶（設計 frame-00：今日課表卡的最後一段，不是另一張卡）

    private var rizoBand: some View {
        VStack(alignment: .leading, spacing: 11) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
