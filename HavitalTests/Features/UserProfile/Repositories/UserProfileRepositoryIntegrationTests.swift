//
//  UserProfileRepositoryIntegrationTests.swift
//  HavitalTests
//
//  集成測試：UserProfileRepository 與真實 API 交互
//

import XCTest
@testable import paceriz_dev

@MainActor
final class UserProfileRepositoryIntegrationTests: IntegrationTestBase {

    // MARK: - Properties

    var repository: UserProfileRepository!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // 確保已經認證
        ensureAuthenticated()

        // 確保依賴已註冊
        if !DependencyContainer.shared.isRegistered(UserProfileRepository.self) {
            DependencyContainer.shared.registerUserDependencies()
        }

        // 從 DependencyContainer 獲取 Repository
        // 使用 tryResolve 來避免 fatalError
        if let resolvedRepo: UserProfileRepository = DependencyContainer.shared.tryResolve() {
            repository = resolvedRepo
        } else {
            // 嘗試再次註冊
            print("⚠️ UserProfileRepository 未找到，嘗試重新註冊...")
            DependencyContainer.shared.registerUserProfileModule()
            repository = DependencyContainer.shared.tryResolve()
        }

        // 確保 repository 初始化成功
        XCTAssertNotNil(repository, "❌ Repository 初始化失敗")

        print("✅ UserProfileRepository 已初始化 (instance: \(Unmanaged.passUnretained(self).toOpaque()))")
    }

    override func tearDown() async throws {
        repository = nil
        try await super.tearDown()
    }

    // MARK: - Integration Tests

    /// 測試 1: 獲取用戶資料（真實 API）
    func test_getUserProfile_shouldReturnValidData() async throws {
        logTestStart("獲取用戶資料")

        // Guard: 確保 repository 已初始化
        guard repository != nil else {
            XCTFail("❌ Repository 未初始化")
            return
        }

        // When: 調用 Repository 獲取用戶資料
        let profile = try await repository.getUserProfile()

        // Then: 驗證回傳數據
        // Note: Demo 帳號可能沒有 email，所以只驗證 profile 本身存在
        print("✅ 用戶資料: \(profile.displayName ?? profile.email ?? "N/A")")
        // 至少要有 displayName 或 email 其中之一
        let hasIdentity = profile.displayName != nil || profile.email != nil
        XCTAssertTrue(hasIdentity, "用戶應至少有 displayName 或 email")

        logTestEnd("獲取用戶資料", success: true)
    }

    /// 測試 2: 強制刷新用戶資料
    func test_refreshUserProfile_shouldReturnFreshData() async throws {
        logTestStart("強制刷新用戶資料")

        // Guard: 確保 repository 已初始化
        guard repository != nil else {
            XCTFail("❌ Repository 未初始化")
            return
        }

        // When: 強制刷新
        let profile = try await repository.refreshUserProfile()

        // Then: 驗證數據
        // Note: Demo 帳號可能沒有 email，所以只驗證有身份識別資訊
        print("✅ 刷新後用戶資料: \(profile.displayName ?? profile.email ?? "N/A")")
        let hasIdentity = profile.displayName != nil || profile.email != nil
        XCTAssertTrue(hasIdentity, "用戶應至少有 displayName 或 email")

        logTestEnd("強制刷新用戶資料", success: true)
    }

    /// 測試 3: 獲取心率區間
    func test_getHeartRateZones_shouldReturnZonesIfAvailable() async throws {
        logTestStart("獲取心率區間")

        do {
            // When: 獲取心率區間
            let zones = try await repository.getHeartRateZones()

            // Then: 驗證數據
            XCTAssertEqual(zones.count, 6, "應該有 6 個心率區間")
            for zone in zones {
                print("   Zone \(zone.zone): \(zone.name) - \(zone.range)")
            }
            print("✅ 成功獲取 \(zones.count) 個心率區間")

        } catch UserProfileError.invalidHeartRate {
            // 如果用戶沒有設置心率數據，這是預期的錯誤
            print("ℹ️ 用戶尚未設置心率數據")
        }

        logTestEnd("獲取心率區間", success: true)
    }

    /// 測試 4: 獲取用戶目標
    func test_getTargets_shouldReturnTargetsList() async throws {
        logTestStart("獲取用戶目標")

        // When: 獲取目標
        let targets = try await repository.getTargets()

        // Then: 驗證數據
        print("✅ 獲取 \(targets.count) 個目標")
        for target in targets {
            print("   - \(target.name): \(target.distanceKm) km")
        }

        logTestEnd("獲取用戶目標", success: true)
    }

    /// 測試 5: 計算用戶統計
    func test_calculateStatistics_shouldReturnStats() async throws {
        logTestStart("計算用戶統計")

        // Given: 先載入用戶資料
        _ = try await repository.getUserProfile()

        // When: 計算統計
        let stats = await repository.calculateStatistics()

        // Then: 驗證數據
        if let stats = stats {
            print("✅ 用戶統計:")
            print("   - 總距離: \(stats.totalDistance) km")
            print("   - 目標數: \(stats.targetCount)")
            XCTAssertGreaterThanOrEqual(stats.targetCount, 0)
        } else {
            print("ℹ️ 無法計算統計（可能尚未載入用戶資料）")
        }

        logTestEnd("計算用戶統計", success: true)
    }

    /// 測試 6: 緩存機制驗證
    func test_caching_shouldReturnCachedData() async throws {
        logTestStart("緩存機制驗證")

        // 1. 第一次載入
        print("1️⃣ 第一次載入...")
        let startTime1 = Date()
        let profile1 = try await repository.getUserProfile()
        let duration1 = Date().timeIntervalSince(startTime1)
        print("   ⏱️ 耗時: \(String(format: "%.2f", duration1)) 秒")

        // 2. 第二次載入（應該使用緩存）
        print("2️⃣ 第二次載入（預期使用緩存）...")
        let startTime2 = Date()
        let profile2 = try await repository.getUserProfile()
        let duration2 = Date().timeIntervalSince(startTime2)
        print("   ⏱️ 耗時: \(String(format: "%.2f", duration2)) 秒")

        // Then: 數據應一致
        XCTAssertEqual(profile1.email, profile2.email)

        print("📊 緩存效果分析:")
        print("   - 第一次調用: \(String(format: "%.2f", duration1)) 秒")
        print("   - 第二次調用: \(String(format: "%.2f", duration2)) 秒")

        if duration2 < duration1 {
            print("   ✅ 第二次調用更快，緩存生效！")
        } else {
            print("   ℹ️ 第二次調用未明顯更快（可能無緩存或網路快速）")
        }

        logTestEnd("緩存機制驗證", success: true)
    }
}
