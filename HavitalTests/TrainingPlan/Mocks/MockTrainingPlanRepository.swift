//
//  MockTrainingPlanRepository.swift
//  HavitalTests
//
//  Mock Repository for ViewModel unit testing
//

import Foundation
@testable import paceriz_dev

/// Mock implementation of TrainingPlanRepository for ViewModel testing
final class MockTrainingPlanRepository: TrainingPlanRepository {

    // MARK: - Configuration

    var weeklyPlanToReturn: WeeklyPlan?
    var overviewToReturn: TrainingPlanOverview?
    var planStatusToReturn: PlanStatusResponse?
    var weeklySummaryToReturn: WeeklyTrainingSummary?
    var weeklySummariesListToReturn: [WeeklySummaryItem] = []
    var adjustmentItemsToReturn: [AdjustmentItem] = []
    var createOverviewResult: Result<TrainingPlanOverview, Error>?
    var errorToThrow: Error?

    // MARK: - Call Tracking

    private(set) var getWeeklyPlanCallCount = 0
    private(set) var getWeeklyPlanLastPlanId: String?

    private(set) var refreshWeeklyPlanCallCount = 0
    private(set) var createWeeklyPlanCallCount = 0
    private(set) var modifyWeeklyPlanCallCount = 0

    private(set) var getOverviewCallCount = 0
    private(set) var refreshOverviewCallCount = 0

    private(set) var getPlanStatusCallCount = 0
    private(set) var refreshPlanStatusCallCount = 0
    private(set) var createOverviewCallCount = 0

    private(set) var createWeeklySummaryCallCount = 0
    private(set) var createWeeklySummaryLastParams: (weekNumber: Int?, forceUpdate: Bool)?

    private(set) var getWeeklySummariesCallCount = 0
    private(set) var updateAdjustmentsCallCount = 0
    private(set) var updateAdjustmentsLastParams: (summaryId: String, items: [AdjustmentItem])?

    // MARK: - Weekly Plan

    func getWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        getWeeklyPlanCallCount += 1
        getWeeklyPlanLastPlanId = planId

        if let error = errorToThrow {
            throw error
        }

        guard let plan = weeklyPlanToReturn else {
            throw TrainingPlanError.weeklyPlanNotFound(planId: planId)
        }

        return plan
    }

    func refreshWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        refreshWeeklyPlanCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        guard let plan = weeklyPlanToReturn else {
            throw TrainingPlanError.weeklyPlanNotFound(planId: planId)
        }

        return plan
    }

    func createWeeklyPlan(week: Int?, startFromStage: String?, isBeginner: Bool) async throws -> WeeklyPlan {
        createWeeklyPlanCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        guard let plan = weeklyPlanToReturn else {
            throw TrainingPlanError.noPlan
        }

        return plan
    }

    func modifyWeeklyPlan(planId: String, updatedPlan: WeeklyPlan) async throws -> WeeklyPlan {
        modifyWeeklyPlanCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        return updatedPlan
    }

    // MARK: - Training Overview

    func getOverview() async throws -> TrainingPlanOverview {
        getOverviewCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        guard let overview = overviewToReturn else {
            throw TrainingPlanError.overviewNotFound
        }

        return overview
    }

    func refreshOverview() async throws -> TrainingPlanOverview {
        refreshOverviewCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        guard let overview = overviewToReturn else {
            throw TrainingPlanError.overviewNotFound
        }

        return overview
    }

    func createOverview(startFromStage: String?, isBeginner: Bool) async throws -> TrainingPlanOverview {
        createOverviewCallCount += 1
        
        if let result = createOverviewResult {
            switch result {
            case .success(let overview):
                return overview
            case .failure(let error):
                throw error
            }
        }
        
        if let error = errorToThrow {
            throw error
        }

        guard let overview = overviewToReturn else {
            throw TrainingPlanError.overviewNotFound
        }

        return overview
    }

    func updateOverview(overviewId: String) async throws -> TrainingPlanOverview {
        if let error = errorToThrow {
            throw error
        }

        guard let overview = overviewToReturn else {
            throw TrainingPlanError.overviewNotFound
        }

        return overview
    }

    // MARK: - Plan Status

    func getPlanStatus() async throws -> PlanStatusResponse {
        getPlanStatusCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        guard let status = planStatusToReturn else {
            throw TrainingPlanError.invalidPlanStatus
        }

        return status
    }

    func refreshPlanStatus() async throws -> PlanStatusResponse {
        refreshPlanStatusCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        guard let status = planStatusToReturn else {
            throw TrainingPlanError.invalidPlanStatus
        }

        return status
    }

    // MARK: - Modifications

    func getModifications() async throws -> [Modification] {
        return []
    }

    func getModificationsDescription() async throws -> String {
        return ""
    }

    func createModification(_ modification: NewModification) async throws -> Modification {
        throw TrainingPlanError.noPlan
    }

    func updateModifications(_ modifications: [Modification]) async throws -> [Modification] {
        return modifications
    }

    func clearModifications() async throws {}

    // MARK: - Weekly Summary

    func createWeeklySummary(weekNumber: Int?, forceUpdate: Bool) async throws -> WeeklyTrainingSummary {
        createWeeklySummaryCallCount += 1
        createWeeklySummaryLastParams = (weekNumber, forceUpdate)

        if let error = errorToThrow {
            throw error
        }

        guard let summary = weeklySummaryToReturn else {
            throw TrainingPlanError.noPlan
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
        if let error = errorToThrow {
            throw error
        }

        guard let summary = weeklySummaryToReturn else {
            throw TrainingPlanError.noPlan
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

    // MARK: - Cache Management

    func clearCache() async {}
    func preloadData() async {}

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
        refreshWeeklyPlanCallCount = 0
        createWeeklyPlanCallCount = 0
        modifyWeeklyPlanCallCount = 0
        getOverviewCallCount = 0
        refreshOverviewCallCount = 0
        getPlanStatusCallCount = 0
        refreshPlanStatusCallCount = 0
        createWeeklySummaryCallCount = 0
        createWeeklySummaryLastParams = nil
        getWeeklySummariesCallCount = 0
        updateAdjustmentsCallCount = 0
        updateAdjustmentsLastParams = nil
    }
}
