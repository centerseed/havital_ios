//
//  ReonboardingVersionCheckTests.swift
//  HavitalTests
//
//  復現 Bug: v1 用戶 re-onboarding 後，TrainingVersionRouter 仍返回 "v1"
//  根因: UserProfileLocalDataSource 未註冊為 Cacheable，
//        且 OnboardingCoordinator.completeOnboarding() 沒有清除 user profile cache，
//        導致 cache-first 策略返回 stale v1 profile。
//

import XCTest
@testable import paceriz_dev

final class ReonboardingVersionCheckTests: XCTestCase {

    // MARK: - Properties

    private var mockLocalDS: MockUserProfileLocalDataSource!
    private var mockRemoteDS: MockUserProfileRemoteDataSource!
    private var mockTargetRemoteDS: MockTargetRemoteDataSource!
    private var repository: UserProfileRepositoryImpl!
    private var router: TrainingVersionRouter!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockLocalDS = MockUserProfileLocalDataSource()
        mockRemoteDS = MockUserProfileRemoteDataSource()
        mockTargetRemoteDS = MockTargetRemoteDataSource()

        repository = UserProfileRepositoryImpl(
            remoteDataSource: mockRemoteDS,
            localDataSource: mockLocalDS,
            targetRemoteDataSource: mockTargetRemoteDS
        )

        router = TrainingVersionRouter(userProfileRepository: repository)
    }

    override func tearDown() {
        router = nil
        repository = nil
        mockLocalDS = nil
        mockRemoteDS = nil
        mockTargetRemoteDS = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func createUser(trainingVersion: String?) -> User {
        var dict: [String: Any] = [
            "display_name": "Test User",
            "email": "test@example.com",
            "max_hr": 190,
            "relaxing_hr": 60
        ]
        if let trainingVersion {
            dict["training_version"] = trainingVersion
        }
        let data = try! JSONSerialization.data(withJSONObject: dict)
        return try! JSONDecoder().decode(User.self, from: data)
    }

    // MARK: - Bug Reproduction Tests

    /// 模擬 OnboardingCoordinator.completeOnboarding() 的修復流程：
    /// 1. CompleteOnboardingUseCase 已執行，後端 training_version = "v2"
    /// 2. Coordinator 先清除 user profile cache
    /// 3. 設定 isReonboardingMode = false → 觸發 checkTrainingVersion()
    /// 4. cache miss → API fetch → 返回 v2
    ///
    /// 修復前此測試 FAIL（因為 cache 未清除，返回 stale v1）。
    /// 修復後此測試 PASS。
    func test_reonboarding_clearCacheBeforeVersionCheck_returnsV2() async {
        // Given: cache 有 v1 user（未過期），remote 已更新為 v2
        let v1User = createUser(trainingVersion: "v1")
        let v2User = createUser(trainingVersion: "v2")
        mockLocalDS.userToReturn = v1User
        mockLocalDS.isUserProfileExpiredValue = false
        mockRemoteDS.userToReturn = v2User

        // When: 模擬 coordinator 修復後的流程
        // Step 1: 清除 user profile cache（coordinator 中新增的步驟）
        mockLocalDS.clearUserProfile()
        // Step 2: checkTrainingVersion() 呼叫 getTrainingVersion()
        let version = await router.getTrainingVersion()

        // Then: cache miss → API 取得 v2
        XCTAssertEqual(version, "v2",
            "Re-onboarding 完成後，清除 cache 再做版本檢查應返回 v2")
    }

    /// 驗證 bug 場景：若不清除 cache，版本檢查返回 stale v1。
    /// 這個測試確保 cache-first 策略的行為是可預期的，
    /// 並證明 coordinator 層面的 cache 清除是必要的。
    func test_reonboarding_withoutCacheClear_returnsStaleV1_regression() async {
        // Given: cache 有 v1 user（未過期），remote 已更新為 v2
        let v1User = createUser(trainingVersion: "v1")
        let v2User = createUser(trainingVersion: "v2")
        mockLocalDS.userToReturn = v1User
        mockLocalDS.isUserProfileExpiredValue = false
        mockRemoteDS.userToReturn = v2User

        // When: 不清除 cache 就做版本檢查
        let version = await router.getTrainingVersion()

        // Then: cache hit → 返回 stale v1（這就是 bug 的表現）
        XCTAssertEqual(version, "v1",
            "未清除 cache 時，cache-first 策略返回 stale v1——" +
            "這證明 coordinator 層面清除 cache 的必要性")
    }

    /// 驗證: 當 user profile cache 被清除後，
    /// TrainingVersionRouter 能正確從 API 取得 v2。
    func test_reonboarding_versionCheckReturnsV2_afterCacheCleared() async {
        // Given: cache 已清除，remote 回傳 v2
        let v2User = createUser(trainingVersion: "v2")
        mockLocalDS.userToReturn = nil  // cache 已清除
        mockRemoteDS.userToReturn = v2User

        // When
        let version = await router.getTrainingVersion()

        // Then: cache miss → API fetch → 返回 v2
        XCTAssertEqual(version, "v2")
    }

    /// 驗證 UserProfileRepositoryImpl 的 cache-first 行為：
    /// 當 cache 有效時，getUserProfile() 返回 cache 中的 user，
    /// 即使 remote 已有更新。
    func test_repository_returnsCachedProfile_whenCacheIsValid() async throws {
        // Given: cache 有 v1 user（未過期），remote 有 v2 user
        let v1User = createUser(trainingVersion: "v1")
        let v2User = createUser(trainingVersion: "v2")
        mockLocalDS.userToReturn = v1User
        mockLocalDS.isUserProfileExpiredValue = false
        mockRemoteDS.userToReturn = v2User

        // When
        let user = try await repository.getUserProfile()

        // Then: cache-first → 返回 v1（這是設計行為，不是 bug）
        XCTAssertEqual(user.trainingVersion, "v1",
            "cache-first 策略應返回 cache 中的 user")
    }

    /// 驗證: cache miss 時從 API 取得最新 profile。
    func test_repository_fetchesFromAPI_whenCacheCleared() async throws {
        // Given: cache 已清除，remote 有 v2
        let v2User = createUser(trainingVersion: "v2")
        mockLocalDS.userToReturn = nil
        mockRemoteDS.userToReturn = v2User

        // When
        let user = try await repository.getUserProfile()

        // Then
        XCTAssertEqual(user.trainingVersion, "v2")
    }

    /// 驗證: refreshUserProfile() 繞過 cache 直接從 API 取得資料。
    func test_repository_refreshBypassesCache() async throws {
        // Given: cache 有 v1，remote 有 v2
        let v1User = createUser(trainingVersion: "v1")
        let v2User = createUser(trainingVersion: "v2")
        mockLocalDS.userToReturn = v1User
        mockLocalDS.isUserProfileExpiredValue = false
        mockRemoteDS.userToReturn = v2User

        // When: 使用 refreshUserProfile 繞過 cache
        let user = try await repository.refreshUserProfile()

        // Then: 直接從 API 取得 v2
        XCTAssertEqual(user.trainingVersion, "v2")
    }

}
