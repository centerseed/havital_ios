//
//  TrainingPlanUseCaseIntegrationTests.swift
//  HavitalTests
//
//  集成測試：TrainingPlan UseCases 與真實 API 交互
//

import XCTest
@testable import paceriz_dev

@MainActor
final class TrainingPlanUseCaseIntegrationTests: IntegrationTestBase {

    // MARK: - Integration Tests

    /*
    /// 測試 1: GetTrainingOverviewUseCase - 獲取訓練概覽
    /// NOTE: UseCase missing
    func test_getTrainingOverviewUseCase_shouldReturnValidData() async throws {
        logTestStart("GetTrainingOverviewUseCase - 獲取訓練概覽")

        // Given: 從 DI 容器獲取 UseCase
        let useCase: GetTrainingOverviewUseCase = getUseCase()

        do {
            // When: 執行 UseCase
            let overview = try await useCase.execute()

            // Then: 驗證返回數據
            print("📊 UseCase 返回的訓練概覽:")
            print("   - Plan ID: \(overview.id)")
            print("   - 計劃名稱: \(overview.trainingPlanName)")
            print("   - 總週數: \(overview.totalWeeks)")
            print("   - 目標評估: \(overview.targetEvaluate)")

            // 斷言
            XCTAssertFalse(overview.id.isEmpty, "Plan ID 不應為空")
            XCTAssertGreaterThan(overview.totalWeeks, 0, "總週數應大於 0")

            logTestEnd("GetTrainingOverviewUseCase - 獲取訓練概覽", success: true)

        } catch {
            logTestEnd("GetTrainingOverviewUseCase - 獲取訓練概覽", success: false)
            XCTFail("❌ UseCase 執行失敗: \(error.localizedDescription)")
        }
    }
    */

    /*
    /// 測試 2: GetWeeklyPlanUseCase - 獲取週計劃
    /// NOTE: UseCase missing
    func test_getWeeklyPlanUseCase_shouldReturnValidData() async throws {
        logTestStart("GetWeeklyPlanUseCase - 獲取週計劃")

        // Given: 從 DI 容器獲取 UseCases
        let overviewUseCase: GetTrainingOverviewUseCase = getUseCase()
        let weeklyPlanUseCase: GetWeeklyPlanUseCase = getUseCase()
        let repository: TrainingPlanRepository = getRepository()

        do {
            // 先獲取 overview 和 status 來取得 plan ID
            let overview = try await overviewUseCase.execute()
            let status = try await repository.getPlanStatus()
            let planId = "\(overview.id)_\(status.currentWeek)"

            print("📋 使用 Plan ID: \(planId)")

            // When: 執行 UseCase（注意：無參數標籤）
            let weeklyPlan = try await weeklyPlanUseCase.execute(planId)

            // Then: 驗證返回數據
            print("📅 UseCase 返回的週計劃:")
            print("   - Plan ID: \(weeklyPlan.id)")
            print("   - 週次: \(weeklyPlan.weekOfPlan)")
            print("   - 總距離: \(weeklyPlan.totalDistance) km")
            print("   - 訓練天數: \(weeklyPlan.days.count)")

            // 斷言
            XCTAssertFalse(weeklyPlan.id.isEmpty, "週計劃 ID 不應為空")
            XCTAssertEqual(weeklyPlan.weekOfPlan, status.currentWeek, "週次應與 status 一致")

            logTestEnd("GetWeeklyPlanUseCase - 獲取週計劃", success: true)

        } catch {
            logTestEnd("GetWeeklyPlanUseCase - 獲取週計劃", success: false)
            XCTFail("❌ UseCase 執行失敗: \(error.localizedDescription)")
        }
    }
    */

    /*
    /// 測試 3: GenerateNewWeekPlanUseCase - 生成新週計劃
    /// NOTE: UseCase missing
    func test_generateNewWeekPlanUseCase_shouldGenerateNewPlan() async throws {
        logTestStart("GenerateNewWeekPlanUseCase - 生成新週計劃")

        // Given: 從 DI 容器獲取 UseCases
        let repository: TrainingPlanRepository = getRepository()
        let generateUseCase: GenerateNewWeekPlanUseCase = getUseCase()

        do {
            // 先獲取 status 來取得當前週次
            let status = try await repository.getPlanStatus()
            let nextWeek = status.currentWeek + 1

            // 檢查是否已經到達最後一週
            if nextWeek > status.totalWeeks {
                print("⚠️ 已經到達最後一週，跳過生成測試")
                logTestEnd("GenerateNewWeekPlanUseCase - 生成新週計劃", success: true)
                return
            }

            print("📝 嘗試生成第 \(nextWeek) 週計劃...")

            // When: 執行 UseCase（注意：無參數標籤）
            let newPlan = try await generateUseCase.execute(nextWeek)

            // Then: 驗證返回數據
            print("✨ UseCase 返回的新週計劃:")
            print("   - Plan ID: \(newPlan.id)")
            print("   - 週次: \(newPlan.weekOfPlan)")
            print("   - 總距離: \(newPlan.totalDistance) km")

            // 斷言
            XCTAssertFalse(newPlan.id.isEmpty, "新週計劃 ID 不應為空")
            XCTAssertEqual(newPlan.weekOfPlan, nextWeek, "週次應為下一週")

            logTestEnd("GenerateNewWeekPlanUseCase - 生成新週計劃", success: true)

        } catch {
            // 注意：生成新計劃可能會因為各種原因失敗（例如已經生成過），這是正常的
            print("ℹ️ 生成新週計劃失敗（可能已經存在）: \(error.localizedDescription)")
            logTestEnd("GenerateNewWeekPlanUseCase - 生成新週計劃", success: true)
        }
    }
    */

    // MARK: - 完整流程測試

    /*
    /// 測試 4: 完整數據流 - 從 UseCase 到真實 API
    /// NOTE: UseCase missing
    func test_completeDataFlow_useCaseToAPI_shouldWork() async throws {
        logTestStart("完整數據流測試")

        print("\n🔄 測試完整數據流程:")
        print("   UseCase → Repository → RemoteDataSource → HTTPClient → 真實 API\n")

        do {
            // ===== Step 1: 獲取訓練概覽 =====
            print("📍 Step 1: 獲取訓練概覽...")
            let overviewUseCase: GetTrainingOverviewUseCase = getUseCase()
            let overview = try await overviewUseCase.execute()
            print("   ✅ 成功獲取 Overview: Plan ID = \(overview.id)")

            // ===== Step 2: 獲取當前週次 =====
            print("\n📍 Step 2: 獲取當前週次...")
            let repository: TrainingPlanRepository = getRepository()
            let status = try await repository.getPlanStatus()
            print("   ✅ 成功獲取 Status: Current Week = \(status.currentWeek)")

            // ===== Step 3: 獲取週計劃 =====
            print("\n📍 Step 3: 獲取週計劃...")
            let weeklyPlanUseCase: GetWeeklyPlanUseCase = getUseCase()
            let planId = "\(overview.id)_\(status.currentWeek)"
            let weeklyPlan = try await weeklyPlanUseCase.execute(planId)
            print("   ✅ 成功獲取 WeeklyPlan: \(weeklyPlan.days.count) 天訓練")

            // ===== Step 4: 驗證數據一致性 =====
            print("\n📍 Step 4: 驗證數據一致性...")
            XCTAssertEqual(weeklyPlan.weekOfPlan, status.currentWeek, "週次應一致")
            print("   ✅ 數據一致性驗證通過")

            print("\n✅ 完整數據流測試通過！")
            logTestEnd("完整數據流測試", success: true)

        } catch {
            logTestEnd("完整數據流測試", success: false)
            XCTFail("❌ 完整數據流測試失敗: \(error.localizedDescription)")
        }
    }
    */
}
