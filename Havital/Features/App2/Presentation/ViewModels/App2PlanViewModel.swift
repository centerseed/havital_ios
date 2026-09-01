import Foundation

// MARK: - App2PlanViewModel
/// Presentation Layer — 2.0 課表頁（`DESIGN-app2-decision-chain-api.md` §3.3）。
///
/// 週目標量／每日安排來自 `GET /v2/plan/weekly/{plan_id}`；**已完成量不在該 payload 裡**
/// （§3.3 第 2 列），要另外從 `GET /v2/workouts` 的本週紀錄合併計算。
@MainActor
final class App2PlanViewModel: ObservableObject, TaskManageable, App2Revalidating {

    @Published private(set) var isLoading = true
    @Published private(set) var week: App2Sourced<App2PlanWeek>?
    /// 後端明說本週還沒有課表（`current_week_plan_id == nil`）。
    /// 讀取失敗不算 —— 那時 `week` 保持舊值或退樣本，這個旗標維持 true。
    @Published private(set) var isPlanGenerated = true
    /// 計畫結束態（設計 frame-00g2（c））。**有值時這一頁不再顯示第 N/M 週**
    /// —— 計畫已經走完，週次切換器與日卡整段換成結束態卡。
    ///
    /// 判準與首頁同一條（`App2PlanEndProjection.card`），不是這一頁自己再判一次。
    @Published private(set) var planEnd: App2PlanEndCard?
    /// 每日卡點下去要開的訓練詳情（設計 frame-02），key = `day_index`。
    /// **與課表頁同一份 payload**，詳情頁不再打端點；休息日不在這張表裡（不進詳情）。
    @Published private(set) var dayDetails: [Int: App2SessionDetail] = [:]
    /// 歷史回看正在看第幾週（裁決（e））。nil ＝ 沒在歷史模式。
    ///
    /// 走的是**既有**的 `getWeeklyPlan(weekOfTraining:overviewId:)`
    /// （`GET /v2/plan/weekly/{overviewId}_{week}`），不新開端點也不新開頁面。
    @Published private(set) var historyWeek: Int?
    /// 這一週後端沒有課表（404）。**那不是錯誤**：計畫可能有幾週從沒生成過，
    /// 那幾週顯示空態，其他週照走。
    @Published private(set) var isHistoryWeekMissing = false

    // MARK: - 產生本週課表（2026-08-27 晚走查裁決（i））
    //
    // **裁決前是死循環**：首頁說「到『課表』頁產生」，課表頁的未產生態卻只有同一句
    // 文字卡、沒有任何產生入口（1.4 有 `training.generate_weekly_plan` 那顆鈕，
    // App2 漏接）。生成要數十秒，所以要有 loading 態並擋住重複點擊。

    @Published private(set) var isGeneratingPlan = false
    /// 產生失敗的訊息（可重試）。
    @Published var generateError: String?

    // MARK: - 未產生態 CTA 分流（2026-08-27 晚走查裁決（k））
    //
    // 上一週的回顧還沒生成時，後端的 plan status 給的是 `next_action == "create_summary"`
    // （`domains/plan_week/service.py:1242`：`current_week ≥ 2`、本週無課表、上週無回顧）。
    // 那個狀態下「產生本週課表」是**走不通的一步**——1.4 正是在 `create_summary` 時把
    // 產生鈕換成回顧入口。這裡沿用同一條判準，讓 CTA 指向真正的下一步。
    //
    // ⚠️ 裁決（k）的文字寫的是 `needs_weekly_summary`，後端沒有這個值；實際的
    // 阻擋值是 `create_summary`（上面的 file:line）。以後端事實為準。

    /// 這個 `next_action` 表示「先做上週回顧」，不是「可以產生課表」。
    private static let needsWeeklySummaryAction = "create_summary"

    /// 未產生態的 CTA 該指向週回顧而不是產生課表。
    var requiresWeeklyReviewBeforeGenerate: Bool {
        latestPlanStatus?.nextAction == Self.needsWeeklySummaryAction
    }

    /// 要先完成的是**哪一週**的回顧。`create_summary` 只在 `current_week ≥ 2` 且
    /// 上週回顧缺席時出現，所以目標一律是 `current_week − 1`
    /// （與首頁週回顧 CTA 平日那三列同一個算法）。
    var weeklyReviewTargetWeek: Int? {
        guard requiresWeeklyReviewBeforeGenerate,
              let current = latestPlanStatus?.currentWeek, current > 1 else { return nil }
        return current - 1
    }

    /// 現在畫的是**哪一週**。歷史模式＝那一週，否則＝本週。
    /// header 的週回顧鈕用它決定要開哪一週的回顧（2026-08-27 走查裁決（q））。
    /// 推不出週次（plan status 還沒回來）時 nil，那顆鈕就不出現。
    var selectedWeekOfPlan: Int? { historyWeek ?? latestPlanStatus?.currentWeek }

    private(set) var hasLoaded = false
    private(set) var lastLoadedAt: Date?
    /// 這一輪是否真的完成（成功或真失敗）。取消（含子載入的 -999）會把它收回 false。
    /// 放實例層是因為 `loadHistoryWeek` 也要能收回它（部分取消，外審第七輪 D04）。
    private var finishedRound = false
    /// revalidate 的同輪互斥：兩輪並發會在 await 點交錯共用取消旗標與完成標記。
    private var isRevalidating = false
    /// 這一輪重驗的起點（判卡死用，見 revalidate 開頭）。
    private var revalidateBegan: Date?
    /// 鎖的輪次所有權：被接管的卡死輪回來時不得放掉新輪的鎖（T-0359 外審 D04）。
    private var revalidateGeneration = 0
    /// 現任輪的 task：接管時取消它，逼舊輪走取消路徑退出。
    private var revalidateRoundTask: Task<Void, Never>?
    /// 被接管的舊輪（在輪內、代號非現任）。helper 在 await 後寫共用狀態前必查
    /// ——不在任何輪內（id == 0，使用者動作路徑）不受限（外審第四輪 D04）。
    private var isStaleRound: Bool {
        App2RevalidateRound.id != 0 && App2RevalidateRound.id != revalidateGeneration
    }

    /// 最近一次讀到的 plan status —— 歷史週的週起點與週次上限都從它推。
    private var latestPlanStatus: PlanStatusV2Response?
    /// `planId` ＝ `{overviewId}_{week}`，所以歷史回看要 overview id。
    /// **只在真的進歷史模式時才解**（正常路徑仍然不為了這一頁多打 overview）。
    private var overviewId: String?

    // MARK: - 已完成量的補史（T-0374，2026-09-01 裁決）
    //
    // 「完成標記只讀本地快取先畫；快取沒有的才背景補抓，永不擋切週。」
    // 修前這一段是同步的：每切一次週就 `await ensureMonthLoaded` 一到兩個月，
    // 而近 45 天的月份**無條件**打一趟 `GET /v2/workouts?page_size=50`
    //（`WorkoutRepositoryImpl:158-163`），更舊的月份最多 30 頁——而且沒有去重，
    // 同兩週之間來回切十次就是十次重跑。那一週已經走完，是不會再變的歷史事實。

    /// 這個 ViewModel 的生命週期內已經補過史的月份（`year * 100 + month`）。
    /// **不是第二份 workout 快取**：真正的快取是 `WorkoutLocalDataSource`，
    /// 這裡只記「這個月問過後端了」，避免同一趟往返重複付。
    ///
    /// 每一輪 `revalidate()` 開頭整份丟掉（下拉刷新與 60 秒 SWR 仍然一定重新補史），
    /// 收到 `.dataChanged(.workouts)` 也丟掉並重算目前這一週。
    private var backfilledMonths: Set<Int> = []
    /// 最近一顆背景補史（只給測試等它跑完；正式路徑沒有人等它，那正是重點）。
    private var backfillTask: Task<Void, Never>?

    // MARK: - 整期週課表預抓（T-0378，2026-09-01 裁決）
    //
    // 使用者原話：「切換週課表還是會有一到兩秒的lag」。T-0374 讓切週不再等 workout
    // 補史，但**沒看過的那一週仍然要等 `GET /v2/plan/weekly/{overviewId}_{week}`**
    // ——`prepaintHistoryWeek` 靠的是 repository 快取，快取沒有就只能空著等。
    //
    // 所以進課表頁時在背景把整期逐週填進同一份快取（`TrainingPlanV2LocalDataSource`），
    // 之後每一次切週都是快取命中、零網路。**不擋首屏**（沒有人 await 它）、
    // **404 容忍**（那一週從沒生成過課表，不是錯誤）、**一個 session 只跑一次**。

    /// 這個 ViewModel 的生命週期內已經排過整期預抓。**不是第二份快取**：
    /// 週課表的 SSOT 仍然是 repository 的 cache-first `getWeeklyPlan`，
    /// 這裡只記「這一期已經排過預抓了」，避免每一輪 SWR 重驗都重排一次。
    private var hasScheduledWeeklyPlanPrefetch = false
    /// 最近一顆整期預抓（只給測試等它跑完；正式路徑沒有人等它）。
    private var weeklyPlanPrefetchTask: Task<Void, Never>?
    /// 併發上限（裁決：3）。整期 20 幾週一次全部丟出去會把連線佔滿，
    /// 把首屏那幾筆真正要用的請求排到後面。
    private static let weeklyPlanPrefetchLanes = 3
    /// 目前畫面上這一週的投影素材。補史回來、或收到新紀錄推播時，
    /// 用它重算已完成量並重新發布 `week`（`dayDetails` 與已完成量無關，不重建）。
    private var displayedWeek: DisplayedWeek?

    /// 現在畫的是哪一份週課表 —— 重算已完成量要的全部素材。
    private struct DisplayedWeek {
        /// nil ＝ 本週（走裝置日曆的「今天」）；有值 ＝ 歷史回看的第 N 週。
        let historyWeek: Int?
        let plan: WeeklyPlanV2
        let planStatus: PlanStatusV2Response
        let weekStart: Date
    }

    // MARK: - 結束態 ／ 歷史回看的狀態判準

    /// 現在畫的是不是結束卡。歷史模式時結束卡讓位給週課表。
    var isHistoryMode: Bool { historyWeek != nil }
    /// header 右上角週回顧鈕：只在歷史週出現（裁決（q）2026-09-01 覆寫）。
    /// 當週不畫——產生走首頁時機卡與「先完成週回顧」CTA。
    var showsHeaderWeeklyReview: Bool { isHistoryMode }
    var showsPlanEnd: Bool { planEnd != nil && historyWeek == nil }
    /// 歷史回看退出後會落在哪：結束畫面（結束態）或本週課表（進行中）。
    var showsPlanEndAfterExit: Bool { planEnd != nil }

    /// 課表還能不能編輯（裁決（b））。**結束了就一路唯讀，歷史模式也一樣。**
    var allowsEditing: Bool { App2PlanEndProjection.allowsEditing(planEnd: planEnd) }

    /// 這期共幾週 —— 歷史回看的上限。
    var historyTotalWeeks: Int? { planEnd?.totalWeeks ?? latestPlanStatus?.totalWeeks }

    /// 進行中也能從當週往回翻（8/27 走查：第 9 週的用戶左箭頭永遠停用＝缺陷）。
    var canGoPreviousHistoryWeek: Bool {
        ((historyWeek ?? latestPlanStatus?.currentWeek) ?? 1) > 1
    }
    var canGoNextHistoryWeek: Bool {
        guard let historyWeek else { return false }
        // 進行中往後翻的上限＝當週（回到當週就退回現行畫面）；結束態＝總週數。
        let cap = planEnd == nil
            ? (latestPlanStatus?.currentWeek ?? historyTotalWeeks ?? historyWeek)
            : (historyTotalWeeks ?? historyWeek)
        return historyWeek < cap
    }

    nonisolated let taskRegistry = TaskRegistry()

    /// **課表資料只有這一個入口。**（2026-08-26 架構收斂）
    /// 冷啟先渲染的那一份與這一輪要重驗的那一份，都從它拿 —— App2 不再自己持有
    /// `TrainingPlanV2RemoteDataSource`，也不再另存一份週課表快照。
    private let planRepository: TrainingPlanV2Repository
    private let workoutRepository: WorkoutRepository
    /// 結束態卡的賽名來源（只讀本機快取的 `getMainTarget()`）。
    /// **沒註冊就不強行註冊** —— 那時只是結束態卡少一個賽名，不該讓整頁掛掉。
    private let targetRepository: TargetRepository?

    init(
        planRepository: TrainingPlanV2Repository? = nil,
        workoutRepository: WorkoutRepository? = nil,
        targetRepository: TargetRepository? = nil
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

        if let workoutRepository {
            self.workoutRepository = workoutRepository
        } else {
            if !container.isRegistered(WorkoutRepository.self) {
                container.registerWorkoutModule()
            }
            self.workoutRepository = container.resolve() as WorkoutRepository
        }

        if let targetRepository {
            self.targetRepository = targetRepository
        } else {
            self.targetRepository = container.isRegistered(TargetRepository.self)
                ? (container.resolve() as TargetRepository)
                : nil
        }

        // 目標變更後計畫會整份重生——與 `App2HomeViewModel` 同一組事件、同一個理由
        // （常駐 VM 的 60 秒 SWR 門檻擋住跨頁寫入），收到就作廢時戳並立即重驗。
        CacheEventBus.shared.subscribe(forIdentifier: "App2PlanViewModel.targets") { [weak self] reason in
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
            // 新紀錄進來了（推播／同步）——「已補過這個月」的判斷跟著作廢，
            // 並就地重算目前這一週的已完成量（T-0374 裁決的失效條件）。
            // 不整頁重驗：週課表 payload 與 workouts 無關，重驗只是多付一趟。
            case .dataChanged(.workouts):
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.backfilledMonths.removeAll()
                    // 歷史週：那一個月可能因為這筆新紀錄而需要重新補史。
                    // 本週不重補——推播的來源本來就剛把本地列表刷過了，再問一次是白付。
                    if let displayed = self.displayedWeek, displayed.historyWeek != nil {
                        self.backfillCompletedDistance(weekStart: displayed.weekStart)
                    }
                    await self.recomputeCompletedDistance()
                }
            default:
                break
            }
        }
    }

    deinit {
        cancelAllTasks()
    }

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

        // 重驗＝一定重新問後端一次，補史的去重水位跟著整份丟掉（T-0374）。
        // 去重只擋「切週來回翻」那種零新增資訊的重跑，不擋下拉刷新與 SWR。
        backfilledMonths.removeAll()

        // 冷啟第一輪：先把上一次的週課表渲染出來，這一輪的網路變成背景刷新。
        if !hasLoaded { hydrateFromCache() }
        isLoading = !hasLoaded && week == nil
        finishedRound = false
        defer {
            // 只有現任輪能收尾——被接管的舊輪連 isLoading 都不得清（外審第三輪 D04）。
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

        do {
            // `forceRefresh` ＝ 這一輪一定走網路。SWR 的「先舊後新」由上面那一行
            // 的快取渲染負責，不是靠 repository 的 cooldown 決定要不要重驗。
            let status = try await planRepository.getPlanStatus(forceRefresh: true)
            guard revalidateGeneration == round else { return }
            latestPlanStatus = status
            finishedRound = true

            // 整期預抓（T-0378）：不 await —— 首屏與切週都不得等它。
            schedulePrefetchAllWeeks(totalWeeks: status.totalWeeks)

            await applyPlanEnd(planStatus: status)
            // await 恢復點：被接管的舊輪不得再寫 week／dayDetails 等共用狀態
            //（外審第三輪 D04）。
            guard revalidateGeneration == round else { return }
            if let historyWeek {
                // 歷史回看中（結束態或進行中都可以往回翻）：這一輪重驗的是
                // **那一週**，不是本週。進行中不能回看是 8/27 實機走查抓到的缺陷
                // ——第 9 週的用戶按左箭頭永遠沒反應。
                await loadHistoryWeek(historyWeek)
                return
            }
            if planEnd != nil {
                // 結束態：**不再交出週課表**。留著它畫面上就會同時出現
                // 「計畫完成」與「第 6 / 6 週」的日卡 —— 設計 frame-00g2（c）明定
                // 這一頁不能再顯示第 N/M 週。
                week = nil
                dayDetails = [:]
                isPlanGenerated = true
                return
            }
            isHistoryWeekMissing = false

            guard let planId = status.currentWeekPlanId else {
                // **本週沒有課表就說沒有。** 這裡原本退樣本，畫面上會出現一整週
                // 「第 5 週 / 22」的假課表，而首頁同時說「本週課表尚未產生」——
                // 2026-08-25 用戶截圖上那組矛盾就是這麼來的。
                Logger.debug("[App2PlanVM] 本週尚無課表 (next_action=\(status.nextAction))")
                week = nil
                isPlanGenerated = false
                return
            }
            isPlanGenerated = true

            // `fetchWeeklyPlan` ＝ 走網路並寫回 repository 快取（下一次冷啟就是它）。
            let plan = try await planRepository.fetchWeeklyPlan(planId: planId)
            let completed = await completedDistanceKmThisWeek()
            guard revalidateGeneration == round else { return }
            apply(plan: plan, planStatus: status, completedKm: completed)
        } catch {
            // 取消不是失敗（`AGENTS.md` 陷阱 2）：下拉刷新的 task 被收掉時
            // in-flight 請求會回 -999，當成失敗會把真課表換成樣本。
            // plan status 成功後才被取消（fetchWeeklyPlan 等後續）＝部分取消：
            // 一樣不算載過，把先前樂觀設下的旗標收回（外審第七輪 D04）。
            guard !error.isCancellationError else { if !isStaleRound { finishedRound = false }; return }
            guard revalidateGeneration == round else { return }
            finishedRound = true
            Logger.debug("[App2PlanVM] 週課表取得失敗,退樣本: \(error)")
            guard week == nil else { return }       // SWR：重驗失敗時保留舊資料
            // 歷史回看不退樣本 —— 使用者要看的是**那一週真的排了什麼**，
            // 拿一份假課表頂上去比空著更糟。
            guard !isHistoryMode else { return }
            week = App2Sourced(
                App2StubFixtures.planWeek,
                origin: .stub(pendingSection: App2StubFixtures.Section.offline)
            )
        }
    }

    /// 產生本週課表（`POST /v2/plan/weekly`，既有出口，不新開路徑）。
    ///
    /// 週次取 plan status 的 `current_week` —— 這一頁的週次骨幹本來就是它，
    /// 不自己從日期推一個。沒有 plan status 就產不了（那時連第幾週都不知道）。
    ///
    /// 成功後**重跑 `revalidate()`**：`isPlanGenerated` 與日卡都由那一支決定，
    /// 不在這裡自己把旗標翻真（翻了但課表沒下來，畫面會空著卻宣稱已產生）。
    ///
    /// **上週回顧沒做時這一支直接不動作**（裁決（k））：那時 CTA 畫的是「先完成週回顧」，
    /// 呼叫這裡只會走進失敗重試的死路。
    @discardableResult
    func generateCurrentWeekPlan() async -> Bool {
        guard !isGeneratingPlan else { return false }
        guard !requiresWeeklyReviewBeforeGenerate else {
            Logger.debug("[App2PlanVM] 上週回顧未完成 (next_action=create_summary)，不產生本週課表")
            return false
        }
        guard let week = latestPlanStatus?.currentWeek else {
            Logger.debug("[App2PlanVM] 沒有 plan status,產不了本週課表")
            return false
        }

        isGeneratingPlan = true
        generateError = nil
        defer { isGeneratingPlan = false }

        do {
            _ = try await planRepository.generateWeeklyPlan(
                weekOfTraining: week,
                forceGenerate: nil,
                promptVersion: nil,
                methodology: nil
            )
        } catch {
            guard !error.isCancellationError else { return false }
            let domainError = error.toDomainError()
            Logger.debug("[App2PlanVM] 產生本週課表失敗: \(domainError)")
            generateError = domainError.localizedDescription
            return false
        }

        // 課表下來了 —— 這一頁與首頁今日課表都要換成新的那一份。
        await revalidate()
        // 首頁的今日課表吃同一份週課表 —— 用既有的失效事件把它叫醒
        // （同 `EditScheduleV2ViewModel` 存檔後的處置，不新開通知路徑）。
        CacheEventBus.shared.publish(.dataChanged(.trainingPlanV2))
        return isPlanGenerated
    }

    /// 結束態卡。與首頁走**同一支投影**（`App2PlanEndProjection.card`），
    /// 所以兩個 tab 上的變體、週數、賽名一定一致。
    ///
    /// 變體來自 `plan status` 自己的 `target_type`（與 overview 同一份文件的同一欄），
    /// **所以這一頁不為了判變體多打一次 `GET /v2/plan/overview`**。
    private func applyPlanEnd(planStatus: PlanStatusV2Response) async {
        let target = await targetRepository?.getMainTarget()
        guard !isStaleRound else { return }

        #if DEBUG
        if let forced = App2DevSettings.shared.planEndOverride.resolve(
            planStatus: planStatus,
            overview: nil,
            target: target,
            // 課表 tab 的結束態卡不畫完賽預估（frame-00g2（c）沒有那一格），
            // 所以這一頁不為它多打一次 readiness。
            estimatedFinish: nil
        ) {
            planEnd = forced
            return
        }
        #endif

        planEnd = App2PlanEndProjection.card(
            planStatus: planStatus,
            overview: nil,
            target: target,
            estimatedFinish: nil
        )
    }

    // MARK: - 歷史課表回看（裁決（e））

    /// 進歷史模式，從**最後一週**開始（那是使用者剛走完的那一週，離結束畫面最近）。
    func enterHistoryMode() async {
        guard let target = App2PlanEndProjection.clampHistoryWeek(
            historyTotalWeeks ?? 0, totalWeeks: historyTotalWeeks
        ) else { return }
        await loadHistoryWeek(target)
    }

    /// 回到計畫完成畫面。**要有這條返程**，否則按下「瀏覽歷史課表」之後就回不去了。
    func exitHistoryMode() {
        historyWeek = nil
        isHistoryWeekMissing = false
        week = nil
        dayDetails = [:]
        displayedWeek = nil
    }

    /// 上一週／下一週（`offset` ＝ ±1）。夾在 `1…total_weeks` 內。
    ///
    /// 非歷史模式（看本週）按左箭頭＝從當週的前一週進歷史模式；
    /// 進行中的計畫往後翻回到當週＝退出歷史模式回到現行畫面。
    func goToHistoryWeek(offset: Int) async {
        guard let current = historyWeek ?? latestPlanStatus?.currentWeek else { return }
        if planEnd == nil,
           let currentWeek = latestPlanStatus?.currentWeek,
           current + offset >= currentWeek {
            guard historyWeek != nil else { return }
            exitHistoryMode()
            await revalidate()
            return
        }
        guard let next = App2PlanEndProjection.clampHistoryWeek(
                  current + offset, totalWeeks: historyTotalWeeks
              ),
              next != historyWeek else { return }
        await loadHistoryWeek(next)
    }

    /// 取第 N 週的課表。
    ///
    /// 走既有的 `getWeeklyPlan(weekOfTraining:overviewId:)`（快取優先，miss 才打
    /// `GET /v2/plan/weekly/{overviewId}_{week}`）。**404 ＝ 該週從沒生成過課表**，
    /// 那不是錯誤：這一週顯示空態，週次切換照常，其他週照走。
    private func loadHistoryWeek(_ target: Int) async {
        historyWeek = target
        isHistoryWeekMissing = false
        // 切週的第一畫：**這一行之前不得有任何 `await`**（T-0374 裁決
        // 「切週零同步網路請求」＋「切週瞬間 UI 必須切換」）。修前這裡只設
        // `historyWeek`，`week` 保持舊值，所以週次標跳走、七張日卡停在上一週。
        prepaintHistoryWeek(target)

        let resolvedOverviewId = await resolveOverviewId()
        guard !isStaleRound else { return }
        guard let status = latestPlanStatus, let overviewId = resolvedOverviewId else {
            week = nil
            dayDetails = [:]
            isHistoryWeekMissing = true
            return
        }

        do {
            let plan = try await planRepository.getWeeklyPlan(
                weekOfTraining: target,
                overviewId: overviewId
            )
            guard !isStaleRound else { return }
            await applyHistory(plan: plan, planStatus: status, week: target)
        } catch {
            guard !error.isCancellationError else { if !isStaleRound { finishedRound = false }; return }
            guard !isStaleRound else { return }
            Logger.debug("[App2PlanVM] 歷史第 \(target) 週無課表: \(error)")
            week = nil
            dayDetails = [:]
            isHistoryWeekMissing = true
        }
    }

    /// `planId` ＝ `{overviewId}_{week}`，所以歷史回看要 overview id。
    /// 快取有就用快取；沒有才打一次 `GET /v2/plan/overview`，之後這個 session 不再打。
    private func resolveOverviewId() async -> String? {
        if let overviewId { return overviewId }
        if let cached = planRepository.getCachedOverview()?.id {
            overviewId = cached
            return cached
        }
        let fetched = try? await planRepository.getOverview().id
        // 被接管的舊輪不寫快取，只回值（呼叫端會再以輪代號把整段丟棄）。
        guard !isStaleRound else { return fetched }
        overviewId = fetched
        return overviewId
    }

    // MARK: - 整期預抓（T-0378）

    /// 背景把 `1…totalWeeks` 逐週填進 repository 快取。**沒有人 await 它。**
    ///
    /// 走的是既有的 cache-first `getWeeklyPlan(weekOfTraining:overviewId:)` ——
    /// 已經在快取裡的週不會產生任何往返，所以重跑的成本只有沒抓過的那幾週。
    /// 失敗（含 404 ＝ 該週從沒生成過課表）就跳過那一週，不影響其他週。
    private func schedulePrefetchAllWeeks(totalWeeks: Int) {
        guard totalWeeks > 0, !hasScheduledWeeklyPlanPrefetch else { return }
        hasScheduledWeeklyPlanPrefetch = true

        weeklyPlanPrefetchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            // overview id 是 `{overviewId}_{week}` 的前半 —— 快取有就用快取，
            // 沒有才打一次 `GET /v2/plan/overview`（與歷史回看同一支，不新開路徑）。
            guard let overviewId = await self.resolveOverviewId() else { return }
            guard !Task.isCancelled else { return }

            let lanes = min(Self.weeklyPlanPrefetchLanes, totalWeeks)
            await withTaskGroup(of: Void.self) { group in
                for lane in 0..<lanes {
                    group.addTask { @MainActor [weak self] in
                        var week = lane + 1
                        while week <= totalWeeks, !Task.isCancelled {
                            _ = try? await self?.planRepository.getWeeklyPlan(
                                weekOfTraining: week,
                                overviewId: overviewId
                            )
                            week += lanes
                        }
                    }
                }
            }
            Logger.debug("[App2PlanVM] 整期課表預抓完成（\(totalWeeks) 週）")
        }
    }

    #if DEBUG
    /// 測試用：等整期預抓跑完（正式路徑沒有人等它 —— 那正是重點）。
    func waitForWeeklyPlanPrefetchForTesting() async {
        await weeklyPlanPrefetchTask?.value
    }
    #endif

    /// 切週的預畫 —— **同步、零 `await`、零網路**（T-0374）。
    ///
    /// 週課表的 SSOT 是 repository 的快取（`getWeeklyPlan` 本來就 cache-first，
    /// `TrainingPlanV2RepositoryImpl:202-215`），所以這裡讀的是同一份，
    /// **不是這一頁自己再存一份週課表**。命中就立刻換掉跑量卡與七張日卡；
    /// 沒命中就清空，讓週次標（會退到 `selectedWeekOfPlan`）與內容同步落到目標週的等待態。
    ///
    /// 已完成量留白：它是本地紀錄現算的，下面那一步（本地快取，零網路）馬上補上。
    private func prepaintHistoryWeek(_ target: Int) {
        guard let status = latestPlanStatus,
              let cached = planRepository.getCachedWeeklyPlan(week: target) else {
            week = nil
            dayDetails = [:]
            displayedWeek = nil
            return
        }
        publishHistory(
            plan: cached,
            planStatus: status,
            week: target,
            weekStart: App2PlanEndProjection.historyWeekStart(week: target, planStatus: status),
            completedKm: nil
        )
    }

    /// 歷史週的組裝。與本週走同一支 `planWeek`，只換兩個錨點：
    /// - `weekStart` ＝ **那一週**的週一（日卡日期要標那一週）。
    /// - `todayIndex: 0` ＝ 沒有任何一天是「今天」（`day_index` 是 1…7）——
    ///   已走完的那一週上不該掛「今天」膠囊。
    ///
    /// 已完成量**只讀本地快取**（T-0374）：那一週已經走完，是不會再變的歷史事實，
    /// 不需要每次切週都同步問一次 API。快取涵蓋不到的月份丟給背景補史。
    private func applyHistory(plan: WeeklyPlanV2, planStatus: PlanStatusV2Response, week target: Int) async {
        isPlanGenerated = true
        let start = App2PlanEndProjection.historyWeekStart(week: target, planStatus: planStatus)
        let completed = await completedDistanceKmFromCache(weekStart: start)
        guard !isStaleRound else { return }
        publishHistory(
            plan: plan,
            planStatus: planStatus,
            week: target,
            weekStart: start,
            completedKm: completed
        )
        backfillCompletedDistance(weekStart: start)
    }

    /// 歷史週的發布（預畫與正式投影共用一支，兩條路不得長出不同的畫面）。
    private func publishHistory(
        plan: WeeklyPlanV2,
        planStatus: PlanStatusV2Response,
        week target: Int,
        weekStart start: Date,
        completedKm: Double?
    ) {
        isPlanGenerated = true
        displayedWeek = DisplayedWeek(
            historyWeek: target,
            plan: plan,
            planStatus: planStatus,
            weekStart: start
        )
        week = App2Sourced(
            Self.planWeek(
                plan: plan,
                planStatus: planStatus,
                completedKm: completedKm,
                todayIndex: 0,
                weekStart: start
            ),
            origin: .live(endpoint: "GET /v2/plan/weekly/{plan_id} + GET /v2/workouts")
        )
        dayDetails = Dictionary(
            uniqueKeysWithValues: plan.days.compactMap { day -> (Int, App2SessionDetail)? in
                guard let detail = App2SessionDetailProjection.detail(
                    day: day,
                    weekStart: start,
                    // 氣候的 UI 唯一入口（`climate[7]` 優先、缺席退 legacy `climate_meta`）。
                    // 配速帶的溫度補償要它（裁決（n））。
                    climateDay: plan.climate(forDayIndex: day.dayIndex)
                ) else { return nil }
                return (day.dayIndex, detail)
            }
        )
    }

    /// 週課表 ＋ 每日詳情的組裝。網路回應與冷啟快取都走這一支。
    private func apply(plan: WeeklyPlanV2, planStatus: PlanStatusV2Response, completedKm: Double?) {
        isPlanGenerated = true
        week = App2Sourced(
            Self.planWeek(plan: plan, planStatus: planStatus, completedKm: completedKm),
            origin: .live(endpoint: "GET /v2/plan/weekly/{plan_id} + GET /v2/workouts")
        )
        let weekStart = App2WeekCalendar.currentWeekStart()
        displayedWeek = DisplayedWeek(
            historyWeek: nil,
            plan: plan,
            planStatus: planStatus,
            weekStart: weekStart
        )
        dayDetails = Dictionary(
            uniqueKeysWithValues: plan.days.compactMap { day -> (Int, App2SessionDetail)? in
                guard let detail = App2SessionDetailProjection.detail(
                    day: day,
                    weekStart: weekStart,
                    climateDay: plan.climate(forDayIndex: day.dayIndex)
                ) else { return nil }
                return (day.dayIndex, detail)
            }
        )
    }

    /// 冷啟：plan status ＋ 本週課表都在 repository 快取裡才渲染。
    ///
    /// **已完成量（`completedKm`）不進快取**：它是本週紀錄現算出來的，冷啟給的是
    /// 「上一次算的值」而不是「上一次的回應」，兩者的腐爛速度不一樣。先留白，
    /// 這一輪網路回來就有了。
    private func hydrateFromCache() {
        guard let status = planRepository.getCachedPlanStatus(),
              let plan = planRepository.getCachedWeeklyPlan(week: status.currentWeek),
              App2HomeViewModel.isWeeklyPlan(plan, boundTo: status) else { return }
        apply(plan: plan, planStatus: status, completedKm: nil)
    }

    #if DEBUG
    /// 測試／預覽用：直接填入本週課表，不打網路。
    func applyForTesting(week: App2Sourced<App2PlanWeek>?) {
        self.week = week
        isLoading = false
        hasLoaded = true
        lastLoadedAt = Date()
    }
    #endif

    // MARK: - Mapping

    /// 週課表投影。`map` 原本是 instance method 但沒用到任何 instance 狀態 ——
    /// 改成 static 之後可以單獨測（`App2PlanProjectionTests`）。
    static func planWeek(
        plan: WeeklyPlanV2,
        planStatus: PlanStatusV2Response,
        completedKm: Double?,
        /// 測試可指定「今天」；nil = 用裝置日曆。
        todayIndex: Int? = nil,
        /// 測試可指定當週週一（日起點）；nil = 用裝置日曆推。
        weekStart: Date? = nil
    ) -> App2PlanWeek {
        let today = todayIndex ?? App2WeekCalendar.todayDayIndex()
        let start = weekStart ?? App2WeekCalendar.currentWeekStart()
        let weekNumber = plan.weekOfTraining ?? plan.weekOfPlan ?? planStatus.currentWeek
        let climateByDayIndex = Dictionary(
            plan.climateDays.map { ($0.dayIndex, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let days: [App2PlanDay] = plan.days.map { day in
            // 沒有 primary activity ＝ 休息日。
            let primary = day.session?.primary
            let isRest = primary == nil
            let dayType = isRest ? DayType.rest : Self.dayType(primary)
            return App2PlanDay(
                id: day.dayIndex,
                weekdayLabel: Self.weekdayLabel(dayIndex: day.dayIndex),
                dateLabel: App2WeekCalendar.dateLabel(dayIndex: day.dayIndex, weekStart: start),
                // 課型顯示字走既有的 `DayType.localizedName`（三語已齊），
                // 不再把後端的 `run_type` 識別字（`easy`／`lsd`）直接印到畫面上。
                // 對不到課型就退 `day_target`（後端已在地化）。不退 `category` ——
                // 那是 run／strength／cross／rest 四值 enum，rawValue 是識別字。
                tag: dayType?.localizedName
                    ?? (isRest ? L10n.App2.Plan.rest.localized : day.dayTarget),
                dayType: dayType,
                // 設計 frame-01 的「課表」行是「量 · 配速」（`4.0 km · 7:17/km`），
                // 不是裸距離；與今日課表卡走同一支 `contentLine`，不另做一份格式。
                planned: Self.contentLine(primary, totalDistanceKm: day.distanceKm),
                description: Self.descriptionLine(day),
                // 實際值要按日期對齊 workouts；骨架階段僅在週總量層合併（見 completedKm）。
                actual: nil,
                temp: Self.temperatureLabel(climateByDayIndex[day.dayIndex]),
                isToday: day.dayIndex == today
            )
        }

        return App2PlanWeek(
            // 設計 frame-01 的週次切換器是「第 N 週 / M」，不是裸數字。
            // 「第 N 週」三語已有（1.x 週次選單在用同一條），不另開 app2 命名空間的重複字串。
            weekLabel: String(format: L10n.WeekSelector.weekNumber.localized, weekNumber),
            // planStatus 優先：per-week doc 的 total_weeks 是生成當下的快照，計畫改期後
            // 不回填（dev 實測第 1 週 doc 停在 6、現行計畫是 7 → 歷史回看標成「第 1 週 / 6」）。
            totalWeeks: planStatus.totalWeeks ?? plan.totalWeeks,
            targetDistanceKm: plan.totalDistance,
            completedDistanceKm: completedKm,
            intensityLowMinutes: plan.intensityTotalMinutes.map { Int($0.low.rounded()) },
            intensityMediumMinutes: plan.intensityTotalMinutes.map { Int($0.medium.rounded()) },
            intensityHighMinutes: plan.intensityTotalMinutes.map { Int($0.high.rounded()) },
            days: days
        )
    }

    /// 本週已完成量的時間窗 —— 起點是**週一 00:00**，終點是此刻。
    ///
    /// 原本這裡是 `calendar.dateInterval(of: .weekOfYear, for: now)`，那條的週首隨
    /// locale 變（zh-TW ＝ 週日），與 backend 的週一週界差一天：2026-08-31（週一）
    /// 實機把週日 8/30 的 5.01 km 算進本週，13 km vs 正確的 8.46 km。
    /// `App2WeekCalendar.currentWeekStart` 的 doc comment 早就寫明不要用 dateInterval。
    static func completedThisWeekWindow(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        (App2WeekCalendar.currentWeekStart(reference: now, calendar: calendar), now)
    }

    private func completedDistanceKmThisWeek() async -> Double? {
        let window = Self.completedThisWeekWindow()
        return await completedDistanceKm(from: window.start, to: window.end)
    }

    /// 歷史週的已完成量 —— 範圍是**那一整週**（週一 00:00 到週日 23:59），
    /// 不是「到今天為止」：那一週早就走完了，沒有「還沒到的日子」。
    ///
    /// **只讀本地快取，零網路**（T-0374）。本地 workout 快取只涵蓋最近抓過的頁，
    /// 較早的週可能整週不在快取裡——那由 `backfillCompletedDistance` 在背景補，
    /// 補到再回頭更新這一格。切週的路徑上不得有任何網路往返。
    private func completedDistanceKmFromCache(weekStart: Date) async -> Double? {
        let calendar = Calendar.current
        guard let end = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return nil }
        return await completedDistanceKm(from: weekStart, to: end)
    }

    /// 一週最多橫跨兩個月（週一與週日各取一次，去重）。
    static func monthsSpanned(byWeekStartingAt weekStart: Date, calendar: Calendar = .current) -> [(year: Int, month: Int)] {
        let sunday = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        var months: [(year: Int, month: Int)] = []
        for anchor in [weekStart, sunday] {
            let parts = calendar.dateComponents([.year, .month], from: anchor)
            guard let year = parts.year, let month = parts.month,
                  !months.contains(where: { $0.year == year && $0.month == month }) else { continue }
            months.append((year, month))
        }
        return months
    }

    /// 背景補史（T-0374）——**永不擋切週**。
    ///
    /// 走的是訓練日曆同一支 `WorkoutRepository.ensureMonthLoaded`，沒有第二份快取。
    /// 已經補過的月份直接跳過：那一週的紀錄是歷史事實，同一個 session 裡問第二次
    /// 不會得到不一樣的答案（水位由 `revalidate()` 與 `.dataChanged(.workouts)` 清）。
    /// 補完才回頭重算那一格。
    ///
    /// **水位先記再補**，而且這顆 task 不被後續切週取消：連按箭頭時，前一顆已經
    /// 認領的月份不會被丟掉重來（取消會把水位洗成「補過了但其實沒補到」）。
    /// 補完時使用者可能已經切走 —— `recomputeCompletedDistance` 認的是**當下**
    /// 畫面上那一週，所以晚到的那一份只會讓現在這一格更準，不會蓋錯週。
    private func backfillCompletedDistance(weekStart: Date) {
        let pending = Self.monthsSpanned(byWeekStartingAt: weekStart)
            .filter { !backfilledMonths.contains($0.year * 100 + $0.month) }
        guard !pending.isEmpty else { return }
        for entry in pending { backfilledMonths.insert(entry.year * 100 + entry.month) }

        backfillTask = Task { [weak self] in
            for entry in pending {
                await self?.workoutRepository.ensureMonthLoaded(year: entry.year, month: entry.month)
            }
            await self?.recomputeCompletedDistance()
        }
    }

    /// 用手上這一份投影素材重算已完成量並重新發布 `week`。
    /// `dayDetails` 與已完成量無關，不重建。
    private func recomputeCompletedDistance() async {
        guard let displayed = displayedWeek else { return }
        let completed: Double?
        if displayed.historyWeek == nil {
            completed = await completedDistanceKmThisWeek()
        } else {
            completed = await completedDistanceKmFromCache(weekStart: displayed.weekStart)
        }
        // 期間使用者切走了 → 這一份已經不是畫面上那一週，丟掉。
        guard let current = displayedWeek,
              current.historyWeek == displayed.historyWeek else { return }
        week = App2Sourced(
            Self.planWeek(
                plan: current.plan,
                planStatus: current.planStatus,
                completedKm: completed,
                todayIndex: current.historyWeek == nil ? nil : 0,
                weekStart: current.weekStart
            ),
            origin: .live(endpoint: "GET /v2/plan/weekly/{plan_id} + GET /v2/workouts")
        )
    }

    #if DEBUG
    /// 測試用：等背景補史那一顆跑完（正式路徑沒有人等它 —— 那正是重點）。
    func waitForCompletedDistanceBackfillForTesting() async {
        await backfillTask?.value
    }
    #endif

    private func completedDistanceKm(from start: Date, to end: Date) async -> Double? {
        let workouts = await workoutRepository.getWorkoutsInDateRangeAsync(
            startDate: start,
            endDate: end
        )
        guard !workouts.isEmpty else { return nil }
        let meters = workouts
            .filter { $0.activityType.lowercased().contains("run") }
            .compactMap(\.distanceMeters)
            .reduce(0, +)
        return meters / 1000
    }

    // MARK: - Formatting

    /// `day_index` **1 = 週一 … 7 = 週日**。
    ///
    /// 原本這裡當成 0-based（`(dayIndex + 1) % 7`），星期與「今天」整整差一天。
    /// 2026-08-25 對 dev 的真實 payload 確認：`day_index: 2` 的 `reason` 寫的是
    /// 「週二安排長距離慢跑」，所以 1 = 週一。
    static func weekdayLabel(dayIndex: Int) -> String {
        // 跟著 app 語言走，不是系統 locale（app 語言＝繁中、系統＝英文時會露出 Wed/Sun）。
        var calendar = Calendar.current
        calendar.locale = LanguageManager.shared.locale
        let symbols = calendar.shortWeekdaySymbols
        // shortWeekdaySymbols[0] 是週日；day_index 7（週日）→ 0，1…6 → 1…6。
        let index = dayIndex % 7
        return symbols.indices.contains(index) ? symbols[index] : "—"
    }

    // `todayDayIndex` / `currentWeekStart` / `dateLabel` 已搬到 `App2WeekCalendar`
    // （Domain，層中立）—— `App2StubFixtures` 在 Data 層要用同一組換算。

    /// 每日卡的敘述行 —— 後端 `day_target`（已在地化、三語由後端 `content_lang` 決定）。
    /// 空字串當成沒有，不畫空行。
    static func descriptionLine(_ day: DayDetail) -> String? {
        let text = day.dayTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// `run_type` → 既有的 `DayType`。肌力／交叉訓練沒有跑步課型，各自映到對應的 case。
    /// 交叉訓練有具體 `cross_type`（yoga／cycling…）就報那一項（2026-08-29 D20 裁決，
    /// 與 Android 同一條：課表寫了什麼就顯示什麼），認不得才退通稱。
    static func dayType(_ primary: PrimaryActivity?) -> DayType? {
        switch primary {
        case .run(let run):
            return DayType(rawValue: run.runType.lowercased())
        case .strength:
            return .strength
        case .cross(let cross):
            return DayType(rawValue: cross.crossType.lowercased()) ?? .crossTraining
        case .none:
            return .rest
        @unknown default:
            return nil
        }
    }

    /// 「課表」那一行的結構化內容（設計 frame-00 今日課表卡、frame-01 每日卡）。
    ///
    /// 全部從 payload 的結構欄位組出來，沒有一個字是編的：
    /// - 有間歇段 → `6 × 200m · 5:25/km · 組間 90 秒`
    /// - 一般跑   → `9.0 km · 7:55/km`
    /// 課表分段列表 —— 卡片摘要、配速結構圖、分段列三個投影共用的那一份。
    ///
    /// **後端對間歇課不送 `segments[]`**：dev 實測 4×400m 那天 `primary` 只有
    /// `interval`（`repeats` / `work_*` / `recovery_*`），`segments` 整個缺席。
    /// 下游全都只認 `segments[].kind == "interval"`，於是間歇課被畫成一整塊
    /// 綠色穩定段、分段列也不展開衝刺與組間恢復（2026-08-26 使用者截圖）。
    /// 這裡把 `interval` 攤平成同一種段，讓三個投影繼續走同一條路徑，
    /// 不在各自的分支裡再判一次 payload 形狀。
    static func effectiveSegments(_ run: RunActivity) -> [RunSegment] {
        if let segments = run.segments, !segments.isEmpty { return segments }
        guard let interval = run.interval, interval.repeats > 0 else { return [] }
        return [RunSegment(
            distanceKm: interval.workDistanceKm,
            distanceM: interval.workDistanceM,
            distanceDisplay: nil,
            distanceUnit: nil,
            durationMinutes: interval.workDurationMinutes,
            durationSeconds: nil,
            pace: interval.workPace,
            basePace: nil,
            climateAdjustedPace: nil,
            climateMeta: nil,
            heartRateRange: nil,
            intensity: nil,
            description: interval.workDescription,
            kind: "interval",
            repeats: interval.repeats,
            work: SegmentEffort(
                distanceKm: interval.workDistanceKm,
                distanceM: interval.workDistanceM,
                durationMinutes: interval.workDurationMinutes,
                durationSeconds: nil,
                pace: interval.workPace,
                basePace: nil,
                paceZone: nil,
                targetHrr: nil,
                recoveryType: nil
            ),
            recovery: SegmentEffort(
                distanceKm: interval.recoveryDistanceKm,
                distanceM: interval.recoveryDistanceM,
                durationMinutes: interval.recoveryDurationMinutes,
                durationSeconds: interval.recoveryDurationSeconds,
                pace: interval.recoveryPace,
                basePace: nil,
                paceZone: nil,
                targetHrr: nil,
                recoveryType: nil
            )
        )]
    }

    /// 兩者都拿不到 → nil（畫面就不顯示這一行，不用 placeholder 充數）。
    ///
    /// `totalDistanceKm` ＝ 這一天的總量（payload 的日層 `distance_km`）。給了就用它，
    /// 因為 `primary.distance_km` 在間歇課只算主課段（dev 實測 `2.2`＝4×400m 加組間
    /// 恢復），跟下面分段列的熱身 2.0 ＋ 衝刺 1.6 ＋ 緩和 1.0 加不起來
    /// （2026-08-26 使用者回報）。日層 `5.2` 才是那張卡在講的量。
    ///
    /// 距離與配速走**同一個** `unitSystem`（2026-09-01）：原本配速已接 `UnitManager`、
    /// 距離卻寫死 `km`，英制用戶看到的是同一行裡「公里數字 · 每英里配速」。
    static func contentLine(
        _ primary: PrimaryActivity?,
        totalDistanceKm: Double? = nil,
        unitSystem: UnitSystem? = nil
    ) -> String? {
        guard case .run(let run) = primary else { return nil }
        // 預設值不能寫在參數上：default argument 在 nonisolated context 求值。
        let unitSystem = unitSystem ?? .current

        if let line = intervalContentLine(run, unitSystem: unitSystem) { return line }

        var parts: [String] = []
        if let km = totalDistanceKm ?? run.distanceKm, km > 0 {
            parts.append(unitSystem.formatDistance(km))
        } else if let minutes = run.durationMinutes {
            parts.append("\(minutes) min")
        }
        if let pace = dayPace(run) {
            parts.append(unitSystem.formatPaceString(pace))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// 日級配速。**一律是處方配速**（2026-05 使用者裁決，2026-08-26 起 App2 全面適用）：
    /// 熱調整後的值只出現在訓練詳情的熱適應卡，不得在課表／卡片上頂替處方值。
    ///
    /// 間歇課的 `primary.pace` 缺席（dev 實測只有 `climate_adjusted_pace`），
    /// 這時從處方分段推導 —— 主課段的 `work_pace`（4×400m 那天是 `4:50`）。
    /// 推不出來就回 nil（那一段不顯示），不拿熱調整值充數。
    static func dayPace(_ run: RunActivity) -> String? {
        if let pace = run.pace { return pace }
        return effectiveSegments(run)
            .first { $0.segmentKind == .interval }
            .flatMap { $0.work?.pace ?? $0.pace }
    }

    /// 間歇日的「課表」行 ＝ **主課段（含組間恢復）總距離 ＋ 該段總時間**
    /// （2026-08-26 使用者裁決；設計 dc.html「今日課表 · 間歇」的 `1.6 km · 11:00`
    /// 那一行）。不是全程距離、也不是均配。
    ///
    /// 組間恢復的段數是 `repeats - 1`（最後一趟跑完就進緩和）—— dev 實測
    /// 4×400m ＋ 200m 恢復的 `primary.distance_km` 是 `2.2`＝`1.6 + 3×0.2`，
    /// 與這個算法一致。組不出距離或時間就少那一欄，兩欄都組不出就整行不顯示。
    static func intervalContentLine(
        _ run: RunActivity,
        unitSystem: UnitSystem? = nil
    ) -> String? {
        let unitSystem = unitSystem ?? .current
        guard let segment = effectiveSegments(run).first(where: { $0.segmentKind == .interval }),
              let repeats = segment.repeats, repeats > 0,
              let work = segment.work else { return nil }
        let recoveryCount = Double(max(repeats - 1, 0))

        var parts: [String] = []
        if let workKm = effortDistanceKm(work) {
            let recoveryKm = segment.recovery.flatMap(effortDistanceKm) ?? 0
            parts.append(unitSystem.formatDistance(workKm * Double(repeats) + recoveryKm * recoveryCount))
        }
        if let workSeconds = effortSeconds(work) {
            let recoverySeconds = segment.recovery.flatMap(effortSeconds) ?? 0
            parts.append(TimeFormatting.formatTime(
                Int((workSeconds * Double(repeats) + recoverySeconds * recoveryCount).rounded())
            ))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// 一段 effort 的距離（km）。距離缺席時回 nil —— 不用時長換算，那需要配速。
    static func effortDistanceKm(_ effort: SegmentEffort) -> Double? {
        if let km = effort.distanceKm, km > 0 { return km }
        if let metres = effort.distanceM, metres > 0 { return Double(metres) / 1000 }
        return nil
    }

    /// 一段 effort 的時間（秒）。明寫的時長優先；只有距離＋配速時才換算。
    static func effortSeconds(_ effort: SegmentEffort) -> Double? {
        if let seconds = effort.durationSeconds, seconds > 0 { return Double(seconds) }
        if let minutes = effort.durationMinutes, minutes > 0 { return Double(minutes) * 60 }
        guard let km = effortDistanceKm(effort),
              let perKm = (effort.pace ?? effort.basePace).flatMap(PaceFormatterHelper.paceToSeconds)
        else { return nil }
        return km * perKm
    }

    // `4:50` → 290 秒的解析走 `PaceFormatterHelper.paceToSeconds`，
    // `m:ss`／`h:mm:ss` 走 `TimeFormatting.formatTime` —— 兩支都是 `Havital/Utils/`
    // 的既有共用出口，App2 不再各留一份（2026-08-26 收斂）。

    /// 強度徽章（設計 dc.html 今日課表卡標題列右側的方角 chip）。
    ///
    /// payload 的 `target_intensity` 優先；**缺席時退到課型**（2026-08-26 裁決：
    /// 這顆 chip 每張今日卡都要有）。退法是結構化的 `DayType` → 強度級距對照，
    /// 不是對顯示字做詞表比對；課型也判不出來才回 nil。
    static func intensityLabel(_ primary: PrimaryActivity?) -> String? {
        if case .run(let run) = primary, let raw = run.targetIntensity {
            switch raw.lowercased() {
            case "low":    return L10n.App2.Session.effortChipLow.localized
            case "medium": return L10n.App2.Session.effortChipMedium.localized
            case "high":   return L10n.App2.Session.effortChipHigh.localized
            default:       break
            }
        }
        return TrainingEffortScale.chipLabel(for: dayType(primary))
    }

    /// 溫度缺席時整格不顯示（`climate[7]` 一定有溫度，legacy `climate_meta` 可能沒有）。
    private static func temperatureLabel(_ climate: ClimateDay?) -> String? {
        guard let temp = climate?.feelsLikeTempC else { return nil }
        return String(format: "%.0f°C", temp)
    }
}
