//
//  TrainingPlanViewModelIntegrationTests.swift
//  HavitalTests
//
//  集成測試：TrainingPlanViewModel 與真實 API 交互
//

import XCTest
import Combine
@testable import paceriz_dev

@MainActor
final class TrainingPlanViewModelIntegrationTests: IntegrationTestBase {

    // MARK: - Properties

    var viewModel: TrainingPlanViewModel!
    var cancellables: Set<AnyCancellable>!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // 確保已經認證
        ensureAuthenticated()
        try await requireActiveTrainingPlanAccess()

        // 確保依賴已註冊 (強制註冊以避免測試間的狀態污染)
        DependencyContainer.shared.registerTrainingPlanModule()

        // 從 DependencyContainer 獲取 Repository
        let repository: TrainingPlanRepository = getRepository()
        let workoutRepository: WorkoutRepository = DependencyContainer.shared.resolve()
        
        // 獲取 UseCases (會自動註冊 WorkoutRepository)
        let loadWorkoutsUC = DependencyContainer.shared.makeLoadWeeklyWorkoutsUseCase()
        let aggregageMetricsUC = DependencyContainer.shared.makeAggregateWorkoutMetricsUseCase()
        
        // 初始化 ViewModel
        viewModel = TrainingPlanViewModel(
            repository: repository,
            workoutRepository: workoutRepository,
            loadWeeklyWorkoutsUseCase: loadWorkoutsUC,
            aggregateWorkoutMetricsUseCase: aggregageMetricsUC
        )
        cancellables = []

        print("✅ TrainingPlanViewModel 已初始化")
        
        // 確保測試數據存在
        try await ensureTrainingPlanExists(repository: repository)
    }
    
    /// 確保主要比賽存在（創建訓練計畫的前提條件）
    private func ensureMainRaceExists() async throws {
        print("🔍 Checking if main race exists (ViewModel Test)...")

        let targetRepository: TargetRepository = getRepository()
        let targets = try await targetRepository.getTargets()

        // 檢查是否有主要比賽
        if targets.contains(where: { $0.isMainRace }) {
            print("ℹ️ Found existing main race")
            return
        }

        print("ℹ️ No main race found, creating one for test...")

        // 創建一個測試用的主要比賽
        let raceDate = Int(Date().addingTimeInterval(12 * 7 * 24 * 60 * 60).timeIntervalSince1970)

        let testMainRace = Target(
            id: "",
            type: "race_run",
            name: "Integration Test Marathon",
            distanceKm: 42,
            targetTime: 14400,
            targetPace: "5:41",
            raceDate: raceDate,
            isMainRace: true,
            trainingWeeks: 12,
            timezone: "Asia/Taipei"
        )

        _ = try await targetRepository.createTarget(testMainRace)
        print("✅ Created test main race")
    }

    private func ensureTrainingPlanExists(repository: TrainingPlanRepository) async throws {
         print("🔍 Checking if training plan exists (ViewModel Test)...")

         // 首先確保主要比賽存在
         try await ensureMainRaceExists()

         // 確保 Overview 存在
         var overview: TrainingPlanOverview
         do {
             overview = try await repository.getOverview()
             print("ℹ️ Found existing training plan: \(overview.id)")
         } catch {
             print("ℹ️ No existing plan, creating new one...")
             overview = try await repository.createOverview(startFromStage: nil, isBeginner: true)
             print("✅ Created new training plan: \(overview.id)")
         }

         // 確保 Week 1 計劃存在
         let planId = "\(overview.id)_1"
         do {
             _ = try await repository.getWeeklyPlan(planId: planId)
             print("ℹ️ Found existing weekly plan: \(planId)")
         } catch {
             print("ℹ️ No week 1 plan found, creating one...")
             let newPlan = try await repository.createWeeklyPlan(week: 1, startFromStage: nil, isBeginner: true)
             print("✅ Created weekly plan: \(newPlan.id)")
         }
    }

    override func tearDown() async throws {
        viewModel = nil
        cancellables = nil
        try await super.tearDown()
    }

    // MARK: - Integration Tests

    /// 測試 1: 初始化並載入計畫狀態和概覽
    func test_initialize_shouldLoadPlanStatusAndOverview() async throws {
        logTestStart("初始化並載入計畫")

        // Expectation for plan status change
        let statusExpectation = XCTestExpectation(description: "Plan status should change from loading")
        var loadedPlan: WeeklyPlan?

        viewModel.$planStatus
            .dropFirst() // Drop initial .loading
            .sink { status in
                if case .ready(let plan) = status {
                    loadedPlan = plan
                    statusExpectation.fulfill()
                } else if case .noPlan = status {
                     statusExpectation.fulfill()
                } else if case .completed = status {
                    statusExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When: 初始化 ViewModel
        await viewModel.initialize()

        // Wait for expectations
        await fulfillment(of: [statusExpectation], timeout: 10.0)

        // Then: 驗證狀態
        XCTAssertNotEqual(viewModel.planStatus, .loading, "計畫狀態不應為 loading")
        XCTAssertNil(viewModel.networkError, "不應有網路錯誤")
        
        // 驗證 Overview 是否載入
        XCTAssertNotNil(viewModel.trainingOverview, "訓練概覽應已載入")
        if let overview = viewModel.trainingOverview {
             print("📊 訓練計畫: \(overview.trainingPlanName)")
        }

        // 如果是 Ready 狀態，驗證週計畫
        if let plan = loadedPlan {
            print("📅 載入週計畫: 第 \(plan.weekOfPlan) 週")
            XCTAssertFalse(plan.id.isEmpty)
        } else {
            print("ℹ️ 當前無進行中的週計畫")
        }

        logTestEnd("初始化並載入計畫", success: true)
    }

    /// 測試 2: 刷新週計畫應更新數據
    func test_refreshWeeklyPlan_shouldUpdateData() async throws {
        logTestStart("刷新週計畫")

        // Given: 先初始化
        await viewModel.initialize()
        
        // 確保至少有一個狀態（無論是 noPlan 或 ready）
        guard viewModel.planStatus != .loading else {
            XCTFail("初始化失敗")
            return
        }

        // Capture initial state
        let initialUpdateTimestamp = Date()

        // When: 執行刷新
        await viewModel.refreshWeeklyPlan(isManualRefresh: true)

        // Then: 驗證無錯誤
        XCTAssertNil(viewModel.networkError, "刷新不應產生錯誤")
        
        // 額外驗證：確認 Overview 依然存在
        XCTAssertNotNil(viewModel.trainingOverview)

        logTestEnd("刷新週計畫", success: true)
    }
    
    /// 測試 3: 數據快取驗證
    /// 模擬兩次調用，第二次應該非常快（因為有快取，雖然 IntegrationTestBase 不易直接測量時間，但可驗證數據一致性）
    func test_dataCaching_shouldReturnCachedData() async throws {
        logTestStart("數據快取驗證")
        
        // 1. 第一次載入
        print("1️⃣ 第一次載入...")
        await viewModel.loadPlanStatus()
        let firstStatus = viewModel.planStatusResponse
        
        XCTAssertNotNil(firstStatus, "第一次載入應成功")
        
        // 2. 第二次載入（不強制刷新）
        print("2️⃣ 第二次載入（預期使用快取）...")
        await viewModel.loadPlanStatus(skipCache: false)
        let secondStatus = viewModel.planStatusResponse
        
        // Then: ID 和內容應一致
        XCTAssertEqual(firstStatus?.currentWeekPlanId, secondStatus?.currentWeekPlanId)
        XCTAssertEqual(firstStatus?.currentWeek, secondStatus?.currentWeek)
        
        logTestEnd("數據快取驗證", success: true)
    }
}
