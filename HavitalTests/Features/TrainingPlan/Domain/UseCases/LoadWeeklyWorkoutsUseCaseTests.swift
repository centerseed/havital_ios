//
//  LoadWeeklyWorkoutsUseCaseTests.swift
//  HavitalTests
//

import XCTest
@testable import paceriz_dev

final class LoadWeeklyWorkoutsUseCaseTests: XCTestCase {
    
    var sut: LoadWeeklyWorkoutsUseCase!
    var mockWorkoutRepository: MockWorkoutRepository!
    
    override func setUp() {
        super.setUp()
        mockWorkoutRepository = MockWorkoutRepository()
        sut = LoadWeeklyWorkoutsUseCase(workoutRepository: mockWorkoutRepository)
    }
    
    override func tearDown() {
        sut = nil
        mockWorkoutRepository = nil
        super.tearDown()
    }
    
    func testExecute_ReturnsGroupedWorkouts() async {
        // Given
        let startDate = Date(timeIntervalSince1970: 1704067200) // 2024-01-01 (Monday)
        let endDate = Date(timeIntervalSince1970: 1704671999)   // 2024-01-07 (Sunday)
        
        var daysMap: [Int: Date] = [:]
        for i in 1...7 {
            daysMap[i] = startDate.addingTimeInterval(Double(i-1) * 86400)
        }
        
        let weekInfo = WeekDateInfo(startDate: startDate, endDate: endDate, daysMap: daysMap)
        
        let workout1 = createWorkout(id: "1", date: "2024-01-01T12:00:00Z", type: "running") // Mon
        let workout2 = createWorkout(id: "2", date: "2024-01-03T12:00:00Z", type: "running") // Wed
        let workout3 = createWorkout(id: "3", date: "2024-01-03T14:00:00Z", type: "running") // Wed (later)
        
        mockWorkoutRepository.workoutsToReturn = [workout1, workout2, workout3]
        
        // When
        let result = sut.execute(weekInfo: weekInfo)
        
        // Then
        XCTAssertEqual(mockWorkoutRepository.getWorkoutsInDateRangeCallCount, 1)
        XCTAssertEqual(result.count, 2) // Mon and Wed
        XCTAssertEqual(result[1]?.count, 1) // Mon: 1 workout
        XCTAssertEqual(result[3]?.count, 2) // Wed: 2 workouts
        
        // Verify sorting (latest first)
        XCTAssertEqual(result[3]?.first?.id, "3")
        XCTAssertEqual(result[3]?.last?.id, "2")
    }
    
    func testExecute_FiltersActivityTypes() async {
        // Given
        let startDate = Date(timeIntervalSince1970: 1704067200) // 2024-01-01
        let endDate = Date(timeIntervalSince1970: 1704671999)
        var daysMap: [Int: Date] = [:]
        for i in 1...7 { daysMap[i] = startDate.addingTimeInterval(Double(i-1) * 86400) }
        let weekInfo = WeekDateInfo(startDate: startDate, endDate: endDate, daysMap: daysMap)
        
        let run = createWorkout(id: "1", date: "2024-01-01T10:00:00Z", type: "running")
        let swim = createWorkout(id: "2", date: "2024-01-02T10:00:00Z", type: "swimming")
        
        mockWorkoutRepository.workoutsToReturn = [run, swim]
        
        // When
        let result = sut.execute(weekInfo: weekInfo, activityTypes: ["running"])
        
        // Then
        XCTAssertEqual(result.count, 1)
        XCTAssertNotNil(result[1])
        XCTAssertNil(result[2])
    }
    
    func testExecute_EmptyRepository_ReturnsEmpty() async {
        // Given
        let startDate = Date()
        let weekInfo = WeekDateInfo(startDate: startDate, endDate: startDate.addingTimeInterval(86400*7), daysMap: [:])
        mockWorkoutRepository.workoutsToReturn = []
        
        // When
        let result = sut.execute(weekInfo: weekInfo)
        
        // Then
        XCTAssertTrue(result.isEmpty)
    }
    
    // MARK: - Helper
    
    private func createWorkout(id: String, date: String, type: String) -> WorkoutV2 {
        return WorkoutV2(
            id: id,
            provider: "manual",
            activityType: type,
            startTimeUtc: date,
            endTimeUtc: date, // Simplify for test
            durationSeconds: 3600,
            distanceMeters: 5000,
            deviceName: "Garmin",
            basicMetrics: nil,
            advancedMetrics: nil,
            createdAt: date,
            schemaVersion: "2.0",
            storagePath: nil,
            dailyPlanSummary: nil,
            aiSummary: nil,
            shareCardContent: nil
        )
    }
}
