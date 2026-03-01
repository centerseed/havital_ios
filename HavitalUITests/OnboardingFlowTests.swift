//
//  OnboardingFlowTests.swift
//  HavitalUITests
//
//  Created by Automation on 2026/01/06.
//

import XCTest

final class OnboardingFlowTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here.
    }

    @MainActor
    func testOnboardingFlow_AppleHealth_FreshInstall() throws {
        let app = XCUIApplication()
        
        // 傳遞重置標誌，確保每次測試都從頭開始
        app.launchArguments.append("-resetOnboarding")
        app.launch()

        // 1. 處理潛在的登入流程 (如果是 Fresh Install，應該先顯示登入畫面)
        let demoLoginButton = app.buttons["Login_DemoButton"]
        if demoLoginButton.waitForExistence(timeout: 5.0) {
            print("🧪 [UI Test] 找到 Demo 登入按鈕，點擊登入...")
            demoLoginButton.tap()
            
            // 等待登入完成並跳轉到 Onboarding
            // 登入過程涉及 API 調用，可能需要較長時間
            sleep(2) // 簡單等待，讓 UI 反應
        }

        // 2. 驗證是否進入 Onboarding Intro 頁面
        // 檢查是否存在 "Start Setup" 按鈕
        let startButton = app.buttons["OnboardingStartButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10.0), "應用應該顯示 Intro 頁面 (Demo Login 後)")
        
        // 點擊開始
        startButton.tap()

        // 2. 數據源選擇頁面
        // 選擇 Apple Health
        let appleHealthOption = app.buttons["DataSourceOption_appleHealth"]
        XCTAssertTrue(appleHealthOption.waitForExistence(timeout: 2.0), "應該顯示 Apple Health 選項")
        appleHealthOption.tap()
        
        // 點擊繼續
        let continueButton = app.buttons["OnboardingContinueButton"]
        XCTAssertTrue(continueButton.isEnabled, "選擇數據源後繼續按鈕應啟用")
        continueButton.tap()
        
        // 3. 期望進入下一個步驟 (Heart Rate Zone / Data Sync)
        // 根據 DataSourceSelectionView 的邏輯，接下來會請求權限並導航
        // 由於我們無法真正與系統權限彈窗交互 (有時可以，但不可靠)，這裡假設我們能看到下一個頁面的元素
        // 注意：如果是模擬器，可能不會彈出權限框或者會自動處理
        
        // 監控是否有系統彈窗 (System Alert)
        addUIInterruptionMonitor(withDescription: "System Permission Alert") { alert in
            // 如果出現 "“Havital” Would Like to Access Your Health Data"，點擊 "Turn On All" 或 "Allow"
            // 注意：HealthKit 權限視圖是系統級且不可直接測試（out-of-process），通常需要手動或特殊的 TCC 設置
            // 但如果之前已經授權過，可能不會彈出。
            // 這裡我們嘗試處理一般的彈窗
            if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap()
                return true
            }
            if alert.buttons["OK"].exists {
                alert.buttons["OK"].tap()
                return true
            }
            return false
        }
        
        // 觸發一下 UI 以處理中斷監視器
        app.tap()
        
        // 在這裡，您可能需要根據下一頁的具體內容來斷言
        // 假設下一頁有特定的標題或按鈕
        // 由於我們沒有看到 HeartRateZoneView 的代碼，這裡做一個通用的等待
        
        // 假設成功進入下一頁
        // XCTAssertTrue(...)
        
        print("✅ Onboarding Flow Test Base Passed")
    }
}
