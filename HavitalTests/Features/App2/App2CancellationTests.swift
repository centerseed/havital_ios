//
//  App2CancellationTests.swift
//  HavitalTests
//
//  被取消的載入輪不得發布任何 UI 結果（AGENTS.md 陷阱 5；2026-08-29 外審 D04/E03）：
//  optional-load 路徑用 `try?` 把取消折成 nil，若不另外判 `Task.isCancelled`，
//  部分成功＋部分被取消會組出殘缺畫面蓋掉舊資料。
//
//  records VM 的取消行為已在 `App2RecordsViewModelTests`（URLError(.cancelled) 樣式）；
//  這裡補的是 period summary 與 metric detail 兩條 optional-load 路徑的真實 task 取消。
//

import Combine
import UserNotifications
import XCTest
@testable import paceriz_dev

@MainActor
final class App2CancellationTests: XCTestCase {

    // MARK: - Hanging fakes（掛住直到被取消，取消時 Task.sleep 自己丟 CancellationError）

    private final class HangingStatsSource: WorkoutStatsDataSourceProtocol {
        func fetchWorkoutStats(days: Int, weeks: Int?) async throws -> WorkoutStatsResponse {
            try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            throw CancellationError()
        }

        func fetchRecentWorkouts(pageSize: Int) async throws -> [WorkoutV2] {
            try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            throw CancellationError()
        }

        func fetchWorkoutsPage(pageSize: Int?, cursor: String?) async throws -> WorkoutListResponse {
            try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            throw CancellationError()
        }
    }

    private final class ImmediateStatsSource: WorkoutStatsDataSourceProtocol {
        var statsCalls = 0

        func fetchWorkoutStats(days: Int, weeks: Int?) async throws -> WorkoutStatsResponse {
            statsCalls += 1
            let json = """
            { "data": { "total_workouts": 0, "total_distance_km": 0.0,
                        "provider_distribution": {}, "activity_type_distribution": {},
                        "period_days": 30 } }
            """
            return try JSONDecoder().decode(WorkoutStatsResponse.self, from: Data(json.utf8))
        }

        func fetchRecentWorkouts(pageSize: Int) async throws -> [WorkoutV2] { [] }

        func fetchWorkoutsPage(pageSize: Int?, cursor: String?) async throws -> WorkoutListResponse {
            WorkoutListResponse(
                workouts: [],
                pagination: PaginationInfo(
                    nextCursor: nil, prevCursor: nil, hasMore: false, hasNewer: false,
                    oldestId: nil, newestId: nil, totalItems: nil, pageSize: pageSize
                )
            )
        }
    }

    private final class HangingHealthSource: HealthDailyDataSourceProtocol {
        func fetchHealthDaily(limit: Int) async throws -> HealthDailyResponse {
            try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            throw CancellationError()
        }
    }

    private final class HangingVdotSource: VDOTDataSourceProtocol {
        func getVDOTs(limit: Int) async throws -> VDOTResponse {
            try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            throw CancellationError()
        }
    }

    // MARK: - 訓練量詳情：stats 成功、health 被取消 → 不發布

    func test_volumeDetail_cancelledLoadDoesNotPublish() async {
        let vm = App2VolumeDetailViewModel(
            insight: App2Insight(id: "volume", label: "訓練量", value: nil, direction: .unknown, verdict: nil),
            narrative: nil,
            workoutDataSource: ImmediateStatsSource(),
            healthDataSource: HangingHealthSource(),
            profileRepository: nil
        )

        let load = Task { await vm.revalidate() }
        try? await Task.sleep(nanoseconds: 200_000_000)
        load.cancel()
        await load.value

        XCTAssertNil(vm.detail, "被取消的載入輪不得發布 detail")
        XCTAssertFalse(vm.isLoading, "取消後 spinner 要收掉")
    }

    // MARK: - 期間總結：全部載入被取消 → 不發布

    func test_periodSummary_cancelledLoadDoesNotPublish() async {
        let card = App2PlanEndCard(
            kind: .race, raceName: "測試賽", raceDate: "2026-12-06",
            distanceLabel: nil, totalWeeks: 2, targetTime: nil,
            estimatedFinish: nil, actualFinish: nil, narrative: nil
        )
        let vm = App2PeriodSummaryViewModel(
            card: card,
            planRepository: MockTrainingPlanV2Repository(),
            workoutDataSource: HangingStatsSource(),
            vdotDataSource: HangingVdotSource()
        )

        let load = Task { await vm.revalidate() }
        try? await Task.sleep(nanoseconds: 200_000_000)
        load.cancel()
        await load.value

        XCTAssertNil(vm.summary, "被取消的載入輪不得發布 summary")
        XCTAssertFalse(vm.isLoading, "取消後 spinner 要收掉")
    }

    // MARK: - 紀錄頁：取消不標 hasLoaded、不落半套快照

    private final class SnapshotSpy: App2SnapshotStoring {
        private(set) var saved: [App2SnapshotKey] = []
        func load<Value: Decodable>(_ type: Value.Type, for key: App2SnapshotKey) -> App2Snapshot<Value>? { nil }
        func save<Value: Encodable>(_ value: Value, for key: App2SnapshotKey) { saved.append(key) }
        func invalidate(_ keys: Set<App2SnapshotKey>) {}
        func clearAll() { saved.removeAll() }
    }

    /// stats 成功、page 掛住被取消：不得只落 stats 半套快照，也不得把這一輪標成已載
    ///（下次進頁的 SWR 要重試；2026-08-29 外審 E03）。
    private final class StatsOkPageHangsSource: WorkoutStatsDataSourceProtocol {
        func fetchWorkoutStats(days: Int, weeks: Int?) async throws -> WorkoutStatsResponse {
            let json = """
            { "data": { "total_workouts": 0, "total_distance_km": 0.0,
                        "provider_distribution": {}, "activity_type_distribution": {},
                        "period_days": 30 } }
            """
            return try JSONDecoder().decode(WorkoutStatsResponse.self, from: Data(json.utf8))
        }
        func fetchRecentWorkouts(pageSize: Int) async throws -> [WorkoutV2] { [] }
        func fetchWorkoutsPage(pageSize: Int?, cursor: String?) async throws -> WorkoutListResponse {
            try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            throw CancellationError()
        }
    }

    func test_records_cancelledPageDoesNotMarkLoadedNorPersistPartialSnapshots() async {
        let spy = SnapshotSpy()
        let vm = App2RecordsViewModel(workoutDataSource: StatsOkPageHangsSource(), snapshots: spy)

        let load = Task { await vm.revalidate() }
        try? await Task.sleep(nanoseconds: 200_000_000)
        load.cancel()
        await load.value

        XCTAssertNil(vm.records, "被取消的載入輪不得發布")
        XCTAssertFalse(vm.hasLoaded, "取消不算載過——下次進頁要重試")
        XCTAssertNil(vm.lastLoadedAt)
        XCTAssertFalse(vm.isLoading)
        XCTAssertTrue(spy.saved.isEmpty, "stats 先落、page 被收掉＝半套快照，不得發生")
    }

    // MARK: - 取消**錯誤**（-999）不設 Task.isCancelled——四個改過的 loader 逐一驗

    /// SwiftUI 收掉 refresh task 時 in-flight 請求回 `URLError(.cancelled)`，
    /// 但 `Task.isCancelled` 是 false——完成態標記必須兩種取消都擋（外審 D04/E03）。

    func test_planVM_cancellationErrorDoesNotMarkLoaded() async {
        let repository = MockTrainingPlanV2Repository()
        repository.errorToThrow = URLError(.cancelled)
        let vm = App2PlanViewModel(
            planRepository: repository,
            workoutRepository: MockWorkoutRepository(),
            targetRepository: nil
        )

        await vm.revalidate()

        XCTAssertFalse(vm.hasLoaded, "-999 取消錯誤不算載過")
        XCTAssertNil(vm.lastLoadedAt)
        XCTAssertFalse(vm.isLoading)
    }

    func test_planOverviewVM_cancellationErrorDoesNotMarkLoaded() async {
        let repository = MockTrainingPlanV2Repository()
        repository.errorToThrow = URLError(.cancelled)
        // 四個本機快取都是空的 —— 這條鎖的是「**這一輪自己的**殘缺結果不得發布」，
        // 有快取時畫面上的東西是快取放的、不是這一輪放的（T-0365）。
        repository.simulatesEmptyLocalCache = true
        let vm = App2PlanOverviewViewModel(
            planRepository: repository,
            targetRepository: MockTargetRepository(),
            userProfileRepository: MockUserProfileRepository(),   // cachedUserToReturn 預設 nil
            readinessViewModel: nil,
            weeklyVolumesLoader: { [] }
        )

        await vm.revalidate()

        XCTAssertFalse(vm.hasLoaded)
        XCTAssertNil(vm.lastLoadedAt)
        XCTAssertNil(vm.overview, "取消的那一輪不得發布殘缺 overview")
    }

    func test_raceManagementVM_cancellationErrorDoesNotMarkLoaded() async {
        let repository = MockTargetRepository()
        repository.errorToThrow = URLError(.cancelled)
        let vm = App2RaceManagementViewModel(targetRepository: repository)

        await vm.reload()

        XCTAssertFalse(vm.hasLoaded)
        XCTAssertNil(vm.errorMessage, "取消不是失敗，不得報錯")
    }

    // MARK: - 部分取消：主載成功、子載被取消 → 一樣不算載過（外審第七輪 D04/E03）

    private func makePlanStatus(
        planId: String? = "p_1",
        nextAction: String = "view_plan"
    ) -> PlanStatusV2Response {
        PlanStatusV2Response(
            currentWeek: 2, totalWeeks: 5, nextAction: nextAction,
            canGenerateNextWeek: false, currentWeekPlanId: planId,
            previousWeekSummaryId: nil, targetType: "race_run",
            methodologyId: "paceriz", nextWeekInfo: nil, metadata: nil
        )
    }

    private final class CancelledHealthSource: HealthDailyDataSourceProtocol {
        func fetchHealthDaily(limit: Int) async throws -> HealthDailyResponse {
            throw URLError(.cancelled)
        }
    }

    private final class CancelledVdotSource: VDOTDataSourceProtocol {
        func getVDOTs(limit: Int) async throws -> VDOTResponse {
            throw URLError(.cancelled)
        }
    }

    func test_planVM_cancelledWeeklyFetchAfterStatusSuccess_doesNotMarkLoaded() async {
        let repository = MockTrainingPlanV2Repository()
        repository.planStatusToReturn = makePlanStatus()
        repository.fetchWeeklyPlanErrorToThrow = URLError(.cancelled)
        let vm = App2PlanViewModel(
            planRepository: repository,
            workoutRepository: MockWorkoutRepository(),
            targetRepository: nil
        )

        await vm.revalidate()

        XCTAssertFalse(vm.hasLoaded, "plan status 成功後被取消＝部分取消，不算載過")
        XCTAssertNil(vm.lastLoadedAt)
    }

    func test_planOverviewVM_cancelledChildLoad_doesNotPublishNorMarkLoaded() async {
        let planRepo = MockTrainingPlanV2Repository()
        planRepo.planStatusToReturn = makePlanStatus()
        // 本機快取是空的 —— 這條鎖的是「**這一輪自己的**殘缺結果不得發布」，
        // 所以要把 T-0365 的快取那一畫排除在外，否則畫面上有東西是快取放的、
        // 不是這一輪放的，斷言會指錯對象。有快取那一格由下面那支鎖。
        planRepo.simulatesEmptyLocalCache = true
        let targetRepo = MockTargetRepository()
        targetRepo.errorToThrow = URLError(.cancelled)
        let vm = App2PlanOverviewViewModel(
            planRepository: planRepo,
            targetRepository: targetRepo,
            userProfileRepository: MockUserProfileRepository(),   // cachedUserToReturn 預設 nil
            readinessViewModel: nil,
            weeklyVolumesLoader: { [] }
        )

        await vm.revalidate()

        XCTAssertNil(vm.overview, "子載入被取消＝整輪作廢，不得發布殘缺 overview")
        XCTAssertFalse(vm.hasLoaded)
    }

    /// 有快取時被取消：**快取那一畫留著**（那是上一次真的看過的畫面，取消只代表
    /// 這一輪沒拿到新的），但這一輪仍然不算載過 —— 下一次進頁還要再試（T-0365）。
    func test_planOverviewVM_cancelledChildLoad_keepsCachedPaintButDoesNotMarkLoaded() async {
        let planRepo = MockTrainingPlanV2Repository()
        planRepo.planStatusToReturn = makePlanStatus()
        let targetRepo = MockTargetRepository()
        targetRepo.errorToThrow = URLError(.cancelled)
        let vm = App2PlanOverviewViewModel(
            planRepository: planRepo,
            targetRepository: targetRepo,
            userProfileRepository: MockUserProfileRepository(),
            readinessViewModel: nil,
            weeklyVolumesLoader: { [] }
        )

        await vm.revalidate()

        XCTAssertNotNil(vm.overview, "快取那一畫不因這一輪被取消而收回")
        XCTAssertFalse(vm.hasLoaded, "快取不算載過")
        XCTAssertNil(vm.lastLoadedAt)
    }

    func test_periodSummary_cancelledPartialLoad_doesNotPublishNorMarkLoaded() async {
        let card = App2PlanEndCard(
            kind: .race, raceName: "測試賽", raceDate: "2026-12-06",
            distanceLabel: nil, totalWeeks: 2, targetTime: nil,
            estimatedFinish: nil, actualFinish: nil, narrative: nil
        )
        let vm = App2PeriodSummaryViewModel(
            card: card,
            planRepository: MockTrainingPlanV2Repository(),
            workoutDataSource: ImmediateStatsSource(),
            vdotDataSource: CancelledVdotSource()
        )

        await vm.revalidate()

        XCTAssertNil(vm.summary, "stats 成功、vdots 被取消＝部分取消，不得發布")
        XCTAssertFalse(vm.hasLoaded)
    }

    func test_volumeDetail_cancelledHealthLoad_doesNotPublishNorMarkLoaded() async {
        let vm = App2VolumeDetailViewModel(
            insight: App2Insight(id: "volume", label: "訓練量", value: nil, direction: .unknown, verdict: nil),
            narrative: nil,
            workoutDataSource: ImmediateStatsSource(),
            healthDataSource: CancelledHealthSource(),
            profileRepository: nil
        )

        await vm.revalidate()

        XCTAssertNil(vm.detail, "stats 成功、health 被取消＝部分取消，不得發布")
        XCTAssertFalse(vm.hasLoaded)
    }

    func test_periodSummary_cancelledWeeklySummaries_doesNotPublishNorMarkLoaded() async {
        let card = App2PlanEndCard(
            kind: .race, raceName: "測試賽", raceDate: "2026-12-06",
            distanceLabel: nil, totalWeeks: 2, targetTime: nil,
            estimatedFinish: nil, actualFinish: nil, narrative: nil
        )
        // 逐週回顧被取消（404 折 nil 是常態，取消不是）→ 整輪作廢。
        let planRepo = MockTrainingPlanV2Repository()
        planRepo.errorToThrow = URLError(.cancelled)
        let vm = App2PeriodSummaryViewModel(
            card: card,
            planRepository: planRepo,
            workoutDataSource: ImmediateStatsSource(),
            vdotDataSource: HangingVdotSource()
        )

        let load = Task { await vm.revalidate() }
        try? await Task.sleep(nanoseconds: 200_000_000)
        load.cancel()
        await load.value

        XCTAssertNil(vm.summary)
        XCTAssertFalse(vm.hasLoaded)
    }

    func test_homeVM_cancelledChildLoad_doesNotMarkLoaded() async {
        // plan status 成功、targets 子載被取消（-999）→ 部分取消，不算載過；
        // **本機快取有主賽事也不得用它組卡發布**（取消＝整段停手）。
        let planRepo = MockTrainingPlanV2Repository()
        planRepo.planStatusToReturn = makePlanStatus(planId: nil)
        let targetRepo = MockTargetRepository()
        targetRepo.errorToThrow = URLError(.cancelled)
        targetRepo.mainTargetToReturn = makeCachedMainTarget()
        let vm = App2HomeViewModel(
            dailyStateRepository: nil,
            targetRepository: targetRepo,
            planRepository: planRepo,
            readinessViewModel: nil,
            readinessService: nil,
            workoutDataSource: ImmediateStatsSource(),
            snapshots: SnapshotSpy()
        )

        await vm.revalidate()

        XCTAssertFalse(vm.hasLoaded, "子載入被取消＝這一輪不算載過")
        XCTAssertNil(vm.lastLoadedAt)
        // 冷啟 hydrate 的預渲染是設計內的 SWR「先舊後新」，卡片可以在；
        // 但它必須停留在 hydrate 版（origin 只有 targets+status 兩端點），
        // 不得被這一輪被取消的組裝覆蓋（組裝版 origin 會多 readiness/overview）。
        XCTAssertEqual(
            vm.goalCard?.origin,
            .live(endpoint: "GET /user/targets + GET /v2/plan/status"),
            "取消後不得走完整組裝發布，只准留冷啟預渲染"
        )
    }

    func test_homeVM_overlappingRevalidates_runOneRoundAtATime() async {
        // 兩輪並發會在 await 點交錯共用取消旗標與完成標記——同一時間只准一輪。
        let planRepo = MockTrainingPlanV2Repository()
        planRepo.planStatusToReturn = makePlanStatus(planId: nil)
        let vm = App2HomeViewModel(
            dailyStateRepository: nil,
            targetRepository: MockTargetRepository(),
            planRepository: planRepo,
            readinessViewModel: nil,
            readinessService: nil,
            workoutDataSource: ImmediateStatsSource(),
            snapshots: SnapshotSpy()
        )

        async let first: Void = vm.revalidate()
        async let second: Void = vm.revalidate()
        _ = await (first, second)

        XCTAssertEqual(planRepo.getPlanStatusCallCount, 1, "後進的那一輪要直接跳過")
    }

    private final class CancelledReadinessService: TrainingReadinessProviding {
        func getReadiness(date: String, forceCalculate: Bool) async throws -> TrainingReadinessResponse {
            throw URLError(.cancelled)
        }
    }

    // MARK: - T-0387 目標卡週次的出現時機（owner path）
    //
    // 這幾個測試走 `revalidate()` 的實際載入順序，不是純投影——投影測試證明不了
    // 「週次有沒有等 readiness」。共用的 VM harness（mock repository、makePlanStatus、
    // makeCachedMainTarget）就住在這個檔案，不另外複製一份。

    /// 冷啟：本機快取一開始是空的，`getTargets()` 回來之後才有主賽事。
    private final class ColdCacheTargetRepository: MockTargetRepository {
        private var didFetch = false
        override func getTargets() async throws -> [Target] {
            let targets = try await super.getTargets()
            didFetch = true
            return targets
        }
        override func getMainTarget() async -> Target? {
            didFetch ? await super.getMainTarget() : nil
        }
    }

    /// readiness 卡在這裡直到測試放行——用來驗「週次有沒有等它」。
    private final class GatedReadinessViewModel: TrainingReadinessViewModel {
        private var resume: CheckedContinuation<Void, Never>?
        private var entered: CheckedContinuation<Void, Never>?

        /// 等 `loadData()` 真的被呼叫到（避免用 sleep 猜時序）。
        func waitUntilEntered() async {
            await withCheckedContinuation { entered = $0 }
        }

        func release() {
            resume?.resume()
            resume = nil
        }

        override func loadData() async {
            entered?.resume()
            entered = nil
            await withCheckedContinuation { resume = $0 }
        }
    }

    func test_homeVM_coldTargetCache_publishesWeekBeforeReadinessReturns() async {
        // 冷啟（快取空）時週次仍不得等 readiness。這是使用者回報的
        // 「要等很久才會自己更新，或點進訓練計畫才會更新」（2026-09-02）。
        let planRepo = MockTrainingPlanV2Repository()
        planRepo.planStatusToReturn = makePlanStatus(planId: nil)
        let targetRepo = ColdCacheTargetRepository()
        targetRepo.mainTargetToReturn = makeCachedMainTarget()
        targetRepo.targetsToReturn = [makeCachedMainTarget()]
        let readiness = GatedReadinessViewModel()
        let vm = App2HomeViewModel(
            dailyStateRepository: nil,
            targetRepository: targetRepo,
            planRepository: planRepo,
            readinessViewModel: readiness,
            readinessService: nil,
            workoutDataSource: ImmediateStatsSource(),
            snapshots: SnapshotSpy()
        )

        async let round: Void = vm.revalidate()
        await readiness.waitUntilEntered()

        XCTAssertEqual(vm.goalCard?.value.currentWeek, 2, "readiness 還沒回來，週次就該在畫面上")
        XCTAssertEqual(vm.goalCard?.value.totalWeeks, 5)

        readiness.release()
        await round

        XCTAssertEqual(targetRepo.getTargetsCallCount, 1, "同一輪只准打一次 /user/targets")
    }

    func test_homeVM_taskCancelled_doesNotPublishEarlyGoalCard() async {
        // 提前發布只讀本機快取，快取讀不會丟錯——外層 task 被取消時它照樣回值。
        // `Task.isCancelled` 是這條路上唯一看得到取消的地方（外審 D04）。
        // 用閘門把 plan status 停住，確定取消發生在提前發布之前，不靠時序運氣。
        let gate = AsyncGate()
        let planRepo = MockTrainingPlanV2Repository()
        planRepo.planStatusToReturn = makePlanStatus(planId: nil)
        planRepo.networkReadGate = { await gate.wait() }
        // 用冷快取：`hydrateFromSnapshot` 的預渲染需要本機已有主賽事，這裡沒有，
        // 所以畫面上出現的任何一張卡都只可能來自提前發布那一段。
        let targetRepo = ColdCacheTargetRepository()
        targetRepo.mainTargetToReturn = makeCachedMainTarget()
        targetRepo.targetsToReturn = [makeCachedMainTarget()]
        let vm = App2HomeViewModel(
            dailyStateRepository: nil,
            targetRepository: targetRepo,
            planRepository: planRepo,
            readinessViewModel: nil,
            readinessService: nil,
            workoutDataSource: ImmediateStatsSource(),
            snapshots: SnapshotSpy()
        )

        let round = Task { await vm.revalidate() }
        await gate.waitUntilEntered()
        round.cancel()
        await gate.open()
        await round.value

        XCTAssertNil(vm.goalCard, "被取消的那一輪不得發布目標卡")
        XCTAssertFalse(vm.hasLoaded)
    }

    func test_homeVM_cancelledPlanStatus_keepsDisplayedWeek() async {
        // plan status 這一輪被取消（-999）＝沒有新的週次可畫；已經在畫面上的那一組
        // 不得被洗成 `—`（票面 Contract 2）。
        let planRepo = MockTrainingPlanV2Repository()
        planRepo.planStatusToReturn = makePlanStatus(planId: nil)
        let targetRepo = MockTargetRepository()
        targetRepo.mainTargetToReturn = makeCachedMainTarget()
        targetRepo.targetsToReturn = [makeCachedMainTarget()]
        let vm = App2HomeViewModel(
            dailyStateRepository: nil,
            targetRepository: targetRepo,
            planRepository: planRepo,
            readinessViewModel: nil,
            readinessService: nil,
            workoutDataSource: ImmediateStatsSource(),
            snapshots: SnapshotSpy()
        )

        await vm.revalidate()
        XCTAssertEqual(vm.goalCard?.value.currentWeek, 2)

        planRepo.errorToThrow = URLError(.cancelled)
        await vm.revalidate()

        XCTAssertEqual(vm.goalCard?.value.currentWeek, 2, "取消的那一輪不得把週次清掉")
        XCTAssertEqual(vm.goalCard?.value.totalWeeks, 5)
    }

    private func makeCachedMainTarget() -> Target {
        Target(
            id: "t1", type: "race_run", name: "快取賽事", distanceKm: 21,
            targetTime: 7200, targetPace: "5:41",
            raceDate: Int(Date().addingTimeInterval(86400 * 30).timeIntervalSince1970),
            isMainRace: true, trainingWeeks: 5, raceId: nil
        )
    }

    func test_homeVM_cancelledOverview_doesNotAssembleGoalOrPlanEnd() async {
        // overview 子載被取消（-999）→ 記旗標回 nil；呼叫端不得把 nil 當「沒資料」
        // 繼續 applyPlanEnd／組卡（外審第十輪 D04/E03）。
        let planRepo = MockTrainingPlanV2Repository()
        planRepo.planStatusToReturn = makePlanStatus(planId: nil)
        planRepo.refreshOverviewErrorToThrow = URLError(.cancelled)
        let targetRepo = MockTargetRepository()
        targetRepo.mainTargetToReturn = makeCachedMainTarget()
        let vm = App2HomeViewModel(
            dailyStateRepository: nil,
            targetRepository: targetRepo,
            planRepository: planRepo,
            readinessViewModel: nil,
            readinessService: nil,
            workoutDataSource: ImmediateStatsSource(),
            snapshots: SnapshotSpy()
        )

        await vm.revalidate()

        XCTAssertFalse(vm.hasLoaded, "overview 被取消＝部分取消，不算載過")
        XCTAssertNil(vm.lastLoadedAt)
        XCTAssertNil(vm.planEnd, "取消的輪不得組結束態卡")
        XCTAssertEqual(
            vm.goalCard?.origin,
            .live(endpoint: "GET /user/targets + GET /v2/plan/status"),
            "取消後只准留冷啟預渲染，不得被該輪組裝覆蓋"
        )
    }

    func test_homeVM_cancelledRaceDayReadiness_doesNotAssemblePlanEnd() async {
        // 結束態（training_completed × race）要打賽事日 readiness；那一發被取消
        // 就整段停手，不得帶著 nil 預估組結束態卡（外審第十輪 E03）。
        let planRepo = MockTrainingPlanV2Repository()
        planRepo.planStatusToReturn = makePlanStatus(planId: nil, nextAction: "training_completed")
        let targetRepo = MockTargetRepository()
        targetRepo.mainTargetToReturn = makeCachedMainTarget()
        let vm = App2HomeViewModel(
            dailyStateRepository: nil,
            targetRepository: targetRepo,
            planRepository: planRepo,
            readinessViewModel: nil,
            readinessService: CancelledReadinessService(),
            workoutDataSource: ImmediateStatsSource(),
            snapshots: SnapshotSpy()
        )

        await vm.revalidate()

        XCTAssertFalse(vm.hasLoaded, "賽事日 readiness 被取消＝部分取消，不算載過")
        XCTAssertNil(vm.lastLoadedAt)
        XCTAssertNil(vm.planEnd, "取消的輪不得組結束態卡")
    }

    // MARK: - 指標詳情：快速切 range，後選要取消前選（外審第十輪 D04/E08）

    private final class FirstHangsThenImmediateStatsSource: WorkoutStatsDataSourceProtocol {
        private(set) var statsCalls = 0
        private(set) var firstCallWasCancelled = false

        func fetchWorkoutStats(days: Int, weeks: Int?) async throws -> WorkoutStatsResponse {
            statsCalls += 1
            if statsCalls == 1 {
                do {
                    try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                } catch {
                    firstCallWasCancelled = true
                }
                throw CancellationError()
            }
            let json = """
            { "data": { "total_workouts": 0, "total_distance_km": 0.0,
                        "provider_distribution": {}, "activity_type_distribution": {},
                        "period_days": 30 } }
            """
            return try JSONDecoder().decode(WorkoutStatsResponse.self, from: Data(json.utf8))
        }

        func fetchRecentWorkouts(pageSize: Int) async throws -> [WorkoutV2] { [] }

        func fetchWorkoutsPage(pageSize: Int?, cursor: String?) async throws -> WorkoutListResponse {
            WorkoutListResponse(
                workouts: [],
                pagination: PaginationInfo(
                    nextCursor: nil, prevCursor: nil, hasMore: false, hasNewer: false,
                    oldestId: nil, newestId: nil, totalItems: nil, pageSize: pageSize
                )
            )
        }
    }

    private final class FailingHealthSource: HealthDailyDataSourceProtocol {
        func fetchHealthDaily(limit: Int) async throws -> HealthDailyResponse {
            throw NSError(domain: "test", code: 1)
        }
    }

    func test_volumeVM_reselectRange_cancelsPreviousReload() async {
        let source = FirstHangsThenImmediateStatsSource()
        let vm = App2VolumeDetailViewModel(
            insight: App2Insight(id: "volume", label: "訓練量", value: nil, direction: .unknown, verdict: nil),
            narrative: nil,
            workoutDataSource: source,
            healthDataSource: FailingHealthSource(),
            profileRepository: nil
        )

        vm.select(range: .weeks26)
        let firstReload = vm.rangeReloadTask
        try? await Task.sleep(nanoseconds: 200_000_000)
        vm.select(range: .year)
        let secondReload = vm.rangeReloadTask

        await firstReload?.value
        await secondReload?.value

        XCTAssertTrue(source.firstCallWasCancelled, "後選必須取消前選那一發")
        XCTAssertEqual(vm.range, .year)
        XCTAssertNotNil(vm.detail, "新 range 那一輪要正常發布")
        XCTAssertTrue(vm.hasLoaded)
    }

    func test_volumeVM_teardown_cancelsInflightRangeReload_andReleasesVM() async {
        // 離開畫面（view onDisappear → cancelInFlightReload）要取消 in-flight 的
        // range 重載；task 收掉後不得再抓著 VM（外審第十一輪 D04/E08）。
        let source = FirstHangsThenImmediateStatsSource()
        var vm: App2VolumeDetailViewModel? = App2VolumeDetailViewModel(
            insight: App2Insight(id: "volume", label: "訓練量", value: nil, direction: .unknown, verdict: nil),
            narrative: nil,
            workoutDataSource: source,
            healthDataSource: FailingHealthSource(),
            profileRepository: nil
        )
        weak var weakVM = vm

        vm?.select(range: .weeks26)
        let reload = vm?.rangeReloadTask
        try? await Task.sleep(nanoseconds: 200_000_000)

        vm?.cancelInFlightReload()
        vm = nil
        await reload?.value

        XCTAssertTrue(source.firstCallWasCancelled, "teardown 必須取消 in-flight 的 range 重載")
        XCTAssertNil(weakVM, "重載 task 收掉後 VM 要能釋放，不得被 task 抓著")
    }

    func test_homeVM_cancelledPlanStatusDoesNotMarkLoaded() async {
        let repository = MockTrainingPlanV2Repository()
        repository.errorToThrow = URLError(.cancelled)
        let vm = App2HomeViewModel(
            dailyStateRepository: nil,
            targetRepository: MockTargetRepository(),
            planRepository: repository,
            readinessViewModel: nil,
            readinessService: nil,
            workoutDataSource: ImmediateStatsSource(),
            snapshots: SnapshotSpy()
        )

        await vm.revalidate()

        XCTAssertFalse(vm.hasLoaded, "plan status 被取消＝這一輪不算載過")
        XCTAssertNil(vm.lastLoadedAt)
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - 重驗鎖讓位（T-0355；缺陷原型：2026-08-31 prod log——推播已到、
    // 18:47–19:07 App 對後端零請求，一輪卡死讓之後每次下拉都靜默 no-op）

    func test_stuckRevalidate_pastThreshold_yieldsToNewRound() {
        let began = Date(timeIntervalSinceNow: -(App2RevalidatePolicy.stuckThreshold + 1))
        XCTAssertFalse(
            App2RevalidatePolicy.shouldBlock(isRevalidating: true, began: began),
            "前一輪卡超過門檻時必須讓位——下拉刷新要真正打出網路"
        )
    }

    func test_stuckRevalidate_freshInFlightRound_stillBlocks() {
        let began = Date(timeIntervalSinceNow: -5)
        XCTAssertTrue(
            App2RevalidatePolicy.shouldBlock(isRevalidating: true, began: began),
            "門檻內的重入仍要被互斥擋掉（SWR 防抖不變）"
        )
    }

    func test_stuckRevalidate_notRevalidating_runs() {
        XCTAssertFalse(App2RevalidatePolicy.shouldBlock(isRevalidating: false, began: nil))
    }

    func test_stuckRevalidate_inFlightWithoutTimestamp_blocks() {
        XCTAssertTrue(
            App2RevalidatePolicy.shouldBlock(isRevalidating: true, began: nil),
            "沒有起點時戳就無法判卡死，保守維持互斥"
        )
    }

    // MARK: - 推播觸發失效（T-0355）

    func test_workoutProcessedPush_emitsInvalidation() {
        let manager = WorkoutBackgroundManager.shared
        var received = 0
        let cancellable = manager.workoutPushReceived.sink { received += 1 }
        defer { cancellable.cancel() }

        manager.emitWorkoutPushIfNeeded(["type": "workout_processed"])

        XCTAssertEqual(received, 1, "workout_processed 推播必須發出失效事件")
    }

    func test_otherPushTypes_doNotEmitInvalidation() {
        let manager = WorkoutBackgroundManager.shared
        var received = 0
        let cancellable = manager.workoutPushReceived.sink { received += 1 }
        defer { cancellable.cancel() }

        manager.emitWorkoutPushIfNeeded(["type": "weekly_review_ready"])
        manager.emitWorkoutPushIfNeeded([:])

        XCTAssertEqual(received, 0, "非 workout_processed 推播不得觸發 workouts 失效")
    }

    // `UNNotification`／`UNNotificationResponse` 無公開 initializer，delegate 方法
    // 本體只做拆封；這裡測的 handle* 就是 delegate 的全部邏輯（外審第三輪 E03）。

    func test_willPresentHandler_workoutProcessed_emitsOnceThenCompletes() {
        let manager = WorkoutBackgroundManager.shared
        var received = 0
        let cancellable = manager.workoutPushReceived.sink { received += 1 }
        defer { cancellable.cancel() }

        var receivedAtCompletion = -1
        var options: UNNotificationPresentationOptions?
        manager.handleWillPresent(userInfo: ["type": "workout_processed"]) { opts in
            receivedAtCompletion = received
            options = opts
        }

        XCTAssertEqual(received, 1, "前景推播恰發一次失效事件")
        XCTAssertEqual(receivedAtCompletion, 1, "失效事件必須在 completion 之前發出（先失效再顯示）")
        XCTAssertEqual(options, [.banner, .sound, .list], "通知照常顯示，不因失效邏輯被吞")
    }

    func test_willPresentHandler_otherType_stillCompletesWithoutEmit() {
        let manager = WorkoutBackgroundManager.shared
        var received = 0
        let cancellable = manager.workoutPushReceived.sink { received += 1 }
        defer { cancellable.cancel() }

        var completed = false
        manager.handleWillPresent(userInfo: ["type": "weekly_review_ready"]) { _ in completed = true }

        XCTAssertEqual(received, 0)
        XCTAssertTrue(completed, "過濾掉的推播仍必須回 completion，否則系統不顯示通知")
    }

    func test_didReceiveHandler_workoutProcessed_emitsOnceThenCompletes() {
        let manager = WorkoutBackgroundManager.shared
        var received = 0
        let cancellable = manager.workoutPushReceived.sink { received += 1 }
        defer { cancellable.cancel() }

        var receivedAtCompletion = -1
        manager.handleDidReceive(userInfo: ["type": "workout_processed"]) {
            receivedAtCompletion = received
        }

        XCTAssertEqual(received, 1, "點擊推播恰發一次失效事件")
        XCTAssertEqual(receivedAtCompletion, 1, "失效事件必須在 completion 之前發出")
    }

    func test_didReceiveHandler_otherType_stillCompletesWithoutEmit() {
        let manager = WorkoutBackgroundManager.shared
        var received = 0
        let cancellable = manager.workoutPushReceived.sink { received += 1 }
        defer { cancellable.cancel() }

        var completed = false
        manager.handleDidReceive(userInfo: [:]) { completed = true }

        XCTAssertEqual(received, 0)
        XCTAssertTrue(completed, "點擊路徑無論型別都必須回 completion")
    }

    // MARK: - 重驗鎖 owner path（T-0359 外審 E02/E05/D04）：
    // 真 VM＋可控卡住的載入，斷言網路輪數而不是純函式回傳值。

    private final class LoaderGate {
        var entered = 0
        var continuations: [CheckedContinuation<Void, Never>] = []
        private var released = 0

        func releaseNext() {
            guard released < continuations.count else { return }
            continuations[released].resume()
            released += 1
        }

        /// 收尾保險：任何模式（含 body-swap RED）下都不留懸掛的輪。
        func releaseAll() {
            while released < continuations.count { releaseNext() }
        }
    }

    func test_stuckRevalidate_ownerPath_takeoverAndLockOwnership() async {
        let repository = MockTrainingPlanV2Repository()
        let gate = LoaderGate()
        let vm = App2PlanOverviewViewModel(
            planRepository: repository,
            targetRepository: MockTargetRepository(),
            userProfileRepository: MockUserProfileRepository(),
            weeklyVolumesLoader: {
                await MainActor.run { gate.entered += 1 }
                await withCheckedContinuation { gate.continuations.append($0) }
                return []
            }
        )

        // 輪 A 卡在載入中（鎖被持有）。
        let roundA = Task { await vm.revalidate() }
        for _ in 0..<50 where gate.entered < 1 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertEqual(gate.entered, 1)

        // 門檻內重入：被互斥擋掉，不打第二輪（缺陷原型的防抖行為保留）。
        await vm.revalidate()
        XCTAssertEqual(gate.entered, 1, "門檻內重入不得打出新輪")

        // 卡超過門檻（seam 回撥起點）：下拉刷新必須真正接管開新輪。
        // 缺陷原型（2026-08-31 prod log）：舊 `guard !isRevalidating` 在這裡
        // 永遠 return，18:47–19:07 對後端零請求。
        vm.backdateRevalidateBeganForTesting(by: 31)
        let roundB = Task { await vm.revalidate() }
        for _ in 0..<50 where gate.entered < 2 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertEqual(gate.entered, 2, "卡死輪必須讓位，新輪要真正打出載入")

        // D04：卡死輪 A 結束時不得放掉輪 B 的鎖——第三次門檻內重入仍被擋。
        // 第三輪包 Task＋短輪詢（不 await 到底），body-swap RED 模式下才不會
        // 因為輪 C 真的開跑、卡在 gate 而讓整個測試懸掛。
        gate.releaseNext()
        await roundA.value
        let roundC = Task { await vm.revalidate() }
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(gate.entered, 2, "被接管的舊輪結束不得放掉新輪的鎖")

        gate.releaseAll()
        await roundB.value
        // body-swap RED 模式下輪 C 可能真的開跑：等它掛上 continuation 再放行，
        // 任何模式都不留懸掛。
        for _ in 0..<50 where gate.entered > gate.continuations.count {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        gate.releaseAll()
        await roundC.value
        XCTAssertEqual(gate.entered, 2)
    }

    func test_staleRoundCompletion_doesNotClearNewRoundLoadingState() async {
        // 外審第三輪 D04：首載輪 A 卡死被接管後才完成，其收尾不得清掉
        // 現任輪 B 的 isLoading——否則首載 spinner 消失、畫面停在空狀態。
        let repository = MockTrainingPlanV2Repository()
        let gate = LoaderGate()
        let vm = App2PlanOverviewViewModel(
            planRepository: repository,
            targetRepository: MockTargetRepository(),
            userProfileRepository: MockUserProfileRepository(),
            weeklyVolumesLoader: {
                await MainActor.run { gate.entered += 1 }
                await withCheckedContinuation { gate.continuations.append($0) }
                return []
            }
        )

        let roundA = Task { await vm.revalidate() }
        for _ in 0..<50 where gate.entered < 1 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertTrue(vm.isLoading, "首載中")

        vm.backdateRevalidateBeganForTesting(by: 31)
        let roundB = Task { await vm.revalidate() }
        for _ in 0..<50 where gate.entered < 2 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertEqual(gate.entered, 2)

        // 放行舊輪 A 讓它跑完收尾——現任輪 B 仍在載入，spinner 必須還在。
        gate.releaseNext()
        await roundA.value
        XCTAssertTrue(vm.isLoading, "被接管的舊輪收尾不得清掉現任輪的 loading 態")

        gate.releaseAll()
        await roundB.value
        XCTAssertFalse(vm.isLoading, "現任輪自己收尾")
    }

    // MARK: - 推播 → coordinator → bus → 消費端 owner path（T-0359 外審 E03/E11）

    func test_workoutPush_chainReachesRecordsRefetch() async {
        // 鏈路的佈線端顯式建立，不依賴 test host 先前的初始化順序（外審 E05）；
        // registerAll 冪等，app 已註冊時是 no-op。
        CacheRegistrationCoordinator.registerAll()

        let source = ImmediateStatsSource()
        // 最後建立的 Records VM 持有 bus identifier（同 production 常駐實例語意）。
        let vm = App2RecordsViewModel(workoutDataSource: source)
        await vm.revalidate()
        let callsBefore = source.statsCalls

        // 從推播 seam 出發走真實鏈路：emit → CacheRegistrationCoordinator 轉發
        // `.dataChanged(.workouts)` → Records VM 訂閱 → revalidate 重打網路。
        // （`UNNotification`／`UNNotificationResponse` 無公開建構式，delegate
        // 方法本體只做拆封；其邏輯由上面的 handleWillPresent/handleDidReceive
        // 測試覆蓋，這裡從 seam 入口驗佈線。）
        WorkoutBackgroundManager.shared.emitWorkoutPushIfNeeded(["type": "workout_processed"])

        for _ in 0..<50 where source.statsCalls == callsBefore {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertEqual(source.statsCalls, callsBefore + 1,
                       "一次 workout_processed 推播＝恰好一次重打網路（不是只清快取，也不重複打）")

        // 第二發推播（例如前景顯示＋點擊各觸發一次 emit）→ 再恰好一次。
        WorkoutBackgroundManager.shared.emitWorkoutPushIfNeeded(["type": "workout_processed"])
        for _ in 0..<50 where source.statsCalls == callsBefore + 1 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertEqual(source.statsCalls, callsBefore + 2, "每次 emit 恰好一次重驗，順序不亂")
    }
}
