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
    /// 「稍後」只收掉這一次進頁（T-0438）。刻意不落地：條件還在的話，下次進首頁該再問一次；
    /// 連線滿 7 天後端自己就不再回 true，不需要 App 記一個會過期的旗標。
    @State private var garminHistoryPromptDismissed = false
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
    /// 指標第二層（checklist §51–53）。nil = 沒開。
    ///
    /// **2026-08-26 晚裁決：指標列每一項點擊直接進對應詳情頁**，不經 §55／§56 的
    /// sheet 快視圖（那兩張暫不接入任何入口）。訓練狀況卡的「為什麼？」維持
    /// frame-00c 的 inline 展開，不動。
    @State private var metricDetail: App2MetricDetailKind?
    /// 模態頁的 ViewModel 在這裡持有（tab 才由 `App2RootView` 持有）——
    /// 沒被打開過就不會 fetch（載入在被呈現那一頁的 `.task`）。
    @StateObject private var planOverviewViewModel = App2PlanOverviewViewModel()
    /// 整期總結（設計 frame-00g2）。入口是結束態卡下方那張入口卡。
    @State private var isShowingPeriodSummary = false
    /// 「設定新目標」——**既有**的重設目標流程（`App2SettingsView` 的 `.reonboarding`
    /// 走的是同一支），不是為結束態新做的目標選擇 UI。
    @State private var isShowingReonboarding = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                // 計畫走完時，目標卡＋今日課表卡整段換成結束態內容（設計 frame-00g）
                // —— 那是同一塊版位的另一種內容，不是多加一張卡。訓練狀況卡留著：
                // 身體狀態與計畫有沒有走完是兩件事。
                if let planEnd = viewModel.planEnd {
                    planEndSection(planEnd)
                    trainingStatusSection
                } else {
                    goalSection
                    trainingStatusSection
                    todaySection
                }
                weeklyReviewRow
                garminHistoryPromptCard
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
        .fullScreenCover(isPresented: $isShowingPeriodSummary) {
            if let planEnd = viewModel.planEnd {
                App2PeriodSummaryView(
                    card: planEnd,
                    onClose: { isShowingPeriodSummary = false }
                )
            }
        }
        .fullScreenCover(isPresented: $isShowingReonboarding) {
            App2OnboardingContainerView(
                isReonboarding: true,
                onFinished: {
                    isShowingReonboarding = false
                    // 重設完目標，首頁整組（結束態／目標卡／今日課表）都要換掉。
                    Task { await viewModel.forceRefresh() }
                },
                // 還沒提交就返回：只關掉，不重取（什麼都沒改）。
                onCancel: { isShowingReonboarding = false }
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
        .fullScreenCover(item: $metricDetail) { kind in
            // 大數字與判語**用首頁這一列的同一份 insight**，詳情頁不重新評級。
            if let insight = viewModel.insights?.value.first(where: { $0.id == kind.rawValue }) {
                App2MetricDetailView(
                    kind: kind,
                    insight: insight,
                    // 訓練量的敘事是 `mileage_progression`（跑量漸進那一段）；
                    // 其餘兩頁用該列自己的 evidence 句。
                    narrative: kind == .weeklyVolume
                        ? viewModel.trainingStatus?.value.mileageProgression
                        : insight.evidence,
                    // 完賽預估同樣**用首頁那一輪已經載到的 readiness**（T-0376），
                    // 詳情頁不為它多打一次網路。空陣列＝那一區不畫。
                    finishPredictions: viewModel.finishPredictions,
                    // 有氧續航／速度耐力的 30 天序列窗右端＝卡片的業務日（T-0617）。
                    asof: viewModel.stateAsof,
                    onClose: { metricDetail = nil }
                )
            }
        }
        .fullScreenCover(item: $detailSession) { detail in
            App2SessionDetailView(detail: detail) { detailSession = nil }
        }
        .fullScreenCover(item: $weeklyReviewWeek) { target in
            App2WeeklyReviewView(
                weekOfPlan: target.weekOfPlan,
                isCurrentWeek: target.isCurrentWeek,
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
        // sheet 的內容**不依賴任何在同一個 tick 才寫進去的 optional state**：
        // 那樣 content closure 會拿到還沒更新的 view struct，`if let` 全部落空，
        // 開出來是一片空白（2026-08-26 實測，`isPresented` 與 `item` 兩種寫法都中）。
        // 對話 ViewModel 由 sheet 自己以 `@StateObject` 持有（見 `App2RizoChatSheet`）。
        .sheet(item: $rizoSheetContext) { context in
            App2RizoChatSheet(
                context: context,
                scenario: viewModel.rizoScenario ?? "body_status"
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(26)
        }
    }

    /// 首頁兩個 Rizo 入口都開同一個 bottom sheet（設計 frame-00d），只有 context 不同。
    /// 對話狀態與送出仍是既有的 `StateRizoChatViewModel`／既有 Rizo API。
    private func openRizoChat(_ context: App2RizoChatSheet.Context) {
        rizoSheetContext = context
    }

    /// 訓練狀況卡（展開態）的 Rizo 入口 → 「聊天主題 · 今日建議」。
    private func openRizoChatFromStatus(_ status: App2TrainingStatus) {
        openRizoChat(
            App2RizoChatSheet.Context(
                topic: L10n.App2.Home.rizoTopicAdvice.localized,
                title: status.headline,
                detail: status.narrative,
                opening: Self.rizoOpening(from: status.narrative ?? status.headline)
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
                opening: Self.rizoOpening(from: viewModel.rizoOpeningLine)
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
            // **計畫走完後不再提供編輯入口**（2026-08-27 裁決：結束態下歷史課表唯讀）。
            // 課表頁的鉛筆鈕同一條規則，兩邊一起收 —— 只收一邊的話，用戶還是能從
            // 這裡改到一份已經結束的計畫。
            if viewModel.planEnd == nil {
                Button {
                    isShowingPlanEdit = true
                } label: {
                    Label(L10n.App2.Home.menuEditPlan.localized, systemImage: "square.and.pencil")
                }
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

    // MARK: - 計畫結束態（設計 frame-00g（a）（b））

    /// 結束態 ＝ **一張 hero 卡 ＋ 一張「看整期總結」入口卡**。
    ///
    /// 兩種語意共用同一個版式，差在配色與內容（frame-00g（b））：
    /// - race：深藍，聚焦賽事 —— 賽名／賽日／目標 vs 完賽。
    /// - maintenance：綠，聚焦維持成果，**一個字都不提賽事成績**。
    ///
    /// **兩處降級**（backend 缺口，見 `App2PlanEndModels` 檔頭）：
    /// 1. 沒有賽事實際成績 → 右欄退「當時預估」並隱藏差值，另加一句說明它是預估。
    /// 2. 沒有 LLM 敘事 → Rizo 敘事子卡**整卡不畫**（不畫空卡、不編一句）。
    @ViewBuilder
    private func planEndSection(_ planEnd: App2PlanEndCard) -> some View {
        VStack(spacing: 12) {
            planEndHero(planEnd)
            entryRow(
                symbol: "chart.line.uptrend.xyaxis",
                title: L10n.App2.PlanEnd.summaryEntry.localized,
                subtitle: L10n.App2.PlanEnd.summaryEntrySub.localized,
                identifier: "App2_PeriodSummaryEntry"
            )
            .contentShape(Rectangle())
            .onTapGesture { isShowingPeriodSummary = true }
            .accessibilityAddTraits(.isButton)
        }
    }

    private func planEndHero(_ planEnd: App2PlanEndCard) -> some View {
        let isRace = planEnd.kind == .race
        return VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                    Text(isRace
                         ? L10n.App2.PlanEnd.chipRace.localized
                         : L10n.App2.PlanEnd.chipMaintenance.localized)
                        .font(.system(size: 13, weight: .heavy))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.16)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))

                Spacer(minLength: 4)

                if let distance = planEnd.distanceLabel {
                    App2Pill(
                        text: distance,
                        foreground: .white,
                        background: Color.white.opacity(0.16),
                        border: Color.white.opacity(0.28)
                    )
                }
            }

            HStack(alignment: .center, spacing: 13) {
                trophyBadge
                VStack(alignment: .leading, spacing: 3) {
                    // 卡片標記掛在標題這顆葉節點上 —— 掛在最外層容器時 SwiftUI 會把
                    // identifier 蓋到**每一個子節點**，卡內的降級說明、CTA 在 a11y
                    // tree 上就全部叫 `App2_PlanEndCard`，一顆都抓不到
                    // （2026-08-27 maestro 實測；同 `App2_TrainingStatusCard` 的註解）。
                    Text(planEndTitle(planEnd))
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .accessibilityIdentifier("App2_PlanEndCard")
                    Text(planEndSubtitle(planEnd))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            // 目標 vs 完賽兩欄。**maintenance 不畫**（不提賽事成績）。
            // race 走與整期總結頁**同一條降級階梯**（`degradedFinish`）：
            // 成績 → 當時預估 → 目標，一路退到最後一個講得出來的量；
            // 全都沒有時才整塊不畫（不畫一排「—」）。
            if let degraded = App2PeriodSummaryView.degradedFinish(planEnd) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .bottom, spacing: 10) {
                        // 左欄是目標。**只有在右欄不是目標本身時才畫** ——
                        // 退到最後一格（連預估都沒有）時右欄就是目標，
                        // 兩欄都畫會變成同一個數字並排兩次。
                        if let target = planEnd.targetTime, degraded.target != nil {
                            planEndColumn(
                                label: L10n.App2.Home.goalTarget.localized,
                                value: target
                            )
                        }
                        // **identifier 掛在這一欄上，不掛外層的 VStack**：純容器
                        // （沒有自己的背景）不會被 SwiftUI 交進 accessibility tree，
                        // maestro 就抓不到（2026-08-27 實測，同 `insightHandle` 的既有坑）。
                        // 這一欄有自己的底色，而且它就是降級階梯落在哪一格的證據。
                        planEndColumn(
                            label: degraded.label,
                            value: degraded.value,
                            // 差值只有「目標 ＋ 實際成績」都在時才成立 ——
                            // 不拿預估去減目標，那個差值講的不是同一件事。
                            trailing: planEnd.showsFinishDelta ? planEnd.targetTime : nil,
                            identifier: "App2_PlanEndFinish"
                        )
                    }
                    // 退到「只剩目標」那一格時沒有話要補 —— 那一行整個不出現。
                    if let note = degraded.note {
                        Text(note)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.58))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // Rizo 整期敘事子卡：**端點未落地 → `narrative` 恆 nil → 整卡不出現**。
            // 版面照稿留著，等端點來就自然接上（不畫空卡、不編一句）。
            if let narrative = planEnd.narrative {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        App2Avatar(initial: "R", size: 22, showsRing: false)
                        Text(L10n.App2.PlanEnd.narrativeChip.localized)
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                    Text(narrative)
                        .font(.system(size: 14, weight: .semibold))
                        .lineSpacing(3)
                        .foregroundStyle(Color.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("App2_PlanEndNarrative")
            }

            planEndCTA
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: App2Theme.cardCornerRadius, style: .continuous)
                .fill(planEnd.kind.heroGradient)
        )
        .shadow(color: planEnd.kind.heroShadow, radius: 22, x: 0, y: 14)
    }

    /// 獎盃徽章。
    ///
    /// **不綁成就系統的某一顆徽章**：`plan_finished` 的 fact 已經在 ingest
    /// （`application/plan_status.py:100`），但它對應到哪一顆徽章的語意還沒確認
    /// （盤點 §B.3 記為「hook 在，徽章語意未確認」）。所以這裡畫的是版式上的獎盃，
    /// 不是一顆會被讀成「你解鎖了這個成就」的真徽章。
    private var trophyBadge: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [App2Theme.medalGradient.from, App2Theme.medalGradient.to],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 52, height: 52)
            .overlay {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }

    private func planEndColumn(
        label: String,
        value: String,
        trailing: String? = nil,
        identifier: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.app2FieldLabel)
                .tracking(1)
                .foregroundStyle(Color.white.opacity(0.66))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.app2Mono(23))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(App2Theme.accentRed)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier ?? "")
    }

    /// 白底 CTA ＋ 小字。**導既有的重設目標流程**（race／beginner／maintenance 三出口），
    /// 不做新的目標選擇 UI（2026-08-26 產品裁決）。
    private var planEndCTA: some View {
        VStack(spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: "star")
                    .font(.system(size: 14, weight: .black))
                Text(L10n.App2.PlanEnd.ctaNewGoal.localized)
                    .font(.system(size: 16, weight: .black))
            }
            .foregroundStyle(App2Theme.inkPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(App2Theme.cardBackground)
            )
            .contentShape(Rectangle())
            .onTapGesture { isShowingReonboarding = true }
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("App2_PlanEndNewGoal")

            Text(L10n.App2.PlanEnd.ctaNewGoalSub.localized)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.6))
        }
        .padding(.top, 2)
    }

    /// race＝賽名；maintenance 沒有賽事 → `N 週維持計畫`。
    private func planEndTitle(_ planEnd: App2PlanEndCard) -> String {
        if planEnd.kind == .race, let name = planEnd.raceName, !name.isEmpty { return name }
        guard let weeks = planEnd.totalWeeks else {
            return L10n.App2.PlanEnd.maintenanceHeadline.localized
        }
        return String(format: L10n.App2.PlanEnd.maintenanceTitleFormat.localized, weeks)
    }

    /// race＝`2026-12-06 · N 週備賽完成`；maintenance＝`訓練期完成`。
    /// 週數缺席時只留得出來的那一段（不印一個空的「 週」）。
    private func planEndSubtitle(_ planEnd: App2PlanEndCard) -> String {
        guard planEnd.kind == .race else {
            return L10n.App2.PlanEnd.maintenanceHeadline.localized
        }
        let headline = planEnd.totalWeeks.map {
            String(format: L10n.App2.PlanEnd.raceHeadlineFormat.localized, $0)
        }
        return [planEnd.raceDate, headline].compactMap { $0 }.joined(separator: " · ")
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

                // 三格**水平分散鋪滿卡寬**（2026-08-28 走查：左／中／右對齊，
                // 不是三格都靠左——那樣右側 1/3 是空的，看起來擠在左邊）。
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
                    .frame(maxWidth: .infinity, alignment: .center)
                    App2FieldColumn(
                        label: L10n.App2.Home.goalWeek.localized,
                        value: goal.currentWeek.map(String.init) ?? "—",
                        valueColor: App2Theme.inkPrimary,
                        suffix: goal.totalWeeks.map { "/\($0)" }
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
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
                    // 標題弱化（2026-08-27 晚走查裁決（a））：深灰、w600、16px。
                    // 只有這一顆換 —— 「個人最佳」等仍是 `app2CardTitle`。
                    Text(L10n.App2.Home.statusSection.localized)
                        .font(.app2CardTitleMuted)
                        .tracking(0.5)
                        .foregroundStyle(App2Theme.inkSecondary)
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
    /// headline ＋ 句尾的展開／收起連結（設計 frame-00c2，2026-08-26 裁決）。
    ///
    /// **同一列是偏好，放不下才降級**（2026-09-12 使用者裁決，取代 2026-09-01
    /// 的「永遠同一列」）：放得下就 headline ＋ 連結同一列；放不下時 headline
    /// 吃滿整個卡寬自由換行，連結掉到下一行行尾右緣。
    ///
    /// 三語實測（2026-09-12，`STATUS/evidence/T-0666/`）：這張卡的可用寬度被
    /// 300km 徽章吃掉一塊，**中文也放不下**，所以三語都走降級分支。修前中文是
    /// headline 自己斷成兩行、連結釘在第二行行尾；現在是 headline 完整一行、
    /// 連結自己一行。兩者都是兩行高。
    ///
    /// 沒有敘述可展開時（免費用戶 `narrative_text` 為 nil）只有 headline，
    /// 不掛連結也不吃點擊。
    @ViewBuilder
    private func statusHeadline(_ status: App2TrainingStatus) -> some View {
        let canExpand = status.narrative != nil
        let label = isStatusExpanded
            ? L10n.Training.collapse.localized          // 「收起」三語已齊，不開第二份
            : L10n.App2.Achievements.seeMore.localized  // 「看更多」同上
        // 固定深灰、不隨狀態換色（2026-08-27 使用者：「不要換色，細一點」，
        // 撤掉同日稍早的 worry 換色）。
        let headline = Text(status.headline)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(App2Theme.inkPrimary)

        let link =
            (
                Text(label)
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(App2Theme.accentBlue)
                    + Text(" ")
                    + Text(Image(systemName: isStatusExpanded ? "chevron.up" : "chevron.down"))
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(App2Theme.accentBlue)
            )
            .lineLimit(1)
            .fixedSize()

        Group {
            if canExpand {
                // **連結與標題同一列是偏好，放不下才降級**（2026-09-01 使用者裁決
                // 「同一列」＋2026-09-12 使用者裁決「最差就是在原本標題下一行放看更多」）。
                //
                // 一行版把連結的固有寬度（約 90pt）從 headline 手上拿走，headline
                // 只剩約 190pt：英文 headline 是整句（`reason_guard` 放行到 16 個詞），
                // 在那個寬度會斷成 5 行細長條（2026-09-12 使用者 prod 截圖）。
                // 所以 headline 在第一個分支帶 `.fixedSize()` 交出單行固有寬度，
                // `ViewThatFits` 就量得出「這句話配這個連結放不進一行」，放不下時
                // 走第二個分支：headline 吃滿整個寬度自由換行，連結掉到下一行行尾。
                //
                // headline 不帶 fixedSize 是量不出來的——文字永遠能靠換行「放得下」，
                // `ViewThatFits` 就永遠選第一個分支（8/26 的舊 ViewThatFits 版就是
                // 這樣才恆選到 VStack 分支）。
                ViewThatFits(in: .horizontal) {
                    // 間距用設計稿的 8。先前寫成 4 並註明「不然中文也會掉到第二行」，
                    // 但修後三語實測中文本來就放不下（見上方 docstring），
                    // 那個理由不成立，不留沒有證據的魔術數字。
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        headline
                            .tracking(0.3)
                            .lineLimit(1)
                            .fixedSize()
                        Spacer(minLength: 0)
                        link
                    }

                    VStack(alignment: .trailing, spacing: 6) {
                        headline
                            .tracking(0.3)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        link
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) { isStatusExpanded.toggle() }
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_StatusWhyToggle")
            } else {
                headline
                    .tracking(0.3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func statusBanner(_ status: App2TrainingStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 13) {
                // 2026-08-26 裁決：這一顆＝**用戶成就頁預設顯示的那一顆徽章**
                // （最新解鎖），沿用既有徽章美術與 `AchievementBadgeImage` renderer。
                // 設計稿的「LV 7」六角只是樣本，不做成等級系統、也不畫成空殼。
                statusBadge

                statusHeadline(status)
            }

            // 敘述是付費內容：免費用戶 `narrative_text` 為 nil，這時沒有東西可展開，
            // 展開連結整個不出現（不做成點了沒反應的死連結），headline 就是純文字。
            if let narrative = status.narrative {
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
    /// `App2RootView` 持有），挑選規則直接用 `App2AchievementsView.displayBadge`
    /// —— 首頁與成就頁顯示同一顆是這條裁決的重點，所以不另寫一份挑法。
    /// 使用者在成就頁換過展示徽章（pin）之後，這裡也跟著換。
    /// 還沒載到／一顆都沒解鎖時留一個中性的圓角方塊，不畫假徽章。
    @ViewBuilder
    private var statusBadge: some View {
        // 冷啟時 `summary` 還沒回來 —— `displayBadge` 會退到既有的持久化快照
        // （`DisplayBadgeStorage`），所以這一顆不會先空一格再跳出來。
        let badge = achievementsViewModel.displayBadge
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
            // **容器上不掛 identifier**：SwiftUI 會把它蓋到每一個子節點，三列指標在
            // a11y tree 裡就全部叫 `App2_InsightsGrid`，逐列的 id 一個都抓不到
            // （2026-08-26 maestro hierarchy dump 實測）。列的 id 掛在列自己身上。
        }
    }

    /// 一列指標。**有詳情頁的五個可點進第二層**（訓練量／能力基準／恢復恆可點；
    /// 有氧續航／速度耐力只要不是 `not_computed` 就可點 —— 2026-08-29 創辦人裁決
    /// 取代 2026-08-26「無詳情稿不可點」那一條）。其餘不可點也不畫 chevron，
    /// 把關在 `App2MetricDetailKind.from(insight:)`。
    @ViewBuilder
    private func insightRow(_ insight: App2Insight) -> some View {
        let kind = App2MetricDetailKind.from(insight: insight)
        insightRowContent(insight, isTappable: kind != nil)
            .contentShape(Rectangle())
            .onTapGesture {
                guard let kind else { return }
                metricDetail = kind
            }
            // 做成單一 a11y 葉節點 ＋ 明確 label ＋ identifier，**全部掛在有手勢的
            // 這一層**：掛在裡面那一層時，外層的 `onTapGesture` 會把 identifier
            // 從 accessibility tree 上蓋掉（2026-08-26 maestro 實測抓不到
            // `App2_InsightRow_weekly_volume`；同頁 `App2_InsightHandle` 的註解）。
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(kind != nil ? [.isButton] : [])
            .accessibilityLabel(Self.insightAccessibilityLabel(insight))
            .accessibilityIdentifier("App2_InsightRow_\(insight.id)")
    }

    /// 一列指標唸出來的字（`訓練量 下修 11 vs 上週 30 km`）。
    /// 右側那一格唸的跟看的是同一個字串（[insightTrailingText]）。
    static func insightAccessibilityLabel(_ insight: App2Insight) -> String {
        [insight.label, insight.verdict, insightTrailingText(insight)]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    /// 一列指標右側那一格的字：**有對照句就畫對照句，沒有才退到當下水準**。
    ///
    /// 後端的 `change` 只在有序列或有對照量時才給（SPEC-today-state §4.5：單一時點
    /// MUST NOT 推出趨勢），所以有氧續航／速度耐力／恢復這幾格恆為 null——它們給的是
    /// `value_text`。這裡原本只畫 `change`，於是那幾列右側只剩一顆方向點，28／70／61
    /// 整個被丟掉（2026-08-29 創辦人 prod 截圖）。
    ///
    /// 兩個都有時**只畫 `change`**：對照句本身已經含當下值（`37.7 → 38.5`），再擠一個
    /// `38.5` 進同一格是同一個數字講兩次。兩個都沒有（`not_computed`）就回 nil，
    /// 那一格不畫——不畫空字串，也不補 0。
    static func insightTrailingText(_ insight: App2Insight) -> String? {
        insight.change ?? insight.value
    }

    /// 一列指標的版面。**指標名與判語都是後端給的自由字串**，長度不受畫面控制
    /// （`reason_guard` 只約束今日卡的 headline／direction，指標列沒有字數閘門），
    /// 英文一來就四格全被截成 `Aerobic…`／`Still buil…`／`On the st…`
    /// （2026-09-12 使用者 prod 截圖）。所以一行是**偏好**不是唯一版面：
    /// 名稱與判語帶 `fixedSize()` 交出真實固有寬度，`ViewThatFits` 量得出放不下，
    /// 放不下就把判語降到名稱下一行；右邊那組的**縮放退路只在降級版保留**
    /// （見 `insightRowTrailing` 的 `rigid`）。
    /// 中文照舊走第一個分支，跟修前完全一樣。
    private func insightRowContent(_ insight: App2Insight, isTappable: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            insightRowOneLine(insight, isTappable: isTappable)
            insightRowStacked(insight, isTappable: isTappable)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 2)
    }

    private func insightRowOneLine(_ insight: App2Insight, isTappable: Bool) -> some View {
        HStack(spacing: 10) {
            insightRowIcon(insight)
            insightRowLabel(insight).fixedSize()
            if let verdict = insight.verdict {
                insightRowVerdict(verdict, tint: insight.tint).fixedSize()
            }
            Spacer(minLength: 6)
            insightRowTrailing(insight, isTappable: isTappable, rigid: true)
        }
    }

    private func insightRowStacked(_ insight: App2Insight, isTappable: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            insightRowIcon(insight)
            VStack(alignment: .leading, spacing: 3) {
                insightRowLabel(insight)
                if let verdict = insight.verdict {
                    insightRowVerdict(verdict, tint: insight.tint)
                }
            }
            Spacer(minLength: 6)
            insightRowTrailing(insight, isTappable: isTappable, rigid: false)
        }
    }

    private func insightRowIcon(_ insight: App2Insight) -> some View {
        Image(systemName: insight.symbolName)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(insight.tint)
            .frame(width: 20)
    }

    private func insightRowLabel(_ insight: App2Insight) -> some View {
        Text(insight.label)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(App2Theme.inkSubtle)
            .lineLimit(1)
    }

    private func insightRowVerdict(_ verdict: String, tint: Color) -> some View {
        Text(verdict)
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(tint)
            .lineLimit(1)
    }

    /// 右邊那組（對照數字 ＋ 箭頭 ＋ chevron）。
    ///
    /// `rigid` 只在**量測用**的一行版為 true：`ViewThatFits` 要判「這一列放不放得下」，
    /// 數字那格就必須交出完整固有寬度，`minimumScaleFactor` 會讓它宣稱自己隨便都塞得下。
    /// 降級版（`rigid: false`）反過來要保留縮放退路——`change` 是後端的自由字串
    /// （`23 km vs 0 km last week` 這種），兩個分支都放不下時它得能縮，
    /// 不然壓力會轉嫁給左邊的指標名與判語，又變成 `Aerobic…`／`Still buil…`。
    @ViewBuilder
    private func insightRowTrailing(_ insight: App2Insight, isTappable: Bool,
                                    rigid: Bool) -> some View {
        if let trailing = Self.insightTrailingText(insight) {
            Text(trailing)
                .font(.app2Mono(12, weight: .bold))
                .foregroundStyle(App2Theme.inkFaint)
                .lineLimit(1)
                .minimumScaleFactor(rigid ? 1.0 : 0.7)
                .fixedSize(horizontal: rigid, vertical: false)
        }
        Text(insight.arrowGlyph)
            .font(.app2Mono(15))
            .foregroundStyle(insight.tint)
            .frame(width: 13)
        // 可點的那三列才有 chevron —— 沒有詳情稿的指標不畫，
        // 免得畫出一個按下去沒反應的入口。
        if isTappable {
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(App2Theme.chevron)
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
                case .needsV2Setup:
                    todayNeedsV2SetupContent
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
                if let pill = viewModel.todayPillState(isRest: session.isRest) {
                    todayStatusPill(pill)
                }
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

    /// V1 帳號的今日課那格（T-0449 / P-002 D4 裁決）。
    ///
    /// **版面沿今日課卡的空狀態**：小標 → 標題 → 一句說明 → 主按鈕。多出來的只有
    /// 標題與按鈕兩列 —— 設計包沒有畫這一格，所以不發明新的裝飾層，也不刪版面
    /// （卡片下半的 Rizo 對話帶照舊在，那是同一張卡的一部分）。
    ///
    /// 按鈕開的是**既有的** re-onboarding（設定頁「重設目標」、計畫結束態 CTA 同一個
    /// `App2OnboardingContainerView(isReonboarding: true)`），不做第二套目標設定流程。
    /// 走完由後端把 `training_version` 寫成 v2，`onFinished` 的 `forceRefresh()` 讓
    /// 首頁整組換掉。
    @ViewBuilder
    private var todayNeedsV2SetupContent: some View {
        Text(L10n.App2.Home.todaySection.localized)
            .font(.system(size: 13, weight: .heavy))
            .tracking(1.5)
            .foregroundStyle(App2Theme.inkMuted)
        Text(L10n.App2.Home.needsV2SetupTitle.localized)
            .font(.system(size: 17, weight: .heavy))
            .foregroundStyle(App2Theme.inkPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("App2_TodayNeedsV2Setup")
        Text(L10n.App2.Home.needsV2SetupBody.localized)
            .font(.system(size: 14, weight: .medium))
            .lineSpacing(2)
            .foregroundStyle(App2Theme.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
        Button {
            isShowingReonboarding = true
        } label: {
            Text(L10n.App2.Home.needsV2SetupCta.localized)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule().fill(App2Theme.accentBlue))
        }
        .accessibilityIdentifier("App2_TodayNeedsV2Setup_Reonboard")
    }

    /// 狀態 chip：有課的日子是「今天還沒跑」（橘點）→ 跑完變「今天已跑」（綠勾），
    /// 休息日是「安排休息」（綠勾）。完成訊號＝今天有一筆已完成紀錄
    /// （`todayCompletedWorkout`，與下方「今天已經跑完了」列同一個判準）——原本
    /// chip 沒接這個訊號，跑完當天會與完成列同框互相矛盾（2026-08-31 用戶截圖）。
    /// 三態的決策在 [App2HomeViewModel.todayPillState]（owner 佈線＋純函式）；
    /// 視覺本體抽成 [App2TodayStatusPill]，渲染層回歸測試直接畫它（T-0352）。
    private func todayStatusPill(_ pill: App2HomeViewModel.TodayPillState) -> some View {
        App2TodayStatusPill(pill: pill)
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
                        opening: Self.rizoOpening(from: viewModel.rizoOpeningLine)
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
        // 視覺上的膠囊只有 ~32pt 高，低於 44pt 的最小可點區域（實測：以文字或座標點按
        // 常常沒開 sheet，只有用 a11y id 點才開）。把可點區域撐到 44pt，外觀不變。
        .frame(minHeight: 44)
        .contentShape(Rectangle())
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

    /// **文案與目標週都由 `App2WeekReviewState` 給**（`title`／`subtitle`／`targetWeek`），
    /// 這一段只負責畫。狀態是 nil ＝ 整卡隱藏（§A.5 第 1 列與計畫結束態）。
    @ViewBuilder
    private var weeklyReviewRow: some View {
        if let state = viewModel.weekReview {
            entryRow(
                symbol: "chart.line.uptrend.xyaxis",
                title: state.title,
                subtitle: state.subtitle,
                identifier: "App2_WeekReviewEntry"
            )
            .contentShape(Rectangle())
            .onTapGesture {
                weeklyReviewWeek = App2WeeklyReviewTarget(
                    weekOfPlan: state.targetWeek,
                    isCurrentWeek: state.isCurrentWeek
                )
            }
            .accessibilityAddTraits(.isButton)
        }
    }

    // MARK: - Garmin 缺歷史資料權限（T-0438）

    /// 只在後端說 `history_prompt_eligible == true` 時出現。
    ///
    /// 那個布林背後是三個條件（權限確實 `missing`、連線 ≤7 天、沒成功拿過歷史），
    /// **App 不重判**——少判一個就會對已經授權過的人叫他再授權一次，那是 2026-09-05
    /// 明令禁止的誤報。「稍後」只收掉這一次，下次進首頁若條件仍成立會再出現；
    /// 連線滿 7 天後後端自己就不再回 true。
    @ViewBuilder
    private var garminHistoryPromptCard: some View {
        if viewModel.showsGarminHistoryPrompt && !garminHistoryPromptDismissed {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.orange)
                    Text(L10n.Garmin.historyPromptTitle.localized)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(App2Theme.inkPrimary)
                    Spacer(minLength: 0)
                }
                Text(L10n.Garmin.historyPromptBody.localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button {
                        // 只負責把授權頁推上來。**重讀不掛在這裡**——`startConnection()`
                        // 推完 Safari 就返回，那一刻使用者連授權頁都還沒看到。真正走完是
                        // `handleCallback(url:)`，view model 訂的是它發的 tick（外審 D04）。
                        Task { await GarminManager.shared.startConnection() }
                    } label: {
                        Text(L10n.Garmin.historyPromptCta.localized)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .background(
                                Capsule().fill(App2Theme.accentBlue)
                            )
                    }
                    .accessibilityIdentifier("App2_GarminHistoryPrompt_Reauthorize")

                    Button {
                        garminHistoryPromptDismissed = true
                    } label: {
                        Text(L10n.Garmin.historyPromptDismiss.localized)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(App2Theme.inkSecondary)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("App2_GarminHistoryPrompt_Later")
                    Spacer(minLength: 0)
                }
            }
            .padding(App2Theme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: App2Theme.cardCornerRadius, style: .continuous)
                    .fill(App2Theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: App2Theme.cardCornerRadius, style: .continuous)
                    .stroke(App2Theme.cardBorder, lineWidth: 1)
            )
            .accessibilityIdentifier("App2_GarminHistoryPrompt")
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
/// **對話本體是既有的 `RizoChatView`**（泡泡、typing、改課表提案卡、付費牆全都在
/// 裡面），只是關掉它自己的 header 與卡面，由 sheet 提供。
/// 狀態與送出是既有的 `StateRizoChatViewModel` → 既有 Rizo API，沒有第二套對話狀態。
///
/// **寫死的追問 chips 已經拿掉**（T-0434）：那三句每一輪回覆後都出現、與剛剛講的
/// 內容無關，使用者 2026-09-05 裁決直接拿掉。
///
/// **開起來預設是上次那一段**（T-0434）：使用者聊完退出、再開想看剛剛聊什麼，以前
/// 看不到——sheet 每次都新建一個 `sessionId=nil` 的對話。現在先讀 history，同一個
/// 使用者當地日的最新 session 帶回來並續聊；跨日就是新的一天、新的今日卡，開空白。
/// 頭上兩顆鈕給另外兩條路：「新對話」清空重開，「歷史」推 1.x 既有的 `RizoHistoryView`
/// 並用既有的 fork 續聊。
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
    }

    let context: Context
    /// 對話 ViewModel 由 sheet 自己持有。`@StateObject` 的 autoclosure 是**第一次
    /// render 才求值**，所以 `DependencyContainer` 解 `RizoRepository` 的時機仍在
    /// sheet 被打開之後，不是首頁一出現就解。
    @StateObject private var viewModel: StateRizoChatViewModel
    @Environment(\.dismiss) private var dismiss
    /// 歷史對話清單（1.x 既有畫面）。
    @State private var isPresentingHistory = false
    /// 只在 sheet 第一次出現時去讀 history —— `onAppear` 在 sheet 生命週期裡會不只
    /// 觸發一次，重讀會把使用者剛打的字蓋掉。
    @State private var hasRestored = false

    init(context: Context, scenario: String) {
        self.context = context
        _viewModel = StateObject(wrappedValue: StateRizoChatViewModel(scenario: scenario))
    }

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
        // 先試著把今天那一段對話帶回來；帶不回來才用本機組好的開場白起頭
        // （context 那兩句話畫面上已經有了，不多打一次 LLM）。
        .task {
            guard !hasRestored else { return }
            hasRestored = true
            if await viewModel.restoreTodaySession() { return }
            viewModel.seedOpening(context.opening)
        }
        .sheet(isPresented: $isPresentingHistory) {
            RizoHistoryView { fork in
                viewModel.resumeFromHistory(fork)
            }
        }
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
            headerButton(
                systemImage: "square.and.pencil",
                label: L10n.App2.Home.rizoNewChat.localized,
                identifier: "App2_RizoNewChat"
            ) {
                viewModel.startNewConversation()
                viewModel.seedOpening(context.opening)
            }
            headerButton(
                systemImage: "clock.arrow.circlepath",
                label: L10n.App2.Home.rizoHistory.localized,
                identifier: "App2_RizoHistory"
            ) {
                isPresentingHistory = true
            }
            headerButton(
                systemImage: "xmark",
                label: NSLocalizedString("common.close", comment: "Close"),
                identifier: "App2_RizoChatClose"
            ) {
                dismiss()
            }
        }
        .padding(.horizontal, App2Theme.pagePadding)
        .padding(.vertical, 12)
    }

    /// sheet 頭上的圓鈕。三顆（新對話／歷史／關閉）共用同一份 —— 三段各寫一次
    /// 就會長出三種點擊區域，而關閉鈕的可點區域曾經就是這樣掉到 44pt 以下的。
    private func headerButton(
        systemImage: String,
        label: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Circle()
            .fill(App2Theme.insetBackground)
            .frame(width: 34, height: 34)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(App2Theme.inkSubtle)
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(label)
            .accessibilityIdentifier(identifier)
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


/// 今日卡狀態 chip（T-0352 抽成獨立 view，供渲染層回歸測試直接繪製）。
struct App2TodayStatusPill: View {
    let pill: App2HomeViewModel.TodayPillState

    var body: some View {
        HStack(spacing: 5) {
            if pill.showsCheck {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .black))
            } else {
                Circle()
                    .fill(App2Theme.accentOrangeBright)
                    .frame(width: 6, height: 6)
            }
            Text(pill.textKey.localized)
                .font(.system(size: 13, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(pill.showsCheck ? App2Theme.accentGreen : App2Theme.accentOrangeText)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(
                (pill.showsCheck ? App2Theme.accentGreenBright : App2Theme.accentOrangeSoft)
                    .opacity(0.16)
            )
        )
    }
}
