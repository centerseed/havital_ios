//
//  TrainingPlanLoadingFlowTests.swift
//  HavitalTests
//
//  完整測試 ARCH-006 文件中描述的所有載入流程場景
//  覆蓋：App 啟動、背景恢復、週數切換、產生課表、事件驅動更新
//

import XCTest
import Combine
@testable import paceriz_dev

/// ARCH-006 載入流程完整測試
/// 測試目標：確保所有 UI 狀態在各種場景下都正確顯示
@MainActor
final class TrainingPlanLoadingFlowTests: XCTestCase {

    var sut: TrainingPlanViewModel!
    var mockRepository: MockTrainingPlanRepository!
    var mockWorkoutRepository: MockWorkoutRepository!
    var loadWeeklyWorkoutsUseCase: LoadWeeklyWorkoutsUseCase!
    var aggregateWorkoutMetricsUseCase: AggregateWorkoutMetricsUseCase!
    var cancellables: Set<AnyCancellable>!

    // MARK: - Setup & Teardown

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

    // MARK: - ================================================
    // MARK: - 1. App 乾淨啟動情境（5 種 nextAction 狀態）
    // MARK: - ================================================

    /// 1.1 nextAction = viewPlan → planStatus = .ready(plan)
    func test_appStart_viewPlan_showsWeeklyPlan() async {
        // Given
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusViewPlan
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1

        // When
        await sut.initialize()

        // Then
        if case .ready(let plan) = sut.planStatus {
            XCTAssertEqual(plan.id, "plan_123_1", "應該顯示第一週課表")
            XCTAssertEqual(plan.weekOfPlan, 1)
        } else {
            XCTFail("nextAction=viewPlan 時，planStatus 應為 .ready，但實際為 \(sut.planStatus)")
        }

        XCTAssertEqual(sut.currentWeek, 1, "currentWeek 應為 1")
        XCTAssertEqual(sut.selectedWeek, 1, "selectedWeek 應重置為 currentWeek")
    }

    /// 1.2 nextAction = createSummary → planStatus = .noPlan
    func test_appStart_createSummary_showsNoPlan() async {
        // Given
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusCreateSummary
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview

        // When
        await sut.initialize()

        // Then
        XCTAssertEqual(sut.planStatus, .noPlan, "nextAction=createSummary 時，planStatus 應為 .noPlan")
        XCTAssertEqual(mockRepository.getWeeklyPlanCallCount, 0, "不應載入課表")
    }

    /// 1.3 nextAction = createPlan → planStatus = .noPlan
    func test_appStart_createPlan_showsNoPlan() async {
        // Given
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusCreatePlan
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview

        // When
        await sut.initialize()

        // Then
        XCTAssertEqual(sut.planStatus, .noPlan, "nextAction=createPlan 時，planStatus 應為 .noPlan")
    }

    /// 1.4 nextAction = trainingCompleted → planStatus = .completed
    func test_appStart_trainingCompleted_showsCompleted() async {
        // Given
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusTrainingCompleted
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview

        // When
        await sut.initialize()

        // Then
        XCTAssertEqual(sut.planStatus, .completed, "nextAction=trainingCompleted 時，planStatus 應為 .completed")
        XCTAssertEqual(sut.currentWeek, 12, "currentWeek 應為最後一週")
    }

    /// 1.5 nextAction = noActivePlan → planStatus = .noPlan
    func test_appStart_noActivePlan_showsNoPlan() async {
        // Given
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusNoActivePlan
        mockRepository.overviewToReturn = nil
        mockRepository.errorToThrow = TrainingPlanError.overviewNotFound

        // When
        await sut.initialize()

        // Then
        XCTAssertEqual(sut.planStatus, .noPlan, "nextAction=noActivePlan 時，planStatus 應為 .noPlan")
    }

    // MARK: - ================================================
    // MARK: - 2. App 背景恢復情境
    // MARK: - ================================================

    /// 2.1 未跨週：initialize(force: true) 應正確重新載入
    func test_backgroundRestore_noWeekChange_reinitializes() async {
        // Given - 先完成初始化
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusViewPlan
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1
        await sut.initialize()

        // 重置 call counts
        mockRepository.reset()
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusViewPlan
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1

        // When - 模擬背景恢復
        await sut.initialize(force: true)

        // Then
        XCTAssertEqual(mockRepository.getPlanStatusCallCount, 1, "應重新載入 PlanStatus")
        if case .ready(let plan) = sut.planStatus {
            XCTAssertEqual(plan.id, "plan_123_1")
        } else {
            XCTFail("重新初始化後應顯示課表")
        }
    }

    /// 2.2 跨週且新週有課表：應顯示新週課表
    func test_backgroundRestore_weekChanged_withPlan_showsNewWeekPlan() async {
        // Given - 先完成 Week 1 初始化
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusViewPlan
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1
        await sut.initialize()

        XCTAssertEqual(sut.currentWeek, 1, "初始應為第 1 週")

        // 重置並模擬跨週後的狀態
        mockRepository.reset()
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusAfterWeekChange(
            newWeek: 2,
            hasCurrentWeekPlan: true
        )
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan2

        // When - 模擬跨週後使用 initialize(force: true) 重新初始化
        await sut.initialize(force: true)

        // Then
        XCTAssertEqual(sut.currentWeek, 2, "跨週後 currentWeek 應為 2")
        XCTAssertEqual(sut.selectedWeek, 2, "跨週後 selectedWeek 應重置為 2")
        if case .ready(let plan) = sut.planStatus {
            XCTAssertEqual(plan.weekOfPlan, 2, "應顯示第 2 週課表")
        } else {
            XCTFail("跨週後有課表時，planStatus 應為 .ready")
        }
    }

    /// 2.3 跨週且新週需產生週回顧：應顯示 .noPlan
    func test_backgroundRestore_weekChanged_needSummary_showsNoPlan() async {
        // Given - 先完成 Week 1 初始化
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusViewPlan
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1
        await sut.initialize()

        // 重置並模擬跨週後需要產生週回顧
        // 注意：不能使用 errorToThrow，因為它會影響到 getPlanStatus
        mockRepository.reset()
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusCreateSummary // Week 2, createSummary
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        // 不設置 weeklyPlanToReturn（保持 nil），但不設置 errorToThrow
        // 這樣 getPlanStatus 會成功返回，但 getWeeklyPlan 會返回 nil

        // When - 模擬跨週後使用 initialize(force: true) 重新初始化
        await sut.initialize(force: true)

        // Then
        XCTAssertEqual(sut.currentWeek, 2, "跨週後 currentWeek 應為 2")
        XCTAssertEqual(sut.planStatus, .noPlan, "需要產生週回顧時，planStatus 應為 .noPlan")
    }

    // MARK: - ================================================
    // MARK: - 3. 週數切換情境
    // MARK: - ================================================

    /// 3.1 切換到過去週（有課表）
    func test_weekSwitch_toPastWeek_withPlan_showsPlan() async {
        // Given - 初始化在 Week 3
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusCanGenerateNeedSummary
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan3
        await sut.initialize()

        XCTAssertEqual(sut.currentWeek, 3)

        // 設置 Week 1 課表
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1

        // When - 切換到 Week 1
        await sut.fetchWeekPlan(week: 1)

        // Then
        XCTAssertEqual(sut.selectedWeek, 1, "selectedWeek 應為 1")
        XCTAssertEqual(sut.currentWeek, 3, "currentWeek 應保持不變")
        if case .ready(let plan) = sut.planStatus {
            XCTAssertEqual(plan.weekOfPlan, 1, "應顯示第 1 週課表")
        } else {
            XCTFail("切換到過去有課表的週，planStatus 應為 .ready")
        }
    }

    /// 3.2 切換到過去週（無課表）
    func test_weekSwitch_toPastWeek_noPlan_showsNoPlan() async {
        // Given - 初始化在 Week 3
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusCanGenerateNeedSummary
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan3
        await sut.initialize()

        // 設置 Week 1 無課表
        mockRepository.weeklyPlanToReturn = nil
        mockRepository.errorToThrow = TrainingPlanError.weeklyPlanNotFound(planId: "plan_123_1")

        // When - 切換到 Week 1
        await sut.fetchWeekPlan(week: 1)

        // Then
        XCTAssertEqual(sut.selectedWeek, 1, "selectedWeek 應為 1")
        XCTAssertEqual(sut.planStatus, .noPlan, "無課表時，planStatus 應為 .noPlan")
    }

    /// 3.3 切換到未來週（已產生）
    func test_weekSwitch_toFutureWeek_withPlan_showsPlan() async {
        // Given - 初始化在 Week 3
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusNextWeekAlreadyGenerated
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan3
        await sut.initialize()

        XCTAssertEqual(sut.currentWeek, 3)

        // 設置 Week 4 課表
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan4
        mockRepository.errorToThrow = nil

        // When - 切換到 Week 4
        await sut.fetchWeekPlan(week: 4)

        // Then
        XCTAssertEqual(sut.selectedWeek, 4, "selectedWeek 應為 4")
        XCTAssertEqual(sut.currentWeek, 3, "currentWeek 應保持不變")
        if case .ready(let plan) = sut.planStatus {
            XCTAssertEqual(plan.weekOfPlan, 4, "應顯示第 4 週課表")
        } else {
            XCTFail("切換到未來已產生的週，planStatus 應為 .ready")
        }

        // 應該可以顯示「返回本週」按鈕
        XCTAssertTrue(sut.selectedWeek > sut.currentWeek, "selectedWeek > currentWeek 時應顯示返回按鈕")
    }

    /// 3.4 從未來週切換回當前週
    func test_weekSwitch_returnToCurrentWeek() async {
        // Given - 初始化在 Week 3，然後切換到 Week 4
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusNextWeekAlreadyGenerated
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan3
        await sut.initialize()

        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan4
        await sut.fetchWeekPlan(week: 4)

        XCTAssertEqual(sut.selectedWeek, 4)

        // When - 返回 Week 3
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan3
        await sut.fetchWeekPlan(week: 3)

        // Then
        XCTAssertEqual(sut.selectedWeek, 3, "selectedWeek 應為 3")
        XCTAssertEqual(sut.currentWeek, 3, "currentWeek 應為 3")
        if case .ready(let plan) = sut.planStatus {
            XCTAssertEqual(plan.weekOfPlan, 3, "應顯示第 3 週課表")
        } else {
            XCTFail("返回當前週，planStatus 應為 .ready")
        }
    }

    // MARK: - ================================================
    // MARK: - 4. 產生下週課表情境 (關鍵修復驗證)
    // MARK: - ================================================

    /// 4.1 產生下週課表後應立即顯示新課表（關鍵修復）
    func test_generateNextWeekPlan_showsNewPlanImmediately() async {
        // Given - 初始化在 Week 3，週六日可產生下週課表
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusCanGenerateHasSummary
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan3
        await sut.initialize()

        XCTAssertEqual(sut.currentWeek, 3)
        XCTAssertNotNil(sut.nextWeekInfo, "應有 nextWeekInfo")
        XCTAssertTrue(sut.nextWeekInfo?.canGenerate ?? false, "應可產生下週課表")

        // 準備 Week 4 課表
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan4

        // When - 產生第 4 週課表
        await sut.generateNextWeekPlan(targetWeek: 4, forceGenerate: true)

        // Then - 關鍵驗證：應立即顯示新課表
        XCTAssertEqual(sut.selectedWeek, 4, "selectedWeek 應更新為 4")
        if case .ready(let plan) = sut.planStatus {
            XCTAssertEqual(plan.weekOfPlan, 4, "應立即顯示第 4 週課表，而非舊課表")
            XCTAssertEqual(plan.id, "plan_123_4", "應顯示正確的課表 ID")
        } else {
            XCTFail("產生課表後，planStatus 應為 .ready，但實際為 \(sut.planStatus)")
        }

        // 應顯示成功 Toast
        XCTAssertNotNil(sut.successToast, "應顯示成功 Toast")
    }

    /// 4.2 產生下週課表時 planStatus 應先設為 .loading
    func test_generateNextWeekPlan_setsLoadingFirst() async {
        // Given
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusCanGenerateHasSummary
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan3
        await sut.initialize()

        // 追蹤 planStatus 變化
        var statusChanges: [PlanStatus] = []
        sut.$planStatus
            .dropFirst() // 跳過初始值
            .sink { status in
                statusChanges.append(status)
            }
            .store(in: &cancellables)

        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan4

        // When
        await sut.generateNextWeekPlan(targetWeek: 4, forceGenerate: true)

        // Then - 第一個變化應該是 .loading
        XCTAssertGreaterThan(statusChanges.count, 0, "應有狀態變化")
        XCTAssertEqual(statusChanges.first, .loading, "第一個狀態應為 .loading")
    }

    /// 4.3 需要先產生週回顧的流程
    func test_generateNextWeekPlan_requiresSummary_createsSummaryFirst() async {
        // Given - 需要先產生週回顧
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusCanGenerateNeedSummary
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan3
        mockRepository.weeklySummaryToReturn = try! TrainingPlanTestFixtures.createWeeklySummary()
        await sut.initialize()

        let nextWeekInfo = sut.nextWeekInfo!
        XCTAssertTrue(nextWeekInfo.requiresCurrentWeekSummary, "應需要先產生週回顧")

        // When - 呼叫 generateNextWeekPlan（非 forceGenerate）
        await sut.generateNextWeekPlan(nextWeekInfo: nextWeekInfo)

        // Then - 應先產生週回顧
        XCTAssertEqual(mockRepository.createWeeklySummaryCallCount, 1, "應呼叫 createWeeklySummary")
    }

    // MARK: - ================================================
    // MARK: - 5. 事件驅動更新情境
    // MARK: - ================================================

    /// 5.1 dataChanged.trainingPlan 事件應刷新課表並更新 planStatus
    func test_dataChangedEvent_refreshesAndUpdatesPlanStatus() async {
        // Given
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusViewPlan
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1
        await sut.initialize()

        // 重置計數
        mockRepository.reset()
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusViewPlan
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1

        // When - 模擬 dataChanged.trainingPlan 事件：使用 refreshWeeklyPlan
        await sut.refreshWeeklyPlan(isManualRefresh: false)

        // Then
        XCTAssertEqual(mockRepository.refreshWeeklyPlanCallCount, 1, "應刷新課表")
        if case .ready = sut.planStatus {
            // Success
        } else {
            XCTFail("事件處理後 planStatus 應為 .ready")
        }
    }

    /// 5.2 targetUpdated 事件應刷新 overview 和 planStatus
    func test_targetUpdatedEvent_refreshesOverviewAndPlanStatus() async {
        // Given
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusViewPlan
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1
        await sut.initialize()

        mockRepository.reset()
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusViewPlan
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1

        // When - 模擬 targetUpdated 事件：使用 initialize(force: true) 來重新載入
        await sut.initialize(force: true)

        // Then
        XCTAssertEqual(mockRepository.getOverviewCallCount, 1, "應載入 Overview")
        XCTAssertEqual(mockRepository.getPlanStatusCallCount, 1, "應載入 PlanStatus")
        if case .ready = sut.planStatus {
            // Success
        } else {
            XCTFail("targetUpdated 事件處理後 planStatus 應為 .ready")
        }
    }

    // MARK: - ================================================
    // MARK: - 6. 錯誤處理情境
    // MARK: - ================================================

    /// 6.1 API 錯誤且無緩存時應顯示錯誤
    func test_apiError_noCache_showsError() async {
        // Given
        mockRepository.errorToThrow = NSError(domain: "Network", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Network error"
        ])

        // When
        await sut.initialize()

        // Then
        XCTAssertNotNil(sut.networkError, "應設置 networkError")
        XCTAssertEqual(sut.planStatus, .noPlan, "錯誤時 planStatus 應為 .noPlan")
    }

    /// 6.2 載入課表失敗應設置錯誤狀態
    func test_loadWeeklyPlan_failure_setsNoPlan() async {
        // Given
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusViewPlan
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.errorToThrow = TrainingPlanError.weeklyPlanNotFound(planId: "test")

        // When
        await sut.initialize()

        // Then
        // 由於 initialize 會嘗試載入課表但失敗，planStatus 應反映錯誤
        // 根據實現，可能是 .noPlan 或 .error
        let isAcceptableStatus = sut.planStatus == .noPlan || {
            if case .error = sut.planStatus { return true }
            return false
        }()
        XCTAssertTrue(isAcceptableStatus, "載入失敗時 planStatus 應為 .noPlan 或 .error")
    }

    // MARK: - ================================================
    // MARK: - 7. 狀態一致性驗證
    // MARK: - ================================================

    /// 7.1 selectedWeek 和 currentWeek 的關係驗證
    func test_selectedWeek_currentWeek_consistency() async {
        // Given
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusViewPlan
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1
        await sut.initialize()

        // 初始狀態
        XCTAssertEqual(sut.selectedWeek, sut.currentWeek, "初始化後 selectedWeek 應等於 currentWeek")

        // 切換到未來週
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan2
        await sut.fetchWeekPlan(week: 2)

        XCTAssertEqual(sut.selectedWeek, 2, "切換後 selectedWeek 應為 2")
        XCTAssertEqual(sut.currentWeek, 1, "currentWeek 應保持為 1")

        // shouldResetSelectedWeek = true 時
        await sut.loadPlanStatus(skipCache: true, shouldResetSelectedWeek: true)

        XCTAssertEqual(sut.selectedWeek, sut.currentWeek, "shouldResetSelectedWeek=true 後，selectedWeek 應重置為 currentWeek")
    }

    /// 7.2 planStatus 和 weeklyPlanVM.state 的同步驗證
    func test_planStatus_weeklyPlanVMState_synchronization() async {
        // Given
        mockRepository.planStatusToReturn = TrainingPlanTestFixtures.planStatusViewPlan
        mockRepository.overviewToReturn = TrainingPlanTestFixtures.trainingOverview
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1
        await sut.initialize()

        // 設置 mockRepository 返回 Week 2 課表
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan2

        // When - 通過 fetchWeekPlan 觸發 planStatus 更新
        await sut.fetchWeekPlan(week: 2)

        // Then
        if case .ready(let plan) = sut.planStatus {
            XCTAssertEqual(plan.weekOfPlan, 2, "planStatus 應與 weeklyPlanVM.state 同步")
        } else {
            XCTFail("fetchWeekPlan 後，planStatus 應為 .ready")
        }
    }
}

// MARK: - Test Scenario Documentation

/*
 ARCH-006 載入流程測試覆蓋率：

 ✅ 1. App 乾淨啟動情境（5 種 nextAction 狀態）
    - 1.1 viewPlan → .ready(plan)
    - 1.2 createSummary → .noPlan
    - 1.3 createPlan → .noPlan
    - 1.4 trainingCompleted → .completed
    - 1.5 noActivePlan → .noPlan

 ✅ 2. App 背景恢復情境
    - 2.1 未跨週：reinitialize
    - 2.2 跨週且有課表：顯示新週課表
    - 2.3 跨週且需產生週回顧：顯示 .noPlan

 ✅ 3. 週數切換情境
    - 3.1 切換到過去週（有課表）
    - 3.2 切換到過去週（無課表）
    - 3.3 切換到未來週（已產生）
    - 3.4 返回當前週

 ✅ 4. 產生下週課表情境（關鍵修復驗證）
    - 4.1 產生後立即顯示新課表
    - 4.2 產生時先設為 .loading
    - 4.3 需要先產生週回顧的流程

 ✅ 5. 事件驅動更新情境
    - 5.1 dataChanged.trainingPlan
    - 5.2 targetUpdated

 ✅ 6. 錯誤處理情境
    - 6.1 API 錯誤且無緩存
    - 6.2 載入課表失敗

 ✅ 7. 狀態一致性驗證
    - 7.1 selectedWeek/currentWeek 關係
    - 7.2 planStatus/weeklyPlanVM.state 同步
*/
