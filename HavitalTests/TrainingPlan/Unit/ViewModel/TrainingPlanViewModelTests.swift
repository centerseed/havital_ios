//
//  TrainingPlanViewModelTests.swift
//  HavitalTests
//
//  Comprehensive unit tests for TrainingPlanViewModel - targeting 90%+ coverage
//

import XCTest
import Combine
@testable import paceriz_dev

@MainActor
final class TrainingPlanViewModelTests: XCTestCase {
    
    var sut: TrainingPlanViewModel!
    var mockRepository: MockTrainingPlanRepository!
    var mockWorkoutRepository: MockWorkoutRepository!
    var loadWeeklyWorkoutsUseCase: LoadWeeklyWorkoutsUseCase!
    var aggregateWorkoutMetricsUseCase: AggregateWorkoutMetricsUseCase!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockRepository = MockTrainingPlanRepository()
        mockWorkoutRepository = MockWorkoutRepository()
        loadWeeklyWorkoutsUseCase = LoadWeeklyWorkoutsUseCase(workoutRepository: mockWorkoutRepository)
        aggregateWorkoutMetricsUseCase = AggregateWorkoutMetricsUseCase(workoutRepository: mockWorkoutRepository)
        cancellables = Set<AnyCancellable>()
        
        sut = TrainingPlanViewModel(
            repository: mockRepository,
            workoutRepository: mockWorkoutRepository,
            loadWeeklyWorkoutsUseCase: loadWeeklyWorkoutsUseCase,
            aggregateWorkoutMetricsUseCase: aggregateWorkoutMetricsUseCase,
            weeklyPlanVM: WeeklyPlanViewModel(repository: mockRepository),
            summaryVM: WeeklySummaryViewModel(repository: mockRepository)
        )
    }
    
    override func tearDown() async throws {
        sut = nil
        mockRepository = nil
        mockWorkoutRepository = nil
        loadWeeklyWorkoutsUseCase = nil
        aggregateWorkoutMetricsUseCase = nil
        cancellables = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialize_WithViewPlanAction_LoadsAllData() async {
        // Given
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusWithPlan
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1
        
        // When
        await sut.initialize()
        
        // Then
        XCTAssertEqual(mockRepository.getPlanStatusCallCount, 1)
        XCTAssertEqual(mockRepository.getOverviewCallCount, 1)
        XCTAssertEqual(mockRepository.getWeeklyPlanCallCount, 1)
        
        if case .ready(let plan) = sut.planStatus {
            XCTAssertEqual(plan.id, "plan_123_1")
        } else {
            XCTFail("Expected planStatus to be .ready")
        }
    }
    
    func testInitialize_NoStatus_SetsNoPlan() async {
        // Given
        mockRepository.errorToThrow = TrainingPlanError.invalidPlanStatus
        
        // When
        await sut.initialize()
        
        // Then
        XCTAssertEqual(sut.planStatus, .noPlan)
    }
    
    func testInitialize_CreatePlanAction_SetsNoPlan() async {
        // Given
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusNeedCreate
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        
        // When
        await sut.initialize()
        
        // Then
        XCTAssertEqual(sut.planStatus, .noPlan)
        XCTAssertEqual(mockRepository.getWeeklyPlanCallCount, 0) // No plan loaded
    }
    
    // MARK: - fetchWeekPlan Tests
    
    func testFetchWeekPlan_Success_UpdatesStatus() async {
        // Given - setup overview first
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1
        sut.weeklyPlanVM.overviewState = .loaded(TrainingPlanTestFixtures.trainingOverview)
        
        // When
        await sut.fetchWeekPlan(week: 1)
        
        // Then
        if case .ready(let plan) = sut.planStatus {
            XCTAssertEqual(plan.weekOfPlan, 1)
        } else {
            XCTFail("Expected planStatus to be .ready")
        }
    }
    
    func testFetchWeekPlan_Error_UpdatesErrorStatus() async {
        // Given
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.errorToThrow = TrainingPlanError.weeklyPlanNotFound(planId: "test")
        sut.weeklyPlanVM.overviewState = .loaded(TrainingPlanTestFixtures.trainingOverview)
        
        // When
        await sut.fetchWeekPlan(week: 1)
        
        // Then
        XCTAssertEqual(sut.planStatus, .noPlan)
    }
    
    // MARK: - loadPlanStatus Tests
    
    func testLoadPlanStatus_Success_UpdatesState() async {
        // Given
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusWithPlan
        
        // When
        await sut.loadPlanStatus()
        
        // Then
        XCTAssertNotNil(sut.planStatusResponse)
        XCTAssertEqual(sut.planStatusResponse?.currentWeek, 1)
        XCTAssertEqual(mockRepository.getPlanStatusCallCount, 1)
    }
    
    func testLoadPlanStatus_SkipCache_RefreshesPlanStatus() async {
        // Given
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusWithPlan
        
        // When
        await sut.loadPlanStatus(skipCache: true)
        
        // Then
        XCTAssertEqual(mockRepository.refreshPlanStatusCallCount, 1)
        XCTAssertEqual(mockRepository.getPlanStatusCallCount, 0)
    }
    
    func testLoadPlanStatus_Error_SetsNetworkError() async {
        // Given
        let testError = NSError(domain: "test", code: -1)
        mockRepository.errorToThrow = testError
        
        // When
        await sut.loadPlanStatus()
        
        // Then
        XCTAssertNotNil(sut.networkError)
    }
    
    // MARK: - refreshWeeklyPlan Tests
    
    func testRefreshWeeklyPlan_Success_UpdatesAllData() async {
        // Given
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusWithPlan
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1
        sut.weeklyPlanVM.overviewState = .loaded(TrainingPlanTestFixtures.trainingOverview)
        
        // When
        await sut.refreshWeeklyPlan(isManualRefresh: true)
        
        // Then
        XCTAssertEqual(mockRepository.refreshPlanStatusCallCount, 1)
        XCTAssertEqual(mockRepository.refreshWeeklyPlanCallCount, 1)
        if case .ready = sut.planStatus {
            // Success
        } else {
            XCTFail("Expected planStatus to be .ready")
        }
    }
    
    // MARK: - generateNextWeekPlan Tests
    
    func testGenerateNextWeekPlan_Success_UpdatesStatus() async {
        // Given
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusWithPlan
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan2
        mockRepository.weeklySummaryToReturn = try! TrainingPlanTestFixtures.createWeeklySummary()
        sut.weeklyPlanVM.overviewState = .loaded(TrainingPlanTestFixtures.trainingOverview)
        
        // When
        await sut.generateNextWeekPlan(targetWeek: 2)
        
        // Then
        XCTAssertEqual(mockRepository.createWeeklyPlanCallCount, 1)
        XCTAssertNotNil(sut.successToast)
    }
    
    // MARK: - determineNextPlanWeek Tests
    
    func testDetermineNextPlanWeek_NoPendingWeek_NoCurrentPlan_ReturnsCurrentWeek() {
        // Given
        sut.planStatusResponse = TrainingPlanTestFixtures.planStatusNeedCreate
        sut.weeklyPlanVM.currentWeek = 2
        
        // When
        let result = sut.determineNextPlanWeek()
        
        // Then
        XCTAssertEqual(result, 2)
    }
    
    func testDetermineNextPlanWeek_HasCurrentPlan_ReturnsNextWeek() {
        // Given
        sut.planStatusResponse = TrainingPlanTestFixtures.planStatusWithPlan
        sut.weeklyPlanVM.currentWeek = 1
        
        // When
        let result = sut.determineNextPlanWeek()
        
        // Then
        XCTAssertEqual(result, 2)
    }
    
    func testDetermineNextPlanWeek_HasPendingWeek_ReturnsPendingWeek() {
        // Given
        sut.summaryVM.pendingTargetWeek = 5
        sut.weeklyPlanVM.currentWeek = 3
        
        // When
        let result = sut.determineNextPlanWeek()
        
        // Then
        XCTAssertEqual(result, 5)
    }
    
    // MARK: - Helper Method Tests
    
    func testWeekdayName_ReturnsCorrectName() {
        // When/Then
        XCTAssertFalse(sut.weekdayName(for: 1).isEmpty)
    }
    
    func testFormatDistance_FormatsCorrectly() {
        // When
        let result = sut.formatDistance(25.7)
        
        // Then
        XCTAssertEqual(result, "26")
    }
    
    func testFormatPace_FormatsCorrectly() {
        // When
        let result = sut.formatPace("5:30")
        
        // Then
        XCTAssertFalse(result.isEmpty)
    }
    
    func testIsToday_ReturnsTrueForToday() {
        // When
        let result = sut.isToday(Date())
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testIsToday_ReturnsFalseForYesterday() {
        // When
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let result = sut.isToday(yesterday)
        
        // Then
        XCTAssertFalse(result)
    }
    
    func testGetDateForDay_NoOverview_ReturnsNil() {
        // Given - no overview set
        
        // When
        let result = sut.getDateForDay(dayIndex: 1)
        
        // Then
        XCTAssertNil(result)
    }
    
    // MARK: - Weekly Summary Proxy Tests
    
    func testCreateWeeklySummary_DelegatesToSummaryVM() async {
        // Given
        mockRepository.weeklySummaryToReturn = try! TrainingPlanTestFixtures.createWeeklySummary()
        
        // When
        await sut.createWeeklySummary(weekNumber: 3)
        
        // Then
        XCTAssertEqual(mockRepository.createWeeklySummaryCallCount, 1)
        XCTAssertEqual(mockRepository.createWeeklySummaryLastParams?.weekNumber, 3)
    }
    
    func testClearWeeklySummary_ClearsSummaryVMState() {
        // Given
        sut.summaryVM.showSummarySheet = true
        
        // When
        sut.clearWeeklySummary()
        
        // Then
        XCTAssertFalse(sut.summaryVM.showSummarySheet)
    }
    
    // MARK: - Adjustment Tests
    
    func testCancelAdjustmentConfirmation_DelegatesToSummaryVM() {
        // Given
        sut.summaryVM.showAdjustmentConfirmation = true
        sut.summaryVM.pendingAdjustments = [AdjustmentItem(content: "Test", apply: true)]
        
        // When
        sut.cancelAdjustmentConfirmation()
        
        // Then
        XCTAssertFalse(sut.summaryVM.showAdjustmentConfirmation)
        XCTAssertTrue(sut.summaryVM.pendingAdjustments.isEmpty)
    }
    
    // MARK: - Computed Property Tests
    
    func testTrainingOverview_ReturnsFromWeeklyPlanVM() {
        // Given
        sut.weeklyPlanVM.overviewState = .loaded(TrainingPlanTestFixtures.trainingOverview)
        
        // When
        let result = sut.trainingOverview
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.id, "plan_123")
    }
    
    func testCurrentWeek_ReturnsFromWeeklyPlanVM() {
        // Given
        sut.weeklyPlanVM.currentWeek = 5
        
        // When
        let result = sut.currentWeek
        
        // Then
        XCTAssertEqual(result, 5)
    }
    
    func testSelectedWeek_ReturnsFromWeeklyPlanVM() {
        // Given
        sut.weeklyPlanVM.selectedWeek = 3
        
        // When
        let result = sut.selectedWeek
        
        // Then
        XCTAssertEqual(result, 3)
    }
    
    func testIsLoading_TrueWhenWeeklyPlanVMLoading() {
        // Given - isLoading checks weeklyPlanVM.isLoading || summaryVM.isLoading
        sut.weeklyPlanVM.state = .loading
        
        // When/Then
        XCTAssertTrue(sut.isLoading)
    }
    
    func testIsLoading_FalseWhenWeeklyPlanVMReady() {
        // Given - isLoading checks weeklyPlanVM.isLoading || summaryVM.isLoading
        sut.weeklyPlanVM.state = .loaded(TrainingPlanTestFixtures.weeklyPlan1)
        sut.summaryVM.summaryState = .empty
        
        // When/Then
        XCTAssertFalse(sut.isLoading)
    }
}
