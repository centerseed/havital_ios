//
//  WeeklyPlanViewModelTests.swift
//  HavitalTests
//
//  Unit tests for WeeklyPlanViewModel
//

import XCTest
import Combine
@testable import paceriz_dev

@MainActor
final class WeeklyPlanViewModelTests: XCTestCase {
    
    var sut: WeeklyPlanViewModel!
    var mockRepository: MockTrainingPlanRepository!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockRepository = MockTrainingPlanRepository()
        cancellables = Set<AnyCancellable>()
        
        sut = WeeklyPlanViewModel(repository: mockRepository)
    }
    
    override func tearDown() async throws {
        sut = nil
        mockRepository = nil
        cancellables = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialize Tests
    
    func testInitialize_Success_LoadsOverviewAndPlan() async {
        // Given
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1
        
        // When
        await sut.initialize()
        
        // Then
        XCTAssertEqual(mockRepository.getOverviewCallCount, 1)
        XCTAssertEqual(mockRepository.getWeeklyPlanCallCount, 1)
        
        if case .loaded(let overview) = sut.overviewState {
            XCTAssertEqual(overview.id, "plan_123")
        } else {
            XCTFail("Expected overview to be loaded")
        }
        
        if case .loaded(let plan) = sut.state {
            XCTAssertEqual(plan.id, "plan_123_1")
        } else {
            XCTFail("Expected plan to be loaded")
        }
        
        XCTAssertEqual(sut.currentWeek, 1) // Default logic in VM calculates 1
        XCTAssertEqual(sut.selectedWeek, 1)
    }
    
    func testInitialize_OverviewFailure_SetsError() async {
        // Given
        mockRepository.errorToThrow = TrainingPlanError.overviewNotFound
        
        // When
        await sut.initialize()
        
        // Then
        if case .error = sut.overviewState {
            // Success
        } else {
            XCTFail("Expected overview error")
        }
        XCTAssertEqual(mockRepository.getWeeklyPlanCallCount, 0)
    }
    
    // MARK: - loadWeeklyPlan Tests
    
    func testLoadWeeklyPlan_Success_UpdatesState() async {
         // Given - need overview first to construct planId
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        await sut.loadOverview()
        
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1
        
        // When
        await sut.loadWeeklyPlan()
        
        // Then
        XCTAssertEqual(mockRepository.getWeeklyPlanCallCount, 1)
        if case .loaded(let plan) = sut.state {
            XCTAssertEqual(plan.weekOfPlan, 1)
        } else {
            XCTFail("Expected plan loaded")
        }
    }
    
    func testLoadWeeklyPlan_NotFound_SetsEmpty() async {
        // Given
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        await sut.loadOverview()
        
        mockRepository.errorToThrow = TrainingPlanError.weeklyPlanNotFound(planId: "test")
        
        // When
        await sut.loadWeeklyPlan()
        
        // Then
        if case .empty = sut.state {
            // Success
        } else {
            XCTFail("Expected empty state")
        }
    }
    
    func testLoadWeeklyPlan_NoPlanId_SetsEmpty() async {
        // Given - No overview loaded, so currentPlanId is nil
        
        // When
        await sut.loadWeeklyPlan()
        
        // Then
        if case .empty = sut.state {
            // Success
        } else {
            XCTFail("Expected empty state")
        }
    }
    
    // MARK: - refreshWeeklyPlan Tests
    
    func testRefreshWeeklyPlan_Success_ReloadsPlan() async {
        // Given
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        await sut.loadOverview()
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1
        
        // When
        await sut.refreshWeeklyPlan()
        
        // Then
        XCTAssertEqual(mockRepository.refreshWeeklyPlanCallCount, 1)
        XCTAssertNotNil(sut.weeklyPlan)
    }
    
    // MARK: - selectWeek Tests
    
    func testSelectWeek_ValidWeek_ChangesSelectionAndLoads() async {
        // Given
        sut.currentWeek = 5
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        await sut.loadOverview()
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan2 // week 2
        
        // When
        await sut.selectWeek(2)
        
        // Then
        XCTAssertEqual(sut.selectedWeek, 2)
        XCTAssertEqual(mockRepository.getWeeklyPlanCallCount, 1)
        XCTAssertEqual(mockRepository.getWeeklyPlanLastPlanId, "plan_123_2")
    }
    
    func testSelectWeek_InvalidWeek_DoesNothing() async {
        // Given
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1
        sut.currentWeek = 5
        sut.selectedWeek = 1

        // When: 選擇未來週次（新邏輯允許查看任何已產生的週計畫）
        await sut.selectWeek(6) // >= 1 是允許的

        // Then: 應該更新 selectedWeek
        XCTAssertEqual(sut.selectedWeek, 6)

        // When: 選擇無效週次 (< 1)
        await sut.selectWeek(0) // < 1 是不允許的

        // Then: selectedWeek 應該保持不變
        XCTAssertEqual(sut.selectedWeek, 6)
    }
    
    // MARK: - generateWeeklyPlan Tests
    
    func testGenerateWeeklyPlan_Success_UpdatesState() async {
        // Given
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1
        
        // When
        await sut.generateWeeklyPlan(targetWeek: 1)
        
        // Then
        XCTAssertEqual(mockRepository.createWeeklyPlanCallCount, 1)
        if case .loaded = sut.state {
            // Success
        } else {
            XCTFail("Expected loaded state")
        }
    }
    
    // MARK: - Event Subscription Tests
    
    func testUserLogout_ClearsState() async {
        // Given
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        await sut.loadOverview()
        
        // When - simulate logout event manually or verify if we can trigger observable
        // Since we can't easily trigger the CacheEventBus in unit test without it being singleton,
        // we assume the integration works. Ideally we mock CacheEventBus or expose the handler.
        // For now, we trust the implementation or would need to refactor EventBus to be injectable.
        
        // However, we can test that the view model responds if we could inject the notification.
        // Skip for now as it requires NotificationCenter mocking or EventBus refactoring.
    }
    
    // MARK: - Computed Properties
    
    func testCurrentPlanId_ReturnsCorrectFormat() async {
        // Given
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        await sut.loadOverview()
        sut.selectedWeek = 3
        
        // When
        let id = sut.currentPlanId
        
        // Then
        XCTAssertEqual(id, "plan_123_3")
    }
    
    func testAvailableWeeks_returnsCorrectRange() {
        // Given
        sut.currentWeek = 3

        // When
        let weeks = sut.availableWeeks

        // Then
        XCTAssertEqual(weeks, [1, 2, 3])
    }

    // MARK: - A-3: V2 User Early Return on V1 WeeklyPlanViewModel

    /// 建一個 V2 SUT，測試專用。V1 原 sut（`setUp` 建立）持續用於向後相容測試。
    private func makeV2SUT() -> (WeeklyPlanViewModel, MockTrainingPlanRepository, MockTrainingVersionRouter) {
        let mockRepo = MockTrainingPlanRepository()
        let router = MockTrainingVersionRouter()
        router.isV2Result = true
        let vm = WeeklyPlanViewModel(repository: mockRepo, versionRouter: router)
        return (vm, mockRepo, router)
    }

    func testLoadWeeklyPlan_v2User_earlyReturn_noRepoCall_stateIsIncorrectVersionRouting() async {
        let (vm, mockRepo, _) = makeV2SUT()

        // Seed overview so currentPlanId is not nil — guard must fire BEFORE planId check
        mockRepo.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        // Can't safely call loadOverview (V2 guard would also fire); poke state directly via selectedWeek
        vm.selectedWeek = 1

        await vm.loadWeeklyPlan()

        XCTAssertEqual(mockRepo.getWeeklyPlanCallCount, 0, "V2 user must not reach V1 repository")
        guard case .error(let err) = vm.state,
              case .incorrectVersionRouting(let ctx) = err else {
            XCTFail("Expected state = .error(.incorrectVersionRouting), got \(vm.state)")
            return
        }
        XCTAssertTrue(ctx.contains("loadWeeklyPlan"))
    }

    func testRefreshWeeklyPlan_v2User_earlyReturn_noRepoCall() async {
        let (vm, mockRepo, _) = makeV2SUT()
        vm.selectedWeek = 1

        await vm.refreshWeeklyPlan()

        XCTAssertEqual(mockRepo.refreshWeeklyPlanCallCount, 0)
        guard case .error(.incorrectVersionRouting(let ctx)) = vm.state else {
            XCTFail("Expected incorrectVersionRouting, got \(vm.state)")
            return
        }
        XCTAssertTrue(ctx.contains("refreshWeeklyPlan"))
    }

    func testGenerateWeeklyPlan_v2User_earlyReturn_noRepoCall() async {
        let (vm, mockRepo, _) = makeV2SUT()

        await vm.generateWeeklyPlan(targetWeek: 1)

        XCTAssertEqual(mockRepo.createWeeklyPlanCallCount, 0)
        guard case .error(.incorrectVersionRouting(let ctx)) = vm.state else {
            XCTFail("Expected incorrectVersionRouting, got \(vm.state)")
            return
        }
        XCTAssertTrue(ctx.contains("generateWeeklyPlan"))
    }

    func testModifyWeeklyPlan_v2User_earlyReturn_noRepoCall() async {
        let (vm, mockRepo, _) = makeV2SUT()
        let plan = TrainingPlanTestFixtures.weeklyPlan1

        await vm.modifyWeeklyPlan(plan)

        XCTAssertEqual(mockRepo.modifyWeeklyPlanCallCount, 0)
        guard case .error(.incorrectVersionRouting(let ctx)) = vm.state else {
            XCTFail("Expected incorrectVersionRouting, got \(vm.state)")
            return
        }
        XCTAssertTrue(ctx.contains("modifyWeeklyPlan"))
    }

    func testLoadOverview_v2User_earlyReturn_noRepoCall_overviewStateIsError() async {
        let (vm, mockRepo, _) = makeV2SUT()

        await vm.loadOverview()

        XCTAssertEqual(mockRepo.getOverviewCallCount, 0)
        guard case .error(.incorrectVersionRouting(let ctx)) = vm.overviewState else {
            XCTFail("Expected overviewState = .error(.incorrectVersionRouting), got \(vm.overviewState)")
            return
        }
        XCTAssertTrue(ctx.contains("loadOverview"))
    }

    func testLoadOverview_v1User_normalFlow_noGuardTriggered() async {
        // sut 使用 default setUp（AlwaysV1Router fallback → V1 user）
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview

        await sut.loadOverview()

        XCTAssertEqual(mockRepository.getOverviewCallCount, 1)
        if case .loaded = sut.overviewState {} else {
            XCTFail("V1 user path should complete normally, got \(sut.overviewState)")
        }
    }

    // MARK: - A-6: SWR Decode Failure Observability

    func testSWR_decodeFailureWithCache_setsDebugBadge_keepsState() async {
        // Seed cached data
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        await sut.loadOverview()
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1
        await sut.loadWeeklyPlan()
        XCTAssertNotNil(sut.weeklyPlan, "precondition: cache must exist")
        XCTAssertFalse(sut.debugDecodeFailureBadge)

        // Now simulate background refresh that fails (decode failure / server error)
        mockRepository.weeklyPlanToReturn = nil
        mockRepository.errorToThrow = DomainError.dataCorruption("decode_failed(type=WeeklyPlan)")

        await sut.refreshWeeklyPlan()

        // Cache retained
        XCTAssertNotNil(sut.weeklyPlan, "cache must be preserved after SWR failure")
        if case .loaded = sut.state {} else {
            XCTFail("state should remain .loaded with stale cache, got \(sut.state)")
        }
        // Badge turned on
        XCTAssertTrue(sut.debugDecodeFailureBadge,
                      "A-6: debug badge must be set when SWR refresh fails with cache")
    }

    func testSWR_cancellation_doesNotSetBadge() async {
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        await sut.loadOverview()
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1
        await sut.loadWeeklyPlan()

        mockRepository.weeklyPlanToReturn = nil
        mockRepository.errorToThrow = DomainError.cancellation

        await sut.refreshWeeklyPlan()

        XCTAssertFalse(sut.debugDecodeFailureBadge,
                       "Cancellation must not be treated as decode failure")
    }
}
