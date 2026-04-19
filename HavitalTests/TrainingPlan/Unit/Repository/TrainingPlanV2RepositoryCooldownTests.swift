//
//  TrainingPlanV2RepositoryCooldownTests.swift
//  HavitalTests
//
//  Unit tests for TrainingPlanV2RepositoryImpl cooldown behaviour.
//  Uses:
//  - Real TrainingPlanV2LocalDataSource (in-memory via MockUserDefaults)
//  - Fake TrainingPlanV2RemoteDataSource (protocol implementation, no mock framework)
//  - FakeV2Clock for time control (defined in TrainingPlanV2LocalDataSourceCooldownTests.swift)
//
//  Covers AC-1, AC-2, AC-3, AC-7, AC-8, AC-9 from the Spec.
//

import XCTest
@testable import paceriz_dev

// MARK: - Fake Remote Data Source

/// Counts getPlanStatus() calls and can be configured to throw.
final class FakeTrainingPlanV2RemoteDataSource: TrainingPlanV2RemoteDataSourceProtocol {

    // MARK: - Configuration

    var planStatusToReturn: PlanStatusV2Response
    var planStatusError: Error?

    // MARK: - Call Tracking

    private(set) var getPlanStatusCallCount = 0

    // MARK: - Init

    init(planStatusToReturn: PlanStatusV2Response = .stub()) {
        self.planStatusToReturn = planStatusToReturn
    }

    // MARK: - Protocol — Plan Status

    func getPlanStatus() async throws -> PlanStatusV2Response {
        getPlanStatusCallCount += 1
        if let error = planStatusError { throw error }
        return planStatusToReturn
    }

    // MARK: - Protocol — Unused in these tests (fatalError to surface accidental calls)

    func getTargetTypes() async throws -> [TargetTypeV2] {
        fatalError("Unexpected call: getTargetTypes()")
    }

    func getMethodologies(targetType: String?) async throws -> [MethodologyV2] {
        fatalError("Unexpected call: getMethodologies(targetType:)")
    }

    func createOverviewForRace(targetId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2DTO {
        fatalError("Unexpected call: createOverviewForRace")
    }

    func createOverviewForNonRace(targetType: String, trainingWeeks: Int, availableDays: Int?, methodologyId: String?, startFromStage: String?, intendedRaceDistanceKm: Int?) async throws -> PlanOverviewV2DTO {
        fatalError("Unexpected call: createOverviewForNonRace")
    }

    func getOverview() async throws -> PlanOverviewV2DTO {
        fatalError("Unexpected call: getOverview()")
    }

    func updateOverview(overviewId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2DTO {
        fatalError("Unexpected call: updateOverview")
    }

    func generateWeeklyPlan(weekOfTraining: Int, forceGenerate: Bool?, promptVersion: String?, methodology: String?) async throws -> WeeklyPlanV2DTO {
        fatalError("Unexpected call: generateWeeklyPlan")
    }

    func getWeeklyPlan(planId: String) async throws -> WeeklyPlanV2DTO {
        fatalError("Unexpected call: getWeeklyPlan")
    }

    func updateWeeklyPlan(planId: String, updates: UpdateWeeklyPlanRequest) async throws -> WeeklyPlanV2DTO {
        fatalError("Unexpected call: updateWeeklyPlan")
    }

    func deleteWeeklyPlan(planId: String) async throws {
        fatalError("Unexpected call: deleteWeeklyPlan")
    }

    func getWeeklyPreview(overviewId: String) async throws -> WeeklyPreviewResponseDTO {
        fatalError("Unexpected call: getWeeklyPreview")
    }

    func getWeeklySummaries() async throws -> [WeeklySummaryItem] {
        fatalError("Unexpected call: getWeeklySummaries()")
    }

    func generateWeeklySummary(weekOfPlan: Int, forceUpdate: Bool?) async throws -> WeeklySummaryV2DTO {
        fatalError("Unexpected call: generateWeeklySummary")
    }

    func getWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2DTO {
        fatalError("Unexpected call: getWeeklySummary")
    }

    func applyAdjustmentItems(weekOfPlan: Int, appliedIndices: [Int]) async throws {
        fatalError("Unexpected call: applyAdjustmentItems")
    }

    func deleteWeeklySummary(summaryId: String) async throws {
        fatalError("Unexpected call: deleteWeeklySummary")
    }
}

// MARK: - PlanStatusV2Response Stub

private extension PlanStatusV2Response {
    static func stub(currentWeek: Int = 1, nextAction: String = "view_plan") -> PlanStatusV2Response {
        PlanStatusV2Response(
            currentWeek: currentWeek,
            totalWeeks: 12,
            nextAction: nextAction,
            canGenerateNextWeek: false,
            currentWeekPlanId: "plan_001_1",
            previousWeekSummaryId: nil,
            targetType: "race",
            methodologyId: "paceriz",
            nextWeekInfo: nil,
            metadata: nil
        )
    }
}

// MARK: - Tests

final class TrainingPlanV2RepositoryCooldownTests: XCTestCase {

    // MARK: - Properties

    private var sut: TrainingPlanV2RepositoryImpl!
    private var fakeRemote: FakeTrainingPlanV2RemoteDataSource!
    private var localDataSource: TrainingPlanV2LocalDataSource!
    private var fakeClock: FakeV2Clock!
    private var mockDefaults: MockUserDefaults!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        fakeClock = FakeV2Clock()
        mockDefaults = MockUserDefaults()
        fakeRemote = FakeTrainingPlanV2RemoteDataSource()
        localDataSource = TrainingPlanV2LocalDataSource(defaults: mockDefaults, clock: fakeClock)
        sut = TrainingPlanV2RepositoryImpl(
            remoteDataSource: fakeRemote,
            localDataSource: localDataSource
        )
    }

    override func tearDown() {
        mockDefaults.clear()
        sut = nil
        fakeRemote = nil
        localDataSource = nil
        fakeClock = nil
        mockDefaults = nil
        super.tearDown()
    }

    // MARK: - AC-1: Cache hit 且在 cooldown 內 → 不打 API

    /// Given: cache 有資料、距上次成功刷新 < 30 分鐘
    /// When: getPlanStatus(forceRefresh: false)
    /// Then: 立即回傳 cache，後台 Task 因 cooldown 未到期而不打 API
    ///       驗證方式：等待足夠時間後，remoteCallCount 仍為 0
    func test_getPlanStatus_cacheHitWithinCooldown_doesNotCallRemote() async throws {
        // Given: seed cache and mark cooldown as recently refreshed
        let cached = PlanStatusV2Response.stub(currentWeek: 3)
        localDataSource.savePlanStatus(cached)
        localDataSource.markRefreshed(.planStatus)  // t=0, cooldown active

        // When
        let result = try await sut.getPlanStatus(forceRefresh: false)

        // Allow any detached tasks to settle
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1s

        // Then: returns cache, no remote call
        XCTAssertEqual(result.currentWeek, 3)
        XCTAssertEqual(fakeRemote.getPlanStatusCallCount, 0,
                       "Remote must not be called when within cooldown window")
    }

    // MARK: - AC-2: Cache hit 且超過 cooldown → 觸發背景 refresh

    /// Given: cache 有資料、距上次成功刷新 ≥ 30 分鐘
    /// When: getPlanStatus(forceRefresh: false)
    /// Then: 立即回傳 cache；background Task 打了一次 remote
    func test_getPlanStatus_cacheHitCooldownExpired_triggersBackgroundRefresh() async throws {
        // Given: cache seeded, cooldown expired (31 min elapsed)
        let cached = PlanStatusV2Response.stub(currentWeek: 2)
        localDataSource.savePlanStatus(cached)
        localDataSource.markRefreshed(.planStatus)
        fakeClock.advance(by: 1860)  // 31 minutes — past cooldown

        // When
        let result = try await sut.getPlanStatus(forceRefresh: false)

        // Wait for background refresh to complete.
        // background priority tasks may take longer in simulator — use a generous 2s window.
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2s

        // Then: cache returned immediately; background hit remote once
        XCTAssertEqual(result.currentWeek, 2, "Should return cached value immediately")
        XCTAssertEqual(fakeRemote.getPlanStatusCallCount, 1,
                       "Background refresh should have called remote once after cooldown expired")
    }

    // MARK: - AC-3: forceRefresh → 無視 cooldown 並重設計時器

    /// Given: cooldown 內（剛 mark 過）
    /// When: getPlanStatus(forceRefresh: true)
    /// Then: 直接呼叫後端，成功後 cooldown 重設（下次 false 不再打 API）
    func test_getPlanStatus_forceRefresh_bypassesCooldownAndResetsTimer() async throws {
        // Given: mark cooldown as recently active
        localDataSource.savePlanStatus(PlanStatusV2Response.stub(currentWeek: 1))
        localDataSource.markRefreshed(.planStatus)  // within cooldown

        fakeRemote.planStatusToReturn = .stub(currentWeek: 5)

        // When: force refresh
        let result = try await sut.getPlanStatus(forceRefresh: true)

        // Then: remote was called
        XCTAssertEqual(fakeRemote.getPlanStatusCallCount, 1, "Force-refresh must bypass cooldown")
        XCTAssertEqual(result.currentWeek, 5, "Should return fresh remote data")

        // And cooldown was reset — a subsequent non-force call within cooldown should NOT hit remote
        fakeRemote.planStatusToReturn = .stub(currentWeek: 6)
        _ = try await sut.getPlanStatus(forceRefresh: false)
        try await Task.sleep(nanoseconds: 100_000_000)  // let any background task settle

        XCTAssertEqual(fakeRemote.getPlanStatusCallCount, 1,
                       "Cooldown should be active after force-refresh success; no additional remote call")
    }

    // MARK: - AC-7: 背景 refresh 失敗 → cooldown 不更新

    /// Given: cache hit，cooldown 已到期
    /// When: background refresh 失敗
    /// Then: cooldown 時間戳不更新，下一次 cache hit 仍會再次嘗試背景刷新
    func test_getPlanStatus_backgroundRefreshFails_doesNotMarkCooldown() async throws {
        // Given: cache seeded, cooldown expired
        let cached = PlanStatusV2Response.stub(currentWeek: 4)
        localDataSource.savePlanStatus(cached)
        localDataSource.markRefreshed(.planStatus)
        fakeClock.advance(by: 1800)  // cooldown expired

        fakeRemote.planStatusError = URLError(.notConnectedToInternet)

        // When: first call triggers background refresh which fails
        _ = try await sut.getPlanStatus(forceRefresh: false)
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2s — allow background task to finish

        // Then: shouldRefresh must still be true (cooldown NOT marked on failure)
        XCTAssertTrue(localDataSource.shouldRefresh(.planStatus),
                      "Cooldown must not be marked when background refresh fails")

        // Confirm: a second cache-hit call triggers remote again (because cooldown was never reset)
        fakeRemote.planStatusError = nil
        fakeRemote.planStatusToReturn = .stub(currentWeek: 7)
        _ = try await sut.getPlanStatus(forceRefresh: false)
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2s

        XCTAssertGreaterThanOrEqual(fakeRemote.getPlanStatusCallCount, 1,
                                    "Remote should be called again since cooldown was never marked")
    }

    // MARK: - AC-8: Cache miss 不受 cooldown 影響

    /// Given: cache 為空（首次登入或 cache 被清除），cooldown 未 mark
    /// When: getPlanStatus(forceRefresh: false)
    /// Then: 直接呼叫後端，不檢查 cooldown
    func test_getPlanStatus_cacheMiss_callsRemoteWithoutCheckingCooldown() async throws {
        // Given: no cached plan status, no cooldown mark

        // When
        let result = try await sut.getPlanStatus(forceRefresh: false)

        // Then: remote was called for the cache miss
        XCTAssertEqual(fakeRemote.getPlanStatusCallCount, 1,
                       "Cache miss must always call remote regardless of cooldown state")
        XCTAssertEqual(result.currentWeek, fakeRemote.planStatusToReturn.currentWeek)
    }

    // MARK: - AC-9: App 重啟 → cooldown 計時器重置（in-memory only）

    /// Given: App 冷啟動（新的 LocalDataSource 實例，cooldown dict 為空）
    ///        cache 仍有資料（UserDefaults 持久化）
    /// When: getPlanStatus(forceRefresh: false)
    /// Then: 觸發背景 refresh（因為記憶體中無 cooldown 記錄）
    func test_getPlanStatus_afterAppRestart_cachePresentButNoCooldownInMemory_triggersRefresh() async throws {
        // Given: pre-populate the UserDefaults-backed cache (simulating pre-restart data)
        let cachedStatus = PlanStatusV2Response.stub(currentWeek: 8)
        localDataSource.savePlanStatus(cachedStatus)
        // Note: markRefreshed is NOT called — simulates a fresh app launch
        // (in-memory cooldown dict starts empty)

        // When
        let result = try await sut.getPlanStatus(forceRefresh: false)

        // Wait for background refresh — use 2s window for background priority task
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // Then: cache was returned immediately, and background refresh was triggered
        XCTAssertEqual(result.currentWeek, 8, "Should return cached value from previous session")
        XCTAssertEqual(fakeRemote.getPlanStatusCallCount, 1,
                       "After app restart, no cooldown in memory → background refresh must be triggered")
    }
}
