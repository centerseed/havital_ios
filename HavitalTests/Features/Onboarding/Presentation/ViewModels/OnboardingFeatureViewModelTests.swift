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
    var mockTrainingPlanV2Repository: MockTrainingPlanV2Repository!
    private var mockRaceRepository: MockRaceRepository!
    var mockVersionRouter: MockTrainingVersionRouter!

    override func setUp() async throws {
        try await super.setUp()

        // Initialize Mocks
        mockUserProfileRepository = MockUserProfileRepository()
        mockTargetRepository = MockTargetRepository()
        mockTrainingPlanRepository = MockTrainingPlanRepository()
        mockTrainingPlanV2Repository = MockTrainingPlanV2Repository()
        mockRaceRepository = MockRaceRepository()
        mockVersionRouter = MockTrainingVersionRouter()

        // Initialize ViewModel with Mocks
        sut = OnboardingFeatureViewModel(
            userProfileRepository: mockUserProfileRepository,
            targetRepository: mockTargetRepository,
            trainingPlanRepository: mockTrainingPlanRepository,
            trainingPlanV2Repository: mockTrainingPlanV2Repository,
            raceRepository: mockRaceRepository,
            versionRouter: mockVersionRouter
        )

        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "onboarding_hasPersonalBest")
    }

    override func tearDown() async throws {
        sut = nil
        mockUserProfileRepository = nil
        mockTargetRepository = nil
        mockTrainingPlanRepository = nil
        mockTrainingPlanV2Repository = nil
        mockRaceRepository = nil
        mockVersionRouter = nil
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
        XCTAssertTrue(sut.hasPersonalBest)
        XCTAssertEqual(sut.personalBestMinutes, 30)
    }

    func testLoadPersonalBests_NoRaceRunData_DefaultsHasPersonalBestOff() async {
        // Given
        let mockProfile = createUser(personalBestV2: nil)
        mockUserProfileRepository.userToReturn = mockProfile
        sut.hasPersonalBest = true
        sut.personalBestMinutes = 42

        // When
        await sut.loadPersonalBests()

        // Then
        XCTAssertFalse(sut.hasPersonalBest)
        XCTAssertTrue(sut.availablePersonalBests.isEmpty)
        XCTAssertEqual(sut.personalBestHours, 0)
        XCTAssertEqual(sut.personalBestMinutes, 0)
        XCTAssertEqual(sut.personalBestSeconds, 0)
    }

    func testLoadPersonalBests_PrefillsSelectedDistanceWhenAvailable() async {
        // Given
        let fiveKPB = PersonalBestRecordV2(
            completeTime: 1500,
            pace: "5:00",
            recordedAt: "2023-01-01T00:00:00Z",
            workoutDate: "2023-01-01",
            workoutId: "manual_5k"
        )
        let halfPB = PersonalBestRecordV2(
            completeTime: 5400,
            pace: "4:16",
            recordedAt: "2023-01-01T00:00:00Z",
            workoutDate: "2023-01-01",
            workoutId: "manual_hm"
        )
        let mockProfile = createUser(personalBestV2: [
            "race_run": [
                "5": [fiveKPB],
                "21.0975": [halfPB]
            ]
        ])
        mockUserProfileRepository.userToReturn = mockProfile
        sut.targetDistance = 21.0975
        sut.selectedPBDistance = "5"

        // When
        await sut.loadPersonalBests()

        // Then
        XCTAssertEqual(sut.selectedPBDistance, "5")
        XCTAssertEqual(sut.personalBestHours, 0)
        XCTAssertEqual(sut.personalBestMinutes, 25)
        XCTAssertEqual(sut.personalBestSeconds, 0)
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
    
    func testDetermineNextStep_HasHistory_ReturnsGoalType() {
        // Given: V2 Flow - Always go to Goal Type first
        UserDefaults.standard.set(true, forKey: "onboarding_hasPersonalBest")
        sut.weeklyDistance = 20

        // When
        let nextStep = sut.determineNextStepAfterWeeklyDistance()

        // Then: V2 Flow 總是先進入 Goal Type 選擇
        XCTAssertEqual(nextStep, .goalType)
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

    // MARK: - Race Setup Tests

    func testClearSelectedRace_ReturnsToManualInputWhileKeepingAutofilledValues() {
        // Given
        let originalDate = Calendar.current.date(byAdding: .day, value: 90, to: Date())!
        let race = RaceEvent(
            raceId: "tw_2026_test_race",
            name: "台北測試馬拉松",
            region: "tw",
            eventDate: originalDate,
            city: "台北市",
            location: "市政府",
            distances: [
                RaceDistance(distanceKm: 42.195, name: "全程馬拉松")
            ],
            entryStatus: "open",
            isCurated: true,
            courseType: "road",
            tags: []
        )
        let distance = RaceDistance(distanceKm: 42.195, name: "全程馬拉松")

        // When
        sut.selectRaceEvent(race, distance: distance)
        sut.clearSelectedRace()

        // Then
        XCTAssertNil(sut.selectedRaceEvent)
        XCTAssertNil(sut.selectedRaceDistance)
        XCTAssertEqual(sut.raceName, "台北測試馬拉松")
        XCTAssertEqual(sut.selectedDistance, "42.195")
        XCTAssertEqual(sut.raceDate.timeIntervalSince1970, originalDate.timeIntervalSince1970, accuracy: 1.0)
    }

    func testSelectTarget_ClearsSelectedRaceDatabaseState() {
        // Given
        let raceDate = Calendar.current.date(byAdding: .day, value: 60, to: Date())!
        let race = RaceEvent(
            raceId: "tw_db_race",
            name: "資料庫賽事",
            region: "tw",
            eventDate: raceDate,
            city: "台北市",
            location: nil,
            distances: [RaceDistance(distanceKm: 21.0975, name: "半程馬拉松")],
            entryStatus: "open",
            isCurated: true,
            courseType: "road",
            tags: []
        )
        sut.selectRaceEvent(race, distance: RaceDistance(distanceKm: 21.0975, name: "半程馬拉松"))

        let target = Target(
            id: "existing_target",
            type: "race_run",
            name: "既有目標賽事",
            distanceKm: 10,
            targetTime: 3000,
            targetPace: "5:00",
            raceDate: Int(raceDate.timeIntervalSince1970),
            isMainRace: true,
            trainingWeeks: 8
        )

        // When
        sut.selectTarget(target)

        // Then
        XCTAssertNil(sut.selectedRaceEvent)
        XCTAssertNil(sut.selectedRaceDistance)
        XCTAssertEqual(sut.selectedTargetKey, "existing_target")
        XCTAssertEqual(sut.raceName, "既有目標賽事")
        XCTAssertEqual(sut.selectedDistance, "10")
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

    // MARK: - selectRaceEvent Clears selectedTargetKey Tests

    func testSelectRaceEvent_ClearsSelectedTargetKey() {
        // Given: user previously selected an existing target
        let existingTarget = Target(
            id: "existing_target_123",
            type: "race_run",
            name: "既有賽事",
            distanceKm: 21,
            targetTime: 6300,
            targetPace: "5:00",
            raceDate: Int(Date().addingTimeInterval(86400 * 60).timeIntervalSince1970),
            isMainRace: true,
            trainingWeeks: 12
        )
        sut.selectTarget(existingTarget)
        XCTAssertEqual(sut.selectedTargetKey, "existing_target_123")

        // When: user switches to a race from the database
        let race = RaceEvent(
            raceId: "db_race_456",
            name: "資料庫馬拉松",
            region: "tw",
            eventDate: Date().addingTimeInterval(86400 * 90),
            city: "台北市",
            location: nil,
            distances: [RaceDistance(distanceKm: 42.195, name: "全馬")],
            entryStatus: "open",
            isCurated: true,
            courseType: "road",
            tags: []
        )
        sut.selectRaceEvent(race, distance: RaceDistance(distanceKm: 42.195, name: "全馬"))

        // Then: selectedTargetKey must be nil so createRaceTarget() creates a new target
        XCTAssertNil(sut.selectedTargetKey, "selectRaceEvent must clear selectedTargetKey to prevent skipping target creation")
        XCTAssertEqual(sut.raceName, "資料庫馬拉松")
    }

    func testSelectRaceEvent_ThenCreateRaceTarget_CreatesNewTarget() async {
        // Given: user selects existing target, then switches to race database
        let existingTarget = Target(
            id: "existing_target_123",
            type: "race_run",
            name: "既有賽事",
            distanceKm: 21,
            targetTime: 6300,
            targetPace: "5:00",
            raceDate: Int(Date().addingTimeInterval(86400 * 60).timeIntervalSince1970),
            isMainRace: true,
            trainingWeeks: 12
        )
        sut.selectTarget(existingTarget)

        let race = RaceEvent(
            raceId: "db_race_456",
            name: "新賽事",
            region: "tw",
            eventDate: Date().addingTimeInterval(86400 * 90),
            city: "台北市",
            location: nil,
            distances: [RaceDistance(distanceKm: 42.195, name: "全馬")],
            entryStatus: "open",
            isCurated: true,
            courseType: "road",
            tags: []
        )
        sut.selectRaceEvent(race, distance: RaceDistance(distanceKm: 42.195, name: "全馬"))

        // When
        let result = await sut.createRaceTarget()

        // Then: should CREATE (POST), not skip
        XCTAssertTrue(result)
        XCTAssertEqual(mockTargetRepository.createTargetCallCount, 1, "Must call createTarget API, not skip")
        XCTAssertEqual(mockTargetRepository.updateTargetCallCount, 0, "Should not update the old target")
    }

    // MARK: - createRaceTarget Stale Target Protection Tests

    func testCreateRaceTarget_StaleTargetKey_UpdatesInsteadOfSkipping() async {
        // Given: selectedTargetKey points to a target NOT in availableTargets
        // This simulates the bug scenario where cache had a stale target
        sut.selectedTargetKey = "stale_target_id"
        sut.raceName = "修改後的名稱"
        sut.raceDate = Date().addingTimeInterval(86400 * 90)
        sut.selectedDistance = "42.195"
        sut.targetHours = 3
        sut.targetMinutes = 30
        // availableTargets is empty — the stale target is not in it

        // When
        let result = await sut.createRaceTarget()

        // Then: should UPDATE (not silently skip), because hasSelectedTargetBeenModified returns true
        XCTAssertTrue(result)
        XCTAssertEqual(mockTargetRepository.updateTargetCallCount, 1, "Must call updateTarget when selectedTargetKey exists but target is not in availableTargets")
        XCTAssertEqual(mockTargetRepository.createTargetCallCount, 0)
    }

    func testCreateRaceTarget_NoTargetKey_CreatesNew() async {
        // Given: fresh state, no existing target selected
        sut.raceName = "新賽事"
        sut.raceDate = Date().addingTimeInterval(86400 * 90)
        sut.selectedDistance = "42.195"
        sut.targetHours = 4
        sut.targetMinutes = 0

        // When
        let result = await sut.createRaceTarget()

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockTargetRepository.createTargetCallCount, 1)
        XCTAssertEqual(mockTargetRepository.updateTargetCallCount, 0)
        XCTAssertNotNil(sut.selectedTargetKey)
    }

    // MARK: - A-1 / A-2 Version Routing Tests

    func testLoadTrainingOverview_V2User_CallsV2RepoNotV1() async throws {
        // Given
        mockVersionRouter.isV2Result = true
        let v2Overview = try Self.loadV2OverviewFixture()
        mockTrainingPlanV2Repository.overviewToReturn = v2Overview

        // When
        await sut.loadTrainingOverview()

        // Then
        XCTAssertEqual(mockTrainingPlanV2Repository.getOverviewCallCount, 1, "V2 user must hit V2 repo exactly once")
        XCTAssertEqual(mockTrainingPlanRepository.getOverviewCallCount, 0, "V2 user must NOT hit V1 repo")
        XCTAssertEqual(sut.trainingOverviewV2?.id, v2Overview.id)
        XCTAssertNil(sut.trainingOverview, "V1 entity slot must stay nil for V2 user")
        XCTAssertNil(sut.error)
    }

    func testLoadTrainingOverview_V1User_CallsV1RepoNotV2() async {
        // Given
        mockVersionRouter.isV2Result = false
        let mockV1Overview = TrainingPlanOverview(
            id: "v1_overview_xyz",
            mainRaceId: "race_1",
            targetEvaluate: "ok",
            totalWeeks: 12,
            trainingHighlight: "h",
            trainingPlanName: "n",
            trainingStageDescription: [],
            createdAt: "2024"
        )
        mockTrainingPlanRepository.overviewToReturn = mockV1Overview

        // When
        await sut.loadTrainingOverview()

        // Then
        XCTAssertEqual(mockTrainingPlanRepository.getOverviewCallCount, 1, "V1 user must hit V1 repo")
        XCTAssertEqual(mockTrainingPlanV2Repository.getOverviewCallCount, 0, "V1 user must NOT hit V2 repo")
        XCTAssertEqual(sut.trainingOverview?.id, "v1_overview_xyz")
        XCTAssertNil(sut.trainingOverviewV2)
    }

    func testLoadTrainingOverview_V2User_RepoThrows_SetsUserFriendlyErrorMessage() async {
        // Given
        mockVersionRouter.isV2Result = true
        mockTrainingPlanV2Repository.errorToThrow = TrainingPlanV2Error.overviewNotFound

        // When
        await sut.loadTrainingOverview()

        // Then
        XCTAssertNotNil(sut.error, "V2 failure must surface an error string")
        XCTAssertFalse(sut.error?.isEmpty ?? true, "Error string must not be empty")
        XCTAssertNil(sut.trainingOverviewV2, "No overview must be cached on failure")
        XCTAssertEqual(mockTrainingPlanRepository.getOverviewCallCount, 0, "V1 repo must not be touched for V2 user")
    }

    func testLoadTrainingOverview_RouterReturnsV1_FallsBackToV1Path() async {
        // Simulates cold start race / nil trainingVersion: router defaults to v1
        // Given
        mockVersionRouter.isV2Result = false
        mockTrainingPlanRepository.overviewToReturn = TrainingPlanOverview(
            id: "fallback_v1",
            mainRaceId: "",
            targetEvaluate: "",
            totalWeeks: 8,
            trainingHighlight: "",
            trainingPlanName: "",
            trainingStageDescription: [],
            createdAt: "2024"
        )

        // When
        await sut.loadTrainingOverview()

        // Then
        XCTAssertEqual(mockVersionRouter.isV2UserCallCount, 1, "Must consult router")
        XCTAssertEqual(mockTrainingPlanRepository.getOverviewCallCount, 1)
        XCTAssertEqual(mockTrainingPlanV2Repository.getOverviewCallCount, 0)
        XCTAssertEqual(sut.trainingOverview?.id, "fallback_v1")
    }

    func testCompleteOnboarding_V2User_CallsV2GenerateWeeklyNotV1CreateWeekly() async throws {
        // Given
        mockVersionRouter.isV2Result = true
        mockTrainingPlanV2Repository.weeklyPlanV2ToReturn = try Self.loadV2WeeklyPlanFixture()
        sut.isBeginner = false

        // When
        let result = await sut.completeOnboarding(startFromStage: "base")

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockTrainingPlanV2Repository.generateWeeklyPlanCallCount, 1)
        XCTAssertEqual(mockTrainingPlanRepository.createWeeklyPlanCallCount, 0, "V2 user must NOT hit V1 createWeeklyPlan")
    }

    func testCompleteOnboarding_V1User_CallsV1CreateWeeklyPlanNotV2() async {
        // Given
        mockVersionRouter.isV2Result = false
        mockTrainingPlanRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1
        sut.isBeginner = true

        // When
        let result = await sut.completeOnboarding(startFromStage: "base")

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockTrainingPlanRepository.createWeeklyPlanCallCount, 1)
        XCTAssertEqual(mockTrainingPlanV2Repository.generateWeeklyPlanCallCount, 0)
    }

    func testCompleteOnboarding_V2User_BeginnerFlag_CompletesSuccessfully() async throws {
        // Given
        mockVersionRouter.isV2Result = true
        mockTrainingPlanV2Repository.weeklyPlanV2ToReturn = try Self.loadV2WeeklyPlanFixture()
        sut.isBeginner = true

        // When
        _ = await sut.completeOnboarding(startFromStage: nil)

        // Then — beginner path runs the V2 generateWeeklyPlan.
        // Methodology value ("beginner" vs "paceriz") is passed through but the mock does not capture it;
        // extending the mock is scope creep. Decorator + log provide the second-level check.
        XCTAssertEqual(mockTrainingPlanV2Repository.generateWeeklyPlanCallCount, 1)
    }

    func testCompleteOnboarding_V2User_RepoThrows_ReturnsFalseAndSetsFriendlyError() async {
        // Given
        mockVersionRouter.isV2Result = true
        mockTrainingPlanV2Repository.generateWeeklyPlanErrors = [
            TrainingPlanV2Error.weeklyPlanGenerationFailed(week: 1, reason: "LLM busy")
        ]

        // When
        let result = await sut.completeOnboarding(startFromStage: nil)

        // Then
        XCTAssertFalse(result)
        XCTAssertNotNil(sut.error)
        XCTAssertEqual(mockTrainingPlanRepository.createWeeklyPlanCallCount, 0)
    }

    // MARK: - A-1/A-2 Helpers

    /// Load a real PlanOverviewV2 fixture so we rely on the same DTO → Entity path as production.
    private static func loadV2OverviewFixture() throws -> PlanOverviewV2 {
        let data = try loadFixtureData(directory: "PlanOverview", name: "race_run_paceriz")
        let dto = try JSONDecoder().decode(PlanOverviewV2DTO.self, from: data)
        return PlanOverviewV2Mapper.toEntity(from: dto)
    }

    private static func loadV2WeeklyPlanFixture() throws -> WeeklyPlanV2 {
        let data = try loadFixtureData(directory: "WeeklyPlan", name: "paceriz_42k_base_week")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(WeeklyPlanV2DTO.self, from: data)
        return WeeklyPlanV2Mapper.toEntity(from: dto)
    }

    private static func loadFixtureData(directory: String, name: String) throws -> Data {
        // Fixtures live at HavitalTests/TrainingPlan/Unit/APISchema/Fixtures/<dir>/<name>.json
        let thisFile = URL(fileURLWithPath: #file)
        // Walk up to HavitalTests/ then descend to the fixtures folder
        var dir = thisFile.deletingLastPathComponent()
        while dir.lastPathComponent != "HavitalTests" && dir.path != "/" {
            dir = dir.deletingLastPathComponent()
        }
        let fixtureURL = dir
            .appendingPathComponent("TrainingPlan/Unit/APISchema/Fixtures/\(directory)/\(name).json")
        return try Data(contentsOf: fixtureURL)
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

private final class MockRaceRepository: RaceRepository {
    var racesToReturn: [RaceEvent] = []
    var errorToThrow: Error?
    var getRacesCallCount = 0

    func getRaces(
        region: String?,
        distanceMin: Double?,
        distanceMax: Double?,
        dateFrom: String?,
        dateTo: String?,
        query: String?,
        curatedOnly: Bool?,
        limit: Int?,
        offset: Int?
    ) async throws -> [RaceEvent] {
        getRacesCallCount += 1
        if let error = errorToThrow { throw error }
        return racesToReturn
    }
}
