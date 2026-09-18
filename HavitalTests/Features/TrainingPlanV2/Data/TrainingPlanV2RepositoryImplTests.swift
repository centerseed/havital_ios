import XCTest
@testable import paceriz_dev

// MARK: - TrainingPlanV2RepositoryImplTests
//
// Tests TrainingPlanV2RepositoryImpl caching strategies:
// - Track A: immediate cache return on cache hit
// - Track B: background refresh scheduling on cache hit (cooldown expired)
// - Cache miss: fetches from API and saves result
// - Force refresh: bypasses cache entirely
//
// Uses:
// - SpyTrainingPlanV2RemoteDataSource (tracks calls, returns fixtures)
// - SpyTrainingPlanV2LocalDataSource (in-memory storage, tracks calls)

final class TrainingPlanV2RepositoryImplTests: XCTestCase {

    // MARK: - Properties

    private var sut: TrainingPlanV2RepositoryImpl!
    private var spyRemote: SpyTrainingPlanV2RemoteDataSource!
    private var spyLocal: SpyTrainingPlanV2LocalDataSource!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        spyRemote = SpyTrainingPlanV2RemoteDataSource()
        spyLocal = SpyTrainingPlanV2LocalDataSource()
        sut = TrainingPlanV2RepositoryImpl(
            remoteDataSource: spyRemote,
            localDataSource: spyLocal
        )
    }

    override func tearDown() {
        sut = nil
        spyRemote = nil
        spyLocal = nil
        super.tearDown()
    }

    // MARK: - getPlanStatus Tests

    /// Track A: cache present, not expired → returns immediately without remote call.
    /// Track B: shouldRefresh returns false (cooldown not expired) → no background call.
    func test_getPlanStatus_cacheHit_returnsCachedAndDoesNotCallRemote() async throws {
        // Given
        let cached = PlanStatusV2Response.stubForRepo(currentWeek: 2)
        spyLocal.cachedPlanStatus = cached
        spyLocal.planStatusExpired = false
        spyLocal.shouldRefreshResult = false

        // When
        let result = try await sut.getPlanStatus(forceRefresh: false)
        // Allow any detached background tasks to settle
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(result.currentWeek, 2, "Should return cached value")
        XCTAssertEqual(spyRemote.getPlanStatusCallCount, 0, "Remote must not be called when within cooldown")
    }

    /// Track B: cache present, shouldRefresh returns true → remote called in background.
    func test_getPlanStatus_cacheHit_cooldownExpired_schedulesBackgroundRefresh() async throws {
        // Given
        let cached = PlanStatusV2Response.stubForRepo(currentWeek: 5)
        spyLocal.cachedPlanStatus = cached
        spyLocal.planStatusExpired = false
        spyLocal.shouldRefreshResult = true
        spyRemote.planStatusToReturn = PlanStatusV2Response.stubForRepo(currentWeek: 6)

        // When
        let result = try await sut.getPlanStatus(forceRefresh: false)
        // Wait for background task
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Then
        XCTAssertEqual(result.currentWeek, 5, "Track A: should return cached value immediately")
        XCTAssertGreaterThanOrEqual(spyRemote.getPlanStatusCallCount, 1, "Track B: background refresh should hit remote")
    }

    func test_getPlanStatus_cacheMiss_fetchesFromAPI() async throws {
        // Given: no cached value
        spyLocal.cachedPlanStatus = nil
        spyRemote.planStatusToReturn = PlanStatusV2Response.stubForRepo(currentWeek: 1)

        // When
        let result = try await sut.getPlanStatus(forceRefresh: false)

        // Then
        XCTAssertEqual(result.currentWeek, 1)
        XCTAssertEqual(spyRemote.getPlanStatusCallCount, 1, "Cache miss must call remote")
        XCTAssertNotNil(spyLocal.savedPlanStatus, "Result must be saved to cache")
    }

    func test_getPlanStatus_forceRefresh_bypassesCache() async throws {
        // Given: cache has stale value
        spyLocal.cachedPlanStatus = PlanStatusV2Response.stubForRepo(currentWeek: 1)
        spyRemote.planStatusToReturn = PlanStatusV2Response.stubForRepo(currentWeek: 9)

        // When
        let result = try await sut.getPlanStatus(forceRefresh: true)

        // Then
        XCTAssertEqual(result.currentWeek, 9, "Force refresh should return fresh remote data")
        XCTAssertEqual(spyRemote.getPlanStatusCallCount, 1, "Force refresh must call remote regardless of cache")
    }

    // MARK: - getOverview Tests

    func test_getOverview_success_savesToCache() async throws {
        // Given: no cached overview
        spyLocal.cachedOverview = nil
        spyRemote.overviewDTOToReturn = .stubForRepo()

        // When
        let result = try await sut.getOverview()

        // Then
        XCTAssertEqual(result.id, "overview_001")
        XCTAssertNotNil(spyLocal.savedOverview, "Overview should be saved to cache after fetch")
        XCTAssertEqual(spyLocal.savedOverview?.id, "overview_001")
    }

    func test_getOverview_cacheHit_doesNotCallRemote() async throws {
        // Given
        spyLocal.cachedOverview = .stubForRepo()

        // When
        let result = try await sut.getOverview()

        // Then
        XCTAssertEqual(result.id, "overview_001")
        XCTAssertEqual(spyRemote.getOverviewCallCount, 0, "Cache hit should not call remote")
    }

    // MARK: - getWeeklyPlan Tests

    func test_getWeeklyPlan_notFound_propagatesError() async {
        // Given
        spyLocal.cachedWeeklyPlan = nil
        spyRemote.weeklyPlanError = HTTPError.notFound("Weekly plan not found")

        // When / Then
        do {
            _ = try await sut.getWeeklyPlan(weekOfTraining: 3, overviewId: "overview_001")
            XCTFail("Should have thrown an error")
        } catch {
            // DomainError conversion happens inside the repo, so just check error was thrown
            XCTAssertNotNil(error)
        }
    }

    // MARK: - A.5 diagnostic reporting classification

    func test_A5_designedEmptyStateCodes_doNotReport() {
        let codes = [
            "no_active_training_plan",
            "training_plan_not_found",
            "weekly_plan_not_found",
            "weekly_summary_not_found",
            "weekly_preview_not_found",
            "weekly_adjustment_items_not_found"
        ]

        for code in codes {
            XCTAssertFalse(
                TrainingPlanV2RepositoryImpl.shouldReportCloudError(
                    HTTPError.notFound(Self.errorEnvelope(code: code))
                ),
                "Designed empty state (code) must not be reported"
            )
        }
    }

    func test_A5_unknownOrCorruptedCodes_areReported() {
        XCTAssertTrue(
            TrainingPlanV2RepositoryImpl.shouldReportCloudError(
                HTTPError.notFound(Self.errorEnvelope(code: "weekly_plan_corrupted"))
            )
        )
        XCTAssertTrue(
            TrainingPlanV2RepositoryImpl.shouldReportCloudError(
                HTTPError.notFound("")
            )
        )
    }

    func test_A5_planAndStatusNotFound_preserveBackendCodeForCaller() async {
        let code = "training_plan_not_found"
        spyRemote.overviewError = HTTPError.notFound(Self.errorEnvelope(code: code))
        spyRemote.planStatusError = HTTPError.notFound(Self.errorEnvelope(code: code))

        do {
            _ = try await sut.getOverview()
            XCTFail("Overview 404 should remain a failure")
        } catch let error as DomainError {
            guard case .notFound(let message) = error else {
                return XCTFail("Expected DomainError.notFound, got \(error)")
            }
            XCTAssertTrue(message.contains(code))
        } catch {
            XCTFail("Expected DomainError, got \(error)")
        }

        do {
            _ = try await sut.getPlanStatus(forceRefresh: true)
            XCTFail("Plan status 404 should remain a failure")
        } catch let error as DomainError {
            guard case .notFound(let message) = error else {
                return XCTFail("Expected DomainError.notFound, got \(error)")
            }
            XCTAssertTrue(message.contains(code))
        } catch {
            XCTFail("Expected DomainError, got \(error)")
        }
    }

    private static func errorEnvelope(code: String) -> String {
        "{\"success\":false,\"error\":\"\(code)\"}"
    }

    // MARK: - generateWeeklyPlan Tests

    func test_generateWeeklyPlan_success_savesAndInvalidatesCache() async throws {
        // Given
        spyRemote.weeklyPlanDTOToReturn = .stubForRepo(weekOfTraining: 4)

        // When
        let result = try await sut.generateWeeklyPlan(
            weekOfTraining: 4,
            forceGenerate: nil,
            promptVersion: nil,
            methodology: nil
        )

        // Then
        XCTAssertEqual(result.effectiveWeek, 4)
        XCTAssertNotNil(spyLocal.savedWeeklyPlan, "Generated plan must be saved to cache")
    }

    func test_generateWeeklyPlan_networkError_throwsDomainError() async {
        // Given
        spyRemote.weeklyPlanError = HTTPError.serverError(500, "Generation failed")

        // When / Then
        do {
            _ = try await sut.generateWeeklyPlan(
                weekOfTraining: 2,
                forceGenerate: nil,
                promptVersion: nil,
                methodology: nil
            )
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - clearCache Tests

    func test_clearCache_clearsAllLayers() async {
        // Given
        spyLocal.cachedPlanStatus = PlanStatusV2Response.stubForRepo()
        spyLocal.cachedOverview = PlanOverviewV2.stubForRepo()

        // When
        await sut.clearCache()

        // Then
        XCTAssertEqual(spyLocal.clearAllCallCount, 1, "clearAll() must be called on local data source")
    }

    // MARK: - fetchWeeklySummary（T-0362：唯讀契約）
    //
    // `getWeeklySummary` 在 404 時 fallback 到 `POST`
    // （`fetchOrGenerateWeeklySummary`），所以「讀」會變成「寫」：週回顧頁光是打開
    // 就送出生成請求，整期總結逐週掃還會把每個沒生成的週都補生成一份。
    // `fetchWeeklySummary` 是那條路的唯讀版本。**這幾支直接打 `TrainingPlanV2RepositoryImpl`**
    // ——上層 VM 測試用的是 mock repository，看不到這裡的具體行為（外審第二輪 E05）。

    /// 後端 404 ⇒ 回 nil，且**一個生成請求都不送**。
    func test_fetchWeeklySummary_remote404_returnsNilAndDoesNotGenerate() async throws {
        spyLocal.cachedWeeklySummary = nil
        spyRemote.weeklySummaryDTOToReturn = nil          // ⇒ getWeeklySummary 丟 HTTPError.notFound

        let result = try await sut.fetchWeeklySummary(weekOfPlan: 5)

        XCTAssertNil(result, "那一週沒有回顧就是 nil")
        XCTAssertEqual(spyRemote.getWeeklySummaryCallCount, 1, "要真的打過 GET，否則這一輪什麼都沒驗到")
        XCTAssertEqual(
            spyRemote.generateWeeklySummaryCallCount, 0,
            "唯讀路徑不得 fallback 到 POST —— 這正是 getWeeklySummary 會做的事"
        )
    }

    /// 對照組：同一個 404，`getWeeklySummary` **會**生成。
    /// 沒有這一支，上面那條斷言可能只是因為 spy 根本沒接上才綠。
    func test_getWeeklySummary_remote404_stillFallsBackToGenerate() async throws {
        spyLocal.cachedWeeklySummary = nil
        spyRemote.weeklySummaryDTOToReturn = nil

        _ = try? await sut.getWeeklySummary(weekOfPlan: 5)

        XCTAssertEqual(spyRemote.getWeeklySummaryCallCount, 1)
        XCTAssertEqual(
            spyRemote.generateWeeklySummaryCallCount, 1,
            "既有行為：getWeeklySummary 的 404 會 fallback 到 POST（本票沒有改它）"
        )
    }

    /// 有回顧時照樣拿得到，而且會寫進本地快取。
    func test_fetchWeeklySummary_remoteHit_returnsEntityAndCaches() async throws {
        spyLocal.cachedWeeklySummary = nil
        spyRemote.weeklySummaryDTOToReturn = try Self.summaryDTO(week: 3)

        let result = try await sut.fetchWeeklySummary(weekOfPlan: 3)

        XCTAssertNotNil(result)
        XCTAssertEqual(spyRemote.generateWeeklySummaryCallCount, 0)
        XCTAssertEqual(spyLocal.savedWeeklySummaryWeeks, [3], "取回的那一份要落快取")
    }

    /// 最小可解碼的週回顧 payload（形狀同 `App2HomeProjectionTests` 那一份）。
    private static func summaryDTO(week: Int) throws -> WeeklySummaryV2DTO {
        let json = """
        {
          "id": "ov_\(week)_summary", "week_of_training": \(week),
          "training_completion": { "completed_km": 0, "planned_km": 0,
            "completed_sessions": 0, "planned_sessions": 0, "percentage": 0,
            "evaluation": "" },
          "training_analysis": { "pace": null, "heart_rate": null, "distance": null,
            "intensity_distribution": null },
          "weekly_highlights": { "highlights": [], "achievements": null,
            "areas_for_improvement": [] },
          "next_week_adjustments": { "items": [], "summary": "",
            "methodology_constraints_considered": false, "based_on_flags": [] },
          "weekly_story": null, "observations": null,
          "capability_progression": null, "plan_context": null
        }
        """
        return try JSONDecoder().decode(WeeklySummaryV2DTO.self, from: Data(json.utf8))
    }

    /// 非 404 的錯誤仍然往上丟——不得被折成「這一週沒有回顧」。
    func test_fetchWeeklySummary_serverError_throwsInsteadOfReturningNil() async {
        spyLocal.cachedWeeklySummary = nil
        spyRemote.weeklySummaryError = HTTPError.serverError(500, "boom")

        do {
            _ = try await sut.fetchWeeklySummary(weekOfPlan: 5)
            XCTFail("500 不是『沒有回顧』，必須往上丟")
        } catch {
            XCTAssertEqual(spyRemote.generateWeeklySummaryCallCount, 0)
        }
    }
}

// MARK: - SpyTrainingPlanV2RemoteDataSource

/// Full-fidelity spy: tracks calls and returns configurable fixtures.
/// Methods not under test fatalError to surface unexpected calls.
private final class SpyTrainingPlanV2RemoteDataSource: TrainingPlanV2RemoteDataSourceProtocol {

    // MARK: - Return Values

    var planStatusToReturn: PlanStatusV2Response = PlanStatusV2Response.stubForRepo()
    var planStatusError: Error?
    var overviewDTOToReturn: PlanOverviewV2DTO = .stubForRepo()
    var overviewError: Error?
    var weeklyPlanDTOToReturn: WeeklyPlanV2DTO?
    var weeklyPlanError: Error?
    /// 週回顧（T-0362：`fetchWeeklySummary` 的唯讀契約）。
    var weeklySummaryDTOToReturn: WeeklySummaryV2DTO?
    var weeklySummaryError: Error?

    // MARK: - Call Tracking

    private(set) var getPlanStatusCallCount = 0
    private(set) var getOverviewCallCount = 0
    private(set) var generateWeeklyPlanCallCount = 0
    private(set) var getWeeklyPlanCallCount = 0
    private(set) var getWeeklySummaryCallCount = 0
    private(set) var generateWeeklySummaryCallCount = 0

    // MARK: - Protocol — Plan Status

    func getPlanStatus() async throws -> PlanStatusV2Response {
        getPlanStatusCallCount += 1
        if let error = planStatusError { throw error }
        return planStatusToReturn
    }

    // MARK: - Protocol — Target Types & Methodologies

    func getTargetTypes() async throws -> [TargetTypeV2] {
        fatalError("Unexpected: getTargetTypes()")
    }

    func getMethodologies(targetType: String?) async throws -> [MethodologyV2] {
        fatalError("Unexpected: getMethodologies()")
    }

    // MARK: - Protocol — Plan Overview

    func createOverviewForRace(targetId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2DTO {
        fatalError("Unexpected: createOverviewForRace()")
    }

    func createOverviewForNonRace(targetType: String, trainingWeeks: Int, availableDays: Int?, methodologyId: String?, startFromStage: String?, intendedRaceDistanceKm: Int?) async throws -> PlanOverviewV2DTO {
        fatalError("Unexpected: createOverviewForNonRace()")
    }

    func getOverview() async throws -> PlanOverviewV2DTO {
        getOverviewCallCount += 1
        if let error = overviewError { throw error }
        return overviewDTOToReturn
    }

    func updateOverview(overviewId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2DTO {
        fatalError("Unexpected: updateOverview()")
    }

    // MARK: - Protocol — Weekly Plan

    func generateWeeklyPlan(weekOfTraining: Int, forceGenerate: Bool?, promptVersion: String?, methodology: String?) async throws -> WeeklyPlanV2DTO {
        generateWeeklyPlanCallCount += 1
        if let error = weeklyPlanError { throw error }
        guard let dto = weeklyPlanDTOToReturn else {
            throw HTTPError.serverError(500, "No mock plan configured")
        }
        return dto
    }

    func getWeeklyPlan(planId: String) async throws -> WeeklyPlanV2DTO {
        getWeeklyPlanCallCount += 1
        if let error = weeklyPlanError { throw error }
        guard let dto = weeklyPlanDTOToReturn else {
            throw HTTPError.notFound("No mock weekly plan configured")
        }
        return dto
    }

    func updateWeeklyPlan(planId: String, updates: UpdateWeeklyPlanRequest) async throws -> WeeklyPlanV2DTO {
        fatalError("Unexpected: updateWeeklyPlan()")
    }

    func deleteWeeklyPlan(planId: String) async throws {
        fatalError("Unexpected: deleteWeeklyPlan()")
    }

    // MARK: - Protocol — Weekly Preview

    func getWeeklyPreview(overviewId: String) async throws -> WeeklyPreviewResponseDTO {
        fatalError("Unexpected: getWeeklyPreview()")
    }

    // MARK: - Protocol — Weekly Summary

    func getWeeklySummaries() async throws -> [WeeklySummaryItem] {
        fatalError("Unexpected: getWeeklySummaries()")
    }

    func generateWeeklySummary(weekOfPlan: Int, forceUpdate: Bool?) async throws -> WeeklySummaryV2DTO {
        generateWeeklySummaryCallCount += 1
        guard let dto = weeklySummaryDTOToReturn else {
            throw HTTPError.serverError(500, "No mock weekly summary configured")
        }
        return dto
    }

    func getWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2DTO {
        getWeeklySummaryCallCount += 1
        if let error = weeklySummaryError { throw error }
        guard let dto = weeklySummaryDTOToReturn else {
            throw HTTPError.notFound("Weekly summary not found")
        }
        return dto
    }

    func applyAdjustmentItems(weekOfPlan: Int, appliedIndices: [Int]) async throws {
        fatalError("Unexpected: applyAdjustmentItems()")
    }

    func deleteWeeklySummary(summaryId: String) async throws {
        fatalError("Unexpected: deleteWeeklySummary()")
    }

    func completeStrengthSession(_ request: StrengthCompletionRequestDTO) async throws -> StrengthCompletionResponseDTO {
        fatalError("Unexpected: completeStrengthSession()")
    }

    // MARK: - Decision chain（T-0383）：這一組測試不走清單，全部不預期被呼叫

    func runDecisionChainWeek(asOf: String, weekOfTraining: Int) async throws -> DecisionChainWeekRunDTO {
        fatalError("Unexpected call: runDecisionChainWeek")
    }

    func getDecisionChainChecklist(asOf: String) async throws -> DecisionChainChecklistDTO {
        fatalError("Unexpected call: getDecisionChainChecklist")
    }

    func postDecisionChainChecklistStance(
        asOf: String,
        itemId: String,
        body: DecisionChainChecklistStanceRequestDTO
    ) async throws -> DecisionChainChecklistStanceResponseDTO {
        fatalError("Unexpected call: postDecisionChainChecklistStance")
    }

    func getDecisionChainIntentCard() async throws -> DecisionChainIntentCardDTO {
        fatalError("Unexpected call: getDecisionChainIntentCard")
    }
}

// MARK: - SpyTrainingPlanV2LocalDataSource

/// In-memory local data source spy that tracks save calls.
private final class SpyTrainingPlanV2LocalDataSource: TrainingPlanV2LocalDataSourceProtocol {

    // MARK: - Stored State

    var cachedPlanStatus: PlanStatusV2Response?
    var savedPlanStatus: PlanStatusV2Response?
    var planStatusExpired = true
    var shouldRefreshResult = false

    var cachedOverview: PlanOverviewV2?
    var savedOverview: PlanOverviewV2?
    var overviewExpired = true

    var cachedWeeklyPlan: WeeklyPlanV2?
    var savedWeeklyPlan: WeeklyPlanV2?
    var weeklyPlanExpired = true

    // MARK: - Call Tracking

    private(set) var clearAllCallCount = 0

    // MARK: - Plan Status

    func getPlanStatus() -> PlanStatusV2Response? { cachedPlanStatus }

    func savePlanStatus(_ status: PlanStatusV2Response) {
        savedPlanStatus = status   // write receipt for test assertions
        cachedPlanStatus = status  // update read path so subsequent get() returns fresh value
    }

    func isPlanStatusExpired() -> Bool { planStatusExpired }

    func clearPlanStatus() {
        cachedPlanStatus = nil
    }

    // MARK: - Cooldown

    func shouldRefresh(_ resource: CooldownResource) -> Bool { shouldRefreshResult }
    func markRefreshed(_ resource: CooldownResource) {}
    func invalidateCooldown(_ resource: CooldownResource) {}

    // MARK: - Overview

    func getOverview() -> PlanOverviewV2? { cachedOverview }

    func saveOverview(_ overview: PlanOverviewV2) {
        savedOverview = overview
        cachedOverview = overview
    }

    func isOverviewExpired() -> Bool { overviewExpired }

    func clearOverview() {
        cachedOverview = nil
    }

    // MARK: - Weekly Plan

    func getWeeklyPlan(week: Int) -> WeeklyPlanV2? { cachedWeeklyPlan }

    func saveWeeklyPlan(_ plan: WeeklyPlanV2, week: Int) {
        savedWeeklyPlan = plan
        cachedWeeklyPlan = plan
    }

    func isWeeklyPlanExpired(week: Int) -> Bool { weeklyPlanExpired }
    func clearWeeklyPlan(week: Int) { cachedWeeklyPlan = nil }
    func clearAllWeeklyPlans() { cachedWeeklyPlan = nil }

    // MARK: - Weekly Summary

    /// 週回顧快取（T-0362：`fetchWeeklySummary` 的唯讀契約要驗到快取那一段）。
    var cachedWeeklySummary: WeeklySummaryV2?
    var weeklySummaryExpired = true
    private(set) var savedWeeklySummaryWeeks: [Int] = []

    func getWeeklySummary(week: Int) -> WeeklySummaryV2? { cachedWeeklySummary }
    func saveWeeklySummary(_ summary: WeeklySummaryV2, week: Int) {
        savedWeeklySummaryWeeks.append(week)
    }
    func isWeeklySummaryExpired(week: Int) -> Bool { weeklySummaryExpired }
    func clearWeeklySummary(week: Int) {}
    func clearAllWeeklySummaries() {}

    // MARK: - Weekly Preview

    func getWeeklyPreview(overviewId: String) -> WeeklyPreviewV2? { nil }
    func saveWeeklyPreview(_ preview: WeeklyPreviewV2, overviewId: String) {}
    func isWeeklyPreviewExpired(overviewId: String) -> Bool { true }
    func clearWeeklyPreview(overviewId: String) {}

    // MARK: - Utility

    func clearAll() {
        clearAllCallCount += 1
        cachedPlanStatus = nil
        cachedOverview = nil
        cachedWeeklyPlan = nil
    }
}

// MARK: - Fixture Extensions

private extension PlanStatusV2Response {
    static func stubForRepo(currentWeek: Int = 1) -> PlanStatusV2Response {
        PlanStatusV2Response(
            currentWeek: currentWeek,
            totalWeeks: 12,
            nextAction: "view_plan",
            canGenerateNextWeek: false,
            currentWeekPlanId: "plan_001_\(currentWeek)",
            previousWeekSummaryId: nil,
            targetType: "race_run",
            methodologyId: "paceriz",
            nextWeekInfo: nil,
            metadata: nil
        )
    }
}

private extension PlanOverviewV2DTO {
    static func stubForRepo() -> PlanOverviewV2DTO {
        PlanOverviewV2DTO(
            id: "overview_001",
            targetId: "target_abc",
            targetType: "race_run",
            targetDescription: nil,
            methodologyId: "paceriz",
            totalWeeks: 16,
            startFromStage: "base",
            raceDate: 1_800_000_000,
            distanceKm: 42.195,
            distanceKmDisplay: nil,
            distanceUnit: nil,
            targetPace: "5:30",
            targetTime: nil,
            isMainRace: true,
            targetName: "Test Race",
            methodologyOverview: nil,
            targetEvaluate: nil,
            approachSummary: nil,
            trainingStages: [],
            milestones: [],
            createdAt: nil,
            methodologyVersion: nil,
            milestoneBasis: nil
        )
    }
}

private extension PlanOverviewV2 {
    static func stubForRepo() -> PlanOverviewV2 {
        PlanOverviewV2(
            id: "overview_001",
            targetId: "target_abc",
            targetType: "race_run",
            targetDescription: nil,
            methodologyId: "paceriz",
            totalWeeks: 16,
            startFromStage: "base",
            raceDate: 1_800_000_000,
            distanceKm: 42.195,
            distanceKmDisplay: nil,
            distanceUnit: nil,
            targetPace: "5:30",
            targetTime: nil,
            isMainRace: true,
            targetName: "Test Race",
            methodologyOverview: nil,
            targetEvaluate: nil,
            approachSummary: nil,
            trainingStages: [],
            milestones: [],
            createdAt: nil,
            methodologyVersion: nil,
            milestoneBasis: nil
        )
    }
}

private extension WeeklyPlanV2DTO {
    static func stubForRepo(weekOfTraining: Int = 1) -> WeeklyPlanV2DTO {
        let json = """
        {
            "plan_id": "overview_001_\(weekOfTraining)",
            "overview_id": "overview_001",
            "week_of_training": \(weekOfTraining),
            "id": "overview_001_\(weekOfTraining)",
            "purpose": "Build aerobic base",
            "week_of_plan": \(weekOfTraining),
            "total_weeks": 16,
            "total_distance_km": 40.0,
            "days": [],
            "api_version": "2.0"
        }
        """
        return try! JSONDecoder().decode(WeeklyPlanV2DTO.self, from: Data(json.utf8))
    }
}
