//
//  TrainingPlanLocalDataSourceTests.swift
//  HavitalTests
//
//  Unit tests for TrainingPlanLocalDataSource
//  Tests caching functionality including save, retrieve, expiration, and removal
//

import XCTest
@testable import paceriz_dev

final class TrainingPlanLocalDataSourceTests: XCTestCase {

    // MARK: - Properties

    var sut: TrainingPlanLocalDataSource!
    var mockDefaults: MockUserDefaults!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockDefaults = MockUserDefaults()
        sut = TrainingPlanLocalDataSource(defaults: mockDefaults)
    }

    override func tearDown() {
        mockDefaults.clear()
        sut = nil
        mockDefaults = nil
        super.tearDown()
    }

    // MARK: - Weekly Plan Tests

    func test_saveAndGetWeeklyPlan_shouldStoreAndRetrieve() {
        // Given
        let plan = TrainingPlanTestFixtures.weeklyPlan1
        let planId = "plan_123_1"

        // When
        sut.saveWeeklyPlan(plan, planId: planId)
        let retrieved = sut.getWeeklyPlan(planId: planId)

        // Then
        XCTAssertNotNil(retrieved, "Retrieved plan should not be nil")
        XCTAssertEqual(retrieved?.id, plan.id, "Plan ID should match")
        XCTAssertEqual(retrieved?.weekOfPlan, plan.weekOfPlan, "Week of plan should match")
        XCTAssertEqual(retrieved?.totalDistance, plan.totalDistance, "Total distance should match")
    }

    func test_getWeeklyPlan_withNonExistentId_shouldReturnNil() {
        // Given
        let nonExistentPlanId = "nonexistent_plan_999"

        // When
        let retrieved = sut.getWeeklyPlan(planId: nonExistentPlanId)

        // Then
        XCTAssertNil(retrieved, "Should return nil for non-existent plan")
    }

    func test_isWeeklyPlanExpired_whenJustSaved_shouldReturnFalse() {
        // Given
        let plan = TrainingPlanTestFixtures.weeklyPlan1
        let planId = "plan_123_1"
        sut.saveWeeklyPlan(plan, planId: planId)

        // When
        let isExpired = sut.isWeeklyPlanExpired(planId: planId)

        // Then
        XCTAssertFalse(isExpired, "Just saved plan should not be expired")
    }

    func test_isWeeklyPlanExpired_withNoTimestamp_shouldReturnTrue() {
        // Given
        let planId = "plan_without_timestamp"
        // No plan saved, so no timestamp exists

        // When
        let isExpired = sut.isWeeklyPlanExpired(planId: planId)

        // Then
        XCTAssertTrue(isExpired, "Plan without timestamp should be considered expired")
    }

    func test_removeWeeklyPlan_shouldDeleteFromCache() {
        // Given
        let plan = TrainingPlanTestFixtures.weeklyPlan1
        let planId = "plan_123_1"
        sut.saveWeeklyPlan(plan, planId: planId)

        // Verify it exists first
        XCTAssertNotNil(sut.getWeeklyPlan(planId: planId))

        // When
        sut.removeWeeklyPlan(planId: planId)

        // Then
        XCTAssertNil(sut.getWeeklyPlan(planId: planId), "Plan should be nil after removal")
    }

    func test_saveMultipleWeeklyPlans_shouldStoreAllPlans() {
        // Given
        let plan1 = TrainingPlanTestFixtures.weeklyPlan1
        let plan2 = TrainingPlanTestFixtures.weeklyPlan2
        let planId1 = "plan_123_1"
        let planId2 = "plan_123_2"

        // When
        sut.saveWeeklyPlan(plan1, planId: planId1)
        sut.saveWeeklyPlan(plan2, planId: planId2)

        // Then
        let retrieved1 = sut.getWeeklyPlan(planId: planId1)
        let retrieved2 = sut.getWeeklyPlan(planId: planId2)

        XCTAssertNotNil(retrieved1)
        XCTAssertNotNil(retrieved2)
        XCTAssertEqual(retrieved1?.weekOfPlan, 1)
        XCTAssertEqual(retrieved2?.weekOfPlan, 2)
    }

    // MARK: - Overview Tests

    func test_saveAndGetOverview_shouldStoreAndRetrieve() {
        // Given
        let overview = TrainingPlanTestFixtures.trainingOverview

        // When
        sut.saveOverview(overview)
        let retrieved = sut.getOverview()

        // Then
        XCTAssertNotNil(retrieved, "Retrieved overview should not be nil")
        XCTAssertEqual(retrieved?.id, overview.id, "Overview ID should match")
        XCTAssertEqual(retrieved?.totalWeeks, overview.totalWeeks, "Total weeks should match")
        XCTAssertEqual(retrieved?.trainingPlanName, overview.trainingPlanName, "Plan name should match")
    }

    func test_getOverview_whenNotSaved_shouldReturnNil() {
        // When
        let retrieved = sut.getOverview()

        // Then
        XCTAssertNil(retrieved, "Should return nil when no overview is saved")
    }

    func test_isOverviewExpired_whenJustSaved_shouldReturnFalse() {
        // Given
        sut.saveOverview(TrainingPlanTestFixtures.trainingOverview)

        // When
        let isExpired = sut.isOverviewExpired()

        // Then
        XCTAssertFalse(isExpired, "Just saved overview should not be expired")
    }

    func test_isOverviewExpired_withNoTimestamp_shouldReturnTrue() {
        // When (no overview saved)
        let isExpired = sut.isOverviewExpired()

        // Then
        XCTAssertTrue(isExpired, "Overview without timestamp should be considered expired")
    }

    func test_removeOverview_shouldDeleteFromCache() {
        // Given
        sut.saveOverview(TrainingPlanTestFixtures.trainingOverview)
        XCTAssertNotNil(sut.getOverview())

        // When
        sut.removeOverview()

        // Then
        XCTAssertNil(sut.getOverview(), "Overview should be nil after removal")
    }

    // MARK: - Plan Status Tests

    func test_saveAndGetPlanStatus_shouldStoreAndRetrieve() {
        // Given
        let status = TrainingPlanTestFixtures.planStatusWithPlan

        // When
        sut.savePlanStatus(status)
        let retrieved = sut.getPlanStatus()

        // Then
        XCTAssertNotNil(retrieved, "Retrieved status should not be nil")
        XCTAssertEqual(retrieved?.currentWeek, status.currentWeek, "Current week should match")
        XCTAssertEqual(retrieved?.totalWeeks, status.totalWeeks, "Total weeks should match")
        XCTAssertEqual(retrieved?.nextAction, status.nextAction, "Next action should match")
    }

    func test_getPlanStatus_whenNotSaved_shouldReturnNil() {
        // When
        let retrieved = sut.getPlanStatus()

        // Then
        XCTAssertNil(retrieved, "Should return nil when no status is saved")
    }

    func test_isPlanStatusExpired_whenJustSaved_shouldReturnFalse() {
        // Given
        sut.savePlanStatus(TrainingPlanTestFixtures.planStatusWithPlan)

        // When
        let isExpired = sut.isPlanStatusExpired()

        // Then
        XCTAssertFalse(isExpired, "Just saved plan status should not be expired")
    }

    func test_removePlanStatus_shouldDeleteFromCache() {
        // Given
        sut.savePlanStatus(TrainingPlanTestFixtures.planStatusWithPlan)
        XCTAssertNotNil(sut.getPlanStatus())

        // When
        sut.removePlanStatus()

        // Then
        XCTAssertNil(sut.getPlanStatus(), "Plan status should be nil after removal")
    }

    // MARK: - Cache Management Tests

    func test_clearAll_shouldRemoveAllCachedData() {
        // Given - save all types of data
        sut.saveOverview(TrainingPlanTestFixtures.trainingOverview)
        sut.savePlanStatus(TrainingPlanTestFixtures.planStatusWithPlan)
        sut.saveWeeklyPlan(TrainingPlanTestFixtures.weeklyPlan1, planId: "plan_123_1")
        sut.saveWeeklyPlan(TrainingPlanTestFixtures.weeklyPlan2, planId: "plan_123_2")

        // Verify all data exists
        XCTAssertNotNil(sut.getOverview())
        XCTAssertNotNil(sut.getPlanStatus())
        XCTAssertNotNil(sut.getWeeklyPlan(planId: "plan_123_1"))
        XCTAssertNotNil(sut.getWeeklyPlan(planId: "plan_123_2"))

        // When
        sut.clearAll()

        // Then
        XCTAssertNil(sut.getOverview(), "Overview should be nil after clearAll")
        XCTAssertNil(sut.getPlanStatus(), "Plan status should be nil after clearAll")
        XCTAssertNil(sut.getWeeklyPlan(planId: "plan_123_1"), "Weekly plan 1 should be nil after clearAll")
        XCTAssertNil(sut.getWeeklyPlan(planId: "plan_123_2"), "Weekly plan 2 should be nil after clearAll")
    }

    func test_getCacheSize_shouldReturnTotalBytes() {
        // Given
        sut.saveOverview(TrainingPlanTestFixtures.trainingOverview)
        sut.savePlanStatus(TrainingPlanTestFixtures.planStatusWithPlan)
        sut.saveWeeklyPlan(TrainingPlanTestFixtures.weeklyPlan1, planId: "plan_123_1")

        // When
        let cacheSize = sut.getCacheSize()

        // Then
        XCTAssertGreaterThan(cacheSize, 0, "Cache size should be greater than 0 when data is saved")
    }

    func test_getCacheSize_whenEmpty_shouldReturnZero() {
        // When
        let cacheSize = sut.getCacheSize()

        // Then
        XCTAssertEqual(cacheSize, 0, "Cache size should be 0 when no data is saved")
    }

    // MARK: - Corrupted Data Tests

    func test_getWeeklyPlan_withCorruptedData_shouldReturnNilAndClearCorruptedData() {
        // Given - manually set corrupted data
        let key = "weekly_plan_v2_corrupted_plan"
        mockDefaults.set("not valid json".data(using: .utf8), forKey: key)
        mockDefaults.set(Date(), forKey: key + "_timestamp")

        // When
        let retrieved = sut.getWeeklyPlan(planId: "corrupted_plan")

        // Then
        XCTAssertNil(retrieved, "Should return nil for corrupted data")
        // Corrupted data should be cleared
        XCTAssertNil(mockDefaults.data(forKey: key), "Corrupted data should be cleared")
    }

    // MARK: - Cacheable Protocol Tests

    func test_clearCache_shouldClearAllData() {
        // Given
        sut.saveOverview(TrainingPlanTestFixtures.trainingOverview)
        sut.savePlanStatus(TrainingPlanTestFixtures.planStatusWithPlan)

        // When
        sut.clearCache()

        // Then
        XCTAssertNil(sut.getOverview())
        XCTAssertNil(sut.getPlanStatus())
    }

    func test_isExpired_whenFreshData_shouldReturnFalse() {
        // Given
        sut.saveOverview(TrainingPlanTestFixtures.trainingOverview)
        sut.savePlanStatus(TrainingPlanTestFixtures.planStatusWithPlan)

        // When
        let isExpired = sut.isExpired()

        // Then
        XCTAssertFalse(isExpired, "Should not be expired when fresh data exists")
    }

    func test_isExpired_whenNoData_shouldReturnTrue() {
        // When
        let isExpired = sut.isExpired()

        // Then
        XCTAssertTrue(isExpired, "Should be expired when no data exists")
    }

    func test_cacheIdentifier_shouldReturnExpectedValue() {
        // When
        let identifier = sut.cacheIdentifier

        // Then
        XCTAssertEqual(identifier, "training_plan_local", "Cache identifier should match expected value")
    }
}
