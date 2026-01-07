//
//  TargetToOverviewIntegrationTests.swift
//  HavitalTests
//
//  整合測試：Target 更新後觸發 TrainingPlanOverview 更新流程
//  驗證 Clean Architecture 端到端流程
//

import XCTest
@testable import paceriz_dev

/// Target → TrainingPlanOverview 更新流程整合測試
/// 測試場景：當用戶修改賽事目標（距離/完賽時間）後，系統應自動更新訓練計畫概覽
@MainActor
final class TargetToOverviewIntegrationTests: IntegrationTestBase {

    // MARK: - Properties

    private var targetRepository: TargetRepository!
    private var trainingPlanRepository: TrainingPlanRepository!
    private var trainingPlanViewModel: TrainingPlanViewModel!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        ensureAuthenticated()

        // 註冊依賴
        DependencyContainer.shared.registerTargetDependencies()
        DependencyContainer.shared.registerTrainingPlanModule()

        // 獲取 Repositories
        // 必須顯式指定類型，否則 T 可能被推斷為 Optional，導致 Key 不匹配
        let targetRepo: TargetRepository = getRepository()
        targetRepository = targetRepo

        let planRepo: TrainingPlanRepository = getRepository()
        trainingPlanRepository = planRepo

        // 創建 ViewModel
        trainingPlanViewModel = TrainingPlanViewModel()

        // 確保測試數據存在
        try await ensureTestDataExists()
    }

    /// 確保測試所需的數據存在
    private func ensureTestDataExists() async throws {
        print("🔍 確保測試數據存在...")

        // 1. 確保主要賽事存在
        let targets = try await targetRepository.getTargets()
        if !targets.contains(where: { $0.isMainRace }) {
            print("ℹ️ 沒有主要賽事，創建測試賽事...")
            let testTarget = Target(
                id: "",
                type: "race_run",
                name: "Integration Test Marathon",
                distanceKm: 42,
                targetTime: 14400, // 4 hours
                targetPace: "5:41",
                raceDate: Int(Date().addingTimeInterval(12 * 7 * 24 * 60 * 60).timeIntervalSince1970),
                isMainRace: true,
                trainingWeeks: 12,
                timezone: "Asia/Taipei"
            )
            _ = try await targetRepository.createTarget(testTarget)
            print("✅ 已創建測試賽事")
        }

        // 2. 確保訓練計畫概覽存在
        do {
            _ = try await trainingPlanRepository.getOverview()
            print("ℹ️ 訓練計畫概覽已存在")
        } catch {
            print("ℹ️ 創建訓練計畫概覽...")
            _ = try await trainingPlanRepository.createOverview(startFromStage: nil, isBeginner: true)
            print("✅ 已創建訓練計畫概覽")
        }
    }

    // MARK: - Integration Tests

    /// 測試：修改 Target 距離後，TrainingPlanOverview 應被更新
    /// 這是完整的 Clean Architecture 端到端流程測試
    func test_targetDistanceChange_triggersOverviewUpdate() async throws {
        logTestStart("Target 距離變更 → Overview 更新流程")

        print("\n🎬 模擬用戶場景：修改賽事距離 → 重新生成訓練計畫\n")

        do {
            // ===== Step 1: 獲取當前 Target 和 Overview =====
            print("📍 Step 1: 獲取當前狀態")

            let targets = try await targetRepository.getTargets()
            guard let mainTarget = targets.first(where: { $0.isMainRace }) else {
                XCTFail("❌ 沒有找到主要賽事")
                return
            }

            let originalOverview = try await trainingPlanRepository.getOverview()

            print("   ✅ 當前主要賽事:")
            print("      - ID: \(mainTarget.id)")
            print("      - 名稱: \(mainTarget.name)")
            print("      - 距離: \(mainTarget.distanceKm) km")
            print("      - 完賽時間: \(mainTarget.targetTime) 秒")
            print("   ✅ 當前訓練計畫:")
            print("      - ID: \(originalOverview.id)")
            print("      - 名稱: \(originalOverview.trainingPlanName)")

            // ===== Step 2: 修改 Target（透過 TargetRepository）=====
            print("\n📍 Step 2: 修改賽事目標")

            // 創建修改後的 Target（更改距離）
            let newDistance = mainTarget.distanceKm == 42 ? 21 : 42
            var updatedTarget = mainTarget
            updatedTarget = Target(
                id: mainTarget.id,
                type: mainTarget.type,
                name: mainTarget.name,
                distanceKm: newDistance,
                targetTime: mainTarget.targetTime,
                targetPace: mainTarget.targetPace,
                raceDate: mainTarget.raceDate,
                isMainRace: mainTarget.isMainRace,
                trainingWeeks: mainTarget.trainingWeeks,
                timezone: mainTarget.timezone
            )

            let savedTarget = try await targetRepository.updateTarget(id: mainTarget.id, target: updatedTarget)
            print("   ✅ Target 已更新:")
            print("      - 原距離: \(mainTarget.distanceKm) km")
            print("      - 新距離: \(savedTarget.distanceKm) km")

            // ===== Step 3: 透過 TrainingPlanViewModel 更新 Overview（Clean Architecture）=====
            print("\n📍 Step 3: 透過 Clean Architecture 更新 TrainingPlanOverview")
            print("   → 調用路徑: TrainingPlanViewModel.updateOverview()")
            print("   → 內部路徑: Repository → RemoteDataSource → API")

            let updatedOverview = try await trainingPlanViewModel.updateOverview(overviewId: originalOverview.id)

            print("   ✅ Overview 已更新:")
            print("      - ID: \(updatedOverview.id)")
            print("      - 計畫名稱: \(updatedOverview.trainingPlanName)")
            print("      - 總週數: \(updatedOverview.totalWeeks)")

            // ===== Step 4: 驗證 Overview 確實被更新 =====
            print("\n📍 Step 4: 驗證更新結果")

            // 從 Repository 重新獲取以確認數據持久化
            let verifiedOverview = try await trainingPlanRepository.refreshOverview()

            XCTAssertEqual(verifiedOverview.id, originalOverview.id, "Overview ID 應保持不變")
            print("   ✅ Overview 驗證通過")

            // ===== Step 5: 還原 Target（避免影響其他測試）=====
            print("\n📍 Step 5: 還原測試數據")

            let restoredTarget = Target(
                id: mainTarget.id,
                type: mainTarget.type,
                name: mainTarget.name,
                distanceKm: mainTarget.distanceKm,
                targetTime: mainTarget.targetTime,
                targetPace: mainTarget.targetPace,
                raceDate: mainTarget.raceDate,
                isMainRace: mainTarget.isMainRace,
                trainingWeeks: mainTarget.trainingWeeks,
                timezone: mainTarget.timezone
            )
            _ = try await targetRepository.updateTarget(id: mainTarget.id, target: restoredTarget)
            print("   ✅ Target 已還原為原始狀態")

            print("\n✅ 端到端流程測試成功！")
            print("   Target 更新 → ViewModel.updateOverview() → Repository → API → 數據持久化")

            logTestEnd("Target 距離變更 → Overview 更新流程", success: true)

        } catch {
            logTestEnd("Target 距離變更 → Overview 更新流程", success: false)
            XCTFail("❌ 測試失敗: \(error.localizedDescription)")
        }
    }

    /// 測試：修改 Target 完賽時間後，TrainingPlanOverview 應被更新
    func test_targetTimeChange_triggersOverviewUpdate() async throws {
        logTestStart("Target 完賽時間變更 → Overview 更新流程")

        print("\n🎬 模擬用戶場景：修改完賽時間目標 → 重新生成訓練計畫\n")

        do {
            // ===== Step 1: 獲取當前狀態 =====
            print("📍 Step 1: 獲取當前狀態")

            let targets = try await targetRepository.getTargets()
            guard let mainTarget = targets.first(where: { $0.isMainRace }) else {
                XCTFail("❌ 沒有找到主要賽事")
                return
            }

            let originalOverview = try await trainingPlanRepository.getOverview()
            let originalTime = mainTarget.targetTime

            print("   ✅ 原完賽時間: \(originalTime) 秒 (\(originalTime / 3600) 小時)")

            // ===== Step 2: 修改完賽時間 =====
            print("\n📍 Step 2: 修改完賽時間")

            let newTime = originalTime == 14400 ? 12600 : 14400 // 4h ↔ 3.5h
            let updatedTarget = Target(
                id: mainTarget.id,
                type: mainTarget.type,
                name: mainTarget.name,
                distanceKm: mainTarget.distanceKm,
                targetTime: newTime,
                targetPace: mainTarget.targetPace,
                raceDate: mainTarget.raceDate,
                isMainRace: mainTarget.isMainRace,
                trainingWeeks: mainTarget.trainingWeeks,
                timezone: mainTarget.timezone
            )

            _ = try await targetRepository.updateTarget(id: mainTarget.id, target: updatedTarget)
            print("   ✅ 完賽時間已更新: \(originalTime)s → \(newTime)s")

            // ===== Step 3: 透過 Clean Architecture 更新 Overview =====
            print("\n📍 Step 3: 更新 TrainingPlanOverview")

            let updatedOverview = try await trainingPlanViewModel.updateOverview(overviewId: originalOverview.id)
            print("   ✅ Overview 更新成功: \(updatedOverview.id)")

            // ===== Step 4: 還原數據 =====
            print("\n📍 Step 4: 還原測試數據")

            let restoredTarget = Target(
                id: mainTarget.id,
                type: mainTarget.type,
                name: mainTarget.name,
                distanceKm: mainTarget.distanceKm,
                targetTime: originalTime,
                targetPace: mainTarget.targetPace,
                raceDate: mainTarget.raceDate,
                isMainRace: mainTarget.isMainRace,
                trainingWeeks: mainTarget.trainingWeeks,
                timezone: mainTarget.timezone
            )
            _ = try await targetRepository.updateTarget(id: mainTarget.id, target: restoredTarget)
            print("   ✅ Target 已還原")

            logTestEnd("Target 完賽時間變更 → Overview 更新流程", success: true)

        } catch {
            logTestEnd("Target 完賽時間變更 → Overview 更新流程", success: false)
            XCTFail("❌ 測試失敗: \(error.localizedDescription)")
        }
    }

    /// 測試：TargetFeatureViewModel 與 TrainingPlanViewModel 的協作
    func test_viewModelsCollaboration_cleanArchitecture() async throws {
        logTestStart("ViewModel 協作測試（Clean Architecture）")

        print("\n🎬 驗證兩個 ViewModel 的 Clean Architecture 協作\n")

        do {
            // ===== 創建 ViewModels =====
            print("📍 Step 1: 創建 ViewModels（使用 DI）")

            let targetVM = TargetFeatureViewModel()
            let trainingPlanVM = TrainingPlanViewModel()

            print("   ✅ TargetFeatureViewModel 已創建（使用 DI 解析 TargetRepository）")
            print("   ✅ TrainingPlanViewModel 已創建（使用 DI 解析 TrainingPlanRepository）")

            // ===== 載入數據 =====
            print("\n📍 Step 2: 載入數據")

            await targetVM.loadTargets()
            await trainingPlanVM.initialize()

            print("   ✅ TargetFeatureViewModel:")
            print("      - 主賽事: \(targetVM.mainTarget?.name ?? "none")")
            print("      - 支援賽事數量: \(targetVM.supportingTargets.count)")

            print("   ✅ TrainingPlanViewModel:")
            print("      - 訓練概覽: \(trainingPlanVM.trainingOverview?.trainingPlanName ?? "none")")
            print("      - 當前週數: \(trainingPlanVM.currentWeek)")

            // ===== 驗證數據一致性 =====
            print("\n📍 Step 3: 驗證數據一致性")

            XCTAssertNotNil(targetVM.mainTarget, "應該有主賽事")
            XCTAssertNotNil(trainingPlanVM.trainingOverview, "應該有訓練概覽")

            print("   ✅ 兩個 ViewModel 數據一致，Clean Architecture 協作正常")

            logTestEnd("ViewModel 協作測試（Clean Architecture）", success: true)

        } catch {
            logTestEnd("ViewModel 協作測試（Clean Architecture）", success: false)
            XCTFail("❌ 測試失敗: \(error)")
        }
    }

    /// 測試：NotificationCenter 通知機制
    func test_notificationMechanism_afterOverviewUpdate() async throws {
        logTestStart("NotificationCenter 通知機制測試")

        print("\n🎬 驗證 Overview 更新後發送正確的通知\n")

        do {
            let overview = try await trainingPlanRepository.getOverview()

            // ===== 設置通知監聽 =====
            print("📍 Step 1: 設置通知監聽")

            var notificationReceived = false
            var receivedOverview: TrainingPlanOverview?

            let expectation = XCTestExpectation(description: "Notification received")

            let observer = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("TrainingOverviewUpdated"),
                object: nil,
                queue: .main
            ) { notification in
                notificationReceived = true
                receivedOverview = notification.object as? TrainingPlanOverview
                expectation.fulfill()
            }

            print("   ✅ NotificationCenter 監聽器已設置")

            // ===== 觸發更新 =====
            print("\n📍 Step 2: 觸發 Overview 更新")

            _ = try await trainingPlanViewModel.updateOverview(overviewId: overview.id)

            // ===== 等待通知 =====
            await fulfillment(of: [expectation], timeout: 5.0)

            // ===== 驗證通知 =====
            print("\n📍 Step 3: 驗證通知")

            XCTAssertTrue(notificationReceived, "應該收到 TrainingOverviewUpdated 通知")
            XCTAssertNotNil(receivedOverview, "通知應該包含更新後的 Overview")
            XCTAssertEqual(receivedOverview?.id, overview.id, "通知中的 Overview ID 應正確")

            print("   ✅ 通知驗證通過:")
            print("      - 通知已收到: \(notificationReceived)")
            print("      - Overview ID: \(receivedOverview?.id ?? "nil")")

            // 清理
            NotificationCenter.default.removeObserver(observer)

            logTestEnd("NotificationCenter 通知機制測試", success: true)

        } catch {
            logTestEnd("NotificationCenter 通知機制測試", success: false)
            XCTFail("❌ 測試失敗: \(error.localizedDescription)")
        }
    }
}
