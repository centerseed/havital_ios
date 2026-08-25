import XCTest
@testable import paceriz_dev

/// 首頁兩張優先卡的投影（`App2HomeViewModel` 的 static 純函式）。
///
/// 這裡測的是「payload → 畫面欄位」，不碰網路。矩陣涵蓋：休息日、無 primary、
/// 無強度、無距離、只有時間、間歇分段、今天不在 days 裡、空 days、
/// 缺個別指標、`not_computed`、超長 headline、免費用戶（narrative nil）。
@MainActor
final class App2HomeProjectionTests: XCTestCase {

    // MARK: - Helpers

    private func day(_ json: String) throws -> DayDetailDTO {
        try JSONDecoder().decode(DayDetailDTO.self, from: Data(json.utf8))
    }

    private func metricRow(_ json: String) throws -> AthleteStateMetricRowDTO {
        try JSONDecoder().decode(AthleteStateMetricRowDTO.self, from: Data(json.utf8))
    }

    private func card(
        headline: String = "在軌道上",
        collapsedReason: String? = nil,
        narrative: String? = "恢復落後了"
    ) -> DailyStateCard {
        DailyStateCard(
            lens: .pre, source: "llm", headline: headline, factType: nil,
            narrativeText: narrative, collapsedReason: collapsedReason,
            chips: [], causeChips: [], mileageProgression: nil,
            actionLine: nil, rizoScenario: nil, divergenceFlagText: nil,
            isPaid: narrative != nil, isLocked: narrative == nil,
            upsellReason: nil, benchmarkCalibration: nil
        )
    }

    private let restDay = """
    { "day_index": 3, "day_target": "完全休息", "reason": "週三排休" }
    """

    private let easyRunDay = """
    { "day_index": 2, "day_target": "輕鬆跑", "reason": "有氧維持",
      "primary": { "run_type": "easy", "distance_km": 9.0, "pace": "7:55",
                   "target_intensity": "low" } }
    """

    private let intervalDay = """
    { "day_index": 5, "day_target": "間歇", "reason": "速耐力",
      "primary": { "run_type": "interval", "target_intensity": "high",
                   "segments": [ { "kind": "interval", "repeats": 6,
                                   "work": { "distance_m": 200, "pace": "5:25" },
                                   "recovery": { "duration_seconds": 90 } } ] } }
    """

    // MARK: - 訓練狀況卡（§3.1a）

    func test_trainingStatus_usesCollapsedReasonAsHeadline() {
        let status = App2HomeViewModel.trainingStatus(
            card: card(headline: "H", collapsedReason: "收合句"),
            currentWeek: 5, totalWeeks: 22
        )
        XCTAssertEqual(status.headline, "收合句")
        XCTAssertEqual(status.currentWeek, 5)
        XCTAssertEqual(status.totalWeeks, 22)
    }

    func test_trainingStatus_freeUser_hasNoNarrative() {
        let status = App2HomeViewModel.trainingStatus(
            card: card(narrative: nil), currentWeek: 1, totalWeeks: 8
        )
        XCTAssertNil(status.narrative)
    }

    func test_trainingStatus_missingPlanStatus_leavesWeeksNil() {
        let status = App2HomeViewModel.trainingStatus(
            card: card(), currentWeek: nil, totalWeeks: nil
        )
        XCTAssertNil(status.currentWeek)
        XCTAssertNil(status.totalWeeks)
        XCTAssertFalse(status.headline.isEmpty)
    }

    /// 超長 headline 不被投影層截斷 —— 截斷是版面的事（`fixedSize` ＋ 多行），
    /// 投影層原樣交出，否則字串會在兩個地方各被改一次。
    func test_trainingStatus_longHeadline_isNotTruncated() {
        let long = String(repeating: "這一週的訓練狀況相當複雜，", count: 12)
        let status = App2HomeViewModel.trainingStatus(
            card: card(headline: long), currentWeek: 3, totalWeeks: 12
        )
        XCTAssertEqual(status.headline, long)
    }

    /// 軌道落點沒有 producer（§7-2）→ 恆置中。改了要有人先動 spec。
    func test_trainingStatus_trackPositionIsCentered() {
        let status = App2HomeViewModel.trainingStatus(
            card: card(), currentWeek: 5, totalWeeks: 22
        )
        XCTAssertEqual(status.trackPosition, 0.5, accuracy: 0.0001)
    }

    // MARK: - 今日課表卡（§3.1）

    func test_todaySession_restDay_showsRestWithoutIntensityOrSummary() throws {
        let session = App2HomeViewModel.todaySession(
            days: [try day(restDay)], todayIndex: 3, dayLabel: "週三 · 8/26"
        )
        XCTAssertEqual(session?.title, DayType.rest.localizedName)
        XCTAssertNil(session?.intensityLabel)
        XCTAssertNil(session?.summary)
        XCTAssertEqual(session?.dayLabel, "週三 · 8/26")
    }

    func test_todaySession_easyRun_buildsDistanceAndPaceLine() throws {
        let session = App2HomeViewModel.todaySession(
            days: [try day(easyRunDay)], todayIndex: 2, dayLabel: "週二"
        )
        XCTAssertEqual(session?.summary, "9.0 km · 7:55/km")
        XCTAssertEqual(session?.intensityLabel, L10n.App2.Plan.intensityLow.localized)
    }

    func test_todaySession_interval_buildsStructuredLine() throws {
        let session = App2HomeViewModel.todaySession(
            days: [try day(intervalDay)], todayIndex: 5, dayLabel: "週五"
        )
        let summary = try XCTUnwrap(session?.summary)
        XCTAssertTrue(summary.hasPrefix("6 × 200m · 5:25/km · "), summary)
        XCTAssertEqual(session?.intensityLabel, L10n.App2.Plan.intensityHigh.localized)
    }

    func test_todaySession_todayNotInDays_returnsNil() throws {
        let session = App2HomeViewModel.todaySession(
            days: [try day(restDay)], todayIndex: 7, dayLabel: "週日"
        )
        XCTAssertNil(session)
    }

    func test_todaySession_emptyWeek_returnsNil() {
        XCTAssertNil(App2HomeViewModel.todaySession(days: [], todayIndex: 1, dayLabel: "週一"))
    }

    /// 沒有 `target_intensity` 就不顯示強度徽章 —— 不從課型自己推一個出來。
    func test_todaySession_missingIntensity_hasNoBadge() throws {
        let json = """
        { "day_index": 1, "day_target": "輕鬆跑", "reason": "r",
          "primary": { "run_type": "easy", "distance_km": 5.0 } }
        """
        let session = App2HomeViewModel.todaySession(
            days: [try day(json)], todayIndex: 1, dayLabel: "週一"
        )
        XCTAssertNil(session?.intensityLabel)
        XCTAssertEqual(session?.summary, "5.0 km")
    }

    /// 沒有距離但有時間 → 用時間；兩者都沒有 → 那一行不顯示。
    func test_todaySession_durationOnly_andNeither() throws {
        let durationOnly = """
        { "day_index": 1, "day_target": "輕鬆跑", "reason": "r",
          "primary": { "run_type": "easy", "duration_minutes": 40 } }
        """
        XCTAssertEqual(
            App2HomeViewModel.todaySession(
                days: [try day(durationOnly)], todayIndex: 1, dayLabel: "週一"
            )?.summary,
            "40 min"
        )

        let neither = """
        { "day_index": 1, "day_target": "輕鬆跑", "reason": "r",
          "primary": { "run_type": "easy" } }
        """
        XCTAssertNil(
            App2HomeViewModel.todaySession(
                days: [try day(neither)], todayIndex: 1, dayLabel: "週一"
            )?.summary
        )
    }

    /// 未知的 `run_type` 不得把識別字印上畫面：`DayType` 對不到就退 `category`。
    func test_todaySession_unknownRunType_fallsBackToCategory() throws {
        let json = """
        { "day_index": 1, "day_target": "t", "reason": "r", "category": "特殊課",
          "primary": { "run_type": "totally_new_type", "distance_km": 3 } }
        """
        let session = App2HomeViewModel.todaySession(
            days: [try day(json)], todayIndex: 1, dayLabel: "週一"
        )
        XCTAssertEqual(session?.title, "特殊課")
    }

    // MARK: - 指標網格（§3.1a）

    func test_insights_keepsFixedOrderAndSkipsUnknownKeys() throws {
        let rows = [
            "speed_endurance": try metricRow(#"{"envelope": {"point_estimate": 62}}"#),
            "capability_baseline": try metricRow(#"{"envelope": {"point_estimate": 64}}"#),
            "totally_unknown": try metricRow(#"{"envelope": {"point_estimate": 1}}"#)
        ]
        let insights = App2HomeViewModel.insights(rows: rows)
        XCTAssertEqual(insights.map(\.id), ["capability_baseline", "speed_endurance"])
        XCTAssertEqual(insights.map(\.value), ["64", "62"])
    }

    func test_insights_notComputedRow_hasNilValue() throws {
        let rows = [
            "recovery_index": try metricRow(#"{"delivery_status": "not_computed"}"#)
        ]
        let insights = App2HomeViewModel.insights(rows: rows)
        XCTAssertEqual(insights.count, 1)
        XCTAssertNil(insights[0].value)
        // 評級文案沒有 producer（§7-2）→ 恆 nil，畫面顯示 `—`。
        XCTAssertNil(insights[0].verdict)
        XCTAssertEqual(insights[0].direction, .unknown)
    }

    func test_insights_noKnownKeys_returnsEmpty() throws {
        let rows = ["nope": try metricRow(#"{"envelope": {"value": 3}}"#)]
        XCTAssertTrue(App2HomeViewModel.insights(rows: rows).isEmpty)
    }

    func test_insights_emptyRows_returnsEmpty() {
        XCTAssertTrue(App2HomeViewModel.insights(rows: [:]).isEmpty)
    }
}
