//
//  AggregateWorkoutMetricsUseCaseTests.swift
//  HavitalTests
//
//  Unit tests for AggregateWorkoutMetricsUseCase
//

import XCTest
@testable import paceriz_dev

final class AggregateWorkoutMetricsUseCaseTests: XCTestCase {
    
    var sut: AggregateWorkoutMetricsUseCase!
    var mockRepository: MockWorkoutRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockWorkoutRepository()
        sut = AggregateWorkoutMetricsUseCase(workoutRepository: mockRepository)
    }
    
    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }
    
    func testExecute_CalculatesTotalDistanceCorrectly() {
        // Given
        let workout1 = TrainingPlanTestFixtures.createWorkout(
            activityType: "running",
            distanceMeters: 5000
        )
        let workout2 = TrainingPlanTestFixtures.createWorkout(
            activityType: "running",
            distanceMeters: 3500
        )
        // Cycling should be included in load/metrics usually, but let's check distance calculation logic.
        // UseCase says: calculateTotalDistance filters for "running" only.
        let workout3 = TrainingPlanTestFixtures.createWorkout(
            activityType: "cycling",
            distanceMeters: 20000
        )
        
        mockRepository.workoutsToReturn = [workout1, workout2, workout3]
        
        let weekInfo = WeekDateInfo(
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7),
            daysMap: [:]
        )
        
        // When
        let result = sut.execute(weekInfo: weekInfo)
        
        // Then
        // 5000 + 3500 = 8500m = 8.5km (cycling excluded from distance sum based on code)
        XCTAssertEqual(result.totalDistanceKm, 8.5, accuracy: 0.01)
    }
    
    func testExecute_CalculatesIntensityFromAdvancedMetrics() {
        // Given
        let workout1 = TrainingPlanTestFixtures.createWorkout(
            intensityMinutes: (low: 10, medium: 20, high: 0)
        ) // 10, 20, 0
        
        let workout2 = TrainingPlanTestFixtures.createWorkout(
            intensityMinutes: (low: 5, medium: 5, high: 10)
        ) // 5, 5, 10
        
        mockRepository.workoutsToReturn = [workout1, workout2]
        let weekInfo = WeekDateInfo(startDate: Date(), endDate: Date(), daysMap: [:])
        
        // When
        let result = sut.execute(weekInfo: weekInfo)
        
        // Then
        XCTAssertEqual(result.intensity.low, 15, accuracy: 0.01)
        XCTAssertEqual(result.intensity.medium, 25, accuracy: 0.01)
        XCTAssertEqual(result.intensity.high, 10, accuracy: 0.01)
    }
    
    func testExecute_CalculatesIntensityFromDuration_WhenMetricsMissing() {
        // Given
        // No advanced metrics, fallback to duration (minutes) added to 'low'
        let workout1 = TrainingPlanTestFixtures.createWorkout(
            durationSeconds: 1800 // 30 mins
        )
        
        mockRepository.workoutsToReturn = [workout1]
        let weekInfo = WeekDateInfo(startDate: Date(), endDate: Date(), daysMap: [:])
        
        // When
        let result = sut.execute(weekInfo: weekInfo)
        
        // Then
        XCTAssertEqual(result.intensity.low, 30, accuracy: 0.01)
        XCTAssertEqual(result.intensity.medium, 0)
        XCTAssertEqual(result.intensity.high, 0)
    }
    
    func testExecute_ExcludesNonAerobicActivitiesFromIntensity() {
        // Given
        let workout1 = TrainingPlanTestFixtures.createWorkout(
            activityType: "running",
            durationSeconds: 1800
        )
        let workout2 = TrainingPlanTestFixtures.createWorkout(
            activityType: "yoga", // likely not in aerobic list
            durationSeconds: 3600
        )
        
        mockRepository.workoutsToReturn = [workout1, workout2]
        let weekInfo = WeekDateInfo(startDate: Date(), endDate: Date(), daysMap: [:])
        
        // When
        let result = sut.execute(weekInfo: weekInfo)
        
        // Then
        // Only running included: 30 mins low
        XCTAssertEqual(result.intensity.low, 30, accuracy: 0.01)
    }
    
    func testExecute_HandlesEmptyWorkouts() {
        // Given
        mockRepository.workoutsToReturn = []
        let weekInfo = WeekDateInfo(startDate: Date(), endDate: Date(), daysMap: [:])
        
        // When
        let result = sut.execute(weekInfo: weekInfo)
        
        // Then
        XCTAssertEqual(result.totalDistanceKm, 0)
        XCTAssertEqual(result.intensity.low, 0)
        XCTAssertEqual(result.intensity.medium, 0)
        XCTAssertEqual(result.intensity.high, 0)
    }
}
