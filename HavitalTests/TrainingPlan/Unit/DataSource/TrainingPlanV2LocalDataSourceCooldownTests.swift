//
//  TrainingPlanV2LocalDataSourceCooldownTests.swift
//  HavitalTests
//
//  Unit tests for TrainingPlanV2LocalDataSource background-refresh cooldown logic.
//  Uses a fake V2Clock to control time without depending on real Date().
//  No mock framework — all fakes implement the real protocols.
//

import XCTest
@testable import paceriz_dev

// MARK: - Fake V2Clock

/// Controllable time source for testing cooldown logic.
final class FakeV2Clock: V2Clock {
    var currentTime: Date

    init(startTime: Date = Date(timeIntervalSince1970: 1_000_000)) {
        self.currentTime = startTime
    }

    func now() -> Date {
        currentTime
    }

    /// Advance the clock by the given number of seconds.
    func advance(by seconds: TimeInterval) {
        currentTime = currentTime.addingTimeInterval(seconds)
    }
}

// MARK: - Tests

final class TrainingPlanV2LocalDataSourceCooldownTests: XCTestCase {

    // MARK: - Properties

    private var sut: TrainingPlanV2LocalDataSource!
    private var fakeClock: FakeV2Clock!
    private var mockDefaults: MockUserDefaults!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        fakeClock = FakeV2Clock()
        mockDefaults = MockUserDefaults()
        sut = TrainingPlanV2LocalDataSource(defaults: mockDefaults, clock: fakeClock)
    }

    override func tearDown() {
        mockDefaults.clear()
        sut = nil
        fakeClock = nil
        mockDefaults = nil
        super.tearDown()
    }

    // MARK: - AC-9: App 重啟 / 初始狀態

    /// Given: cooldown 從未被 mark
    /// When: 呼叫 shouldRefresh
    /// Then: 回傳 true（允許刷新）
    func test_shouldRefresh_initialState_returnsTrue() {
        // Given: no markRefreshed has been called (simulates app restart or first launch)

        // When
        let result = sut.shouldRefresh(.planStatus)

        // Then
        XCTAssertTrue(result, "Initial state should allow refresh (no cooldown record in memory)")
    }

    // MARK: - AC-1: Cache hit 且在 cooldown 內 → 不應刷新

    /// Given: 剛 mark 完（0 秒後）
    /// When: cooldown duration = 1800 秒，0 秒 < 1800 秒
    /// Then: shouldRefresh 回傳 false
    func test_shouldRefresh_afterMarkRefreshed_withinCooldown_returnsFalse() {
        // Given: mark refreshed at t=0
        sut.markRefreshed(.planStatus)

        // When: check immediately (0 seconds elapsed)
        let result = sut.shouldRefresh(.planStatus)

        // Then
        XCTAssertFalse(result, "Should be in cooldown immediately after markRefreshed")
    }

    /// Given: mark 後過了 29 分 59 秒（< 30 分鐘）
    /// When: 呼叫 shouldRefresh
    /// Then: 回傳 false（仍在 cooldown 內）
    func test_shouldRefresh_afterMarkRefreshed_justBeforeCooldownExpires_returnsFalse() {
        // Given
        sut.markRefreshed(.planStatus)
        fakeClock.advance(by: 1799)  // 29 min 59 sec

        // When
        let result = sut.shouldRefresh(.planStatus)

        // Then
        XCTAssertFalse(result, "Should still be in cooldown at 29m59s")
    }

    // MARK: - AC-2: Cache hit 且超過 cooldown → 應觸發刷新

    /// Given: mark 後過了整整 30 分鐘（= 1800 秒）
    /// When: 呼叫 shouldRefresh
    /// Then: 回傳 true（cooldown 已到期）
    func test_shouldRefresh_afterMarkRefreshed_atExactCooldownBoundary_returnsTrue() {
        // Given
        sut.markRefreshed(.planStatus)
        fakeClock.advance(by: 1800)  // exactly 30 minutes

        // When
        let result = sut.shouldRefresh(.planStatus)

        // Then
        XCTAssertTrue(result, "Should allow refresh at exactly 30 minutes (cooldown expired)")
    }

    /// Given: mark 後過了 31 分鐘（> 30 分鐘）
    /// When: 呼叫 shouldRefresh
    /// Then: 回傳 true
    func test_shouldRefresh_afterMarkRefreshed_pastCooldown_returnsTrue() {
        // Given
        sut.markRefreshed(.planStatus)
        fakeClock.advance(by: 1860)  // 31 minutes

        // When
        let result = sut.shouldRefresh(.planStatus)

        // Then
        XCTAssertTrue(result, "Should allow refresh after cooldown expires")
    }

    // MARK: - invalidateCooldown 繞過 cooldown

    /// Given: 在 cooldown 內（剛 mark 過）
    /// When: 呼叫 invalidateCooldown 後再呼叫 shouldRefresh
    /// Then: 回傳 true（invalidate 讓下次一定刷新）
    func test_invalidateCooldown_withinActiveCooldown_shouldRefreshReturnsTrue() {
        // Given: recently marked — within cooldown
        sut.markRefreshed(.planStatus)
        XCTAssertFalse(sut.shouldRefresh(.planStatus), "Precondition: should be in cooldown")

        // When
        sut.invalidateCooldown(.planStatus)

        // Then
        XCTAssertTrue(sut.shouldRefresh(.planStatus), "After invalidate, shouldRefresh must return true")
    }

    // MARK: - markRefreshed resets the timer

    /// Given: cooldown 已到期（超過 30 分鐘）
    /// When: 再次 markRefreshed
    /// Then: cooldown 重設，shouldRefresh 再次回傳 false
    func test_markRefreshed_afterExpiredCooldown_resetsTimer() {
        // Given: mark then advance past cooldown
        sut.markRefreshed(.planStatus)
        fakeClock.advance(by: 1800)
        XCTAssertTrue(sut.shouldRefresh(.planStatus), "Precondition: cooldown should be expired")

        // When: mark again (simulate a successful background refresh)
        sut.markRefreshed(.planStatus)

        // Then: cooldown restarted
        XCTAssertFalse(sut.shouldRefresh(.planStatus), "Cooldown should be reset after second markRefreshed")
    }
}
