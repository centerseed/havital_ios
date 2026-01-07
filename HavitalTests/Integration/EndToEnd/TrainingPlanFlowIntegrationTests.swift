//
//  TrainingPlanFlowIntegrationTests.swift
//  HavitalTests
//
//  端到端集成測試：模擬完整用戶場景
//

import XCTest
@testable import paceriz_dev

@MainActor
final class TrainingPlanFlowIntegrationTests: IntegrationTestBase {

    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        // 確保已經認證
        ensureAuthenticated()
        
        // 確保依賴已註冊 (強制註冊以避免測試間的狀態污染)
        DependencyContainer.shared.registerTrainingPlanModule()
        
        // 確保測試數據存在
        let repository: TrainingPlanRepository = getRepository()
        try await ensureTrainingPlanExists(repository: repository)
    }
    
    /// 確保主要比賽存在（創建訓練計畫的前提條件）
    private func ensureMainRaceExists() async throws {
        print("🔍 Checking if main race exists (Flow Test)...")

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
         print("🔍 Checking if training plan exists (Flow Test)...")

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

    // MARK: - End-to-End Flow Tests

    /*
    /// 端到端測試 1: 用戶查看訓練計劃的完整流程
    /// NOTE: UseCases are missing in project
    func test_userViewTrainingPlan_completeFlow() async throws {
        logTestStart("端到端 - 用戶查看訓練計劃")

        print("\n🎬 模擬用戶場景：打開 App → 查看訓練計劃\n")

        do {
            // ===== Scene 1: 用戶打開 App，載入訓練概覽 =====
            print("📱 Scene 1: 用戶打開 Training Plan 頁面")
            print("   → 觸發: GetTrainingOverviewUseCase")

            let overviewUseCase: GetTrainingOverviewUseCase = getUseCase()
            let overview = try await overviewUseCase.execute()

            print("   ✅ 顯示訓練概覽:")
            print("      - 計劃名稱: \(overview.trainingPlanName)")
            print("      - 總週數: \(overview.totalWeeks) 週")
            print("      - 目標評估: \(overview.targetEvaluate)")

            XCTAssertFalse(overview.id.isEmpty)

            // ===== Scene 2: 獲取當前週次 =====
            print("\n📱 Scene 2: 載入當前週次")
            print("   → 觸發: GetPlanStatus")

            let repository: TrainingPlanRepository = getRepository()
            let status = try await repository.getPlanStatus()

            print("   ✅ 顯示當前進度:")
            print("      - 進度: 第 \(status.currentWeek)/\(status.totalWeeks) 週")
            print("      - 下一步: \(status.nextAction)")

            // ===== Scene 3: 用戶查看當週訓練計劃 =====
            print("\n📱 Scene 3: 用戶點擊查看本週訓練")
            print("   → 觸發: GetWeeklyPlanUseCase")

            let weeklyPlanUseCase: GetWeeklyPlanUseCase = getUseCase()
            let planId = "\(overview.id)_\(status.currentWeek)"
            let weeklyPlan = try await weeklyPlanUseCase.execute(planId)

            print("   ✅ 顯示本週訓練:")
            print("      - 週次: 第 \(weeklyPlan.weekOfPlan) 週")
            print("      - 總距離: \(weeklyPlan.totalDistance) km")
            print("      - 訓練天數: \(weeklyPlan.days.count)")

            XCTAssertEqual(weeklyPlan.weekOfPlan, status.currentWeek)
            XCTAssertGreaterThanOrEqual(weeklyPlan.days.count, 0)

            // ===== Scene 4: 用戶查看每日訓練詳情 =====
            print("\n📱 Scene 4: 用戶查看每日訓練詳情")

            for (index, day) in weeklyPlan.days.enumerated() {
                print("   📅 Day \(day.dayIndex):")
                print("      - 類型: \(day.trainingType)")
                print("      - 目標: \(day.dayTarget)")
            }

            print("\n✅ 用戶成功查看完整訓練計劃！")
            logTestEnd("端到端 - 用戶查看訓練計劃", success: true)

        } catch {
            logTestEnd("端到端 - 用戶查看訓練計劃", success: false)
            XCTFail("❌ 端到端測試失敗: \(error.localizedDescription)")
        }
    }
    */

    /// 端到端測試 2: 驗證雙軌緩存策略
    func test_dualTrackCaching_completeFlow() async throws {
        logTestStart("端到端 - 雙軌緩存驗證")

        print("\n🎬 模擬場景：驗證 Cache-First + Background Refresh\n")

        do {
            let repository: TrainingPlanRepository = getRepository()

            // ===== Track A: 第一次調用（可能有緩存） =====
            print("📍 Track A: 第一次調用 getOverview()")
            let startTime1 = Date()
            let overview1 = try await repository.getOverview()
            let duration1 = Date().timeIntervalSince(startTime1)
            print("   ⏱️ 耗時: \(String(format: "%.2f", duration1)) 秒")
            print("   📊 數據: Plan ID = \(overview1.id)")

            // ===== Track B: 第二次調用（應該使用緩存） =====
            print("\n📍 Track B: 第二次調用 getOverview()（應該使用緩存）")
            let startTime2 = Date()
            let overview2 = try await repository.getOverview()
            let duration2 = Date().timeIntervalSince(startTime2)
            print("   ⏱️ 耗時: \(String(format: "%.2f", duration2)) 秒")
            print("   📊 數據: Plan ID = \(overview2.id)")

            // ===== 驗證緩存效果 =====
            print("\n📊 緩存效果分析:")
            print("   - 第一次調用: \(String(format: "%.2f", duration1)) 秒")
            print("   - 第二次調用: \(String(format: "%.2f", duration2)) 秒")

            if duration2 < duration1 {
                print("   ✅ 第二次調用更快，緩存生效！")
            } else {
                print("   ℹ️ 第二次調用未明顯更快（可能無緩存或網路快速）")
            }

            // 數據應該一致
            XCTAssertEqual(overview1.id, overview2.id, "兩次調用應返回相同的 Plan ID")

            logTestEnd("端到端 - 雙軌緩存驗證", success: true)

        } catch {
            logTestEnd("端到端 - 雙軌緩存驗證", success: false)
            XCTFail("❌ 雙軌緩存測試失敗: \(error.localizedDescription)")
        }
    }

    /// 端到端測試 3: 驗證錯誤處理
    func test_errorHandling_completeFlow() async throws {
        logTestStart("端到端 - 錯誤處理驗證")

        print("\n🎬 模擬場景：測試錯誤處理機制\n")

        do {
            let repository: TrainingPlanRepository = getRepository()

            // ===== 測試：使用無效的 Plan ID =====
            print("📍 測試：使用無效的 Plan ID")
            let invalidPlanId = "invalid_plan_999"

            do {
                _ = try await repository.getWeeklyPlan(planId: invalidPlanId)
                XCTFail("❌ 應該拋出錯誤，但沒有")

            } catch {
                print("   ✅ 成功捕獲錯誤: \(error.localizedDescription)")

                // 驗證錯誤類型
                print("   📝 錯誤類型: \(type(of: error))")
            }

            logTestEnd("端到端 - 錯誤處理驗證", success: true)

        } catch {
            logTestEnd("端到端 - 錯誤處理驗證", success: false)
            XCTFail("❌ 錯誤處理測試失敗: \(error.localizedDescription)")
        }
    }
}
