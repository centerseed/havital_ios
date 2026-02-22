//
//  TrainingPlanRepositoryIntegrationTests.swift
//  HavitalTests
//
//  集成測試：TrainingPlanRepository 與真實 API 交互
//

import XCTest
@testable import paceriz_dev

@MainActor
final class TrainingPlanRepositoryIntegrationTests: IntegrationTestBase {

    // MARK: - Properties

    var repository: TrainingPlanRepository!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // 確保已經認證
        ensureAuthenticated()

        // 確保依賴已註冊
        // 確保依賴已註冊 (強制註冊以避免測試間的狀態污染)
        DependencyContainer.shared.registerTrainingPlanModule()

        // 從 DependencyContainer 獲取 Repository
        // 必須顯式指定類型，否則 T 可能被推斷為 Optional<TrainingPlanRepository>，導致 Key 不匹配
        let repo: TrainingPlanRepository = getRepository()
        repository = repo

        print("✅ TrainingPlanRepository 已初始化")
        print("🔍 [DEBUG] In setUp. Self: \(Unmanaged.passUnretained(self).toOpaque())")
        print("🔍 [DEBUG] Repository set to: \(String(describing: repository))")
        
        // 確保測試數據存在
        try await ensureTrainingPlanExists()
    }

    override func tearDown() async throws {
        repository = nil
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods

    /// 確保主要比賽存在（創建訓練計畫的前提條件）
    private func ensureMainRaceExists() async throws {
        print("🔍 Checking if main race exists...")

        let targetRepository: TargetRepository = getRepository()
        let targets = try await targetRepository.getTargets()

        // 檢查是否有主要比賽
        if targets.contains(where: { $0.isMainRace }) {
            print("ℹ️ Found existing main race")
            return
        }

        print("ℹ️ No main race found, creating one for test...")

        // 創建一個測試用的主要比賽
        // 日期設為 12 週後（Unix timestamp）
        let raceDate = Int(Date().addingTimeInterval(12 * 7 * 24 * 60 * 60).timeIntervalSince1970)

        let testMainRace = Target(
            id: "",  // 由後端生成
            type: "race_run",
            name: "Integration Test Marathon",
            distanceKm: 42,  // 全馬
            targetTime: 14400,  // 4 小時 (秒)
            targetPace: "5:41",
            raceDate: raceDate,
            isMainRace: true,
            trainingWeeks: 12,
            timezone: "Asia/Taipei"
        )

        _ = try await targetRepository.createTarget(testMainRace)
        print("✅ Created test main race")
    }

    private func ensureTrainingPlanExists() async throws {
         print("🔍 Checking if training plan exists...")

         // 首先確保主要比賽存在
         try await ensureMainRaceExists()

         // 確保 Overview 存在
         var overview: TrainingPlanOverview
         do {
             overview = try await repository.getOverview()
             print("ℹ️ Found existing training plan: \(overview.id)")
         } catch {
             print("ℹ️ No existing plan (or error), creating new one...")
             overview = try await repository.createOverview(startFromStage: nil, isBeginner: true)
             print("✅ Created new training plan: \(overview.id)")
         }

         // ✅ 修復：獲取 status 以確保當前週的計劃存在
         let status = try await repository.getPlanStatus()
         let currentWeek = status.currentWeek
         print("📊 Current week from status: \(currentWeek)")

         // 確保當前週的計劃存在（而不是固定 Week 1）
         let planId = "\(overview.id)_\(currentWeek)"
         do {
             _ = try await repository.getWeeklyPlan(planId: planId)
             print("ℹ️ Found existing weekly plan for week \(currentWeek): \(planId)")
         } catch {
             print("ℹ️ No week \(currentWeek) plan found, creating one...")
             let newPlan = try await repository.createWeeklyPlan(week: currentWeek, startFromStage: nil, isBeginner: true)
             print("✅ Created weekly plan for week \(currentWeek): \(newPlan.id)")
         }
    }

    // MARK: - Integration Tests

    /// 測試 1: 獲取訓練計劃概覽（真實 API）
    func test_getOverview_shouldReturnValidData() async throws {
        print("🔍 [DEBUG] In test_getOverview. Self: \(Unmanaged.passUnretained(self).toOpaque())")
        print("🔍 [DEBUG] Repository is nil? \(repository == nil)")
        
        logTestStart("獲取訓練計劃概覽")

        do {
            // When: 調用真實 API
            let overview = try await repository.getOverview()

            // Then: 驗證返回數據
            print("📊 訓練計劃概覽數據:")
            print("   - Plan ID: \(overview.id)")
            print("   - 計劃名稱: \(overview.trainingPlanName)")
            print("   - 總週數: \(overview.totalWeeks)")
            print("   - 目標評估: \(overview.targetEvaluate)")
            print("   - 訓練亮點: \(overview.trainingHighlight)")
            print("   - 建立時間: \(overview.createdAt)")

            // 斷言
            XCTAssertFalse(overview.id.isEmpty, "Plan ID 不應為空")
            XCTAssertGreaterThan(overview.totalWeeks, 0, "總週數應大於 0")
            XCTAssertFalse(overview.trainingPlanName.isEmpty, "計劃名稱不應為空")

            logTestEnd("獲取訓練計劃概覽", success: true)

        } catch {
            logTestEnd("獲取訓練計劃概覽", success: false)
            XCTFail("❌ 獲取訓練計劃概覽失敗: \(error.localizedDescription)")
        }
    }

    /// 測試 2: 獲取週計劃（真實 API）
    func test_getWeeklyPlan_withValidPlanId_shouldReturnValidData() async throws {
        logTestStart("獲取週計劃")

        do {
            // Given: 先獲取 status 來取得 currentWeek
            let status = try await repository.getPlanStatus()
            let overview = try await repository.getOverview()
            let planId = "\(overview.id)_\(status.currentWeek)"

            print("📋 Plan ID: \(planId)")

            // When: 調用真實 API
            let weeklyPlan = try await repository.getWeeklyPlan(planId: planId)

            // Then: 驗證返回數據
            print("📅 週計劃數據:")
            print("   - Plan ID: \(weeklyPlan.id)")
            print("   - 週次: \(weeklyPlan.weekOfPlan)")
            print("   - 目的: \(weeklyPlan.purpose)")
            print("   - 總距離: \(weeklyPlan.totalDistance) km")
            print("   - 訓練天數: \(weeklyPlan.days.count)")

            // 斷言
            XCTAssertFalse(weeklyPlan.id.isEmpty, "週計劃 ID 不應為空")
            XCTAssertEqual(weeklyPlan.weekOfPlan, status.currentWeek, "週次應與 status 一致")
            XCTAssertGreaterThanOrEqual(weeklyPlan.totalDistance, 0, "總距離應 >= 0")

            logTestEnd("獲取週計劃", success: true)

        } catch {
            logTestEnd("獲取週計劃", success: false)
            XCTFail("❌ 獲取週計劃失敗: \(error.localizedDescription)")
        }
    }

    /// 測試 3: 獲取計劃狀態（真實 API）
    func test_getPlanStatus_shouldReturnValidStatus() async throws {
        logTestStart("獲取計劃狀態")

        do {
            // When: 調用真實 API
            let status = try await repository.getPlanStatus()

            // Then: 驗證返回數據
            print("📊 計劃狀態:")
            print("   - 當前週次: \(status.currentWeek)")
            print("   - 總週數: \(status.totalWeeks)")
            print("   - 下一步行動: \(status.nextAction)")
            print("   - 可生成下週: \(status.canGenerateNextWeek)")
            print("   - 當前週計劃 ID: \(status.currentWeekPlanId ?? "無")")

            // 斷言
            XCTAssertGreaterThanOrEqual(status.currentWeek, 1, "當前週次應 >= 1")
            XCTAssertGreaterThan(status.totalWeeks, 0, "總週數應大於 0")
            XCTAssertLessThanOrEqual(status.currentWeek, status.totalWeeks, "當前週次不應超過總週數")

            logTestEnd("獲取計劃狀態", success: true)

        } catch {
            logTestEnd("獲取計劃狀態", success: false)
            XCTFail("❌ 獲取計劃狀態失敗: \(error.localizedDescription)")
        }
    }

    /// 測試 4: 刷新週計劃（強制從 API）
    func test_refreshWeeklyPlan_shouldReturnLatestData() async throws {
        logTestStart("刷新週計劃")

        do {
            // Given: 先獲取 status 和 overview
            let status = try await repository.getPlanStatus()
            let overview = try await repository.getOverview()
            let planId = "\(overview.id)_\(status.currentWeek)"

            // When: 調用刷新 API（強制從 API 獲取）
            let weeklyPlan = try await repository.refreshWeeklyPlan(planId: planId)

            // Then: 驗證返回數據
            print("🔄 刷新後的週計劃:")
            print("   - Plan ID: \(weeklyPlan.id)")
            print("   - 週次: \(weeklyPlan.weekOfPlan)")
            print("   - 總距離: \(weeklyPlan.totalDistance) km")

            // 斷言
            XCTAssertFalse(weeklyPlan.id.isEmpty, "週計劃 ID 不應為空")
            XCTAssertEqual(weeklyPlan.weekOfPlan, status.currentWeek, "週次應與 status 一致")

            logTestEnd("刷新週計劃", success: true)

        } catch {
            logTestEnd("刷新週計劃", success: false)
            XCTFail("❌ 刷新週計劃失敗: \(error.localizedDescription)")
        }
    }

    /*
    /// 測試 5: 獲取當前週數（真實 API）
    /// NOTE: API getCurrentWeek is missing in Repository protocol
    func test_getCurrentWeek_shouldReturnValidWeek() async throws {
        logTestStart("獲取當前週數")

        do {
            // When: 調用真實 API
            let currentWeek = try await repository.getCurrentWeek()

            // Then: 驗證返回數據
            print("📅 當前週數: \(currentWeek)")

            // 斷言
            XCTAssertGreaterThanOrEqual(currentWeek, 1, "當前週次應 >= 1")

            logTestEnd("獲取當前週數", success: true)

        } catch {
            logTestEnd("獲取當前週數", success: false)
            XCTFail("❌ 獲取當前週數失敗: \(error.localizedDescription)")
        }
    }
    */

    // MARK: - 錯誤處理測試

    /// 測試 6: 使用無效的 Plan ID
    func test_getWeeklyPlan_withInvalidPlanId_shouldThrowError() async throws {
        logTestStart("無效 Plan ID 錯誤處理")

        do {
            // When: 使用無效的 Plan ID
            let invalidPlanId = "invalid_plan_id_999"

            _ = try await repository.getWeeklyPlan(planId: invalidPlanId)

            // 如果沒有拋出錯誤，測試失敗
            XCTFail("❌ 應該拋出錯誤，但沒有")
            logTestEnd("無效 Plan ID 錯誤處理", success: false)

        } catch {
            // Then: 應該捕獲到錯誤
            print("✅ 成功捕獲錯誤: \(error.localizedDescription)")
            logTestEnd("無效 Plan ID 錯誤處理", success: true)
        }
    }
}
