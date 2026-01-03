//
//  MockTrainingPlanDataSources.swift
//  HavitalTests
//
//  Mock data sources for Repository unit testing
//

import Foundation
@testable import paceriz_dev

// MARK: - Mock Remote Data Source

/// Mock implementation of TrainingPlanRemoteDataSource for testing
final class MockTrainingPlanRemoteDataSource {

    // MARK: - Configuration

    /// Configured response for getWeeklyPlan
    var weeklyPlanToReturn: WeeklyPlan?

    /// Configured response for getOverview
    var overviewToReturn: TrainingPlanOverview?

    /// Configured response for getPlanStatus
    var planStatusToReturn: PlanStatusResponse?

    /// Error to throw (if set, methods will throw this error)
    var errorToThrow: Error?

    // MARK: - Call Tracking

    private(set) var getWeeklyPlanCallCount = 0
    private(set) var getWeeklyPlanLastPlanId: String?

    private(set) var createWeeklyPlanCallCount = 0
    private(set) var createWeeklyPlanLastParams: (week: Int?, startFromStage: String?, isBeginner: Bool)?

    private(set) var modifyWeeklyPlanCallCount = 0
    private(set) var modifyWeeklyPlanLastParams: (planId: String, updatedPlan: WeeklyPlan)?

    private(set) var getOverviewCallCount = 0
    private(set) var createOverviewCallCount = 0
    private(set) var updateOverviewCallCount = 0

    private(set) var getPlanStatusCallCount = 0

    // MARK: - Methods (Simulating TrainingPlanRemoteDataSource)

    func getWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        getWeeklyPlanCallCount += 1
        getWeeklyPlanLastPlanId = planId

        if let error = errorToThrow {
            throw error
        }

        guard let plan = weeklyPlanToReturn else {
            throw HTTPError.notFound("No mock plan configured")
        }

        return plan
    }

    func createWeeklyPlan(week: Int?, startFromStage: String?, isBeginner: Bool) async throws -> WeeklyPlan {
        createWeeklyPlanCallCount += 1
        createWeeklyPlanLastParams = (week, startFromStage, isBeginner)

        if let error = errorToThrow {
            throw error
        }

        guard let plan = weeklyPlanToReturn else {
            throw HTTPError.serverError(500, "No mock plan configured")
        }

        return plan
    }

    func modifyWeeklyPlan(planId: String, updatedPlan: WeeklyPlan) async throws -> WeeklyPlan {
        modifyWeeklyPlanCallCount += 1
        modifyWeeklyPlanLastParams = (planId, updatedPlan)

        if let error = errorToThrow {
            throw error
        }

        return updatedPlan
    }

    func getOverview() async throws -> TrainingPlanOverview {
        getOverviewCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        guard let overview = overviewToReturn else {
            throw HTTPError.notFound("No mock overview configured")
        }

        return overview
    }

    func createOverview(startFromStage: String?, isBeginner: Bool) async throws -> TrainingPlanOverview {
        createOverviewCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        guard let overview = overviewToReturn else {
            throw HTTPError.serverError(500, "No mock overview configured")
        }

        return overview
    }

    func updateOverview(overviewId: String) async throws -> TrainingPlanOverview {
        updateOverviewCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        guard let overview = overviewToReturn else {
            throw HTTPError.notFound("No mock overview configured")
        }

        return overview
    }

    func getPlanStatus() async throws -> PlanStatusResponse {
        getPlanStatusCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        guard let status = planStatusToReturn else {
            throw HTTPError.notFound("No mock status configured")
        }

        return status
    }

    // MARK: - Weekly Summary Methods

    var weeklySummaryToReturn: WeeklyTrainingSummary?
    var weeklySummariesListToReturn: [WeeklySummaryItem] = []
    var adjustmentItemsToReturn: [AdjustmentItem] = []

    private(set) var createWeeklySummaryCallCount = 0
    private(set) var createWeeklySummaryLastParams: (weekNumber: Int?, forceUpdate: Bool)?

    private(set) var getWeeklySummariesCallCount = 0
    private(set) var getWeeklySummaryCallCount = 0
    private(set) var getWeeklySummaryLastWeekNumber: Int?

    private(set) var updateAdjustmentsCallCount = 0
    private(set) var updateAdjustmentsLastParams: (summaryId: String, items: [AdjustmentItem])?

    func createWeeklySummary(weekNumber: Int?, forceUpdate: Bool) async throws -> WeeklyTrainingSummary {
        createWeeklySummaryCallCount += 1
        createWeeklySummaryLastParams = (weekNumber, forceUpdate)

        if let error = errorToThrow {
            throw error
        }

        guard let summary = weeklySummaryToReturn else {
            throw HTTPError.serverError(500, "No mock summary configured")
        }

        return summary
    }

    func getWeeklySummaries() async throws -> [WeeklySummaryItem] {
        getWeeklySummariesCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        return weeklySummariesListToReturn
    }

    func getWeeklySummary(weekNumber: Int) async throws -> WeeklyTrainingSummary {
        getWeeklySummaryCallCount += 1
        getWeeklySummaryLastWeekNumber = weekNumber

        if let error = errorToThrow {
            throw error
        }

        guard let summary = weeklySummaryToReturn else {
            throw HTTPError.notFound("No mock summary configured")
        }

        return summary
    }

    func updateAdjustments(summaryId: String, items: [AdjustmentItem]) async throws -> [AdjustmentItem] {
        updateAdjustmentsCallCount += 1
        updateAdjustmentsLastParams = (summaryId, items)

        if let error = errorToThrow {
            throw error
        }

        return adjustmentItemsToReturn
    }

    // MARK: - Helper Methods

    func reset() {
        weeklyPlanToReturn = nil
        overviewToReturn = nil
        planStatusToReturn = nil
        weeklySummaryToReturn = nil
        weeklySummariesListToReturn = []
        adjustmentItemsToReturn = []
        errorToThrow = nil

        getWeeklyPlanCallCount = 0
        getWeeklyPlanLastPlanId = nil
        createWeeklyPlanCallCount = 0
        createWeeklyPlanLastParams = nil
        modifyWeeklyPlanCallCount = 0
        modifyWeeklyPlanLastParams = nil
        getOverviewCallCount = 0
        createOverviewCallCount = 0
        updateOverviewCallCount = 0
        getPlanStatusCallCount = 0

        createWeeklySummaryCallCount = 0
        createWeeklySummaryLastParams = nil
        getWeeklySummariesCallCount = 0
        getWeeklySummaryCallCount = 0
        getWeeklySummaryLastWeekNumber = nil
        updateAdjustmentsCallCount = 0
        updateAdjustmentsLastParams = nil
    }
}

// MARK: - Mock Local Data Source

/// Mock implementation of TrainingPlanLocalDataSource for testing
final class MockTrainingPlanLocalDataSource {

    // MARK: - Storage

    var cachedWeeklyPlans: [String: WeeklyPlan] = [:]
    var cachedOverview: TrainingPlanOverview?
    var cachedPlanStatus: PlanStatusResponse?

    /// Expiration status for weekly plans
    var weeklyPlanExpirationStatus: [String: Bool] = [:]
    var overviewExpired = false
    var planStatusExpired = false

    // MARK: - Call Tracking

    private(set) var getWeeklyPlanCallCount = 0
    private(set) var saveWeeklyPlanCallCount = 0
    private(set) var removeWeeklyPlanCallCount = 0

    private(set) var getOverviewCallCount = 0
    private(set) var saveOverviewCallCount = 0
    private(set) var removeOverviewCallCount = 0

    private(set) var getPlanStatusCallCount = 0
    private(set) var savePlanStatusCallCount = 0
    private(set) var removePlanStatusCallCount = 0

    private(set) var clearAllCallCount = 0

    // MARK: - Weekly Plan Methods

    func getWeeklyPlan(planId: String) -> WeeklyPlan? {
        getWeeklyPlanCallCount += 1
        return cachedWeeklyPlans[planId]
    }

    func saveWeeklyPlan(_ plan: WeeklyPlan, planId: String) {
        saveWeeklyPlanCallCount += 1
        cachedWeeklyPlans[planId] = plan
        weeklyPlanExpirationStatus[planId] = false
    }

    func isWeeklyPlanExpired(planId: String) -> Bool {
        return weeklyPlanExpirationStatus[planId] ?? true
    }

    func removeWeeklyPlan(planId: String) {
        removeWeeklyPlanCallCount += 1
        cachedWeeklyPlans.removeValue(forKey: planId)
        weeklyPlanExpirationStatus.removeValue(forKey: planId)
    }

    // MARK: - Overview Methods

    func getOverview() -> TrainingPlanOverview? {
        getOverviewCallCount += 1
        return cachedOverview
    }

    func saveOverview(_ overview: TrainingPlanOverview) {
        saveOverviewCallCount += 1
        cachedOverview = overview
        overviewExpired = false
    }

    func isOverviewExpired() -> Bool {
        return overviewExpired
    }

    func removeOverview() {
        removeOverviewCallCount += 1
        cachedOverview = nil
        overviewExpired = true
    }

    // MARK: - Plan Status Methods

    func getPlanStatus() -> PlanStatusResponse? {
        getPlanStatusCallCount += 1
        return cachedPlanStatus
    }

    func savePlanStatus(_ status: PlanStatusResponse) {
        savePlanStatusCallCount += 1
        cachedPlanStatus = status
        planStatusExpired = false
    }

    func isPlanStatusExpired() -> Bool {
        return planStatusExpired
    }

    func removePlanStatus() {
        removePlanStatusCallCount += 1
        cachedPlanStatus = nil
        planStatusExpired = true
    }

    // MARK: - Cache Management

    func clearAll() {
        clearAllCallCount += 1
        cachedWeeklyPlans.removeAll()
        cachedOverview = nil
        cachedPlanStatus = nil
        weeklyPlanExpirationStatus.removeAll()
        overviewExpired = true
        planStatusExpired = true
    }

    // MARK: - Helper Methods

    func reset() {
        cachedWeeklyPlans.removeAll()
        cachedOverview = nil
        cachedPlanStatus = nil
        weeklyPlanExpirationStatus.removeAll()
        overviewExpired = false
        planStatusExpired = false

        getWeeklyPlanCallCount = 0
        saveWeeklyPlanCallCount = 0
        removeWeeklyPlanCallCount = 0
        getOverviewCallCount = 0
        saveOverviewCallCount = 0
        removeOverviewCallCount = 0
        getPlanStatusCallCount = 0
        savePlanStatusCallCount = 0
        removePlanStatusCallCount = 0
        clearAllCallCount = 0
    }
}
