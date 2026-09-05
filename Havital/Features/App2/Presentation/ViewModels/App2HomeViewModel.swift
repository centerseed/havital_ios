import Combine
import Foundation

// MARK: - App2HomeViewModel
/// Presentation Layer — 2.0 首頁（`DESIGN-app2-decision-chain-api.md` §3.1／§3.1a）。
///
/// 每個區塊各自載入、各自失敗、各自標來源：一條端點掛掉不該讓整個首頁空白。
///
/// **同一個事實只讀一次。** `current_week`／`total_weeks`／`current_week_plan_id`
/// 全部來自同一次 `GET /v2/plan/status`，由 `revalidate()` 取一次後傳給各區塊。
/// 之前三個區塊各打各的，三個回應可以彼此不一致 —— 2026-08-25 用戶截圖上「目標卡
/// 1/17、狀況卡 6/18、今日課表說尚未產生」就是同一屏三份答案。
@MainActor
final class App2HomeViewModel: ObservableObject, TaskManageable, App2Revalidating {

    // MARK: - Published

    @Published private(set) var isLoading = true
    /// 這一頁載成功過至少一次。SWR 用：載過就不再出 loading 骨架。
    private(set) var hasLoaded = false
    private(set) var lastLoadedAt: Date?
    /// 這一輪的子載入是否吃到取消（-999 取消錯誤不設 `Task.isCancelled`）。
    /// 有＝整輪不標載過，下次 SWR 重試（外審第八輪 D04/E03）。
    private var roundSawCancellation = false

    /// 只有現任輪的取消才記進共用旗標——被接管的舊輪不得污染新輪
    /// （T-0359 外審第二輪 D04）。
    private func noteRoundCancellation() {
        if App2RevalidateRound.id == revalidateGeneration { roundSawCancellation = true }
    }
    /// 被接管的舊輪（在輪內、代號非現任）。helper 在 await 後寫共用狀態前必查
    /// ——不在任何輪內（id == 0，使用者動作路徑）不受限（外審第四輪 D04）。
    private var isStaleRound: Bool {
        App2RevalidateRound.id != 0 && App2RevalidateRound.id != revalidateGeneration
    }
    /// revalidate 的同輪互斥（見 revalidate 開頭的註解）。
    private var isRevalidating = false
    /// 這一輪重驗的起點（判卡死用，見 revalidate 開頭）。
    private var revalidateBegan: Date?
    /// 鎖的輪次所有權：被接管的卡死輪回來時不得放掉新輪的鎖（T-0359 外審 D04）。
    private var revalidateGeneration = 0
    /// 現任輪的 task：接管時取消它，逼舊輪走取消路徑退出。
    private var revalidateRoundTask: Task<Void, Never>?
    @Published private(set) var goalCard: App2Sourced<App2GoalCard>?
    /// 計畫結束態（設計 frame-00g）。**有值時首頁的目標卡＋今日課表卡整段換掉**
    /// —— 那是同一塊版位的另一種內容，不是多一張卡。
    ///
    /// 判準只有 `next_action == "training_completed"`，與週回顧時機卡收掉的判準是
    /// **同一欄**（`weekReviewState` 的第一道 guard）—— 所以兩張卡不會同屏。
    @Published private(set) var planEnd: App2PlanEndCard?
    @Published private(set) var trainingStatus: App2Sourced<App2TrainingStatus>?
    @Published private(set) var insights: App2Sourced<[App2Insight]>?
    /// 四個固定距離的完賽預估（T-0376）。能力基準詳情頁（§52）用它。
    ///
    /// **住在首頁 VM 是因為資料在這裡就已經有了**：`loadGoalCard` 每一輪都會
    /// `await readinessViewModel.loadData()`（cache-first ＋ 背景重驗，走既有的
    /// `TrainingReadinessManager`），完賽預估與目標卡的「預估完賽」是**同一份
    /// readiness response** 的兩個欄位。詳情頁沿 `insight`／`narrative` 同一條路
    /// 拿走它，不新增請求、不新增快取、不新增失效訂閱。
    ///
    /// 空陣列 ＝ 這一份 readiness 沒有完賽預估 → 詳情頁整區不畫。
    @Published private(set) var finishPredictions: [App2FinishPrediction] = []
    /// 今日課表卡。nil = 這一輪還沒載完；其餘四態見 `App2TodaySessionState`。
    @Published private(set) var todayState: App2TodaySessionState?
    /// 今日課表卡點下去要開的訓練詳情（設計 frame-02）。
    /// **與卡片同一份 payload**，詳情頁不再打任何端點；休息日為 nil（不進詳情）。
    @Published private(set) var todayDetail: App2SessionDetail?
    @Published private(set) var weekReview: App2WeekReviewState?
    /// 要不要畫「Garmin 缺歷史資料權限」提示卡（T-0438）。
    ///
    /// **只由後端的 `history_prompt_eligible` 決定**，App 不自己判——那個布林背後是三個條件
    /// （權限確實 missing、連線 ≤7 天、沒成功拿過歷史），少判一個就是誤報。
    /// 讀不到（網路失敗、舊版後端沒這欄位）維持 false，什麼都不畫。
    @Published private(set) var showsGarminHistoryPrompt = false
    /// 今天已經跑完的那一筆紀錄（裝置當地日曆的今天）。有值時今日課表卡多一列
    /// 「看這次的訓練詳情」（設計 frame-15 的入口之一）。沒跑就是 nil。
    @Published private(set) var todayCompletedWorkout: WorkoutV2?
    /// 內嵌 Rizo 卡的教練推話。**由 `/v2/state/today` 的句子組出來**，
    /// 組不出來就是 nil ——那時 Rizo 區退成純入口，不顯示假對話。
    @Published private(set) var rizoOpeningLine: String?
    /// 交棒情境（`card.rizoScenario`）。開對話時帶給既有的 `StateRizoChatViewModel`。
    @Published private(set) var rizoScenario: String?

    // §7-16 軌跡圖序列已整塊移除（2026-08-26 裁決）：backend 沒有序列端點，
    // 畫面上掛的是永遠不會變成真資料的樣本圖。等端點落地再依當時的設計重議。

    nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Dependencies

    private let dailyStateRepository: DailyStateRepository
    private let targetRepository: TargetRepository
    /// **課表資料只有這一個入口。**（2026-08-26 架構收斂）plan status／週課表／overview
    /// 全部走它，App2 不再自己持有 `TrainingPlanV2RemoteDataSource`，冷啟先渲染的那一份
    /// 也是它的快取，不另存一份 App2 專屬快照。
    private let planRepository: TrainingPlanV2Repository
    private let readinessViewModel: TrainingReadinessViewModel
    /// 結束態的「當時預估」要**指定日期**那一筆（賽事日），`TrainingReadinessViewModel`
    /// 只交最新的那一筆，所以直接走它底下的同一支既有服務，不新增第二條路徑。
    private let readinessService: TrainingReadinessProviding
    /// 紀錄頁用的同一支 `GET /v2/workouts`，不另開端點。
    private let workoutDataSource: WorkoutStatsDataSourceProtocol
    /// 冷啟快照。只剩「今天跑完沒」那一頁 workouts —— 課表那幾支已收進 repository 快取。
    private let snapshots: any App2SnapshotStoring

    // MARK: - Init

    init(
        dailyStateRepository: DailyStateRepository? = nil,
        targetRepository: TargetRepository? = nil,
        planRepository: TrainingPlanV2Repository? = nil,
        readinessViewModel: TrainingReadinessViewModel? = nil,
        readinessService: TrainingReadinessProviding? = nil,
        workoutDataSource: WorkoutStatsDataSourceProtocol? = nil,
        snapshots: (any App2SnapshotStoring)? = nil
    ) {
        let container = DependencyContainer.shared
        self.snapshots = snapshots ?? App2FileSnapshotStore.shared

        if let planRepository {
            self.planRepository = planRepository
        } else {
            if !container.isRegistered(TrainingPlanV2Repository.self) {
                container.registerTrainingPlanV2Module()
            }
            self.planRepository = container.resolve() as TrainingPlanV2Repository
        }

        if let dailyStateRepository {
            self.dailyStateRepository = dailyStateRepository
        } else {
            if !container.isRegistered(DailyStateRepository.self) {
                container.registerDailyStateModule()
            }
            self.dailyStateRepository = container.resolve() as DailyStateRepository
        }

        if let targetRepository {
            self.targetRepository = targetRepository
        } else {
            if !container.isRegistered(TargetRepository.self) {
                container.registerTargetModule()
            }
            self.targetRepository = container.resolve() as TargetRepository
        }

        self.readinessViewModel = readinessViewModel ?? TrainingReadinessViewModel()
        self.readinessService = readinessService ?? TrainingReadinessService.shared
        self.workoutDataSource = workoutDataSource ?? WorkoutRemoteDataSource()

        #if DEBUG
        // 開發者走查：切了 override 就要立刻看到那一格，不必先下拉刷新
        // （見 `Features/App2/Debug/App2WeeklyReviewDevView.swift`）。
        devOverrideSubscription = App2DevSettings.shared.$weekReviewOverride
            .dropFirst()
            .sink { [weak self] override in
                guard let self, let status = self.lastPlanStatus else { return }
                if let forced = override.resolve(planStatus: status) {
                    self.weekReview = forced
                } else {
                    // 關掉覆寫 → 回到真實判斷，不用等下一輪網路。
                    Task { await self.loadWeekReview(planStatus: status) }
                }
            }

        // 結束態走查（設定 → Developer (DEBUG) → Plan End Dev Tools）。
        // 切了變體要立刻看到，而且**週回顧時機卡要跟著收掉** —— 兩張卡互斥，
        // 這裡與 production 走的是同一條互斥規則，不是走查專屬的特例。
        devPlanEndSubscription = App2DevSettings.shared.$planEndOverride
            .dropFirst()
            .sink { [weak self] override in
                guard let self, let inputs = self.lastPlanEndInputs else { return }
                // `@Published` 在 willSet 送值 —— 這時 `shared.planEndOverride` 還是舊值，
                // 所以把 sink 收到的那個記下來再重算（同 `weekReviewOverride` 的寫法）。
                self.devPlanEndOverride = override
                // 先用手上的輸入畫一次 —— 切了變體要立刻看到，不必等網路。
                self.applyPlanEnd(
                    planStatus: inputs.planStatus,
                    overview: inputs.overview,
                    target: inputs.target,
                    estimatedFinish: inputs.estimatedFinish
                )
                Task {
                    // 「當時預估」是**開啟 race 走查後才會去打**的那一條
                    // （`raceDayEstimate` 的 `shouldFetch`），所以要重跑一次目標卡
                    // 那條路徑，否則走查看到的永遠是空的預估欄。
                    await self.loadGoalCard(planStatus: inputs.planStatus)
                    if let status = self.lastPlanStatus {
                        await self.loadWeekReview(planStatus: status)
                    }
                }
            }
        #endif

        // 目標變更（賽事管理寫入＝`.dataChanged(.targets)`、重設目標＝
        // `.reonboardingCompleted`）：這顆 VM 常駐在 `App2RootView` 殼層，
        // 60 秒 SWR 門檻會把「改完馬上回首頁」擋在舊資料上（用戶要重開 app
        // 才看得到新目標卡，2026-08-28 實機回報）。收到事件就作廢時戳並立即重驗。
        CacheEventBus.shared.subscribe(forIdentifier: "App2HomeViewModel.targets") { [weak self] reason in
            switch reason {
            case .reonboardingCompleted, .dataChanged(.targets):
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.lastLoadedAt = nil
                    if self.hasLoaded { await self.revalidate() }
                }
            case .dataChanged(.workouts):
                // workout_processed 推播（T-0359）與其他 workouts 失效：完成列
                // （todayCompletedWorkout）要立即換新，不能等 60 秒 SWR 視窗。
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.lastLoadedAt = nil
                    if self.hasLoaded { await self.revalidate() }
                }
            // 單位切換（T-0366）：這一頁上的量是**投影時就格式化好的字串**，
            // View 觀察 `UnitManager` 只會重畫同一份舊字。收到就重投影一次。
            case .unitSystemChanged:
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.lastLoadedAt = nil
                    if self.hasLoaded { await self.revalidate() }
                }
            default:
                break
            }
        }
    }

    #if DEBUG
    /// 最後一次拿到的 plan status。**只給開發者走查用**：override 要用它的
    /// `current_week` 算目標週，關掉 override 時也要靠它重算真實那一格。
    private var lastPlanStatus: PlanStatusV2Response?
    private var devOverrideSubscription: AnyCancellable?

    /// 最後一次結束態投影用的那組輸入。切 override 時要靠它立刻重算，不必等下一輪網路。
    private var lastPlanEndInputs: (
        planStatus: PlanStatusV2Response?,
        overview: PlanOverviewV2?,
        target: Target?,
        estimatedFinish: String?
    )?
    private var devPlanEndSubscription: AnyCancellable?

    /// 走查用的結束態覆寫。**由 sink 保持同步**（`@Published` 在 willSet 送值，
    /// 直接讀 `shared` 會拿到上一格）。初值與 `App2DevSettings` 一致。
    private var devPlanEndOverride: App2DevPlanEndOverride = .off
    #endif

    deinit {
        cancelAllTasks()
    }

    // MARK: - Loading

    func revalidate() async {
        // 同一時間只跑一輪：兩輪並發會在 await 點交錯共用 `roundSawCancellation`
        // 與完成標記（外審第九輪 E08）。後進的直接跳過——SWR 下一次會再來。
        // 鎖是防重入，不是允許一輪卡住就永遠吞掉下拉刷新（T-0355，2026-08-31：
        // 推播已到、18:47–19:07 App 對後端零請求，重開 app 才恢復）。超過門檻
        // 視為前一輪卡死，讓位開新輪；卡死輪殘餘的 defer 只會提前放鎖，影響
        // 背景 SWR 的重入時機，資料發布仍在 MainActor 上序列化。
        if App2RevalidatePolicy.shouldBlock(isRevalidating: isRevalidating, began: revalidateBegan) {
            return
        }
        // 接管：真正取消被判卡死的舊輪——其取消 guard 會丟棄後續發布與狀態寫入，
        // 舊輪不得再影響新輪（T-0359 外審第二輪 D04）。
        revalidateRoundTask?.cancel()
        isRevalidating = true
        revalidateBegan = Date()
        revalidateGeneration += 1
        let round = revalidateGeneration
        let roundTask = Task { [weak self] in
            guard let self else { return }
            await App2RevalidateRound.$id.withValue(round) {
                await self.revalidateRound(round)
            }
        }
        revalidateRoundTask = roundTask
        // 呼叫端 task 被取消時把取消轉發進本輪（取消語意不變）。
        await withTaskCancellationHandler {
            await roundTask.value
        } onCancel: {
            roundTask.cancel()
        }
        if revalidateGeneration == round {
            isRevalidating = false
            revalidateRoundTask = nil
        }
    }

    private func revalidateRound(_ round: Int) async {

        // 冷啟第一輪：先把上一次的快照渲染出來，這一輪的網路變成背景刷新。
        if !hasLoaded { await hydrateFromSnapshot() }

        // 每個 await 恢復點都要重驗輪代號：被接管的舊輪恢復後不得再碰共用狀態
        //（isLoading／roundSawCancellation 也算——外審第三輪 D04）。
        guard revalidateGeneration == round else { return }

        // 只有「從未載過、也沒有快照可看」才出 loading ——
        // 重驗時畫面保留上一次的資料，不閃白。
        isLoading = !hasLoaded && trainingStatus == nil && todayState == nil && goalCard == nil

        roundSawCancellation = false
        // 全頁共用的一次 plan status。三張卡都從這一份取週數與本週課表 id。
        let planStatus = await fetchPlanStatus()
        guard revalidateGeneration == round else { return }

        // 其餘區塊獨立：一條失敗不阻斷其他。
        async let state: Void = loadDailyState(planStatus: planStatus.value)
        async let goal: Void = loadGoalCard(planStatus: planStatus.value)
        async let today: Void = loadTodaySession(planStatus: planStatus)
        async let review: Void = loadWeekReview(planStatus: planStatus.value)
        async let completed: Void = loadTodayCompletedWorkout()
        async let garminHistory: Void = loadGarminHistoryPrompt()
        _ = await (state, goal, today, review, completed, garminHistory)

        // loading 態的收尾也只有現任輪能做——舊輪清掉新輪的 spinner 會讓首載
        // 卡在空畫面（外審第三輪 D04）。
        guard revalidateGeneration == round else { return }
        isLoading = false
        // 被取消的那一輪不算載過：子載入各自有取消 guard 不動畫面，這裡也不標
        // hasLoaded／lastLoadedAt，下次進頁的 SWR 會重試（2026-08-29 外審 D04/E03）。
        // 取消有兩種形態：task 本身被取消，或 in-flight 請求回 -999 被折成
        // `.cancelled` outcome（`URLError(.cancelled)` 不會設 `Task.isCancelled`）——兩種都算。
        if case .cancelled = planStatus { return }
        guard !Task.isCancelled, !roundSawCancellation, revalidateGeneration == round else { return }
        hasLoaded = true
        lastLoadedAt = Date()
    }

    /// 一次 plan status 的結果。`.failed` 與「拿到了但沒有本週課表」是兩件事，
    /// 今日課表卡要分得出來才不會把讀取失敗說成「尚未產生」。
    enum PlanStatusOutcome {
        case loaded(PlanStatusV2Response)
        case failed
        /// 這一輪被取消：不要動畫面上的既有資料。
        case cancelled

        var value: PlanStatusV2Response? {
            if case .loaded(let status) = self { return status }
            return nil
        }
    }

    // MARK: - 冷啟快照
    //
    // **投影只有一份。** 下面每一段都是把快照的 payload 餵進與網路路徑同一支
    // `apply*`／`static` 投影，不另寫一套「快取版」的組裝 —— 兩份組裝遲早會長出
    // 兩種畫面。
    //
    // 任何一段缺快照就跳過那一段（畫面維持現行的 spinner／空狀態），
    // 不用樣本補：樣本是「後端沒給」時的降級，不是「還沒載完」的填充。

    private func hydrateFromSnapshot() async {
        let status = planRepository.getCachedPlanStatus()

        if let card = dailyStateRepository.cachedTodayState() {
            applyDailyState(card: card, planStatus: status)
        }

        if let status,
           let plan = planRepository.getCachedWeeklyPlan(week: status.currentWeek),
           Self.isWeeklyPlan(plan, boundTo: status) {
            applyTodaySession(plan: plan)
        }

        if let rows = snapshots.load([WorkoutV2].self, for: .homeRecentWorkouts)?.value {
            todayCompletedWorkout = Self.todayWorkout(rows)
        }

        // 週回顧：平日的目標週是上一週，`plan status` 自己就帶了摘要 id，
        // 快照夠用。週日看的是「本週」，那要另打一支 `getWeeklySummary()`，
        // 不在快照裡 —— 那天冷啟就等網路，不猜。
        //
        // **快取的 status 是時間敏感的**（坑 `576c60e6`：`next_action` 過期會讓
        // 冷啟按鈕閃爍）。這裡只拿它先畫一次，`revalidate()` 這一輪的網路值回來
        // 就整個覆蓋 —— `weekReview` 不做「有值就不更新」的合併。
        if let status, !Self.isSundayInUserTimezone(status) {
            weekReview = Self.weekReviewState(
                planStatus: status,
                isSunday: false,
                summaryId: status.previousWeekSummaryId
            )
        }

        // 目標賽事卡：賽事本體已經在既有的 `TargetLocalDataSource`（UserDefaults）裡，
        // 不需要第二份落地。缺的只是週數（來自 plan status 快照）；完賽預估與期別
        // 都要打網路，先留白，這一輪回來再靜默補上。
        if let main = await targetRepository.getMainTarget() {
            goalCard = Self.goalCard(
                target: main,
                planStatus: status,
                stageLabel: nil,
                estimatedFinish: nil,
                // 冷啟預渲染：畫面上還沒有任何一版可沿用。
                displayedCurrentWeek: nil,
                displayedTotalWeeks: nil,
                origin: .live(endpoint: "GET /user/targets + GET /v2/plan/status")
            )
        }
    }

    /// 今日課表卡狀態 chip 的三態（T-0352）：休息日綠勾「安排休息」、已跑綠勾
    /// 「今天已跑」、未跑橘點「今天還沒跑」。休息日優先——休息日的完成紀錄
    /// （自主訓練）不把 chip 改成「已跑」，卡片語意仍是「今天安排休息」。
    /// 抽成純函式是為了把「跑完仍顯示還沒跑」的矛盾鎖進單元測試
    /// （2026-08-31 用戶截圖，chip 與完成列同框互相矛盾）。
    struct TodayPillState: Equatable {
        let showsCheck: Bool
        let textKey: String
    }

    /// Owner 佈線：view 只給 isRest，完成訊號由 VM 自己讀（與完成列同源）。
    func todayPillState(isRest: Bool) -> TodayPillState? {
        Self.todayPillState(isRest: isRest, isDone: todayCompletedWorkout != nil)
    }

    /// 已完成回 nil：完成資訊由卡片完成列獨佔，chip 不重複顯示
    /// （2026-08-31 使用者裁決，修正 T-0352 的「已跑」態）。
    static func todayPillState(isRest: Bool, isDone: Bool) -> TodayPillState? {
        if isRest { return TodayPillState(showsCheck: true, textKey: L10n.App2.Home.todayRest) }
        if isDone { return nil }
        return TodayPillState(showsCheck: false, textKey: L10n.App2.Home.todayTodo)
    }

    /// 這份快取的週課表是不是 plan status 指向的那一份。
    /// 對不上（跨週、或換了計畫）就不拿它當今天的課 —— 寧可等網路。
    static func isWeeklyPlan(_ plan: WeeklyPlanV2, boundTo status: PlanStatusV2Response) -> Bool {
        guard let currentId = status.currentWeekPlanId else { return false }
        return plan.effectivePlanId == currentId
    }

    private func fetchPlanStatus() async -> PlanStatusOutcome {
        do {
            // `forceRefresh` ＝ 這一輪一定走網路（落地由 repository 做，供下次冷啟用）。
            // SWR 的「先舊後新」由 `hydrateFromSnapshot` 負責，不靠 repository 的 cooldown。
            let status = try await planRepository.getPlanStatus(forceRefresh: true)
            return .loaded(status)
        } catch {
            // 取消不是失敗（`AGENTS.md` 陷阱 2）：下拉刷新的 task 被 SwiftUI 收掉時
            // in-flight 請求會回 -999。
            if error.isCancellationError { return .cancelled }
            Logger.debug("[App2HomeVM] plan status 取得失敗: \(error)")
            return .failed
        }
    }

    // MARK: - §3.1a 訓練狀況卡 ＋ 指標膠囊列 ＋ Rizo 推話
    //
    // 三者同一個來源：`GET /v2/state/today`。
    //
    // **指標列不再打 `/v2/athlete-state/metrics`。** 那條端點依規格只交 envelope、
    // 不評級也不渲染句子（ME-INV-05），所以綁它的膠囊永遠沒有 verdict 也沒有箭頭
    // ——2026-08-25 在 dev 上實測就是整排灰 icon ＋ 小點。`state/today` 的
    // `insights[]` 才是已評級、已在地化的那一份（`label`／`arrow`／`verdict`／
    // `change`／`dot`／`status`），設計文件 §3.1a 指到前者是判定錯誤，票面已記。

    private func loadDailyState(planStatus: PlanStatusV2Response?) async {
        do {
            // 落地由 `DailyStateRepositoryImpl` 在成功回應時做（存 DTO），
            // 這裡拿到的已經是 entity。
            let card = try await dailyStateRepository.fetchTodayState()
            guard !isStaleRound else { return }
            applyDailyState(card: card, planStatus: planStatus)
        } catch {
            // 取消不是失敗（`AGENTS.md` 陷阱 2）。下拉刷新的 task 被 SwiftUI 收掉時
            // 每一條 in-flight 請求都會回 -999；當成失敗會把畫面上的真資料換成樣本。
            guard !error.isCancellationError else { noteRoundCancellation(); return }
            guard !isStaleRound else { return }
            Logger.debug("[App2HomeVM] state/today 取得失敗,退樣本: \(error)")
            if trainingStatus == nil {
                trainingStatus = App2Sourced(
                    // **樣本只填敘事，週數一律用真的。** 樣本檔已經不帶週數欄位，
                    // 這裡再明寫一次來源，避免日後有人把週數塞回樣本。
                    Self.offlineTrainingStatus(
                        currentWeek: planStatus?.currentWeek,
                        totalWeeks: planStatus?.totalWeeks
                    ),
                    origin: .stub(pendingSection: App2StubFixtures.Section.offline)
                )
            }
            if insights == nil {
                insights = App2Sourced(
                    App2StubFixtures.insights,
                    origin: .stub(pendingSection: App2StubFixtures.Section.offline)
                )
            }
        }
    }

    /// 狀況卡 ＋ 指標列 ＋ Rizo 推話的組裝。網路回應與冷啟快照都走這一支。
    private func applyDailyState(card: DailyStateCard, planStatus: PlanStatusV2Response?) {
        trainingStatus = App2Sourced(
            Self.trainingStatus(
                card: card,
                currentWeek: planStatus?.currentWeek,
                totalWeeks: planStatus?.totalWeeks
            ),
            origin: .live(endpoint: "GET /v2/state/today")
        )

        let rows = Self.insights(rows: card.insights)
        if rows.isEmpty {
            // 端點沒帶 insights（舊版後端）→ 這一列先退樣本並掛徽章。
            Logger.debug("[App2HomeVM] state/today 沒有 insights,指標列退樣本")
            insights = App2Sourced(
                App2StubFixtures.insights,
                origin: .stub(pendingSection: App2StubFixtures.Section.insightVerdict)
            )
        } else {
            insights = App2Sourced(rows, origin: .live(endpoint: "GET /v2/state/today"))
        }

        rizoOpeningLine = Self.rizoOpeningLine(card: card)
        rizoScenario = card.rizoScenario
    }

    // MARK: - §3.1 今日課表卡
    //
    // 資料來源是**本週課表的今日項目**（`GET /v2/plan/status` → `GET /v2/plan/weekly/{id}`
    // 的 `days[day_index == 今天]`），不是 `/v2/state/today` 的 `action_line`
    // ——後者是一行已渲染的字（`8K easy`），拆不出課型／強度／內容三個欄位，
    // 也不會在地化。
    //
    // 「本週課表尚未產生」只有在 `current_week_plan_id` 真的是 nil 時才准講。

    private func loadTodaySession(planStatus: PlanStatusOutcome) async {
        switch planStatus {
        case .cancelled:
            return  // 保留上一次的今日課表，不清成空狀態。
        case .failed:
            if todayState == nil { todayState = .unavailable }
            return
        case .loaded(let status):
            guard let planId = status.currentWeekPlanId else {
                Logger.debug("[App2HomeVM] 本週課表尚未產生 (next_action=\(status.nextAction))")
                todayState = .notGenerated
                return
            }
            do {
                let plan = try await planRepository.fetchWeeklyPlan(planId: planId)
                guard !isStaleRound else { return }
                applyTodaySession(plan: plan)
            } catch {
                guard !error.isCancellationError else { noteRoundCancellation(); return }
                guard !isStaleRound else { return }
                Logger.debug("[App2HomeVM] 今日課表取得失敗（plan_id=\(planId)）: \(error)")
                todayState = .unavailable
            }
        }
    }

    /// 今日課表卡 ＋ 它的詳情。網路回應與冷啟快照都走這一支。
    private func applyTodaySession(plan: WeeklyPlanV2) {
        let todayIndex = App2WeekCalendar.todayDayIndex()
        guard let session = Self.todaySession(
            days: plan.days,
            todayIndex: todayIndex,
            dayLabel: Self.todayLabel()
        ) else {
            todayState = .noSessionToday
            todayDetail = nil
            return
        }
        todayState = .session(session)
        todayDetail = plan.days
            .first { $0.dayIndex == todayIndex }
            .flatMap {
                App2SessionDetailProjection.detail(
                    day: $0,
                    weekStart: App2WeekCalendar.currentWeekStart(),
                    // 配速帶的溫度補償（裁決（n））要今天的氣候，走 `WeeklyPlanV2` 的
                    // UI 唯一入口，不在這裡自己解 `climate_meta`。
                    climateDay: plan.climate(forDayIndex: todayIndex)
                )
            }
    }

    // MARK: - 今天已跑完的那一筆

    /// 今天有沒有跑完一筆。**判準是裝置當地日曆的今天**（`start_time_utc` 是 UTC
    /// instant，先換算成當地時間再比），不是 UTC 的今天 —— 台北清晨 06:32 的跑步
    /// 在 UTC 還是昨天。
    ///
    /// 只取最近幾筆就夠：今天的紀錄一定在最前面。
    private func loadTodayCompletedWorkout() async {
        do {
            let rows = try await workoutDataSource.fetchRecentWorkouts(pageSize: 10)
            guard !isStaleRound else { return }
            snapshots.save(rows, for: .homeRecentWorkouts)
            todayCompletedWorkout = Self.todayWorkout(rows)
        } catch {
            guard !error.isCancellationError else { noteRoundCancellation(); return }
            Logger.debug("[App2HomeVM] 今日紀錄查詢失敗: \(error)")
        }
    }

    static func todayWorkout(
        _ rows: [WorkoutV2],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WorkoutV2? {
        rows.first { workout in
            guard workout.startTimeUtc != nil else { return false }
            return calendar.isDate(workout.startDate, inSameDayAs: now)
        }
    }

    // MARK: - 週回顧 CTA
    //
    // 設計 `DESIGN-app2-weekly-review-and-plan-end-inventory` §A.5 的狀態機表：
    // 週日＝「產生本週回顧」，週一～六＝「產生上週回顧」，目標週的回顧已經在了
    // 就改成「查看回顧」。**「今天是不是週日」由後端的使用者時區決定**（§A.1），
    // 不看裝置星期。

    /// 讀一次 `history_prompt_eligible`（T-0438 Contract 4）。
    ///
    /// 失敗一律當 false：這張卡叫使用者去重新授權 Garmin，寧可不出現，也不要對一個
    /// 其實已經授權過的人出現（2026-09-05 裁決「提示不得誤報」）。
    /// 只在資料來源是 Garmin 時才問——其他來源問了也只會拿到 not_connected。
    private func loadGarminHistoryPrompt() async {
        guard UserPreferencesManager.shared.dataSourcePreference == .garmin else {
            showsGarminHistoryPrompt = false
            return
        }
        do {
            let status = try await GarminConnectionStatusService.shared.checkConnectionStatus()
            // 過期的那一輪不得動畫面（同 `loadTodayCompletedWorkout` 的判準）。
            guard !isStaleRound else { return }
            showsGarminHistoryPrompt = status.shouldPromptForHistoryPermission
        } catch {
            // **取消不是答案**：被取消的那一輪把旗標寫成 false，會把上一輪已經算出來的
            // true 蓋掉，卡片就這樣消失了。取消只記一筆，畫面留給現任輪。
            guard !error.isCancellationError else { noteRoundCancellation(); return }
            guard !isStaleRound else { return }
            showsGarminHistoryPrompt = false
        }
    }

    private func loadWeekReview(planStatus: PlanStatusV2Response?) async {
        guard let planStatus else { return }

        #if DEBUG
        lastPlanStatus = planStatus
        // 結束態走查一開，時機卡就收掉 —— 與 production 的互斥規則同一條
        // （`weekReviewState` 的第一道 guard 讀的是同一個事實）。
        // 擺在週回顧 override 之前：兩個走查同時開時，結束態贏，
        // 免得走查出一個真實資料上不可能出現的組合。
        if devPlanEndOverride.isForcing {
            weekReview = nil
            return
        }
        // 開發者走查（設定 → Developer (DEBUG) → Weekly Review Dev Tools）。
        // **只換呈現的那一格**，下面真實的判斷路徑照跑不誤，關掉就恢復。
        if let forced = App2DevSettings.shared.weekReviewOverride.resolve(planStatus: planStatus) {
            weekReview = forced
            return
        }
        #endif

        let isSunday = Self.isSundayInUserTimezone(planStatus)

        if !isSunday {
            // 上週回顧的存在與否，`/v2/plan/status` 已經直接給了，不必多打一條。
            weekReview = Self.weekReviewState(
                planStatus: planStatus,
                isSunday: false,
                summaryId: planStatus.previousWeekSummaryId
            )
            return
        }

        // 週日看的是「本週」，plan status 沒有「本週回顧 id」這一欄。
        //
        // **後端在週日已經把答案放進 `next_week_info.requires_current_week_summary`**
        // （`service.py:1245`，值＝`not has_current_summary`）——那是持久化事實，
        // 不必為了同一個問題再打一次 `GET /v2/summary/weekly`。
        if let requiresSummary = planStatus.nextWeekInfo?.requiresCurrentWeekSummary {
            if requiresSummary {
                weekReview = Self.weekReviewState(planStatus: planStatus, isSunday: true, summaryId: nil)
                return
            }
            // 已生成 —— id 的組法是後端的（`{overview}_{week}_summary`），
            // client 不拼；問一次拿真的那顆。
        } else if planStatus.nextAction == "create_summary" {
            // `next_week_info` 是 null 的週日（最後一週：後端的
            // `can_generate_next_week` 壓了 `current_week < total_weeks`）。
            // `create_summary` 已經明說回顧還沒產生。
            weekReview = Self.weekReviewState(planStatus: planStatus, isSunday: true, summaryId: nil)
            return
        }

        var summaryId: String?
        do {
            // **唯讀探測。** 這裡問的是「本週回顧存在嗎、id 是多少」，不是「幫我產一份」。
            // `getWeeklySummary` 在 404 時 fallback 到 `POST`
            // （`TrainingPlanV2RepositoryImpl.fetchOrGenerateWeeklySummary`），
            // 所以上面那兩個 early return 沒接住的那一格——**計畫最後一週的週日**
            // （`next_week_info` 是 null 且 `next_action != create_summary`）——
            // 光是首頁載入就會靜默生成一份本週回顧。走 T-0362 建立的唯讀路徑
            // （同端點、同快取，只是不接那個 fallback）；沒有就是 nil。
            summaryId = try await planRepository.fetchWeeklySummary(weekOfPlan: planStatus.currentWeek)?.id
        } catch {
            guard !error.isCancellationError else { noteRoundCancellation(); return }
            Logger.debug("[App2HomeVM] 本週回顧查詢失敗,視為尚未產生: \(error)")
        }
        guard !isStaleRound else { return }
        weekReview = Self.weekReviewState(planStatus: planStatus, isSunday: true, summaryId: summaryId)
    }

    #if DEBUG
    /// 測試／預覽用：直接填入各區塊狀態，不打網路。
    /// （沿用 repo 既有的 `DailyStateCardViewModel.loadForTest()` 慣例。）
    func applyForTesting(
        goalCard: App2Sourced<App2GoalCard>? = nil,
        trainingStatus: App2Sourced<App2TrainingStatus>? = nil,
        insights: App2Sourced<[App2Insight]>? = nil,
        todayState: App2TodaySessionState? = nil,
        weekReview: App2WeekReviewState? = nil,
        rizoOpeningLine: String? = nil,
        planEnd: App2PlanEndCard? = nil,
        todayCompletedWorkout: WorkoutV2? = nil
    ) {
        self.planEnd = planEnd
        self.todayCompletedWorkout = todayCompletedWorkout
        self.goalCard = goalCard
        self.trainingStatus = trainingStatus
        self.insights = insights
        self.todayState = todayState
        self.weekReview = weekReview
        self.rizoOpeningLine = rizoOpeningLine
        isLoading = false
        hasLoaded = true
        lastLoadedAt = Date()
    }
    #endif

    // MARK: - 投影（純函式，可單獨測）
    //
    // 「payload → 畫面欄位」全部抽成 static：載入路徑要網路，投影不用。

    /// 訓練狀況卡（§3.1a）。
    /// `trackPosition` 目前沒有 producer（§7-2 同一批評級語意），恆置中。
    static func trainingStatus(
        card: DailyStateCard,
        currentWeek: Int?,
        totalWeeks: Int?
    ) -> App2TrainingStatus {
        // 標題綁 `/v2/state/today` 的 `headline`，**不是 `displayHeadline`**
        // （2026-08-26 使用者裁決）。`displayHeadline` 是 T-0241 給 1.4 收合卡的融合句
        // 規則（`collapsed_reason` 優先），會把標題變成「調整句」，而且 Android 沒有這條
        // ——同一個 payload 兩個平台印出不同的標題。融合句規則留在
        // `DailyStateCardView`（1.4）那一個呼叫點。
        App2TrainingStatus(
            headline: card.headline,
            narrative: card.narrativeText,
            // 首頁不畫這一句，它是訓練量詳情頁 hero 的敘事（checklist §51-2）。
            mileageProgression: card.mileageProgression,
            trackPosition: 0.5,
            currentWeek: currentWeek,
            totalWeeks: totalWeeks
        )
    }

    /// `state/today` 掛掉時的訓練狀況卡：敘事退樣本，**週數仍然是真的**。
    static func offlineTrainingStatus(currentWeek: Int?, totalWeeks: Int?) -> App2TrainingStatus {
        let stub = App2StubFixtures.trainingStatus
        return App2TrainingStatus(
            headline: stub.headline,
            narrative: stub.narrative,
            mileageProgression: nil,
            trackPosition: stub.trackPosition,
            currentWeek: currentWeek,
            totalWeeks: totalWeeks
        )
    }

    /// 今日課表卡（§3.1）。今天不在 `days` 裡就回 nil —— 呼叫端據此走 `.noSessionToday`。
    static func todaySession(
        days: [DayDetail],
        todayIndex: Int,
        dayLabel: String
    ) -> App2TodaySession? {
        guard let day = days.first(where: { $0.dayIndex == todayIndex }) else { return nil }
        let primary = day.session?.primary
        let dayType = primary == nil ? DayType.rest : App2PlanViewModel.dayType(primary)
        let segments = Self.segments(day: day)
        let durationMinutes: Int? = {
            if case .run(let run) = primary { return run.durationMinutes }
            return nil
        }()
        return App2TodaySession(
            dayLabel: dayLabel,
            // 課型對不到（後端新增了 `run_type`）→ 退到 `day_target`（後端已在地化的人話）。
            // **不退 `category`**：domain 的 `category` 是 run／strength／cross／rest 四值 enum，
            // 印它的 rawValue 等於把識別字放上畫面；也不退「休息」——那會把一堂未知的課
            // 說成休息日（2026-08-26 架構收斂時發現，DTO 時代退的是後端的自由字串）。
            title: dayType?.localizedName ?? day.dayTarget,
            intensityLabel: App2PlanViewModel.intensityLabel(primary),
            summary: App2PlanViewModel.contentLine(primary, totalDistanceKm: day.distanceKm),
            segments: segments,
            structureBars: Self.structureBars(day: day),
            strengthLabel: Self.strengthLabel(day: day),
            dayIndex: day.dayIndex,
            dayType: dayType,
            showsFuelingNote: App2SessionDetailProjection.showsFuelingNote(
                dayType: dayType,
                durationMinutes: durationMinutes
            )
        )
    }

    /// 指標膠囊列（§3.1a）。**順序、名稱、評級全部照後端給的來**，
    /// app 端不排序也不改名 —— 那是評級層的決定，不是呈現層的。
    static func insights(rows: [DailyStateInsight]) -> [App2Insight] {
        rows.map { row in
            App2Insight(
                id: row.key,
                label: row.label,
                value: row.valueText,
                direction: App2Insight.Direction(rawValue: row.arrow.rawValue) ?? .unknown,
                verdict: row.verdict,
                change: row.change,
                evidence: row.evidence,
                isNotComputed: row.isNotComputed,
                isGraded: row.isGraded,
                isPositive: row.dot == "positive"
            )
        }
    }

    /// 首頁預設展開的指標列（2026-08-25 裁決：只展開最值得看的 2–3 列，
    /// **變化最大者優先、最強項保底**，其餘收在 chevron 後）。
    ///
    /// 「變化最大」與「最強項」都用**後端的判定**，不在 app 端推：
    /// - 有方向的變化 ＝ `arrow` 是 up／down（`flat`／缺席不算變化）
    /// - 最強項 ＝ `dot == "positive"`
    ///
    /// 分三層取前 `limit` 列，層內維持後端給的順序（排序是評級層的決定，不是呈現層的）：
    /// 1. 已評級 ＋ 有方向 → 這一週真的動了的
    /// 2. 已評級 ＋ 正向 → 沒動但是強項，保底
    /// 3. 其餘已評級
    ///
    /// `insufficient_data`／`not_computed` **排到最後**：預設展開的位置要留給
    /// 有話可說的指標，「還看不準」能收就收在 chevron 後面。
    ///
    /// **但收合態不得是空的**（2026-08-28 走查 F12：dev 帳號一列已評級都沒有，
    /// iOS 收合後整區 0 列，Android 同一畫面有 2 列）。裁決要的是「預設展開
    /// 2–3 列」，不是「有評級才展開」——一列都評不出來時，寧可先畫未評級的那幾列
    /// （它們自己會說「參考資料有限」），也不要讓指標區看起來不存在。
    static func highlightedInsights(_ rows: [App2Insight], limit: Int = 3) -> [App2Insight] {
        let graded = rows.filter(\.isGraded)
        let changed = graded.filter { $0.direction == .up || $0.direction == .down }
        let strong = graded.filter { $0.isPositive && !changed.contains($0) }
        let rest = graded.filter { !changed.contains($0) && !strong.contains($0) }
        let ordered = changed + strong + rest
        // 有評級的就只出評級的（一列也算）；一列都沒有才退未評級的那幾列。
        // **不混著補位** —— 那會把「參考資料有限」擠掉真的有話說的那一列。
        guard ordered.isEmpty else { return Array(ordered.prefix(limit)) }
        return Array(rows.prefix(limit))
    }

    /// Rizo 卡的開場句。**用既有的狀態句組，不生成新文案。**
    /// `collapsed_reason`（融合了建議＋理由＋數字）最貼近設計的推話；沒有就退
    /// `narrative_text`；兩者都沒有 → nil，畫面把 Rizo 區退成純入口。
    static func rizoOpeningLine(card: DailyStateCard) -> String? {
        let candidates = [card.collapsedReason, card.narrativeText]
        return candidates.compactMap { $0 }.first { !$0.isEmpty }
    }

    /// 今天是不是**使用者時區**的週日。
    ///
    /// **不看裝置星期**（`DESIGN-app2-weekly-review-and-plan-end-inventory` §A.1／§A.5：
    /// 時區權威是 `metadata.user_timezone`，dev 實查是 `Asia/Tokyo`，與裝置時區無關）。
    /// 兩層判準：
    ///
    /// 1. `can_generate_next_week == true` ＝ 後端已經在使用者時區判過今天是週日
    ///    （`domains/plan_week/service.py:1228-1236`）。最直接的訊號，直接採信。
    /// 2. **它是 false 不等於不是週日。** 後端在同一個 if 多壓了
    ///    `current_week < total_weeks`，所以**最後一週的週日固定是 false**
    ///    （§A.5 必測清單第 1 條就是這一格）。這時用 `metadata.server_time`
    ///    換算到 `metadata.user_timezone` 自己判 —— 這不是重算週界，是讀後端給的
    ///    兩個權威欄位。
    /// 3. 兩者都缺（舊 payload／時區名解不開）才退回裝置日曆，並留 log。
    static func isSundayInUserTimezone(
        _ status: PlanStatusV2Response,
        deviceNow: Date = Date(),
        deviceCalendar: Calendar = .current
    ) -> Bool {
        if status.canGenerateNextWeek { return true }
        if let calendar = App2WeekCalendar.calendar(inTimezone: status.metadata?.userTimezone) {
            // `server_time` 缺就用裝置的「現在」—— 那只是個瞬間（UTC），
            // 星期仍然是在使用者時區的日曆上算出來的。
            let instant = App2WeekCalendar.parseISO8601(status.metadata?.serverTime) ?? deviceNow
            return App2WeekCalendar.isSunday(date: instant, calendar: calendar)
        }
        Logger.debug("[App2HomeVM] plan status 缺 user_timezone，週日判定退回裝置日曆")
        return App2WeekCalendar.isSunday(date: deviceNow, calendar: deviceCalendar)
    }

    /// 週回顧 CTA 狀態。**回 nil ＝整張卡不顯示。**
    ///
    /// 這是 `DESIGN-app2-weekly-review-and-plan-end-inventory` §A.5 那張狀態機表的實作，
    /// 每一格都只讀 `/v2/plan/status` 的欄位 —— client 不算週界。
    ///
    /// | 條件 | 結果 | 週次 |
    /// |---|---|---|
    /// | `next_action == training_completed` | nil（進「計畫結束」狀態，§B） | — |
    /// | `current_week == 1` 且非週日 | nil（無可回顧週） | — |
    /// | 平日、`next_action == create_summary`（回顧擋著課表） | 產生上週回顧 | `current_week − 1` |
    /// | 平日、其餘一切 | **nil（不出卡）** | — |
    /// | 週日、本週有課表、本週回顧未生成 | 產生本週回顧 | `current_week` |
    /// | 週日、本週回顧已生成 | **nil（不出卡）** | — |
    ///
    /// 這張卡是**時機卡，只為「該產生了」而存在**（2026-09-01 使用者裁決：回顧已存在
    /// 就不出卡——要看既有回顧去課表頁換週數看，首頁不做第二個入口；此裁決收回
    /// 8/28「查看回顧不受此限」的例外）。
    ///
    /// `summaryId` 有值＝目標週的回顧已存在 → 整張卡收掉。
    static func weekReviewState(
        planStatus: PlanStatusV2Response,
        isSunday: Bool,
        summaryId: String?
    ) -> App2WeekReviewState? {
        // 計畫已結束 —— 週回顧的時機語意在這裡就不成立了，卡整張收掉。
        // 結束態是另一條路（§B 的 `TrainingCompletedView`），不是這張卡的第五個狀態。
        guard planStatus.nextAction != "training_completed" else { return nil }

        let targetWeekHasPlan = isSunday
            ? planStatus.currentWeekPlanId != nil
            : planStatus.currentWeek > 1
        guard targetWeekHasPlan else { return nil }

        // 週日看本週，平日看上週。
        let targetWeek = isSunday ? planStatus.currentWeek : planStatus.currentWeek - 1

        if let summaryId, !summaryId.isEmpty {
            return nil
        }
        // 平日的產生 CTA 只在後端擋課表時出現（2026-08-28 裁決，見上表）。
        guard isSunday || planStatus.nextAction == "create_summary" else { return nil }
        return .notGenerated(isCurrentWeek: isSunday, targetWeek: targetWeek)
    }

    // MARK: - 今日課表卡的分段與結構

    /// 分段列（設計 dc.html 今日課表卡的「全程勻速」／「熱身＋節奏段＋緩和」那一排）。
    ///
    /// 依 payload 的實際順序走一遍：`warmup` → `primary.segments[]` → `cooldown`。
    /// 間歇段展開成「衝刺 ＋ 恢復」兩行，其餘段落各一行。組不出值的那一行**不出現**，
    /// 不用 placeholder 補。
    ///
    /// **單段課也有一列。** 8/25 版設計的四張今日課表卡裡，輕鬆跑與長距離都是一列
    /// （「全程勻速 8.0 km · 6:50」／「穩定耐力 24 km · 6:30」），與節奏跑的三列
    /// 同一組視覺；舊版把單列濾掉是因為當時卡片沒有這一排，只有右側的結構圖。
    static func segments(day: DayDetail) -> [App2SessionSegment] {
        var result: [App2SessionSegment] = []
        func append(_ name: String, _ detail: String?, isWork: Bool) {
            guard let detail else { return }
            result.append(.init(id: result.count, name: name, detail: detail, isWork: isWork))
        }

        append(
            NSLocalizedString("training.segment.warmup", comment: ""),
            day.session?.warmup.flatMap(effortLabel(segment:)),
            isWork: false
        )

        if case .run(let run) = day.session?.primary {
            let runSegments = App2PlanViewModel.effectiveSegments(run)
            if runSegments.isEmpty {
                // 單段課（輕鬆跑／長跑）也有結構，只是只有一段主課。
                append(L10n.App2.Home.segmentMain.localized,
                       App2PlanViewModel.contentLine(day.session?.primary), isWork: true)
            }
            for segment in runSegments {
                if segment.segmentKind == .interval {
                    if let work = segment.work, let detail = effortLabel(effort: work) {
                        let repeats = segment.repeats ?? 0
                        append(NSLocalizedString("training.segment.sprint", comment: ""),
                               repeats > 1 ? "\(repeats) × \(detail)" : detail, isWork: true)
                    }
                    append(L10n.App2.Home.segmentRecovery.localized,
                           segment.recovery.flatMap(effortLabel(effort:)), isWork: false)
                } else {
                    append(L10n.App2.Home.segmentMain.localized,
                           effortLabel(segment: segment), isWork: true)
                }
            }
        }

        if case .cross(let cross) = day.session?.primary {
            // 交叉訓練沒有配速，但仍然是一段課 —— 用時長當那一列的量。
            append(
                L10n.App2.Home.segmentMain.localized,
                String(format: L10n.App2.Home.minutes.localized, cross.durationMinutes),
                isWork: true
            )
        }

        append(
            NSLocalizedString("training.segment.cooldown", comment: ""),
            day.session?.cooldown.flatMap(effortLabel(segment:)),
            isWork: false
        )

        return result
    }

    /// 配速結構示意（設計 frame-02「預計配速」同一視覺家族）。
    ///
    /// **每一種課型都要畫得出來**（2026-08-25 用戶裁決）：單段輕鬆跑＝一整塊綠色
    /// 穩定段（塊上標配速），有暖身／緩和就前後加淺色塊，間歇課維持橘色趟柱。
    ///
    /// **橘柱＝衝刺（interval 的 work）那幾趟，只有它算「趟」。** 熱身、主課的
    /// 穩定段、組間恢復、緩和都不計趟 —— 把穩定段也算進去會讓
    /// 「6 × 200m」的課寫成「趟數 × 7 趟」（2026-08-25 用戶在截圖上抓到）。
    static func structureBars(day: DayDetail) -> [App2SessionStructureBar] {
        var bars: [App2SessionStructureBar] = []
        func append(
            _ kind: App2SessionStructureBar.Kind,
            height: Double,
            width: Double,
            pace: String? = nil,
            noteLabel: String? = nil,
            noteDetail: String? = nil,
            // 這一段的處方有沒有配速（8/28 盤點 F16）。預設跟著 `pace` 走——寫在塊上的
            // 一定有；寫不下的（間歇細柱、暖身／緩和矮塊）由呼叫端明講。
            hasPace: Bool? = nil
        ) {
            bars.append(.init(
                id: bars.count, kind: kind, height: height, widthWeight: width, paceLabel: pace,
                noteLabel: noteLabel, noteDetail: noteDetail,
                hasPace: hasPace ?? (pace != nil)
            ))
        }

        // 暖身／緩和：塊上不標配速（矮塊寫不下，而且設計 frame-02 的標註列只列主課段），
        // 但**這一段是有配速的**——那個事實要留下來，否則整堂間歇課會被判成「沒有配速」。
        if let warmup = day.session?.warmup {
            append(.warmup, height: 0.35, width: 1, hasPace: (warmup.pace ?? warmup.basePace) != nil)
        }

        if case .run(let run) = day.session?.primary {
            let runSegments = App2PlanViewModel.effectiveSegments(run)
            if runSegments.isEmpty {
                // 單段課（輕鬆跑／長跑）：一整塊穩定段，配速標在塊上。
                // 標註列的量直接用卡片「課表」那一行的同一支（`contentLine`），
                // 不另組一份字串 —— 兩處出現同一個量卻長得不一樣就是矛盾。
                append(
                    // 配速裁決：一律標處方配速，熱調整值只出現在熱適應卡。
                    .steady, height: 0.6, width: 4,
                    pace: App2PlanViewModel.dayPace(run),
                    noteLabel: L10n.App2.Home.structureNoteSteady.localized,
                    noteDetail: App2PlanViewModel.contentLine(day.session?.primary)
                )
            }
            for segment in runSegments {
                if segment.segmentKind == .interval, let repeats = segment.repeats, repeats > 0 {
                    // 太多趟就不畫滿，畫面上那格只有幾十 pt 寬。
                    let drawn = min(repeats, 10)
                    let detail = segment.work.flatMap(effortLabel(effort:))
                    // 衝刺趟的配速在標註列（`10 × 200m · 4:50/km`），細柱上寫不下；
                    // 有 work 配速就記在 `hasPace` 上（8/28 盤點 F16）。
                    let workHasPace = (segment.work?.pace ?? segment.work?.basePace) != nil
                    for index in 0..<drawn {
                        append(
                            .interval, height: 1.0, width: 1,
                            // 標註列只掛第一根柱，後面的柱共用同一條說明（下面 chart 會去重）。
                            noteLabel: index == 0 ? L10n.App2.Home.structureNoteInterval.localized : nil,
                            noteDetail: index == 0
                                ? detail.map { repeats > 1 ? "\(repeats) × \($0)" : $0 }
                                : nil,
                            hasPace: workHasPace
                        )
                        if index < drawn - 1 { append(.support, height: 0.3, width: 0.6) }
                    }
                } else {
                    append(
                        .steady, height: 0.6, width: 3,
                        pace: segment.work?.pace ?? segment.pace,
                        noteLabel: L10n.App2.Home.structureNoteSteady.localized,
                        noteDetail: effortLabel(segment: segment)
                    )
                }
            }
        } else if day.session?.primary != nil {
            // 肌力／交叉訓練沒有配速，但仍然有「一段課」的結構。
            append(.steady, height: 0.6, width: 4)
        }

        if let cooldown = day.session?.cooldown {
            append(.warmup, height: 0.35, width: 1, hasPace: (cooldown.pace ?? cooldown.basePace) != nil)
        }

        return bars
    }

    /// `力量 · 3 個動作`。今天沒有肌力補充項目就回 nil。
    static func strengthLabel(day: DayDetail) -> String? {
        let exercises = (day.effectiveSupplementary ?? []).reduce(into: 0) { total, activity in
            if case .strength(let strength) = activity { total += strength.exercises.count }
        }
        guard exercises > 0 else { return nil }
        return String(format: L10n.App2.Home.strengthRow.localized, exercises)
    }

    /// `400m · 4:30/km`／`10 分鐘`。組不出來就回 nil（那一行不顯示）。
    ///
    /// 8/28 盤點 V36：分隔號原本是 `@`、配速後面沒有單位（`400m @ 4:30`），與 Android
    /// 的 `400m · 4:30/km` 不同 —— 同一堂課的同一行在兩台讀起來是兩種寫法。這個 app
    /// 的所有「量 · 量」都是中點分隔（日卡、紀錄列、結構卡），配速也一律帶單位。
    static func effortLabel(effort: SegmentEffort) -> String? {
        var parts: [String] = []
        if let metres = effort.distanceM {
            parts.append("\(metres)m")
        } else if let km = effort.distanceKm, km > 0 {
            parts.append(String(format: "%.1f km", km))
        } else if let minutes = effort.durationMinutes {
            parts.append(String(format: L10n.App2.Home.minutes.localized, minutes))
        } else if let seconds = effort.durationSeconds {
            parts.append(String(format: L10n.App2.Home.recoverySeconds.localized, seconds))
        }
        if let pace = effort.pace ?? effort.basePace {
            parts.append(App2SegmentFormat.paceWithUnit(pace))
        }
        return parts.isEmpty ? nil : parts.joined(separator: App2SegmentFormat.separator)
    }

    static func effortLabel(segment: RunSegment) -> String? {
        var parts: [String] = []
        if let km = segment.distanceKm, km > 0 {
            parts.append(String(format: "%.1f km", km))
        } else if let metres = segment.distanceM {
            parts.append("\(metres)m")
        } else if let minutes = segment.durationMinutes {
            parts.append(String(format: L10n.App2.Home.minutes.localized, minutes))
        }
        // 配速裁決（2026-05 使用者裁決，2026-08-26 起 App2 全面適用）：
        // 分段列一律顯示處方配速；`climate_adjusted_pace` 只出現在熱適應卡。
        if let pace = segment.pace ?? segment.basePace {
            parts.append(App2SegmentFormat.paceWithUnit(pace))
        }
        return parts.isEmpty ? nil : parts.joined(separator: App2SegmentFormat.separator)
    }

    /// `週二 · 8/25` —— 裝置當地日期，不是後端字串。
    ///
    /// locale 走 `LanguageManager.shared.locale`（app 目前的語言），**不是
    /// `Locale.current`** —— 後者是行程啟動時決定的，切語言後不會跟著換，
    /// 症狀是字串都翻了只有這一行日期還是舊語系（2026-08-26 QA）。
    @MainActor
    private static func todayLabel() -> String {
        let locale = LanguageManager.shared.locale
        let weekday = DateFormatter()
        weekday.locale = locale
        weekday.setLocalizedDateFormatFromTemplate("EEEE")
        let date = DateFormatter()
        date.locale = locale
        date.setLocalizedDateFormatFromTemplate("Md")
        return "\(weekday.string(from: Date())) · \(date.string(from: Date()))"
    }

    // MARK: - §3.1 目標賽事卡

    /// `getMainTarget()` 只讀本機快取。1.x 的 tab 由別處先打過 `/user/targets`，
    /// 2.0 的 App2RootView 沒有那條路徑，所以冷啟後快取是空的、卡片永遠退樣本。
    /// 走檔頭表列的既有出口 `getTargets()`（dual-track，會填快取），不新增第二條路。
    ///
    /// 回 `false` ＝ 這一輪被取消，呼叫端整段停手：連 cache 路徑都不走，不組裝也不發布
    /// （外審第九輪 D04/E03——記了旗標卻繼續組裝＝取消後仍發布）。
    private func fetchTargetsIntoCache() async -> Bool {
        do {
            _ = try await targetRepository.getTargets()
        } catch {
            if error.isCancellationError {
                noteRoundCancellation()
                return false
            }
            Logger.debug("[App2HomeVM] targets 取得失敗,改讀既有快取: \(error)")
        }
        return true
    }

    private func loadGoalCard(planStatus: PlanStatusV2Response?) async {
        // 週次只要 plan status 就算得出來，但完賽預估要 readiness（重運算）、期別要
        // overview。整張卡一起等的話，週次會被拖到那兩支都回來才上畫面 —— 使用者看到的
        // 是「週次很久才出現，或進訓練計畫頁才有」（2026-09-02 實機回報）。
        // 所以先發一版只帶週次的，後面拿到什麼再覆蓋什麼。
        //
        // plan status 沒回來（失敗或被取消）就沒有可提前畫的東西：跳過這一段，
        // 免得把畫面上已有的週次洗成 `—`（票面 Contract 2）。
        var didFetchTargets = false
        if planStatus != nil {
            // 快取讀不會丟錯，所以外層 task 被取消時它照樣回值——`Task.isCancelled`
            // 是這條路上唯一看得到取消的地方（外審 D04）。
            var early = await targetRepository.getMainTarget()
            guard !Task.isCancelled, !roundSawCancellation, !isStaleRound else { return }
            if early == nil {
                // 冷啟後 2.0 沒有別的地方打過 `/user/targets`，本機快取是空的——
                // 提前發布若只認快取，冷啟這條路仍舊要等 readiness 才有週次。
                guard await fetchTargetsIntoCache() else { return }
                didFetchTargets = true
                early = await targetRepository.getMainTarget()
                guard !Task.isCancelled, !roundSawCancellation, !isStaleRound else { return }
            }
            if let early {
                goalCard = Self.goalCard(
                    target: early,
                    planStatus: planStatus,
                    // 這一版還不知道期別與預估：沿用畫面上已有的，沒有就留白。
                    stageLabel: goalCard?.value.stageLabel,
                    estimatedFinish: goalCard?.value.estimatedFinish,
                    displayedCurrentWeek: goalCard?.value.currentWeek,
                    displayedTotalWeeks: goalCard?.value.totalWeeks,
                    origin: .live(endpoint: "GET /user/targets + GET /v2/plan/status")
                )
            }
        }

        await readinessViewModel.loadData()
        let estimated = readinessViewModel.estimatedRaceTime

        // 能力基準詳情頁的完賽預估（T-0376）。**同一份 readiness response**，
        // 與上面那個「預估完賽」是兩個欄位：`estimated_race_time` 是目標賽事那一個
        // 距離，這一份是四個固定距離的能力對照。整段不新增請求。
        //
        // 目標卡的組裝可能因為沒有主要賽事而提早 return（下面的 `guard let main`），
        // 但完賽預估**與有沒有目標賽事無關** —— 所以在那些 return 之前就先發布。
        // readiness 自己會吞掉取消（`TrainingReadinessManager` catch 後直接 return），
        // 所以 `roundSawCancellation` 不會被設——這一段之後每個 guard 都要自己查
        // `Task.isCancelled`（外審 D04）。
        guard !Task.isCancelled else { return }
        if !isStaleRound {
            finishPredictions = App2MetricDetailProjection.finishPredictions(
                from: readinessViewModel.raceFitnessMetric
            )
        }

        // 提前發布那一段若已經打過就不重打——同一個事實一輪只讀一次。
        if !didFetchTargets {
            guard await fetchTargetsIntoCache() else { return }
        }

        let main = await targetRepository.getMainTarget()
        // overview 一次取用兩處：期別膠囊（目標卡）與 `target_type`（結束態的語意分岔）。
        // **不為了結束態再打一次** —— 同一個事實只讀一次（見檔頭）。
        let overview = await currentOverview(planStatus: planStatus)
        // 每個可取消子載 await 完就查旗標：取消＝整段停手，不得再組 plan-end 或
        // 目標卡（外審第十輪 D04/E03——子載記了旗標回 nil，呼叫端不能當「沒資料」繼續）。
        guard !Task.isCancelled, !roundSawCancellation, !isStaleRound else { return }

        // **結束態的「當時預估」不是 `estimated`**（那是最新那一筆，講的是「現在」）。
        // 2026-08-27 裁決：要賽事日當天那一筆，取不到就整欄不畫。
        let estimatedAtRace = await raceDayEstimate(planStatus: planStatus, target: main)
        guard !Task.isCancelled, !roundSawCancellation, !isStaleRound else { return }

        applyPlanEnd(
            planStatus: planStatus,
            overview: overview,
            target: main,
            estimatedFinish: estimatedAtRace
        )

        // 沒有主要賽事目標 → 卡片留空（畫面顯示「尚未設定目標賽事」），
        // **不拿設計稿的示範賽事充數**。
        guard let main else {
            Logger.debug("[App2HomeVM] 無主要賽事目標,顯示空狀態")
            goalCard = nil
            return
        }

        goalCard = Self.goalCard(
            target: main,
            planStatus: planStatus,
            // 階段標籤（設計 frame-00 右上的藍膠囊）住在 plan overview 的
            // `training_stages[]`，用 plan status 的當前週落在哪一段來挑。
            stageLabel: planStatus.flatMap { status in
                overview.flatMap { overview in
                    Self.isOverview(overview.id, boundTo: status)
                        ? Self.stageName(stages: overview.trainingStages, currentWeek: status.currentWeek)
                        : nil
                }
            },
            estimatedFinish: estimated,
            displayedCurrentWeek: goalCard?.value.currentWeek,
            displayedTotalWeeks: goalCard?.value.totalWeeks,
            origin: .live(
                endpoint: "GET /user/targets + GET /v2/plan/status + GET /plan/readiness"
                    + " + GET /v2/plan/overview"
            )
        )
    }

    /// 結束態 hero 右欄那個「當時預估」（2026-08-27 裁決）。
    ///
    /// **打的是賽事日那一天的 readiness**（`GET /plan/readiness/{race_date}`，
    /// 後端 `api/v1/training_plan.py:803`；該端點的 docstring 明寫
    /// "Readiness is date-specific: never substitute a different date"）。
    ///
    /// 為什麼不能用 `readinessViewModel.estimatedRaceTime`：那是**最新**那一筆，
    /// 講的是「你現在能跑幾分」。計畫已經走完，畫面上那一格要講的是「這段備賽把
    /// 預估推到哪」——拿今天的值冒充當時的值，數字會隨著賽後掉練一路往回走。
    ///
    /// **取不到就回 nil**（整欄不畫）：寧可少一格，也不要標一個別的日子的預估。
    /// 只有 race 語意的結束態才打這一條 —— maintenance 沒有賽事日，也不提成績。
    private func raceDayEstimate(
        planStatus: PlanStatusV2Response?,
        target: Target?
    ) async -> String? {
        guard let target else { return nil }

        var shouldFetch = App2PlanEndProjection.isCompleted(planStatus)
            && App2PlanEndProjection.kind(planStatus: planStatus, overview: nil) == .race
        #if DEBUG
        // 走查：強制 race 結束態時也要真的去取那一天的值，否則走查看到的是空欄，
        // 驗不到「有值長什麼樣」。
        if devPlanEndOverride == .race { shouldFetch = true }
        #endif
        guard shouldFetch else { return nil }

        do {
            // 賽事日期以**賽事時區**換算成當地日字串 —— 與卡片上印的那個日期同一支，
            // 不另算一份（`YYYY-MM-DD` 是當地日，不是 UTC）。
            let raceDate = App2PlanEndProjection.raceDateLabel(target)
            let readiness = try await readinessService.getReadiness(date: raceDate, forceCalculate: false)
            return readiness.metrics?.raceFitness?.estimatedRaceTime
        } catch {
            if error.isCancellationError {
                noteRoundCancellation()
            } else {
                Logger.debug("[App2HomeVM] 賽事日 readiness 取不到,結束態不畫預估欄: \(error)")
            }
            return nil
        }
    }

    /// 結束態卡的組裝 ＋ DEBUG 走查覆寫。
    ///
    /// 覆寫**只換呈現的那一格**：`App2PlanEndProjection.card` 的真實判斷照跑，
    /// 關掉就恢復（同週回顧時機卡的走查機制）。
    private func applyPlanEnd(
        planStatus: PlanStatusV2Response?,
        overview: PlanOverviewV2?,
        target: Target?,
        estimatedFinish: String?
    ) {
        #if DEBUG
        lastPlanEndInputs = (planStatus, overview, target, estimatedFinish)
        if let forced = devPlanEndOverride.resolve(
            planStatus: planStatus,
            overview: overview,
            target: target,
            estimatedFinish: estimatedFinish
        ) {
            planEnd = forced
            return
        }
        #endif

        planEnd = App2PlanEndProjection.card(
            planStatus: planStatus,
            overview: overview,
            target: target,
            estimatedFinish: estimatedFinish
        )
    }

    /// plan status 指向的那一份 overview。取不到就 nil —— 呼叫端據此少一個膠囊／
    /// 退保守的結束語意，不阻斷其他區塊。
    private func currentOverview(planStatus: PlanStatusV2Response?) async -> PlanOverviewV2? {
        guard planStatus != nil else { return nil }
        do {
            return try await planRepository.refreshOverview()
        } catch {
            if error.isCancellationError {
                noteRoundCancellation()
            } else {
                Logger.debug("[App2HomeVM] overview 取得失敗: \(error)")
            }
            return nil
        }
    }

    /// 目標賽事卡的組裝。網路回應與冷啟快照都走這一支（快照那條沒有期別與完賽預估，
    /// 兩個欄位傳 nil，這一輪網路回來再靜默補上）。
    /// `displayedCurrentWeek` / `displayedTotalWeeks` ＝ 畫面上已經有的那一組。
    /// plan status 這一輪沒回來（失敗或被取消）時沿用它們——一輪沒有新的週次可講，
    /// 不代表要把已經在畫面上的那一組洗成 `—`（票面 Contract 2）。
    static func goalCard(
        target: Target,
        planStatus: PlanStatusV2Response?,
        stageLabel: String?,
        estimatedFinish: String?,
        displayedCurrentWeek: Int?,
        displayedTotalWeeks: Int?,
        origin: App2DataOrigin
    ) -> App2Sourced<App2GoalCard> {
        App2Sourced(
            App2GoalCard(
                raceName: target.name,
                raceDate: Self.localDateString(
                    fromEpochSeconds: target.raceDate,
                    timezone: target.timezone
                ),
                distanceLabel: App2OnboardingFormat.distanceLabel(km: Double(target.distanceKm)),
                stageLabel: stageLabel,
                targetTime: target.targetTime > 0 ? TimeFormatting.formatTime(target.targetTime) : nil,
                estimatedFinish: estimatedFinish,
                currentWeek: planStatus?.currentWeek ?? displayedCurrentWeek,
                // **不退回 `target.trainingWeeks`。** 那是設定目標當下的估算，不是計畫
                // 真正的長度：prod 上創辦人帳號的 target 寫 30 週，實際在跑的 overview
                // `f30fed2f03ab` 是 27 週（2026-09-02 使用者回報「總週數是錯的」）。
                // plan status 缺席時退回畫面上已有的那一組（沒有就留白），
                // 不印一個看起來合理但錯的數字。
                totalWeeks: planStatus?.totalWeeks ?? displayedTotalWeeks
            ),
            origin: origin
        )
    }

    /// 這份 overview 是不是 plan status 指向的那一份。
    ///
    /// 期別膠囊**綁的是 plan status 指向的那份 overview，不是「最新的 overview」** ——
    /// 對不上就不顯示期別（寧可少一個膠囊，也不要標一個別的計畫的期別）。
    ///
    /// `current_week_plan_id` 的前綴就是 overview id（dev 實測：plan `e1289e60f251_1`
    /// ↔ overview `e1289e60f251`）。`GET /v2/plan/overview` 只交當前那一份，拿回來要先比對
    /// —— 對不上就什麼都不顯示，不要把另一份計畫的期別／期程畫成這一份的。
    ///
    /// **本週課表還沒產生時（`current_week_plan_id == nil`）綁不了**，一律回 false：
    /// 那時沒有任何東西能證明手上這份 overview 就是要跑的那份。
    ///
    /// 首頁的期別膠囊與訓練計畫總覽頁的期程列表共用這一支，不各寫一份。
    static func isOverview(_ overviewId: String, boundTo planStatus: PlanStatusV2Response) -> Bool {
        guard let planId = planStatus.currentWeekPlanId,
              let boundOverviewId = planId.split(separator: "_").first.map(String.init) else {
            return false
        }
        return overviewId == boundOverviewId
    }

    /// 當前週落在哪一段 `training_stages`。落不進任何一段就沒有期別（不猜最近的那段）。
    ///
    /// **顯示字走 `stage_id` 的既有在地化表**（`PlanGenerationContext
    /// .stageIdToLocalizationKey` → `training.stage.*`），不是 payload 的
    /// `stage_name`：後者由後端依 `content_lang` 生成，App 切語言時不會跟著換，
    /// 三語用字也與 1.4 的期程列表對不上（2026-08-26 裁決：chip 譯名全 App 同一份）。
    static func stageName(stages: [TrainingStageV2], currentWeek: Int) -> String? {
        guard let stage = stages.first(where: { currentWeek >= $0.weekStart && currentWeek <= $0.weekEnd })
        else { return nil }
        return PlanGenerationContext.stageIdToLocalizationKey(stage.stageId).localized
    }

    // MARK: - Formatting

    /// 賽事日期以賽事時區顯示。數字 timestamp 是 UTC，`YYYY-MM-DD` 是當地日期。
    private static func localDateString(fromEpochSeconds seconds: Int, timezone: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: timezone) ?? .current
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(seconds)))
    }

    // 距離標籤走 `App2OnboardingFormat.distanceLabel(km:)`（2026-09-01 收斂）——
    // 這裡原本有一份 `Int` 版，容差更差、非標準賽距的 fallback 還寫死 `km`。
}
