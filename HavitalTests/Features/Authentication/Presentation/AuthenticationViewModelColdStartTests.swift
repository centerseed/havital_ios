import XCTest
@testable import paceriz_dev

/// AC-AUTH-09 / T-0749：冷啟動時向後端確認 onboarding 狀態失敗，落點不得是 onboarding。
///
/// 背景：onboarding 走完會用新的 overview 蓋掉使用者進行中的計畫。2026-09-18 Android 端
/// 因為把「問不到」當成「沒完成」，一位雙平台使用者的 24 週計畫在第 8 週被換成新的第 1 週。
/// iOS 的同類缺口是：本地從來不知道這個帳號完成過 onboarding（重裝／清資料），
/// 而這一輪確認又失敗時，畫面會直接落到 onboarding。
///
/// 既有測試沒有涵蓋這條路徑：`AuthCoordinatorViewModelTests` 測的是另一個沒有呼叫者的
/// `AuthCoordinatorViewModel`，不是這裡真正在跑的 `AuthenticationViewModel`。
@MainActor
final class AuthenticationViewModelColdStartTests: XCTestCase {

    private let onboardingFlagKey = "hasCompletedOnboarding"

    private var mockAuthRepository: MockAuthRepository!
    private var mockAuthSessionRepository: MockAuthSessionRepository!
    private var mockOnboardingRepository: MockOnboardingRepository!

    /// 這支 key 是 app 共用的 UserDefaults，測試前後要原樣還回去。
    private var savedOnboardingFlag: Any?

    override func setUp() async throws {
        try await super.setUp()
        await CacheEventBus.shared.resetForTesting()

        savedOnboardingFlag = UserDefaults.standard.object(forKey: onboardingFlagKey)
        UserDefaults.standard.removeObject(forKey: onboardingFlagKey)

        mockAuthRepository = MockAuthRepository()
        mockAuthSessionRepository = MockAuthSessionRepository()
        mockOnboardingRepository = MockOnboardingRepository()

        // 兩條測試都是「已登入」的冷啟動。
        mockAuthSessionRepository.isAuthenticatedValue = true
    }

    override func tearDown() async throws {
        if let savedOnboardingFlag {
            UserDefaults.standard.set(savedOnboardingFlag, forKey: onboardingFlagKey)
        } else {
            UserDefaults.standard.removeObject(forKey: onboardingFlagKey)
        }
        savedOnboardingFlag = nil

        mockAuthRepository = nil
        mockAuthSessionRepository = nil
        mockOnboardingRepository = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeSUT() -> AuthenticationViewModel {
        AuthenticationViewModel(
            authRepository: mockAuthRepository,
            authSessionRepository: mockAuthSessionRepository,
            onboardingRepository: mockOnboardingRepository,
            observesFirebaseAuthState: false
        )
    }

    /// `init` 裡的冷啟動確認是 fire-and-forget 的 Task，輪詢等它跑完。
    private func waitForColdStartResolution(
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        for _ in 0..<300 {
            if mockAuthSessionRepository.fetchCurrentUserCalled {
                // 讓 resolve 的後續 @MainActor 工作收尾
                try await Task.sleep(nanoseconds: 20_000_000)
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("冷啟動的 onboarding 狀態確認沒有在時限內發生", file: file, line: line)
    }

    // MARK: - AC-AUTH-09

    /// 本地從來不知道（沒有快取的 AuthUser，UserDefaults 也沒有旗標）＋ 這一輪確認失敗
    /// → 必須是「讀不到」狀態，不得是 onboarding 狀態。
    func test_coldStart_localUnknown_confirmationFails_doesNotFallIntoOnboarding() async throws {
        mockAuthSessionRepository.currentUser = nil
        mockAuthSessionRepository.fetchCurrentUserResult = .failure(.networkFailure)

        let sut = makeSUT()
        try await waitForColdStartResolution()

        XCTAssertTrue(
            sut.onboardingStatusUnavailable,
            "本地不知道這個帳號的 onboarding 狀態、這一輪又問不到 → 必須停在可重試的讀不到畫面"
        )
        XCTAssertFalse(
            sut.isResolvingOnboardingStatus,
            "確認已經結束，不該還停在載入畫面"
        )
        XCTAssertFalse(
            sut.hasCompletedOnboarding,
            "問不到就不得擅自把本地旗標寫成已完成"
        )
    }

    /// 本地已知完成過 onboarding ＋ 同樣的確認失敗 → 照本地已知進主 app shell。
    /// 這條是防迴歸：原本的 cache-first 行為不可以被上面那條改壞。
    func test_coldStart_localKnowsCompleted_confirmationFails_entersMainShell() async throws {
        UserDefaults.standard.set(true, forKey: onboardingFlagKey)
        mockAuthSessionRepository.currentUser = AuthUser(
            uid: "test-uid",
            hasCompletedOnboarding: true
        )
        mockAuthSessionRepository.fetchCurrentUserResult = .failure(.networkFailure)

        let sut = makeSUT()
        try await waitForColdStartResolution()

        XCTAssertFalse(
            sut.onboardingStatusUnavailable,
            "本地已知完成過 onboarding，問不到也不該擋住使用者"
        )
        XCTAssertTrue(
            sut.hasCompletedOnboarding,
            "確認失敗時要沿用本地已知的狀態，進主 app shell"
        )
        XCTAssertFalse(sut.isResolvingOnboardingStatus)
    }
}
