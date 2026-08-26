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
    /// 訓練狀況卡左側那顆徽章的來源 —— **與成就 tab 同一個 ViewModel**
    /// （`GET /v2/achievements/summary`），所以兩處顯示的一定是同一顆，
    /// 也不會為了首頁多打一次端點（`loadIfNeeded` 是 SWR）。
    @ObservedObject var achievementsViewModel: PersonalAchievementsViewModel
    /// 指標網格預設收合（設計的收合列就是一排彩色膠囊），點一下展開成 2 欄。
    @State private var isGridExpanded = false
    /// 訓練狀況卡預設收合（設計 frame-00c-status-collapsed：徽章＋headline＋
    /// 「為什麼？」）；展開後才補 `narrative_text` 與內嵌 Rizo 輸入列。
    @State private var isStatusExpanded = false
    /// 內嵌 Rizo 入口點下去開的對話 sheet（設計 frame-00d）。有值＝sheet 開著，
    /// 值本身就是這次對話的 context（今日建議／今日課表）。
    @State private var rizoSheetContext: App2RizoChatSheet.Context?
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
    /// 今天已跑完那一筆的訓練詳情（設計 frame-15）。nil = 沒開。
    @State private var detailWorkout: WorkoutV2?
    /// 週回顧（設計 frame-18／19）。存的是要看第幾週。nil = 沒開。
    @State private var weeklyReviewWeek: App2WeeklyReviewTarget?
    /// 通知清單（首頁 v2 的鈴鐺）。
    ///
    /// **開的是既有的訊息中心** `MessageCenterView`（公告模組，AC-ANN-03），
    /// 不另做一頁 2.0 專用的通知清單 —— 那會是同一件事的第二份實作，
    /// 而且它已經有真的 producer（未讀數就是那顆紅點的來源）。
    @State private var isShowingNotifications = false
    @StateObject private var announcementViewModel = AnnouncementViewModel(
        repository: DependencyContainer.shared.resolve()
    )
    /// 編輯週課表（「…」選單的「修改課表」，設計 frame-03～09）。
    @State private var isShowingPlanEdit = false
    /// 模態頁的 ViewModel 在這裡持有（tab 才由 `App2RootView` 持有）——
    /// 沒被打開過就不會 fetch（載入在被呈現那一頁的 `.task`）。
    @StateObject private var planOverviewViewModel = App2PlanOverviewViewModel()

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
        .task {
            // 未讀數要先載才算得出鈴鐺上那顆紅點（沿用 1.4 的同一支）。
            announcementViewModel.loadAnnouncementsIfNeeded()
            // 訓練狀況卡的徽章要用成就頁那一顆，所以首頁也要確保它載過一次。
            // `loadIfNeeded` 有 SWR 門檻，成就 tab 進過就不會再打一次。
            Task { await achievementsViewModel.loadIfNeeded() }
            await viewModel.loadIfNeeded()
        }
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
        .sheet(isPresented: $isShowingNotifications) {
            NavigationStack {
                MessageCenterView(viewModel: announcementViewModel)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(L10n.Common.close.localized) { isShowingNotifications = false }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $isShowingPlanEdit) {
            App2PlanEditGate(
                onClose: { isShowingPlanEdit = false },
                // 課表改了，首頁的今日課表卡與週跑量要跟著換。
                onSaved: { Task { await viewModel.forceRefresh() } }
            )
        }
        .fullScreenCover(item: $detailSession) { detail in
            App2SessionDetailView(detail: detail) { detailSession = nil }
        }
        .fullScreenCover(item: $weeklyReviewWeek) { target in
            App2WeeklyReviewView(
                weekOfPlan: target.weekOfPlan,
                onClose: { weeklyReviewWeek = nil },
                // 建議套用到下週課表之後，首頁的今日課表卡與週次要跟著換。
                onApplied: { Task { await viewModel.forceRefresh() } }
            )
        }
        .fullScreenCover(item: $detailWorkout) { workout in
            App2WorkoutDetailView(
                workout: workout,
                onClose: { detailWorkout = nil },
                onDeleted: { Task { await viewModel.forceRefresh() } }
            )
        }
        .sheet(item: $rizoSheetContext) { context in
            if let rizoChatViewModel {
                App2RizoChatSheet(context: context, viewModel: rizoChatViewModel)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(26)
            }
        }
    }

    /// 首頁兩個 Rizo 入口都開同一個 bottom sheet（設計 frame-00d），只有 context 不同。
    /// 對話狀態與送出仍是既有的 `StateRizoChatViewModel`／既有 Rizo API。
    private func openRizoChat(_ context: App2RizoChatSheet.Context) {
        let viewModelToUse = rizoChatViewModel
            ?? StateRizoChatViewModel(scenario: viewModel.rizoScenario ?? "body_status")
        rizoChatViewModel = viewModelToUse
        // 開場白在本機組（context 那兩句話畫面上已經有了），不多打一次 LLM。
        viewModelToUse.seedOpening(context.opening)
        rizoSheetContext = context
    }

    /// 訓練狀況卡（展開態）的 Rizo 入口 → 「聊天主題 · 今日建議」。
    private func openRizoChatFromStatus(_ status: App2TrainingStatus) {
        openRizoChat(
            App2RizoChatSheet.Context(
                topic: L10n.App2.Home.rizoTopicAdvice.localized,
                title: status.headline,
                detail: status.narrative,
                opening: Self.rizoOpening(from: status.narrative ?? status.headline),
                quickReplies: [
                    L10n.App2.Home.rizoChipAdvice1.localized,
                    L10n.App2.Home.rizoChipAdvice2.localized,
                    L10n.App2.Home.rizoChipAdvice3.localized
                ]
            )
        )
    }

    /// 今日課表卡的 Rizo 入口 → 「聊天主題 · 今日課表」。
    private func openRizoChatFromSession(_ session: App2TodaySession) {
        openRizoChat(
            App2RizoChatSheet.Context(
                topic: L10n.App2.Home.rizoTopicPlan.localized,
                title: session.title,
                detail: session.summary,
                opening: Self.rizoOpening(from: viewModel.rizoOpeningLine),
                quickReplies: [
                    L10n.App2.Home.rizoChipPlan1.localized,
                    L10n.App2.Home.rizoChipPlan2.localized,
                    L10n.App2.Home.rizoChipPlan3.localized
                ]
            )
        )
    }

    /// 開場白＝context 那句話 ＋ 一句引導。組不出 context 句就只給引導，不編一句。
    static func rizoOpening(from line: String?) -> String {
        guard let line, !line.isEmpty else { return L10n.App2.Home.rizoOpeningPrompt.localized }
        return String(format: L10n.App2.Home.rizoOpening.localized, line)
    }

    // MARK: - Header（字標 ＋ LV 六角徽章）

    /// 首頁 v2 的 header（設計 `screens/frame-00b-home-v2.png`）：
    /// 字標 ＋ 右上兩顆 40pt 白色圓鈕（通知鈴鐺、「…」選單）。
    ///
    /// **LV 徽章不再是設定入口**（2026-08-25 裁決）——它搬進訓練狀況卡，
    /// 設定改走「…」選單的「個人資料」。
    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(verbatim: "Paceriz")
                .font(.system(size: 24, weight: .black))
                .tracking(0.5)
                .foregroundStyle(App2Theme.inkPrimary)
            Spacer()
            roundButton(
                symbol: "bell",
                label: L10n.App2.Home.notifications.localized,
                identifier: "App2_NotificationsEntry",
                // 紅點是真的：`unreadCount` 來自既有的公告模組，不是裝飾。
                showsBadge: announcementViewModel.unreadCount > 0
            ) { isShowingNotifications = true }
            homeMenu
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 0)
    }

    /// 「…」選單。**兩個 item 都有真的目的地**：個人資料 → 既有的 2.0 設定頁，
    /// 修改課表 → 編輯週課表。沒有目的地的項目不放進來。
    private var homeMenu: some View {
        Menu {
            Button {
                onOpenSettings()
            } label: {
                Label(L10n.App2.Home.menuProfile.localized, systemImage: "person.crop.circle")
            }
            Button {
                isShowingPlanEdit = true
            } label: {
                Label(L10n.App2.Home.menuEditPlan.localized, systemImage: "square.and.pencil")
            }
        } label: {
            roundButtonSurface(symbol: "ellipsis")
        }
        .accessibilityLabel(L10n.App2.Home.menu.localized)
        .accessibilityIdentifier("App2_HomeMenu")
    }

    private func roundButton(
        symbol: String,
        label: String,
        identifier: String,
        showsBadge: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        // Button 會吃掉 label 上的 accessibilityIdentifier（同頁 insightHandle 的註解），
        // 所以用容器 ＋ onTapGesture ＋ 單一葉節點。
        roundButtonSurface(symbol: symbol)
            .overlay(alignment: .topTrailing) {
                if showsBadge {
                    Circle()
                        .fill(App2Theme.accentRed)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                        .offset(x: -8, y: 8)
                }
            }
            .contentShape(Circle())
            .onTapGesture(perform: action)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(label)
            .accessibilityIdentifier(identifier)
    }

    private func roundButtonSurface(symbol: String) -> some View {
        Circle()
            .fill(App2Theme.cardBackground)
            .frame(width: 40, height: 40)
            .overlay(Circle().strokeBorder(App2Theme.shadowInk.opacity(0.08), lineWidth: 1))
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(App2Theme.inkPrimary)
            }
            .shadow(color: App2Theme.shadowInk.opacity(0.16), radius: 5, x: 0, y: 4)
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

                // 三格**等寬水平均分鋪滿卡寬**（2026-08-26 裁決），不再靠 spacing
                // ＋ 尾端 Spacer 把三格擠在左半邊。
                HStack(alignment: .bottom, spacing: 8) {
                    App2FieldColumn(
                        label: L10n.App2.Home.goalTarget.localized,
                        value: goal.targetTime ?? "—",
                        valueColor: App2Theme.accentBlueDark
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    App2FieldColumn(
                        label: L10n.App2.Home.goalEstimate.localized,
                        value: goal.estimatedFinish ?? "—",
                        valueColor: App2Theme.accentOrange
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    App2FieldColumn(
                        label: L10n.App2.Home.goalWeek.localized,
                        value: goal.currentWeek.map(String.init) ?? "—",
                        valueColor: App2Theme.inkPrimary,
                        suffix: goal.totalWeeks.map { "/\($0)" }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity)
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
                        // 卡片標記掛在標題這顆葉節點上 —— 掛在容器上 SwiftUI 會把
                        // identifier 蓋到每一個子節點，卡內的 LV 徽章、指標 handle
                        // 在 a11y tree 裡就全部叫 `App2_TrainingStatusCard`
                        // （2026-08-25 maestro 實測，同 `App2PageHeader` 的註解）。
                        .accessibilityIdentifier("App2_TrainingStatusCard")
                    Spacer()
                    App2StubBadge(origin: sourced.origin)
                }

                statusBanner(status)
                insightHandle
                insightsGrid
            }
        }
    }

    /// 設計 v2 的 headline 區塊：淺藍底 inset，**左邊是徽章、右邊是教練洞察**
    /// （2026-08-25 裁決：徽章從 header 搬進訓練狀況卡，與教練洞察同一列）。
    ///
    /// **軌跡趨勢圖已整塊移除**（2026-08-26 裁決）：`Actual／Projected` 序列在
    /// backend 沒有任何端點交得出來，畫面上一直掛著 `Sample §7-16` 徽章的樣本圖。
    /// 有真序列端點時再依當時的設計重議，不留樣本圖佔位。
    private func statusBanner(_ status: App2TrainingStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 13) {
                // 2026-08-26 裁決：這一顆＝**用戶成就頁預設顯示的那一顆徽章**
                // （最新解鎖），沿用既有徽章美術與 `AchievementBadgeImage` renderer。
                // 設計稿的「LV 7」六角只是樣本，不做成等級系統、也不畫成空殼。
                statusBadge

                Text(status.headline)
                    .font(.system(size: 17, weight: .black))
                    .tracking(0.3)
                    .foregroundStyle(App2Theme.accentBlueDeep)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 敘述是付費內容：免費用戶 `narrative_text` 為 nil，這時沒有東西可展開，
            // 整顆「為什麼？」不出現（不做成點了沒反應的死連結）。
            if let narrative = status.narrative {
                HStack(spacing: 4) {
                    Spacer(minLength: 0)
                    Text(L10n.App2.Home.statusWhy.localized)
                        .font(.system(size: 14, weight: .black))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .black))
                        .rotationEffect(.degrees(isStatusExpanded ? 180 : 0))
                }
                .foregroundStyle(App2Theme.accentBlueDeep)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) { isStatusExpanded.toggle() }
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_StatusWhyToggle")

                if isStatusExpanded {
                    Rectangle()
                        .fill(App2Theme.accentBlue.opacity(0.16))
                        .frame(height: 1)

                    Text(narrative)
                        .font(.system(size: 14, weight: .semibold))
                        .lineSpacing(3)
                        .foregroundStyle(App2Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("App2_StatusNarrative")

                    // 內嵌 Rizo 輸入列。點下去**開 frame-00d 的對話 sheet**（帶
                    // 「今日建議」context），與今日課表卡同一條入口、同一個 ViewModel。
                    rizoInputRow(
                        placeholder: L10n.App2.Home.statusRizoPlaceholder.localized,
                        showsAvatar: true,
                        identifier: "App2_StatusRizoInput"
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { openRizoChatFromStatus(status) }
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    /// 訓練狀況卡左側的徽章 —— **成就頁那一顆**。
    ///
    /// 資料走的是成就頁自己的 ViewModel（`GET /v2/achievements/summary`，由
    /// `App2RootView` 持有），挑選規則直接用 `App2AchievementsView.latestUnlocked`
    /// —— 首頁與成就頁顯示同一顆是這條裁決的重點，所以不另寫一份挑法。
    /// 還沒載到／一顆都沒解鎖時留一個中性的圓角方塊，不畫假徽章。
    @ViewBuilder
    private var statusBadge: some View {
        let badge = achievementsViewModel.summary.flatMap(App2AchievementsView.latestUnlocked)
        Group {
            if let badge {
                AchievementBadgeImage(
                    assetName: AchievementBadgeArtwork.assetName(for: badge),
                    status: badge.status,
                    size: 54
                )
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(App2Theme.accentBlue.opacity(0.12))
                    .frame(width: 54, height: 54)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.App2.Achievements.latestUnlock.localized)
        .accessibilityIdentifier("App2_LevelBadge")
    }

    /// 指標區的標題列（設計 v2：小標 ＋ 右側 chevron，整列可點展開／收合）。
    @ViewBuilder
    private var insightHandle: some View {
        if let sourced = viewModel.insights {
            // 用容器＋onTapGesture 而不是 Button：Button 會吃掉 label 上的
            // accessibilityIdentifier，maestro 在 accessibility tree 抓不到
            // （2026-08-25 實測，同頁的非 Button 卡片 id 都抓得到）。
            HStack(spacing: 8) {
                Text(L10n.App2.Home.insightsSection.localized)
                    .font(.system(size: 14, weight: .black))
                    .tracking(0.5)
                    .foregroundStyle(App2Theme.inkPrimary)
                Spacer(minLength: 4)
                App2StubBadge(origin: sourced.origin)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(App2Theme.inkMuted)
                    .rotationEffect(.degrees(isGridExpanded ? 180 : 0))
            }
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) { isGridExpanded.toggle() }
            }
            // 做成單一 accessibility 葉節點 ＋ 明確 label：`.combine` 併出來的元素
            // 標籤可能是空的而被丟掉，identifier 也跟著不出現在 tree 上
            // （2026-08-25 用 maestro 的 hierarchy dump 確認）。
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(
                isGridExpanded
                    ? L10n.App2.Home.insightsSection.localized
                    : L10n.App2.Home.insightsMore.localized
            )
            .accessibilityIdentifier("App2_InsightHandle")
        }
    }

    /// 指標列（設計 v2：icon ＋ 指標名 ＋ 判語 ＋ 右側分數變化與箭頭）。
    ///
    /// **預設只展開最值得看的 2–3 列**（2026-08-25 裁決），其餘收在 chevron 後。
    /// 挑哪幾列由 `App2HomeViewModel.highlightedInsights` 決定，用的是後端的
    /// `arrow`／`dot`／`status`，不在畫面層推。
    @ViewBuilder
    private var insightsGrid: some View {
        if let sourced = viewModel.insights {
            let rows = isGridExpanded
                ? sourced.value
                : App2HomeViewModel.highlightedInsights(sourced.value)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, insight in
                    if index > 0 {
                        Rectangle()
                            .fill(App2Theme.insetBorder)
                            .frame(height: 1)
                    }
                    insightRow(insight)
                }
            }
            .accessibilityIdentifier("App2_InsightsGrid")
        }
    }

    private func insightRow(_ insight: App2Insight) -> some View {
        HStack(spacing: 10) {
            Image(systemName: insight.symbolName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(insight.tint)
                .frame(width: 20)
            Text(insight.label)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(App2Theme.inkSubtle)
                .lineLimit(1)
            if let verdict = insight.verdict {
                Text(verdict)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(insight.tint)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if let change = insight.change {
                Text(change)
                    .font(.app2Mono(12, weight: .bold))
                    .foregroundStyle(App2Theme.inkFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(insight.arrowGlyph)
                .font(.app2Mono(15))
                .foregroundStyle(insight.tint)
                .frame(width: 13)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("App2_InsightRow_\(insight.id)")
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

                // 今天已經跑完了 —— 課表卡下面多一列進「已完成」那筆的訓練詳情
                // （設計 frame-15）。這是另一個目的地，所以是自己一列，
                // 不與上面「點課表看課表詳情」的點擊區重疊。
                if let completed = viewModel.todayCompletedWorkout {
                    completedWorkoutRow(completed)
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
                // 課型大標與同一列的兩顆 chip 共用一行：字長只准縮，折行會把 chip
                // 擠掉一行（en 的 `Interval Training` 曾折成兩行）。
                Text(session.title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                    .lineLimit(1)
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

                // 分段區。payload 組不出任何一段就整段不出現（不用 placeholder 補行）。
                //
                // **間歇卡是左右兩欄**（設計 dc.html「今日課表 · 間歇」）：左邊分段列、
                // 右邊 132pt 的趟數結構圖。輕鬆跑／節奏跑／長距離的今日卡**只有分段列**
                // ——8/25 版設計把柱狀圖從那三張卡上拿掉了，不要補回去
                // （2026-08-26 覆蓋 8/25 早上的「每課型都要示意圖」）。
                if !session.segments.isEmpty {
                    HStack(alignment: .top, spacing: 9) {
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
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if session.hasIntervalStructure {
                            App2SessionStructureChart(bars: session.structureBars, showsNotes: false)
                                .frame(width: 118)
                                .accessibilityIdentifier("App2_TodayStructureChart")
                        }
                    }
                    .accessibilityIdentifier("App2_TodaySegments")
                }

                // 體感強度卡（設計 dc.html「今日課表 · …」第 5 塊）。
                // 值與句子都走課型對照（`TrainingEffortScale`），**不吃逐日生成的敘述**
                // ——那一段在用戶改過課表後不重生，會出現「間歇＋週三休息」這種
                // 與當日課型矛盾的句子（2026-08-26 使用者截圖）。
                if let effort = TrainingEffortScale.value(for: session.dayType) {
                    App2EffortCard(
                        value: effort,
                        sentence: TrainingEffortScale.sentence(for: session.dayType),
                        accent: sessionAccent(session)
                    )
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

    /// 「今天已完成 · 看訓練詳情」那一列。
    private func completedWorkoutRow(_ workout: WorkoutV2) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(App2Theme.accentGreen)
            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.App2.Home.todayCompletedTitle.localized)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(App2Theme.inkPrimary)
                Text(L10n.App2.Home.todayCompletedSub.localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(App2Theme.inkTertiary)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(App2Theme.chevron)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .app2InsetSurface()
        .contentShape(Rectangle())
        .onTapGesture { detailWorkout = workout }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("App2_TodayCompletedRow")
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
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: true, vertical: false)
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

            rizoInputRow(
                placeholder: L10n.App2.Home.rizoInputPlaceholder.localized,
                showsAvatar: false,
                identifier: "App2_RizoInput"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            // 今日課表卡的入口 → frame-00d 對話 sheet，帶「今日課表」context。
            if case .session(let session) = viewModel.todayState {
                openRizoChatFromSession(session)
            } else {
                openRizoChat(
                    App2RizoChatSheet.Context(
                        topic: L10n.App2.Home.rizoTopicPlan.localized,
                        title: L10n.App2.Home.todaySection.localized,
                        detail: nil,
                        opening: Self.rizoOpening(from: viewModel.rizoOpeningLine),
                        quickReplies: [
                            L10n.App2.Home.rizoChipPlan1.localized,
                            L10n.App2.Home.rizoChipPlan2.localized,
                            L10n.App2.Home.rizoChipPlan3.localized
                        ]
                    )
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("App2_RizoEntry")
    }

    /// Rizo 輸入列：（可選）R 頭像 ＋ 佔位字 ＋ 圓形送出鈕。
    ///
    /// 今日課表卡與訓練狀況卡（frame-00c 展開態）用**同一份**：兩張卡的差別只有
    /// 佔位字與要不要帶頭像。送出的目的地也是同一個（`openRizoChat`）。
    private func rizoInputRow(
        placeholder: String,
        showsAvatar: Bool,
        identifier: String
    ) -> some View {
        HStack(spacing: 9) {
            if showsAvatar {
                App2Avatar(initial: "R", size: 34, showsRing: false)
            }
            HStack(spacing: 8) {
                Text(placeholder)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(App2Theme.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 6)
                if !showsAvatar {
                    sendButton(symbol: "arrow.up")
                }
            }
            .padding(EdgeInsets(top: 7, leading: 13, bottom: 7, trailing: showsAvatar ? 13 : 7))
            .app2InsetSurface(cornerRadius: 20)
            // 頭像版（frame-00c）的送出鈕在欄位**外面**、箭頭朝右，照稿。
            if showsAvatar {
                sendButton(symbol: "arrow.right")
            }
        }
        .accessibilityIdentifier(identifier)
    }

    private func sendButton(symbol: String) -> some View {
        Circle()
            .fill(App2Theme.accentBlue)
            .frame(width: 30, height: 30)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
            }
    }

    // MARK: - 週回顧 CTA（設計 dc.html:272／5112 的狀態驅動時機卡）

    @ViewBuilder
    private var weeklyReviewRow: some View {
        switch viewModel.weekReview {
        case .notGenerated(let isCurrentWeek, let targetWeek):
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
            .contentShape(Rectangle())
            .onTapGesture { weeklyReviewWeek = App2WeeklyReviewTarget(weekOfPlan: targetWeek) }
            .accessibilityAddTraits(.isButton)
        case .available(_, _, let targetWeek):
            entryRow(
                symbol: "chart.line.uptrend.xyaxis",
                title: L10n.App2.Home.weekReviewView.localized,
                subtitle: L10n.App2.Home.weekReviewViewSub.localized,
                identifier: "App2_WeekReviewEntry"
            )
            .contentShape(Rectangle())
            .onTapGesture { weeklyReviewWeek = App2WeeklyReviewTarget(weekOfPlan: targetWeek) }
            .accessibilityAddTraits(.isButton)
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

// MARK: - App2RizoChatSheet
/// 首頁兩個 Rizo 入口共用的對話 sheet（設計 **frame-00d**）。
///
/// sheet 頭（R 頭像＋「Rizo · 你的 AI 跑步教練」＋關閉鈕）→ context 卡
/// （「聊天主題 · 今日建議」或「· 今日課表」）→ 對話本體。
///
/// **對話本體是既有的 `RizoChatView`**（泡泡、typing、建議問題 chips、改課表提案卡、
/// 付費牆、歷史對話全都在裡面），只是關掉它自己的 header 與卡面，由 sheet 提供。
/// 狀態與送出是既有的 `StateRizoChatViewModel` → 既有 Rizo API，沒有第二套對話狀態。
struct App2RizoChatSheet: View {

    /// 這次對話的主題。`Identifiable` 是因為 `sheet(item:)` 要它——同時也讓
    /// 「換了 context 就是換一次 sheet」這件事由型別表達。
    struct Context: Identifiable, Equatable {
        var id: String { topic + title }
        /// 「今日建議」／「今日課表」。
        let topic: String
        let title: String
        let detail: String?
        /// 本機組好的開場白（不打 LLM）。
        let opening: String
        let quickReplies: [String]
    }

    let context: Context
    @ObservedObject var viewModel: StateRizoChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(App2Theme.shadowInk.opacity(0.14))
                .frame(width: 38, height: 5)
                .padding(.top, 9)

            header
            Rectangle()
                .fill(App2Theme.insetBorder)
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    contextCard
                    RizoChatView(
                        viewModel: viewModel,
                        quickReplies: context.quickReplies,
                        showsHeader: false,
                        showsSurface: false
                    )
                }
                .padding(.horizontal, App2Theme.pagePadding)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        .accessibilityIdentifier("App2_RizoChatSheet")
    }

    private var header: some View {
        HStack(spacing: 11) {
            App2Avatar(initial: "R", size: 44, showsRing: false)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "Rizo")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                Text(L10n.App2.Home.rizoCoachTitle.localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(App2Theme.inkTertiary)
            }
            Spacer(minLength: 6)
            Circle()
                .fill(App2Theme.insetBackground)
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(App2Theme.inkSubtle)
                }
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_RizoChatClose")
        }
        .padding(.horizontal, App2Theme.pagePadding)
        .padding(.vertical, 12)
    }

    private var contextCard: some View {
        App2Card(padding: 14, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 11, weight: .bold))
                Text("\(L10n.App2.Home.rizoTopicLabel.localized) · \(context.topic)")
                    .font(.system(size: 13, weight: .black))
            }
            .foregroundStyle(App2Theme.accentBlueDeep)

            Text(context.title)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(App2Theme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let detail = context.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 14, weight: .semibold))
                    .lineSpacing(3)
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("App2_RizoChatContext")
    }
}
