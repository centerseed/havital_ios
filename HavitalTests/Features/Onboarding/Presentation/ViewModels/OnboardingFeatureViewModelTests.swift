//
//  OnboardingFeatureViewModelTests.swift
//  HavitalTests
//

import XCTest
import Combine
@testable import paceriz_dev

@MainActor
final class OnboardingFeatureViewModelTests: XCTestCase {
    
    var sut: OnboardingFeatureViewModel!
    var mockUserProfileRepository: MockUserProfileRepository!
    var mockTargetRepository: MockTargetRepository!
    var mockTrainingPlanRepository: MockTrainingPlanRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize Mocks
        mockUserProfileRepository = MockUserProfileRepository()
        mockTargetRepository = MockTargetRepository()
        mockTrainingPlanRepository = MockTrainingPlanRepository()
        
        // Initialize ViewModel with Mocks
        sut = OnboardingFeatureViewModel(
            userProfileRepository: mockUserProfileRepository,
            targetRepository: mockTargetRepository,
            trainingPlanRepository: mockTrainingPlanRepository
        )
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "onboarding_hasPersonalBest")
    }
    
    override func tearDown() async throws {
        sut = nil
        mockUserProfileRepository = nil
        mockTargetRepository = nil
        mockTrainingPlanRepository = nil
        UserDefaults.standard.removeObject(forKey: "onboarding_hasPersonalBest")
        try await super.tearDown()
    }
    
    // MARK: - Personal Best Tests
    
    func testLoadPersonalBests_Success() async {
        // Given
        let mockPB = PersonalBestRecordV2(
            completeTime: 1800, // 30 mins
            pace: "5:00",
            recordedAt: "2023-01-01T00:00:00Z",
            workoutDate: "2023-01-01",
            workoutId: "manual_123"
        )
        // Construct User with Mock PB via JSON
        // Using a helper or fixture would be better but explicit JSON here tests specific structure
        let mockProfile = createUser(personalBestV2: ["race_run": ["5": [mockPB]]])
        mockUserProfileRepository.userToReturn = mockProfile
        
        // When
        await sut.loadPersonalBests()
        
        // Then
        XCTAssertEqual(sut.availablePersonalBests.count, 1)
        XCTAssertEqual(sut.availablePersonalBests["5"]?.first?.completeTime, 1800)
    }
    
    func testSelectPersonalBest_UpdatesState() {
        // Given
        let mockPB = PersonalBestRecordV2(
            completeTime: 1800, // 30 mins -> 0h 30m 0s
            pace: "5:00",
            recordedAt: "2023-01-01T00:00:00Z",
            workoutDate: "2023-01-01",
            workoutId: "manual_123"
        )
        sut.availablePersonalBests = ["5": [mockPB]]
        
        // When
        sut.selectPersonalBest(distanceKey: "5")
        
        // Then
        XCTAssertEqual(sut.selectedPBDistance, "5")
        XCTAssertEqual(sut.personalBestHours, 0)
        XCTAssertEqual(sut.personalBestMinutes, 30)
        XCTAssertEqual(sut.personalBestSeconds, 0)
    }
    
    func testUpdatePersonalBest_Success() async {
        // Given
        sut.hasPersonalBest = true
        sut.personalBestHours = 0
        sut.personalBestMinutes = 25
        sut.personalBestSeconds = 0
        sut.selectedPBDistance = "5"
        
        // Success case is default behavior of mock
        // mockUserProfileRepository.updatePersonalBestResult = .success(())
        
        // When
        let result = await sut.updatePersonalBest()
        
        // Then
        XCTAssertTrue(result)
        XCTAssertNil(sut.error)
        XCTAssertEqual(mockUserProfileRepository.updatePersonalBestCallCount, 1)
    }
    
    func testUpdatePersonalBest_InvalidTime() async {
        // Given
        sut.hasPersonalBest = true
        sut.personalBestHours = 0
        sut.personalBestMinutes = 0
        sut.personalBestSeconds = 0
        
        // When
        let result = await sut.updatePersonalBest()
        
        // Then
        XCTAssertFalse(result)
        XCTAssertNotNil(sut.error)
        XCTAssertEqual(mockUserProfileRepository.updatePersonalBestCallCount, 0)
    }
    
    // MARK: - Weekly Distance Tests
    
    func testSaveWeeklyDistance_Success() async {
        // Given
        sut.weeklyDistance = 25.0
        // Success case is default behavior of mock
        // mockUserProfileRepository.updateUserProfileResult = .success(())
        
        // When
        let result = await sut.saveWeeklyDistance()
        
        // Then
        XCTAssertTrue(result)
        XCTAssertNil(sut.error)
        XCTAssertEqual(mockUserProfileRepository.updateUserProfileCallCount, 1)
    }
    
    func testDetermineNextStep_NoHistory_ReturnsGoalType() {
        // Given
        UserDefaults.standard.set(false, forKey: "onboarding_hasPersonalBest")
        sut.weeklyDistance = 0
        
        // When
        let nextStep = sut.determineNextStepAfterWeeklyDistance()
        
        // Then
        XCTAssertEqual(nextStep, .goalType)
    }
    
    func testDetermineNextStep_HasHistory_ReturnsRaceSetup() {
        // Given
        UserDefaults.standard.set(true, forKey: "onboarding_hasPersonalBest")
        sut.weeklyDistance = 20
        
        // When
        let nextStep = sut.determineNextStepAfterWeeklyDistance()
        
        // Then
        XCTAssertEqual(nextStep, .raceSetup)
    }
    
    // MARK: - Goal Type Tests
    
    func testCreateBeginner5kGoal_Success() async {
        // Given
        // Success case is default behavior of mock
        // mockTargetRepository.createTargetResult = .success(())
        
        // When
        let result = await sut.createBeginner5kGoal()
        
        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(sut.isBeginner)
        XCTAssertNil(sut.error)
        XCTAssertEqual(mockTargetRepository.createTargetCallCount, 1)
    }
    
    // MARK: - Training Days Tests
    
    func testLoadTrainingDayPreferences_Success() async {
        // Given
        let mockProfile = createUser(preferWeekDays: [1, 3, 5], preferWeekDaysLongrun: [6])
        mockUserProfileRepository.userToReturn = mockProfile
        
        // When
        await sut.loadTrainingDayPreferences()
        
        // Then
        XCTAssertEqual(sut.selectedWeekdays, [1, 3, 5])
        XCTAssertEqual(sut.selectedLongRunDay, 6)
    }
    
    func testSaveTrainingDays_ValidationFailure() async {
        // Given
        sut.selectedWeekdays = [] // Empty selection
        
        // When
        let result = await sut.saveTrainingDaysAndGenerateOverview(startFromStage: nil)
        
        // Then
        XCTAssertFalse(result)
        XCTAssertNotNil(sut.error)
        XCTAssertEqual(mockUserProfileRepository.updateUserProfileCallCount, 0)
    }
    
    func testSaveTrainingDays_Success() async {
        // Given
        sut.selectedWeekdays = [1, 3, 5, 6]
        sut.selectedLongRunDay = 6
        
        // Success case is default behavior of mock
        // mockUserProfileRepository.updateUserProfileResult = .success(())
        
        let mockOverview = TrainingPlanOverview(
            id: "plan_id",
            mainRaceId: "race_id",
            targetEvaluate: "Good",
            totalWeeks: 12,
            trainingHighlight: "Highlight",
            trainingPlanName: "Test Plan",
            trainingStageDescription: [],
            createdAt: "2024-01-01"
        )
        mockTrainingPlanRepository.createOverviewResult = .success(mockOverview)
        
        // When
        let result = await sut.saveTrainingDaysAndGenerateOverview(startFromStage: nil)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(sut.trainingOverview?.id, "plan_id")
        XCTAssertEqual(mockUserProfileRepository.updateUserProfileCallCount, 1)
        XCTAssertEqual(mockTrainingPlanRepository.createOverviewCallCount, 1)
    }

    // MARK: - Helpers
    
    private func createUser(preferWeekDays: [Int]? = nil, preferWeekDaysLongrun: [Int]? = nil, personalBestV2: [String: [String: [PersonalBestRecordV2]]]? = nil) -> User {
        // Encoder not available for User (Codable), but we can decode from JSON
        // Constructing Dictionary to encode then decode seems easiest to rely on CodingKeys
        var dict: [String: Any] = [
            "display_name": "Test User",
            "email": "test@example.com",
            "max_hr": 190,
            "relaxing_hr": 60,
            "current_week_distance": 25,
            "data_source": "apple_health"
        ]
        
        if let preferWeekDays = preferWeekDays {
            dict["prefer_week_days"] = preferWeekDays
        }
        if let preferWeekDaysLongrun = preferWeekDaysLongrun {
            dict["prefer_week_days_longrun"] = preferWeekDaysLongrun
        }
        
        if let personalBestV2 = personalBestV2 {
            // Need to convert [String: [String: [PersonalBestRecordV2]]] to JSON object
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(personalBestV2),
               let jsonObject = try? JSONSerialization.jsonObject(with: data) {
                dict["personal_best_v2"] = jsonObject
            }
        }
        
        let data = try! JSONSerialization.data(withJSONObject: dict)
        return try! JSONDecoder().decode(User.self, from: data)
    }
}
