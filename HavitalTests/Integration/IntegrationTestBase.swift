//
//  IntegrationTestBase.swift
//  HavitalTests
//
//  集成測試基礎類 - 處理真實 API 調用和 Demo 帳號認證
//

import XCTest
@testable import paceriz_dev

/// 集成測試基礎類
/// - 自動處理 Demo 帳號登錄
/// - 確保只在開發環境執行
/// - 提供真實 API 調用能力
@MainActor
class IntegrationTestBase: XCTestCase {
    private var reviewerPasscode: String {
        ProcessInfo.processInfo.environment["HAVITAL_REVIEWER_PASSCODE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: - Properties

    /// Demo 帳號的 ID Token（用於真實 API 調用）
    var demoToken: String?

    /// Demo 用戶信息
    var demoUser: DemoUser?

    /// 登錄是否成功
    var isAuthenticated = false

    // MARK: - Setup & Teardown

    /// 測試前設置 - 執行 Demo 登錄
    override func setUp() async throws {
        try await super.setUp()

        try XCTSkipIf(
            reviewerPasscode.isEmpty,
            "Set HAVITAL_REVIEWER_PASSCODE to run integration tests that depend on reviewer demo login."
        )

        print("🧪 ========================================")
        print("🧪 集成測試初始化開始 (Instance Setup)")
        print("🧪 ========================================")

        // ✅ 步驟 1: 驗證環境配置
        guard APIConfig.isDevelopment else {
            fatalError("""
            ❌ 集成測試必須在 DEBUG 配置下運行！

            當前環境: RELEASE
            請確保在 Xcode Scheme 設置中使用 Debug 配置
            """)
        }

        print("✅ 環境驗證通過: DEBUG 模式")
        print("📍 API Base URL: \(APIConfig.baseURL)")

        // ✅ 步驟 2: 執行 Demo 登錄 (如果尚未登錄)
        // 注意：為了避免每個測試都重新登錄導致過慢，我們可以檢查 AuthenticationService 狀態
        // 但為了隔離性，理想情況是每次都檢查
        
        if AuthenticationService.shared.isAuthenticated && AuthenticationService.shared.demoIdToken != nil {
             print("ℹ️ 已經是登錄狀態，跳過重複登錄")
             demoToken = try await AuthenticationService.shared.getIdToken()
             isAuthenticated = true
             return
        }

        print("\n🔐 開始 Demo 登錄 (via AuthenticationService)...")

        let loginExpectation = XCTestExpectation(description: "Demo login")

        Task {
            // 使用 AuthenticationService 進行登入，確保 Token 被正確設置給 HTTPClient
            await AuthenticationService.shared.demoLogin(reviewerPasscode: self.reviewerPasscode)

            // 檢查認證狀態
            if AuthenticationService.shared.isAuthenticated {
                do {
                    // 獲取 Token
                    demoToken = try await AuthenticationService.shared.getIdToken()
                    
                    isAuthenticated = true
                    
                    print("✅ Demo 登錄成功")
                    print("   - Token 長度: \(demoToken?.count ?? 0) 字符")
                    if let user = AuthenticationService.shared.appUser {
                        print("   - Email: \(user.email ?? "unknown")")
                    }

                    loginExpectation.fulfill()
                } catch {
                    XCTFail("❌ 獲取 Token 失敗: \(error.localizedDescription)")
                    loginExpectation.fulfill()
                }
            } else {
                XCTFail("❌ Demo 登錄失敗: AuthenticationService 未認證")
                if let error = AuthenticationService.shared.loginError {
                    print("   錯誤詳情: \(error)")
                }
                loginExpectation.fulfill()
            }
        }

        // 等待登錄完成（最多 15 秒）
        let waiter = XCTWaiter()
        let result = await waiter.fulfillment(of: [loginExpectation], timeout: 15.0)

        // Note: XCTWaiter.fulfillment is async in newer XCTest, but XCTWaiter().wait is sync.
        // wait(for:timeout:) is synchronous.
    }
    
    // override func tearDown() async throws { ... } // default is fine

    // MARK: - Helper Methods

    /// 確保已經認證
    func ensureAuthenticated() {
        XCTAssertTrue(isAuthenticated, "❌ 未完成 Demo 登錄")
        XCTAssertNotNil(demoToken, "❌ Demo Token 為空")
    }

    /// 打印測試開始信息
    func logTestStart(_ testName: String) {
        print("\n" + String(repeating: "=", count: 60))
        print("🧪 測試開始: \(testName)")
        print(String(repeating: "=", count: 60))
    }

    /// 打印測試結束信息
    func logTestEnd(_ testName: String, success: Bool = true) {
        print(String(repeating: "-", count: 60))
        if success {
            print("✅ 測試完成: \(testName)")
        } else {
            print("❌ 測試失敗: \(testName)")
        }
        print(String(repeating: "=", count: 60) + "\n")
    }

    /// 等待異步操作
    func waitForAsync(timeout: TimeInterval = 5.0, description: String = "Async operation") async throws {
        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
    }
}

// MARK: - 擴展：便利方法

extension IntegrationTestBase {
    /// 獲取 DependencyContainer 中的 Repository
    func getRepository<T>() -> T {
        return DependencyContainer.shared.resolve()
    }

    /// 獲取 DependencyContainer 中的 UseCase
    func getUseCase<T>() -> T {
        return DependencyContainer.shared.resolve()
    }

    /// 訓練計畫相關整合測試需要有效訂閱；若 demo 帳號已過期則改為 skip，
    /// 避免外部帳號狀態讓整包測試持續紅燈。
    func requireActiveTrainingPlanAccess() async throws {
        if !DependencyContainer.shared.isRegistered(SubscriptionRepository.self) {
            DependencyContainer.shared.registerSubscriptionModule()
        }

        let repository: SubscriptionRepository = DependencyContainer.shared.resolve()
        let status = try await repository.refreshStatus()

        let hasAccess = status.status == .active || status.status == .trial
        try XCTSkipIf(
            !hasAccess,
            "Demo subscription status is \(status.status.rawValue). Training plan integration tests require active access."
        )
    }
}
