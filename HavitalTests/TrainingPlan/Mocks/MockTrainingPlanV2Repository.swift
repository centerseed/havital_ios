import Foundation
@testable import paceriz_dev

/// Mock implementation of TrainingPlanV2Repository for testing
final class MockTrainingPlanV2Repository: TrainingPlanV2Repository {

    // MARK: - Call Tracking

    var getPlanStatusCallCount = 0
    var getTargetTypesCallCount = 0
    var getMethodologiesCallCount = 0
    var createOverviewForRaceCallCount = 0
    var createOverviewForNonRaceCallCount = 0
    var getOverviewCallCount = 0
    var refreshOverviewCallCount = 0
    var updateOverviewCallCount = 0
    var generateWeeklyPlanCallCount = 0
    var getWeeklyPlanCallCount = 0
    var fetchWeeklyPlanCallCount = 0
    var updateWeeklyPlanCallCount = 0
    var refreshWeeklyPlanCallCount = 0
    var deleteWeeklyPlanCallCount = 0
    var generateWeeklySummaryCallCount = 0
    var getWeeklySummaryCallCount = 0
    var refreshWeeklySummaryCallCount = 0
    var deleteWeeklySummaryCallCount = 0
    var applyAdjustmentItemsCallCount = 0
    var lastAppliedIndices: [Int] = []
    var lastApplyAdjustmentItemsWeekOfPlan: Int?
    var getWeeklyPreviewCallCount = 0
    var clearCacheCallCount = 0
    var lastRequestedWeeklyPlanWeekOfTraining: Int?
    var lastRefreshedWeeklyPlanWeekOfTraining: Int?
    var lastCreateOverviewForRaceTargetId: String?
    var lastCreateOverviewForRaceStartFromStage: String?
    var lastCreateOverviewForRaceMethodologyId: String?
    var lastUpdatedOverviewId: String?
    var lastUpdatedOverviewStartFromStage: String?
    var lastUpdatedOverviewMethodologyId: String?

    // MARK: - Return Values

    var weeklyPreviewToReturn: WeeklyPreviewV2?
    var planStatusToReturn: PlanStatusV2Response?
    var targetTypesToReturn: [TargetTypeV2] = []
    var methodologiesToReturn: [MethodologyV2] = []
    var overviewToReturn: PlanOverviewV2?
    var weeklyPlanV2ToReturn: WeeklyPlanV2?
    var weeklySummaryV2ToReturn: WeeklySummaryV2?
    var errorToThrow: Error?
    var generateWeeklyPlanErrors: [Error] = []
    var applyAdjustmentItemsError: Error?

    // MARK: - Reset

    func reset() {
        getPlanStatusCallCount = 0
        getTargetTypesCallCount = 0
        getMethodologiesCallCount = 0
        createOverviewForRaceCallCount = 0
        createOverviewForNonRaceCallCount = 0
        getOverviewCallCount = 0
        refreshOverviewCallCount = 0
        updateOverviewCallCount = 0
        generateWeeklyPlanCallCount = 0
        getWeeklyPlanCallCount = 0
        fetchWeeklyPlanCallCount = 0
        updateWeeklyPlanCallCount = 0
        refreshWeeklyPlanCallCount = 0
        deleteWeeklyPlanCallCount = 0
        generateWeeklySummaryCallCount = 0
        getWeeklySummaryCallCount = 0
        refreshWeeklySummaryCallCount = 0
        deleteWeeklySummaryCallCount = 0
        applyAdjustmentItemsCallCount = 0
        lastAppliedIndices = []
        lastApplyAdjustmentItemsWeekOfPlan = nil
        getWeeklyPreviewCallCount = 0
        clearCacheCallCount = 0
        lastRequestedWeeklyPlanWeekOfTraining = nil
        lastRefreshedWeeklyPlanWeekOfTraining = nil
        lastCreateOverviewForRaceTargetId = nil
        lastCreateOverviewForRaceStartFromStage = nil
        lastCreateOverviewForRaceMethodologyId = nil
        lastUpdatedOverviewId = nil
        lastUpdatedOverviewStartFromStage = nil
        lastUpdatedOverviewMethodologyId = nil
        errorToThrow = nil
        generateWeeklyPlanErrors = []
        applyAdjustmentItemsError = nil
    }

    // MARK: - Protocol Methods

    func getPlanStatus(forceRefresh: Bool) async throws -> PlanStatusV2Response {
        getPlanStatusCallCount += 1
        if let error = errorToThrow { throw error }
        guard let status = planStatusToReturn else {
            throw TrainingPlanV2Error.unknown("No mock plan status set")
        }
        return status
    }

    func getTargetTypes() async throws -> [TargetTypeV2] {
        getTargetTypesCallCount += 1
        if let error = errorToThrow { throw error }
        return targetTypesToReturn
    }

    func getMethodologies(targetType: String?) async throws -> [MethodologyV2] {
        getMethodologiesCallCount += 1
        if let error = errorToThrow { throw error }
        return methodologiesToReturn
    }

    func createOverviewForRace(targetId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2 {
        createOverviewForRaceCallCount += 1
        lastCreateOverviewForRaceTargetId = targetId
        lastCreateOverviewForRaceStartFromStage = startFromStage
        lastCreateOverviewForRaceMethodologyId = methodologyId
        if let error = errorToThrow { throw error }
        guard let overview = overviewToReturn else {
            throw TrainingPlanV2Error.overviewCreationFailed("No mock overview set")
        }
        return overview
    }

    func createOverviewForNonRace(targetType: String, trainingWeeks: Int, availableDays: Int?, methodologyId: String?, startFromStage: String?, intendedRaceDistanceKm: Int?) async throws -> PlanOverviewV2 {
        createOverviewForNonRaceCallCount += 1
        if let error = errorToThrow { throw error }
        guard let overview = overviewToReturn else {
            throw TrainingPlanV2Error.overviewCreationFailed("No mock overview set")
        }
        return overview
    }

    func getOverview() async throws -> PlanOverviewV2 {
        getOverviewCallCount += 1
        if let error = errorToThrow { throw error }
        guard let overview = overviewToReturn else {
            throw TrainingPlanV2Error.overviewNotFound
        }
        return overview
    }

    func refreshOverview() async throws -> PlanOverviewV2 {
        refreshOverviewCallCount += 1
        if let error = errorToThrow { throw error }
        guard let overview = overviewToReturn else {
            throw TrainingPlanV2Error.overviewNotFound
        }
        return overview
    }

    func updateOverview(overviewId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2 {
        updateOverviewCallCount += 1
        lastUpdatedOverviewId = overviewId
        lastUpdatedOverviewStartFromStage = startFromStage
        lastUpdatedOverviewMethodologyId = methodologyId
        if let error = errorToThrow { throw error }
        guard let overview = overviewToReturn else {
            throw TrainingPlanV2Error.overviewNotFound
        }
        return overview
    }

    func generateWeeklyPlan(weekOfTraining: Int, forceGenerate: Bool?, promptVersion: String?, methodology: String?) async throws -> WeeklyPlanV2 {
        generateWeeklyPlanCallCount += 1
        if !generateWeeklyPlanErrors.isEmpty {
            throw generateWeeklyPlanErrors.removeFirst()
        }
        if let error = errorToThrow { throw error }
        guard let plan = weeklyPlanV2ToReturn else {
            throw TrainingPlanV2Error.weeklyPlanGenerationFailed(week: weekOfTraining, reason: "No mock plan set")
        }
        return plan
    }

    func getWeeklyPlan(weekOfTraining: Int, overviewId: String) async throws -> WeeklyPlanV2 {
        getWeeklyPlanCallCount += 1
        lastRequestedWeeklyPlanWeekOfTraining = weekOfTraining
        if let error = errorToThrow { throw error }
        guard let plan = weeklyPlanV2ToReturn else {
            throw TrainingPlanV2Error.weeklyPlanNotFound(week: weekOfTraining)
        }
        return plan
    }

    func fetchWeeklyPlan(planId: String) async throws -> WeeklyPlanV2 {
        fetchWeeklyPlanCallCount += 1
        if let error = errorToThrow { throw error }
        guard let plan = weeklyPlanV2ToReturn else {
            throw TrainingPlanV2Error.weeklyPlanNotFound(week: 0)
        }
        return plan
    }

    func updateWeeklyPlan(planId: String, updates: UpdateWeeklyPlanRequest) async throws -> WeeklyPlanV2 {
        updateWeeklyPlanCallCount += 1
        if let error = errorToThrow { throw error }
        guard let plan = weeklyPlanV2ToReturn else {
            throw TrainingPlanV2Error.weeklyPlanNotFound(week: 0)
        }
        return plan
    }

    func refreshWeeklyPlan(weekOfTraining: Int, overviewId: String) async throws -> WeeklyPlanV2 {
        refreshWeeklyPlanCallCount += 1
        lastRefreshedWeeklyPlanWeekOfTraining = weekOfTraining
        if let error = errorToThrow { throw error }
        guard let plan = weeklyPlanV2ToReturn else {
            throw TrainingPlanV2Error.weeklyPlanNotFound(week: weekOfTraining)
        }
        return plan
    }

    func deleteWeeklyPlan(planId: String) async throws {
        deleteWeeklyPlanCallCount += 1
        if let error = errorToThrow { throw error }
    }

    func getWeeklyPreview(overviewId: String) async throws -> WeeklyPreviewV2 {
        getWeeklyPreviewCallCount += 1
        if let error = errorToThrow { throw error }
        guard let preview = weeklyPreviewToReturn else {
            throw TrainingPlanV2Error.unknown("No mock weekly preview set")
        }
        return preview
    }

    func generateWeeklySummary(weekOfPlan: Int, forceUpdate: Bool?) async throws -> WeeklySummaryV2 {
        generateWeeklySummaryCallCount += 1
        if let error = errorToThrow { throw error }
        guard let summary = weeklySummaryV2ToReturn else {
            throw TrainingPlanV2Error.weeklySummaryGenerationFailed(week: weekOfPlan, reason: "No mock summary set")
        }
        return summary
    }

    func getWeeklySummaries() async throws -> [WeeklySummaryItem] {
        if let error = errorToThrow { throw error }
        return []
    }

    func getWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2 {
        getWeeklySummaryCallCount += 1
        if let error = errorToThrow { throw error }
        guard let summary = weeklySummaryV2ToReturn else {
            throw TrainingPlanV2Error.weeklySummaryNotFound(week: weekOfPlan)
        }
        return summary
    }

    func refreshWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2 {
        refreshWeeklySummaryCallCount += 1
        if let error = errorToThrow { throw error }
        guard let summary = weeklySummaryV2ToReturn else {
            throw TrainingPlanV2Error.weeklySummaryNotFound(week: weekOfPlan)
        }
        return summary
    }

    func applyAdjustmentItems(weekOfPlan: Int, appliedIndices: [Int]) async throws {
        applyAdjustmentItemsCallCount += 1
        lastApplyAdjustmentItemsWeekOfPlan = weekOfPlan
        lastAppliedIndices = appliedIndices
        if let error = applyAdjustmentItemsError { throw error }
    }

    func deleteWeeklySummary(summaryId: String) async throws {
        deleteWeeklySummaryCallCount += 1
        if let error = errorToThrow { throw error }
    }

    func getCachedPlanStatus() -> PlanStatusV2Response? {
        planStatusToReturn
    }

    func getCachedOverview() -> PlanOverviewV2? {
        overviewToReturn
    }

    func getCachedWeeklyPlan(week: Int) -> WeeklyPlanV2? {
        weeklyPlanV2ToReturn
    }

    func clearCache() async {
        clearCacheCallCount += 1
    }

    func clearOverviewCache() async {}
    func clearWeeklyPlanCache(weekOfTraining: Int?) async {}
    func clearWeeklySummaryCache(weekOfPlan: Int?) async {}
    func preloadData() async {}
}
