import Foundation

// MARK: - App2PlanOverviewViewModel
/// Presentation Layer — 2.0 訓練計畫總覽（設計 **frame-20**）。
///
/// **不是第二份計畫總覽邏輯。** 1.x 已經有 `TrainingOverviewV2View` ＋ `PhaseRoadmapView`
/// 在畫同一份 `training_stages`，但那是 1.x 的視覺與導航樹；2.0 只換版面，資料仍走
/// 同一組既有出口（`TrainingPlanV2RemoteDataSource` / `TargetRepository` /
/// `UserProfileRepository`），完賽預估讀 athlete_state metrics。
///
/// **週次／期別／賽事一律同源。** 週次來自 `GET /v2/plan/status`，期程來自它
/// `current_week_plan_id` 前綴所綁定的那一份 overview（`GET /v2/plan/overview` 拿回來
/// 先過 `App2HomeViewModel.isOverview(_:boundTo:)` 比對，**不是「最新的 overview」**）。
/// 綁不上就整段期程不顯示、畫面說明原因 —— 這條規則與首頁目標卡的期別膠囊是同一支。
///
/// 其餘欄位各自走既有出口：
///
/// | 畫面欄位 | 來源 |
/// |---|---|
/// | 目標賽事名／日期／距離／目標成績 | `TargetRepository`（`GET /user/targets`） |
/// | 「現在的你」完賽預估 | `state.race_projection` 目標距離 channel（`GET /v2/athlete-state/metrics`） |
/// | 「約 N km / 週」 | `WeeklySummaryService.fetchAllWeeklyVolumes`（`GET /summary/weekly/all`） |
/// | 每週跑步天數／長跑日 | `UserProfileRepository` 的 `prefer_week_days` / `prefer_week_days_longrun` |
/// | 訓練方法名 | overview 的 `methodology_overview.name`（後端已在地化） |
@MainActor
final class App2PlanOverviewViewModel: ObservableObject, TaskManageable, App2Revalidating {

    // MARK: - Published

    @Published private(set) var isLoading = true
    @Published private(set) var overview: App2Sourced<App2PlanOverview>?
    /// overview 拿到了但與本週課表不同源 —— 期程整段不顯示，畫面上要說明原因。
    /// 讀取失敗不算（那時不宣稱「不同源」，只是沒有期程）。
    @Published private(set) var stagesUnbound = false
    @Published private(set) var isRegenerating = false

    // MARK: - 更換訓練方法（2026-08-27 晚走查裁決（e））

    /// 可選的方法論。**只有取得 overview 之後才有值**（要用它的 `target_type` 過濾）。
    @Published private(set) var methodologies: [MethodologyV2] = []
    @Published private(set) var isChangingMethodology = false
    /// 換成功了 —— 畫面上出一行小字說「週課表下週依新方法產生」。
    @Published private(set) var didChangeMethodology = false
    /// 換失敗的訊息。**失敗不改變現值**（畫面上的方法名仍是舊的）。
    @Published var methodologyError: String?
    /// 方法論更新被訂閱閘門擋下。
    @Published var showsUpsell = false

    /// 更換方法論要打在哪一份 overview 上。取不到就沒有這一列。
    private(set) var overviewId: String?
    private(set) var targetType: String?

    private(set) var hasLoaded = false
    private(set) var lastLoadedAt: Date?
    /// 這一輪的子載入是否吃到取消（-999 取消錯誤不設 `Task.isCancelled`）。
    /// 有＝整輪作廢：不發布、不標載過（外審第七輪 E03）。
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
    /// revalidate 的同輪互斥：兩輪並發會在 await 點交錯共用取消旗標與完成標記。
    private var isRevalidating = false
    /// 這一輪重驗的起點（判卡死用，見 revalidate 開頭）。
    private var revalidateBegan: Date?
    /// 鎖的輪次所有權：被接管的卡死輪回來時不得放掉新輪的鎖（T-0359 外審 D04）。
    private var revalidateGeneration = 0
    /// 現任輪的 task：接管時取消它，逼舊輪走取消路徑退出。
    private var revalidateRoundTask: Task<Void, Never>?

    /// 測試 seam：把 in-flight 輪的起點回撥，模擬卡死超過門檻
    /// （owner-path 測試不能真等 30 秒）。
    func backdateRevalidateBeganForTesting(by interval: TimeInterval) {
        revalidateBegan = Date(timeIntervalSinceNow: -interval)
    }

    nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Dependencies

    /// **課表資料只有這一個入口**（2026-08-26 架構收斂）。
    private let planRepository: TrainingPlanV2Repository
    private let targetRepository: TargetRepository
    private let userProfileRepository: UserProfileRepository
    private let metricsDataSource: AthleteStateMetricsDataSourceProtocol
    /// 近幾週的實際週跑量。既有出口是 `WeeklySummaryService`（singleton），
    /// 包成 closure 讓測試塞值 —— 不新增第二條 HTTP 路徑。
    private let weeklyVolumesLoader: (() async -> [WeeklySummaryItem])?

    // MARK: - Init

    init(
        planRepository: TrainingPlanV2Repository? = nil,
        targetRepository: TargetRepository? = nil,
        userProfileRepository: UserProfileRepository? = nil,
        metricsDataSource: AthleteStateMetricsDataSourceProtocol? = nil,
        weeklyVolumesLoader: (() async -> [WeeklySummaryItem])? = nil
    ) {
        let container = DependencyContainer.shared

        if let planRepository {
            self.planRepository = planRepository
        } else {
            if !container.isRegistered(TrainingPlanV2Repository.self) {
                container.registerTrainingPlanV2Module()
            }
            self.planRepository = container.resolve() as TrainingPlanV2Repository
        }

        if let targetRepository {
            self.targetRepository = targetRepository
        } else {
            if !container.isRegistered(TargetRepository.self) {
                container.registerTargetModule()
            }
            self.targetRepository = container.resolve() as TargetRepository
        }

        if let userProfileRepository {
            self.userProfileRepository = userProfileRepository
        } else {
            if !container.isRegistered(UserProfileRepository.self) {
                container.registerUserProfileModule()
            }
            self.userProfileRepository = container.resolve() as UserProfileRepository
        }

        self.metricsDataSource = metricsDataSource ?? AthleteStateMetricsRemoteDataSource()
        self.weeklyVolumesLoader = weeklyVolumesLoader

        // 目標變更（賽事管理寫入＝`.dataChanged(.targets)`、重設目標＝
        // `.reonboardingCompleted`）會換掉這一頁的賽事名稱／日期／期程——
        // 與 `App2PlanViewModel` 同一組事件、同一個理由（常駐 VM 的 60 秒
        // SWR 門檻擋住跨頁寫入；2026-08-31 用戶實機回報改賽名後總覽仍是舊名）。
        CacheEventBus.shared.subscribe(forIdentifier: "App2PlanOverviewViewModel.targets") { [weak self] reason in
            switch reason {
            case .reonboardingCompleted, .dataChanged(.targets):
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

    /// 週跑量歷史。取消要記進 `roundSawCancellation`（外審第八輪 E03），
    /// 所以預設實作是實例方法而不是 init 裡的 escaping 預設 closure。
    private func loadWeeklyVolumes() async -> [WeeklySummaryItem] {
        if let weeklyVolumesLoader { return await weeklyVolumesLoader() }
        do {
            // `/summary/weekly/` 這條在 dev 上回空陣列；帶跑量的是 `/summary/weekly/all`
            // （2026-08-25 對創辦人 dev 帳號實測），所以用既有 service 的這一支。
            return try await WeeklySummaryService.shared.fetchAllWeeklyVolumes(limit: 8)
        } catch {
            if error.isCancellationError {
                noteRoundCancellation()
            } else {
                Logger.debug("[App2PlanOverviewVM] 週跑量歷史取得失敗: \(error)")
            }
            return []
        }
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Loading

    func revalidate() async {
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

        isLoading = !hasLoaded
        roundSawCancellation = false
        var finishedRound = false
        defer {
            // 只有現任輪能收尾——被接管的舊輪連 isLoading 都不得清
            //（會關掉新輪的首載 spinner，外審第三輪 D04）。
            if revalidateGeneration == round {
                isLoading = false
                // 成功或**真失敗**才算載過；取消不標——task 取消與 -999 取消錯誤
                // （提早 return，finishedRound 維持 false）都算取消（2026-08-29 外審 D04/E03）。
                if finishedRound, !Task.isCancelled {
                    hasLoaded = true
                    lastLoadedAt = Date()
                }
            }
        }

        // 進頁先畫上一次的畫面（T-0365）。只讀本機快取，一個請求都不發。
        await primeFromCache(round: round)

        // 週次是這一頁的骨幹：沒有 plan status 就沒有「第 N / M 週」，也綁不了 overview。
        let planStatus: PlanStatusV2Response?
        do {
            planStatus = try await planRepository.getPlanStatus(forceRefresh: true)
        } catch {
            // 取消（task 取消或 -999 取消錯誤）不算這一輪：不發布也不標載過。
            guard !error.isCancellationError else { return }
            planStatus = nil
        }

        async let stagesTask = loadStages(planStatus: planStatus)
        async let mainTargetTask = loadMainTarget()
        async let raceProjectionTask = loadRaceProjection()
        async let weeklyTask = loadWeeklyVolumes()
        async let rhythmTask = loadRhythmPreferences()

        let (stageBundle, mainTarget, raceProjection, weeklyItems, preferences) =
            await (stagesTask, mainTargetTask, raceProjectionTask, weeklyTask, rhythmTask)
        let estimate = App2MetricDetailProjection.estimatedFinish(
            deliveryStatus: raceProjection?.deliveryStatus,
            envelope: raceProjection?.envelope,
            targetDistanceKm: mainTarget.map { Double($0.distanceKm) }
        )

        // planStatus 與各子載入都以 `try?`／可缺席語意收攏——取消也會被折成 nil。
        // 被取消的那一輪不得發布殘缺 overview（AGENTS.md 陷阱 5；2026-08-29 外審）。
        if Task.isCancelled || roundSawCancellation || revalidateGeneration != round { return }
        finishedRound = true

        stagesUnbound = stageBundle.isUnbound
        isRegenerating = stageBundle.isRegenerating

        overview = App2Sourced(
            Self.project(
                planStatus: planStatus,
                mainTarget: mainTarget,
                stages: stageBundle.stages,
                milestones: stageBundle.milestones,
                methodologyName: stageBundle.methodologyName,
                isRegenerating: stageBundle.isRegenerating,
                estimatedFinish: estimate,
                weeklyVolumes: weeklyItems,
                preferWeekDays: preferences.days,
                longRunWeekday: preferences.longRun
            ),
            origin: .live(endpoint: Self.liveEndpoints)
        )
    }

    /// 這一頁的資料來源。快取那一畫與重驗那一畫**是同一組端點**，只差取得的時間，
    /// 所以共用同一個字串、同樣是 `.live`（`App2DataOrigin` 分的是真實 vs 樣本，
    /// 不是新鮮 vs 陳舊）。
    private static let liveEndpoints =
        "GET /v2/plan/status + GET /v2/plan/overview + GET /user/targets"
        + " + GET /v2/athlete-state/metrics + GET /summary/weekly/all + GET /user"

    // MARK: - 進頁先畫快取（T-0365）

    /// 畫面上什麼都沒有時，**先用本機快取畫一次**，再讓這一輪去重驗。
    ///
    /// 2026-08-31 使用者實機回報：「訓練計劃依舊沒有先顯示緩存，點進去轉了好幾秒」。
    /// 成因是這一輪在拿到**全部**六個來源之前不發布任何東西，而它的第一步
    /// （`getPlanStatus(forceRefresh: true)`）與 `refreshOverview()` 都刻意跳過快取——
    /// 於是每次冷啟後第一次進頁都是一整頁 spinner，長度＝那趟往返。
    ///
    /// **這裡沒有新的快取。** 讀的全是既有的 cache-only 出口：
    /// `TrainingPlanV2Repository.getCachedPlanStatus()`／`getCachedOverview()`
    /// （`TrainingPlanV2LocalDataSource`，UserDefaults、跨啟動、蓋 uid 戳）、
    /// `TargetRepository.getMainTarget()`（本來就只讀本機）、
    /// `UserProfileRepository.getCachedUserProfile()`。**一個網路請求都不發**：
    /// 快取沒有就什麼都不做，畫面維持既有的首載 spinner，行為與修前相同。
    ///
    /// 「先查既有的」（2026-09-01）：`App2MetricDetailCache`（T-0357）是**指標詳情**的
    /// session 快取，存的是那三支 DTO、而且是為「每次進頁都是新 `@StateObject`」而生；
    /// 這一頁的 VM 常駐在 `App2HomeView`，缺的不是 session 快取而是**冷啟第一畫**，
    /// 而課表三支的落地早就在 repository 自己的 local data source（`App2SnapshotStore`
    /// 檔頭記著這條收斂）。所以正確的做法是讀那一份，不是再造第三份。
    ///
    /// **不標載過**：`hasLoaded`／`lastLoadedAt` 仍只由本輪的權威 pass 設定——
    /// 快取只是先畫出來，不是這一輪的結果；否則 60 秒 SWR 門檻會從「畫了快取」開始算。
    private func primeFromCache(round: Int) async {
        guard overview == nil else { return }

        let cachedStatus = planRepository.getCachedPlanStatus()
        let cachedOverview = planRepository.getCachedOverview()
        let cachedTarget = await targetRepository.getMainTarget()
        let cachedProfile = userProfileRepository.getCachedUserProfile()

        // **四份都沒有**＝這台裝置沒看過這一頁，沒有「上一次的畫面」可畫
        //（外審第一輪 B07：`cachedProfile` 也是四個來源之一，漏掉它就會讓
        //  「只有偏好有快取」那一格白白吃一趟往返的 spinner）。
        guard cachedStatus != nil
            || cachedOverview != nil
            || cachedTarget != nil
            || cachedProfile != nil
        else { return }
        // await 之後才發布：被接管的舊輪不得覆蓋新輪，也不得覆蓋已經有的畫面。
        guard revalidateGeneration == round, overview == nil else { return }

        var bundle = StageBundle()
        if let cachedStatus, let cachedOverview {
            // 換方法論打在這一份 overview 上；重驗那一輪會用同一支覆寫。
            overviewId = cachedOverview.id
            targetType = cachedOverview.targetType
            bundle = Self.stageBundle(overview: cachedOverview, planStatus: cachedStatus)
        }

        stagesUnbound = bundle.isUnbound
        isRegenerating = bundle.isRegenerating
        overview = App2Sourced(
            Self.project(
                planStatus: cachedStatus,
                mainTarget: cachedTarget,
                stages: bundle.stages,
                milestones: bundle.milestones,
                methodologyName: bundle.methodologyName,
                isRegenerating: bundle.isRegenerating,
                // 完賽預估與近幾週跑量沒有 cache-only 出口（metrics 與
                // `/summary/weekly/all` 都不落地），這兩格由本輪的權威 pass 補上。
                estimatedFinish: nil,
                weeklyVolumes: [],
                preferWeekDays: cachedProfile?.preferWeekDays,
                longRunWeekday: cachedProfile?.preferWeekDaysLongrun?.first
            ),
            origin: .live(endpoint: Self.liveEndpoints)
        )
        // 有東西可看了就把首載 spinner 收掉；重驗仍在背景跑。
        isLoading = false
    }

    /// 期程 ＋ 訓練方法名 —— 兩者住在同一份 overview，一次取。
    struct StageBundle {
        var stages: [TrainingStageV2] = []
        /// 里程碑與期程同住一份 overview，同一次取，不另打端點。
        var milestones: [MilestoneV2] = []
        var methodologyName: String?
        var isUnbound = false
        var isRegenerating = false
    }

    /// overview ＋ plan status → 這一頁的期程／里程碑／方法名。只有後端明示總覽仍在重產時
    /// 暫時不顯示期程；課表 id 與總覽 id 的差異不再被當成重產狀態（T-0871）。
    ///
    /// 方法論名不綁週次，仍照常帶出來。只有 queued／running 狀態會暫時隱藏期程與里程碑。
    static func stageBundle(
        overview: PlanOverviewV2,
        planStatus: PlanStatusV2Response
    ) -> StageBundle {
        let isRegenerating = Self.isRegenerating(status: overview.regenerationStatus)
        guard Self.shouldDisplayOverview(
            regenerationStatus: overview.regenerationStatus
        ) else {
            Logger.debug("[App2PlanOverviewVM] overview regeneration active or belongs to another plan")
            return StageBundle(
                methodologyName: overview.methodologyOverview?.name,
                isUnbound: true,
                isRegenerating: isRegenerating
            )
        }
        return StageBundle(
            stages: overview.trainingStages,
            milestones: overview.milestones,
            methodologyName: overview.methodologyOverview?.name,
            isRegenerating: isRegenerating
        )
    }

    static func isRegenerating(status: String?) -> Bool {
        status == "queued" || status == "running"
    }

    static func shouldDisplayOverview(
        regenerationStatus: String?
    ) -> Bool {
        !isRegenerating(status: regenerationStatus)
    }

    static func canGenerateCurrentWeekPlan(
        isRegenerating: Bool,
        currentWeekPlanId: String?
    ) -> Bool {
        !isRegenerating && currentWeekPlanId == nil
    }

    private func loadStages(planStatus: PlanStatusV2Response?) async -> StageBundle {
        guard let planStatus else { return StageBundle() }
        do {
            let overview = try await planRepository.refreshOverview()
            // 被接管的舊輪不得寫 overviewId／targetType（外審第四輪 D04）。
            guard !isStaleRound else { return StageBundle() }
            // 更換方法論打在**目前這一份 overview** 上。
            //
            // **不同源時這個 id 仍然有效**：`isUnbound` 只代表本週課表比 overview 舊
            // （換過方法論或改過目標之後必然如此），不代表拿到了別人的計畫。
            // 這裡曾經在不同源時把 id 清掉，結果是換完方法論那一刻「更換訓練方法」
            // 整列消失、換不回來（2026-08-27 模擬器實測）。
            overviewId = overview.id
            targetType = overview.targetType
            return Self.stageBundle(overview: overview, planStatus: planStatus)
        } catch {
            if error.isCancellationError {
                noteRoundCancellation()
            } else {
                Logger.debug("[App2PlanOverviewVM] overview 取得失敗: \(error)")
            }
            return StageBundle()
        }
    }

    // MARK: - 更換訓練方法

    /// 可換的方法論清單（`GET /v2/methodologies`，依 `target_type` 過濾）。
    /// **1.4 在訓練總覽就能換，App2 漏接＝功能缺口**（2026-08-27 晚走查裁決（e））。
    func loadMethodologies() async {
        guard methodologies.isEmpty else { return }
        do {
            methodologies = try await planRepository.getMethodologies(targetType: targetType)
        } catch {
            if error.isCancellationError {
                noteRoundCancellation()
            } else {
                Logger.debug("[App2PlanOverviewVM] 方法論清單取得失敗: \(error)")
                methodologyError = error.toDomainError().localizedDescription
            }
        }
    }

    /// 換方法論。成功＝**重載 overview**（後端換完會重生），畫面上的方法名跟著變；
    /// 失敗不改變現值，只出錯誤訊息。
    ///
    /// 寫入路徑走既有的 `TrainingPlanV2Repository.updateOverview` —— 與 1.4 的
    /// `MethodologyCoordinator.changeMethodology` 同一條，不另開第二份。
    @discardableResult
    func changeMethodology(to methodologyId: String) async -> Bool {
        guard let overviewId, !isChangingMethodology else { return false }
        isChangingMethodology = true
        didChangeMethodology = false
        methodologyError = nil
        showsUpsell = false
        defer { isChangingMethodology = false }

        do {
            _ = try await planRepository.updateOverview(
                overviewId: overviewId,
                startFromStage: nil,
                methodologyId: methodologyId
            )
        } catch {
            let domainError = error.toDomainError()
            Logger.debug("[App2PlanOverviewVM] 更換方法論失敗: \(domainError)")
            switch domainError {
            case .subscriptionRequired, .trialExpired, .forbidden:
                showsUpsell = true
                return false
            default:
                break
            }
            methodologyError = domainError.localizedDescription
            return false
        }

        await forceRefresh()
        didChangeMethodology = true
        return true
    }

    func dismissMethodologyNotice() {
        didChangeMethodology = false
    }

    private func loadMainTarget() async -> Target? {
        // 冷啟時本機快取是空的（同 `App2HomeViewModel.loadGoalCard` 的註解），
        // 先走 dual-track 的 `getTargets()` 把快取填起來，不新增第二條路。
        do {
            _ = try await targetRepository.getTargets()
        } catch {
            if error.isCancellationError {
                noteRoundCancellation()
            } else {
                Logger.debug("[App2PlanOverviewVM] targets 取得失敗,改讀既有快取: \(error)")
            }
        }
        return await targetRepository.getMainTarget()
    }

    private func loadRaceProjection() async -> AthleteStateRaceProjectionItem? {
        do {
            let response = try await metricsDataSource.fetchMetrics()
            return response.metrics.raceProjection
        } catch {
            if error.isCancellationError {
                noteRoundCancellation()
            } else {
                Logger.debug("[App2PlanOverviewVM] race_projection metrics 取得失敗,完賽預估不顯示: \(error)")
            }
            return nil
        }
    }

    private func loadRhythmPreferences() async -> (days: [Int]?, longRun: Int?) {
        do {
            let user = try await userProfileRepository.getUserProfile()
            return (user.preferWeekDays, user.preferWeekDaysLongrun?.first)
        } catch {
            if error.isCancellationError {
                noteRoundCancellation()
            } else {
                Logger.debug("[App2PlanOverviewVM] 訓練日偏好取得失敗: \(error)")
            }
            return (nil, nil)
        }
    }

    #if DEBUG
    /// 測試／預覽用：直接填投影結果，不打網路。
    func applyForTesting(
        overview: App2Sourced<App2PlanOverview>?,
        stagesUnbound: Bool = false,
        overviewId: String? = nil,
        methodologies: [MethodologyV2] = []
    ) {
        self.overview = overview
        self.stagesUnbound = stagesUnbound
        self.overviewId = overviewId
        self.methodologies = methodologies
        isLoading = false
        hasLoaded = true
        lastLoadedAt = Date()
    }
    #endif

    // MARK: - 投影（純函式，可單獨測）

    static func project(
        planStatus: PlanStatusV2Response?,
        mainTarget: Target?,
        stages: [TrainingStageV2],
        milestones: [MilestoneV2] = [],
        methodologyName: String?,
        isRegenerating: Bool = false,
        estimatedFinish: String?,
        weeklyVolumes: [WeeklySummaryItem],
        preferWeekDays: [Int]?,
        longRunWeekday: Int?,
        now: Date = Date()
    ) -> App2PlanOverview {
        let currentWeek = planStatus?.currentWeek
        // 總週數以 plan status 為準；沒有才退目標賽事自己的訓練週數。
        let totalWeeks = planStatus?.totalWeeks
            ?? mainTarget.flatMap { $0.trainingWeeks > 0 ? $0.trainingWeeks : nil }

        let projectedStages = Self.stages(stages, currentWeek: currentWeek)

        return App2PlanOverview(
            raceName: mainTarget?.name,
            raceDateLabel: mainTarget.map {
                Self.localDateString(fromEpochSeconds: $0.raceDate, timezone: $0.timezone)
            },
            distanceLabel: mainTarget.map {
                App2OnboardingFormat.distanceLabel(km: Double($0.distanceKm))
            },
            weeksUntilRace: mainTarget.flatMap {
                Self.weeksUntil(epochSeconds: $0.raceDate, now: now)
            },
            currentEstimatedFinish: estimatedFinish,
            currentWeeklyKm: Self.averageWeeklyKm(weeklyVolumes, now: now),
            targetTime: mainTarget.flatMap {
                $0.targetTime > 0 ? App2OnboardingFormat.duration($0.targetTime) : nil
            },
            currentWeek: currentWeek,
            totalWeeks: totalWeeks,
            canGenerateCurrentWeekPlan: Self.canGenerateCurrentWeekPlan(
                isRegenerating: isRegenerating,
                currentWeekPlanId: planStatus?.currentWeekPlanId
            ),
            currentStageName: projectedStages.first(where: { $0.state == .active })?.name,
            stages: projectedStages,
            milestones: Self.milestones(milestones),
            rhythm: App2PlanRhythm(
                runDaysPerWeek: preferWeekDays.flatMap { $0.isEmpty ? nil : $0.count },
                longRunDayLabel: longRunWeekday.flatMap {
                    let label = App2OnboardingFormat.weekdayFull($0)
                    return label.isEmpty ? nil : label
                },
                methodologyName: methodologyName
            )
        )
    }

    /// `training_stages[]` → 畫面上的期程列。
    ///
    /// 狀態只看週次落點：當前週在區間內＝進行中，整段在當前週之前＝已完成，其餘＝待進行。
    /// **沒有當前週就沒有狀態可判** —— 那時每一段都是「待進行」，不猜第一段正在跑。
    static func stages(_ dtos: [TrainingStageV2], currentWeek: Int?) -> [App2PlanStage] {
        dtos.map { dto in
            let state: App2PlanStage.State
            var weeksElapsed: Int?
            if let currentWeek {
                if currentWeek > dto.weekEnd {
                    state = .done
                } else if currentWeek >= dto.weekStart {
                    state = .active
                    weeksElapsed = currentWeek - dto.weekStart + 1
                } else {
                    state = .upcoming
                }
            } else {
                state = .upcoming
            }

            let focus = dto.trainingFocus.trimmingCharacters(in: .whitespacesAndNewlines)
            return App2PlanStage(
                id: dto.stageId,
                name: dto.stageName,
                focus: focus.isEmpty ? nil : focus,
                weekStart: dto.weekStart,
                weekEnd: dto.weekEnd,
                state: state,
                weeksElapsed: weeksElapsed
            )
        }
    }

    /// `milestones[]` → 畫面上的里程碑列（2026-08-27 晚走查裁決（c））。
    ///
    /// 順序照週次；**標題空白的那一筆整筆丟掉** —— 沒有標題就沒有可讀的內容，
    /// 印一列空白比不印更糟。`description` 空白只是少一行小字，那一筆仍然留著。
    /// 文字本身後端已在地化，App 端不改寫也不補預設句。
    /// 同一週的多筆維持 payload 原順序（`Array.sorted` 不保證穩定，所以帶原索引比）。
    static func milestones(_ dtos: [MilestoneV2]) -> [App2PlanMilestone] {
        dtos
            .enumerated()
            .compactMap { index, dto -> (Int, App2PlanMilestone)? in
                let title = dto.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return nil }
                let description = dto.description.trimmingCharacters(in: .whitespacesAndNewlines)
                return (index, App2PlanMilestone(
                    week: dto.week,
                    title: title,
                    description: description.isEmpty ? nil : description,
                    isKey: dto.isKeyMilestone
                ))
            }
            .sorted { lhs, rhs in
                lhs.1.week == rhs.1.week ? lhs.0 < rhs.0 : lhs.1.week < rhs.1.week
            }
            .map { $0.1 }
    }

    /// 「約 N km / 週」＝**最近 4 個已結束的週**的實際跑量平均。
    ///
    /// 兩個決定寫在這裡，不散在呼叫端：
    /// - **當週不算**：週三看到的「本週 5 km」不是這個人的週量水準，會把平均拉垮。
    /// - **0 的週照算**：那幾週真的沒跑，濾掉會把平均灌高。全部都是 0 或沒資料 → nil，
    ///   畫面整格不顯示，不印 `0 km / 週`。
    ///
    /// payload（`/summary/weekly/all`）是新到舊，但這裡不靠它的順序 —— 用
    /// `week_start_timestamp` 自己排，順序換了也不會靜靜地取到最舊的四週。
    static func averageWeeklyKm(_ items: [WeeklySummaryItem], now: Date = Date()) -> Double? {
        let currentWeekStart = App2WeekCalendar.currentWeekStart(reference: now)
        let completed = items
            .filter { item in
                guard let timestamp = item.weekStartTimestamp else { return true }
                return Date(timeIntervalSince1970: timestamp) < currentWeekStart
            }
            .sorted { ($0.weekStartTimestamp ?? 0) > ($1.weekStartTimestamp ?? 0) }
            .prefix(4)
            .map { $0.distanceKm ?? 0 }

        guard !completed.isEmpty, completed.contains(where: { $0 > 0 }) else { return nil }
        return completed.reduce(0, +) / Double(completed.count)
    }

    /// 距離賽事還有幾**整**週（floor），與 Android `App2RaceProjections.weeksUntil` 同一算法：
    /// 賽事落在 7 天內（含當週）＝0 週（2026-08-29 D1 裁決）。已過期回 nil —— 不顯示負週數。
    static func weeksUntil(epochSeconds: Int, now: Date = Date()) -> Int? {
        let calendar = Calendar.current
        let raceDay = calendar.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(epochSeconds)))
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: today, to: raceDay).day ?? 0
        guard days >= 0 else { return nil }
        return days / 7
    }

    /// 賽事日期以賽事時區顯示（數字 timestamp 是 UTC，`YYYY-MM-DD` 是當地日期）。
    static func localDateString(fromEpochSeconds seconds: Int, timezone: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timezone) ?? .current
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(seconds)))
    }
}
