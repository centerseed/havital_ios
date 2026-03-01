//
//  UserProfileViewModelIntegrationTests.swift
//  HavitalTests
//
//  集成測試：UserProfileFeatureViewModel 與真實 API 交互
//

import XCTest
import Combine
@testable import paceriz_dev

@MainActor
final class UserProfileViewModelIntegrationTests: IntegrationTestBase {

    // MARK: - Properties

    var viewModel: UserProfileFeatureViewModel!
    var cancellables: Set<AnyCancellable>!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // 確保已經認證
        ensureAuthenticated()

        // 確保依賴已註冊
        DependencyContainer.shared.registerUserDependencies()

        // 初始化 ViewModel
        viewModel = UserProfileFeatureViewModel()
        cancellables = []

        print("✅ UserProfileFeatureViewModel 已初始化")
    }

    override func tearDown() async throws {
        viewModel = nil
        cancellables = nil
        try await super.tearDown()
    }

    // MARK: - Integration Tests

    /// 測試 1: 初始化並載入所有數據
    func test_initialize_shouldLoadAllData() async throws {
        logTestStart("初始化並載入所有數據")

        // Expectation for profile state change
        let profileExpectation = XCTestExpectation(description: "Profile should load")

        viewModel.$profileState
            .dropFirst() // Drop initial .loading
            .sink { state in
                if case .loaded = state {
                    profileExpectation.fulfill()
                } else if case .error = state {
                    profileExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When: 初始化 ViewModel
        await viewModel.initialize()

        // Wait for expectations
        await fulfillment(of: [profileExpectation], timeout: 10.0)

        // Then: 驗證狀態
        if case .loaded(let user) = viewModel.profileState {
            print("✅ 用戶資料載入成功: \(user.displayName ?? user.email ?? "N/A")")
            // Note: Demo 帳號可能沒有 email，只驗證有身份識別資訊
            let hasIdentity = user.displayName != nil || user.email != nil
            XCTAssertTrue(hasIdentity, "用戶應至少有 displayName 或 email")
        } else if case .error(let error) = viewModel.profileState {
            print("❌ 載入失敗: \(error)")
            XCTFail("載入失敗: \(error)")
        }

        logTestEnd("初始化並載入所有數據", success: true)
    }

    /// 測試 2: 載入用戶資料
    func test_loadUserProfile_shouldUpdateState() async throws {
        logTestStart("載入用戶資料")

        // When: 載入用戶資料
        await viewModel.loadUserProfile()

        // Then: 驗證狀態
        XCTAssertFalse(viewModel.isLoading, "載入應已完成")

        if let user = viewModel.currentUser {
            print("✅ 當前用戶: \(user.displayName ?? user.email ?? "N/A")")
            // Note: Demo 帳號可能沒有 email，只驗證有身份識別資訊
            let hasIdentity = user.displayName != nil || user.email != nil
            XCTAssertTrue(hasIdentity, "用戶應至少有 displayName 或 email")
        }

        logTestEnd("載入用戶資料", success: viewModel.currentUser != nil)
    }

    /// 測試 3: 載入心率區間
    func test_loadHeartRateZones_shouldUpdateState() async throws {
        logTestStart("載入心率區間")

        // When: 載入心率區間
        await viewModel.loadHeartRateZones()

        // Then: 驗證狀態
        XCTAssertFalse(viewModel.isLoadingZones, "載入應已完成")

        print("✅ 心率區間數量: \(viewModel.heartRateZones.count)")
        for zone in viewModel.heartRateZones {
            print("   Zone \(zone.zone): \(zone.name)")
        }

        logTestEnd("載入心率區間", success: true)
    }

    /// 測試 4: 載入用戶目標
    func test_loadTargets_shouldUpdateState() async throws {
        logTestStart("載入用戶目標")

        // When: 載入目標
        await viewModel.loadTargets()

        // Then: 驗證狀態
        XCTAssertFalse(viewModel.isLoadingTargets, "載入應已完成")

        print("✅ 目標數量: \(viewModel.targets.count)")
        for target in viewModel.targets {
            print("   - \(target.name): \(target.distanceKm) km")
        }

        logTestEnd("載入用戶目標", success: true)
    }

    /// 測試 5: 驗證便利屬性
    func test_convenienceProperties_shouldWork() async throws {
        logTestStart("驗證便利屬性")

        // Given: 載入數據
        await viewModel.loadAllData()

        // Then: 驗證便利屬性
        print("📊 便利屬性驗證:")
        print("   - currentUser: \(viewModel.currentUser != nil ? "有" : "無")")
        print("   - userData (別名): \(viewModel.userData != nil ? "有" : "無")")
        print("   - isLoading: \(viewModel.isLoading)")
        print("   - hasCompleteProfile: \(viewModel.hasCompleteProfile)")

        // currentUser 和 userData 應該是同一個
        XCTAssertEqual(viewModel.currentUser?.email, viewModel.userData?.email)

        logTestEnd("驗證便利屬性", success: true)
    }

    /// 測試 6: 認證狀態驗證
    func test_authenticationState_shouldReflectService() async throws {
        logTestStart("認證狀態驗證")

        // When: 檢查認證狀態（應該在 init 中已更新）
        // Note: checkAuthenticationStatus() is called in init

        // Then: 驗證狀態
        print("📊 認證狀態:")
        print("   - isAuthenticated: \(viewModel.isAuthenticated)")
        print("   - currentUserId: \(viewModel.currentUserId ?? "nil")")

        // 因為我們是在已認證狀態下運行測試
        XCTAssertTrue(viewModel.isAuthenticated, "應該是已認證狀態")

        logTestEnd("認證狀態驗證", success: true)
    }

    /// 測試 7: 強制刷新用戶資料
    func test_forceRefresh_shouldUpdateData() async throws {
        logTestStart("強制刷新用戶資料")

        // Given: 先載入數據
        await viewModel.loadUserProfile()
        let initialEmail = viewModel.currentUser?.email

        // When: 強制刷新
        await viewModel.loadUserProfile(forceRefresh: true)

        // Then: 數據應該一致（除非後端數據變更）
        let refreshedEmail = viewModel.currentUser?.email
        XCTAssertEqual(initialEmail, refreshedEmail, "刷新後 Email 應該一致")

        print("✅ 初始 Email: \(initialEmail ?? "N/A")")
        print("✅ 刷新後 Email: \(refreshedEmail ?? "N/A")")

        logTestEnd("強制刷新用戶資料", success: true)
    }
}
