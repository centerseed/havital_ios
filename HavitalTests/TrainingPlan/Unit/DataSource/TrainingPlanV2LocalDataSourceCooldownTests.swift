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

// MARK: - 帳號隔離：legacy 快取（無擁有者戳）

/// 擁有者戳上線前寫下的快取證明不了是誰的：讀到就**明確清掉**、getter 回 nil
/// 走網路重取，不讓 legacy blob 靜默滯留（2026-08-29 外審）。
final class TrainingPlanV2LocalDataSourceOwnerTests: XCTestCase {

    private func makeStatus() -> PlanStatusV2Response {
        PlanStatusV2Response(
            currentWeek: 1, totalWeeks: 5, nextAction: "view_plan",
            canGenerateNextWeek: false, currentWeekPlanId: "p_1",
            previousWeekSummaryId: nil, targetType: "race_run",
            methodologyId: "paceriz", nextWeekInfo: nil, metadata: nil
        )
    }

    func test_legacyCacheWithoutOwnerStamp_isClearedAndFallsThroughToNetwork() {
        let defaults = MockUserDefaults()
        let sut = TrainingPlanV2LocalDataSource(defaults: defaults, currentUserID: { "userA" })

        sut.savePlanStatus(makeStatus())
        XCTAssertNotNil(sut.getPlanStatus(), "Precondition: 正常寫入讀得回來")

        // 拔掉擁有者戳，模擬戳上線前寫下的 legacy 快取。
        defaults.removeObject(forKey: "training_plan_v2_cache_owner_uid")

        XCTAssertNil(sut.getPlanStatus(), "legacy 快取不得進畫面（getter 回 nil → 走網路）")
        XCTAssertNil(
            defaults.data(forKey: "training_plan_v2_plan_status_cache"),
            "legacy 快取要被明確清掉，不是靜默滯留"
        )

        // 之後的正常寫入重新蓋戳，讀取恢復。
        sut.savePlanStatus(makeStatus())
        XCTAssertNotNil(sut.getPlanStatus())
    }

    /// weekly 前綴族（週課表／週回顧／週預覽）的 legacy blob 也要被偵測並整批清掉——
    /// 只查 planStatus/overview 會讓 weekly-only 的殘留逃過清除（外審 D06）。
    func test_legacyWeeklyOnlyBlobs_areDetectedAndCleared() {
        let defaults = MockUserDefaults()
        let sut = TrainingPlanV2LocalDataSource(defaults: defaults, currentUserID: { "userA" })

        // 無擁有者戳，只有 weekly 族殘留（raw blob 即可，重點是 key 偵測與清除）。
        defaults.set(Data([0x7B]), forKey: "training_plan_v2_weekly_3")
        defaults.set(Data([0x7B]), forKey: "training_plan_v2_summary_2")
        defaults.set(Data([0x7B]), forKey: "training_plan_v2_preview_abc")

        XCTAssertNil(sut.getPlanStatus(), "讀任何一支都要觸發 legacy 偵測")
        XCTAssertNil(defaults.data(forKey: "training_plan_v2_weekly_3"))
        XCTAssertNil(defaults.data(forKey: "training_plan_v2_summary_2"))
        XCTAssertNil(defaults.data(forKey: "training_plan_v2_preview_abc"))
    }

    /// post-write 情境：第一個動作是 save（網路取回直接落地）時，蓋戳不得「收養」
    /// legacy 週資料——save 前要先整批清掉（外審 D06）。
    func test_saveAfterLegacyBlob_doesNotAdoptOldWeeklyData() {
        let defaults = MockUserDefaults()
        let sut = TrainingPlanV2LocalDataSource(defaults: defaults, currentUserID: { "userA" })

        defaults.set(Data([0x7B]), forKey: "training_plan_v2_weekly_3")

        sut.savePlanStatus(makeStatus())

        XCTAssertNil(
            defaults.data(forKey: "training_plan_v2_weekly_3"),
            "蓋戳前必須清掉無戳 legacy 快取，不得讓它變成現任帳號可讀"
        )
        XCTAssertNotNil(sut.getPlanStatus(), "本輪寫入本身要留存")
    }
}

// MARK: - 週課表 TTL：已經走完的那一週不過期（T-0378）

/// 2026-09-01 裁決：整期預抓把 `1…total_weeks` 全部填進快取；如果舊週每兩小時
/// 就變 stale，回看又會退回「每切一次週等一趟網路」。
/// 「現在第幾週」讀既有的 plan status 快取（`current_week`），**不另立時鐘**。
final class TrainingPlanV2WeeklyPlanTTLTests: XCTestCase {

    private var sut: TrainingPlanV2LocalDataSource!
    private var defaults: MockUserDefaults!

    /// `Keys.weeklyPlanPrefix` 是 private —— 這裡直接寫實際的 key，
    /// 把時間戳倒推到 TTL（`TTL.weeklyPlan` ＝ 7200 秒）之外。
    private func timestampKey(week: Int) -> String {
        "training_plan_v2_weekly_\(week)_timestamp"
    }

    override func setUp() {
        super.setUp()
        defaults = MockUserDefaults()
        sut = TrainingPlanV2LocalDataSource(defaults: defaults, currentUserID: { "userA" })
    }

    override func tearDown() {
        defaults.clear()
        sut = nil
        defaults = nil
        super.tearDown()
    }

    private func makeStatus(currentWeek: Int) -> PlanStatusV2Response {
        PlanStatusV2Response(
            currentWeek: currentWeek, totalWeeks: 17, nextAction: "view_plan",
            canGenerateNextWeek: false, currentWeekPlanId: nil,
            previousWeekSummaryId: nil, targetType: "maintenance",
            methodologyId: "paceriz", nextWeekInfo: nil, metadata: nil
        )
    }

    private func makePlan(week: Int) -> WeeklyPlanV2 {
        WeeklyPlanV2(
            planId: "overview-1_\(week)", weekOfTraining: week, id: "overview-1_\(week)",
            purpose: "history", weekOfPlan: week, totalWeeks: 17, totalDistance: 42,
            totalDistanceDisplay: nil, totalDistanceUnit: nil, totalDistanceReason: nil,
            designReason: nil, mileageProgressionNote: nil, coachNote: nil, days: [],
            intensityTotalMinutes: nil, currentVdot: nil, vdotSource: nil,
            createdAt: Date(), updatedAt: Date(), trainingLoadAnalysis: nil,
            personalizedRecommendations: nil, realTimeAdjustments: nil, apiVersion: "2.0"
        )
    }

    /// 存下來、再把時間戳倒推三小時（TTL 是兩小時）。
    private func saveStale(week: Int) {
        sut.saveWeeklyPlan(makePlan(week: week), week: week)
        defaults.set(Date().addingTimeInterval(-10_800), forKey: timestampKey(week: week))
    }

    /// **第 10 週的用戶，第 3 週的快取永遠不過期。**
    func test_pastWeeks_neverExpire() {
        sut.savePlanStatus(makeStatus(currentWeek: 10))
        saveStale(week: 3)

        XCTAssertFalse(
            sut.isWeeklyPlanExpired(week: 3),
            "已經走完的那一週是不會再變的歷史事實，TTL 到期不代表它腐爛"
        )
    }

    /// **當週與未來週照 TTL 走。** 那幾週的課表還會被編輯／重生成，不得跟著豁免。
    func test_currentAndFutureWeeks_stillExpire() {
        sut.savePlanStatus(makeStatus(currentWeek: 10))
        saveStale(week: 10)
        saveStale(week: 11)

        XCTAssertTrue(sut.isWeeklyPlanExpired(week: 10), "當週照 TTL 走")
        XCTAssertTrue(sut.isWeeklyPlanExpired(week: 11), "未來週照 TTL 走")
    }

    /// 沒有 plan status（推不出「現在第幾週」）就退回純 TTL 判斷。
    func test_withoutPlanStatus_fallsBackToTTL() {
        saveStale(week: 3)

        XCTAssertTrue(sut.isWeeklyPlanExpired(week: 3), "推不出現在第幾週時不得豁免")
    }

    /// 剛存下來的當週仍然新鮮（沒有把整條路徑改成「永遠不過期」）。
    func test_freshCurrentWeek_isNotExpired() {
        sut.savePlanStatus(makeStatus(currentWeek: 10))
        sut.saveWeeklyPlan(makePlan(week: 10), week: 10)

        XCTAssertFalse(sut.isWeeklyPlanExpired(week: 10))
    }
}
