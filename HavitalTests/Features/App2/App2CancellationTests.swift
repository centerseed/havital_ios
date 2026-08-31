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
        let vm = App2PlanOverviewViewModel(
            planRepository: repository,
            targetRepository: MockTargetRepository(),
            userProfileRepository: nil,
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
        let targetRepo = MockTargetRepository()
        targetRepo.errorToThrow = URLError(.cancelled)
        let vm = App2PlanOverviewViewModel(
            planRepository: planRepo,
            targetRepository: targetRepo,
            userProfileRepository: nil,
            readinessViewModel: nil,
            weeklyVolumesLoader: { [] }
        )

        await vm.revalidate()

        XCTAssertNil(vm.overview, "子載入被取消＝整輪作廢，不得發布殘缺 overview")
        XCTAssertFalse(vm.hasLoaded)
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
        // 離開畫面（view onDisappear → cancelRangeReload）要取消 in-flight 的
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

        vm?.cancelRangeReload()
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
}
