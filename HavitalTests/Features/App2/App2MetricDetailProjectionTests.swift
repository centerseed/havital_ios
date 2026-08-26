import XCTest
@testable import paceriz_dev

/// 指標第二層（checklist §51–53）的現算欄。
///
/// 鎖住的是四件會被「順手改」壞掉的事：
/// 1. 8 週平均與週高點**不含本週**（半週不能參與平均）；
/// 2. `tsb_metrics` 全 null → 整塊 nil（不畫空圖）；
/// 3. 「30 天前」序列不夠長就沒有值（不拿最舊那一筆冒充）；
/// 4. 7 日趨勢判語兩邊各要 3 天才判，門檻 ±3%。
final class App2MetricDetailProjectionTests: XCTestCase {

    // MARK: - Helpers

    private func bar(_ weekStart: String, _ km: Double, current: Bool = false) -> App2WeeklyBar {
        App2WeeklyBar(
            weekStart: weekStart,
            distanceKm: km,
            isCurrentWeek: current,
            shortLabel: App2DateLabel.short(isoDate: weekStart)
        )
    }

    private func point(_ date: String, _ value: Double) -> App2MetricPoint {
        App2MetricPoint(date: date, value: value)
    }

    // MARK: - §51 平均／高點

    func testAverageAndPeakExcludeCurrentWeek() {
        let bars = [
            bar("2026-08-03", 30),
            bar("2026-08-10", 40),
            bar("2026-08-17", 20),
            bar("2026-08-24", 5, current: true)   // 半週，不進平均也不進高點
        ]

        XCTAssertEqual(App2MetricDetailProjection.averageKm(bars) ?? 0, 30, accuracy: 0.001)
        XCTAssertEqual(App2MetricDetailProjection.peakKm(bars) ?? 0, 40, accuracy: 0.001)
    }

    func testAverageIsNilWhenOnlyCurrentWeekPresent() {
        let bars = [bar("2026-08-24", 5, current: true)]
        XCTAssertNil(App2MetricDetailProjection.averageKm(bars))
        XCTAssertNil(App2MetricDetailProjection.peakKm(bars))
    }

    func testVolumeStatsRenderPlaceholderSourceAsNil() {
        // YTD 沒回來 → 那一格是 nil（畫面畫「–」），不是 0 km。
        let stats = App2MetricDetailProjection.volumeStats(
            bars: [bar("2026-08-17", 20), bar("2026-08-24", 5, current: true)],
            ytdKm: nil
        )
        XCTAssertEqual(stats.count, 3)
        XCTAssertEqual(stats[0].value, "20 km")
        XCTAssertNil(stats[1].value)
        XCTAssertEqual(stats[2].value, "20 km")
    }

    // MARK: - §51-6 TSB

    func testLoadBlockIsNilWhenAllTsbMissing() {
        // dev 現況：`tsb_metrics` 全 null。
        let records = [
            HealthRecord(date: "2026-08-25", hrvLastNightAvg: 81, restingHeartRate: 48),
            HealthRecord(date: "2026-08-26", hrvLastNightAvg: 47, restingHeartRate: 51)
        ]
        XCTAssertNil(App2MetricDetailProjection.loadBlock(records))
    }

    func testLoadBlockTakesLatestDayValues() {
        let records = [
            HealthRecord(date: "2026-08-26", atl: 56, ctl: 42, tsb: -14),
            HealthRecord(date: "2026-08-25", atl: 50, ctl: 41, tsb: -9)
        ]
        let block = App2MetricDetailProjection.loadBlock(records)
        XCTAssertEqual(block?.series.count, 2)
        // 序列轉成舊→新
        XCTAssertEqual(block?.series.first?.date, "2026-08-25")
        XCTAssertEqual(block?.tsb, -14)
        XCTAssertEqual(block?.ctl, 42)
        XCTAssertEqual(block?.atl, 56)
    }

    // MARK: - §52 30 天前

    func testValueDaysAgoNeedsLongEnoughSeries() {
        let short = [point("2026-08-20", 38.5), point("2026-08-26", 38.7)]
        XCTAssertNil(App2MetricDetailProjection.value(in: short, daysAgo: 30, from: "2026-08-26"))

        let long = [
            point("2026-07-01", 39.0),
            point("2026-07-27", 39.2),
            point("2026-08-20", 38.5),
            point("2026-08-26", 38.7)
        ]
        XCTAssertEqual(
            App2MetricDetailProjection.value(in: long, daysAgo: 30, from: "2026-08-26") ?? 0,
            39.2,
            accuracy: 0.001
        )
    }

    // MARK: - §52-4 診斷列

    func testDiagnosticsAreDataDriven() {
        let entry = VDOTEntry(
            datetime: 1_787_702_400,
            dynamicVdot: 38.7,
            paceVdot: 38.7,
            vdotSource: "personal_best",
            anchorDate: "2026-08-25",
            anchorDecision: "weighted_16x",
            confidence: "high",
            dailyCount: 10
        )
        let rows = App2MetricDetailProjection.diagnostics(latest: entry)
        XCTAssertEqual(rows.map(\.id), ["anchor", "decision", "evidence", "confidence"])
        // `evidence_completeness` 缺席 → 只講知道的那一件（n = 10），不換算百分比
        XCTAssertFalse(rows[2].value.contains("%"))

        // 一個欄位都沒有 → 一列都不出現（不畫一排「–」）
        let bare = VDOTEntry(datetime: 1_787_702_400, dynamicVdot: 38.7)
        XCTAssertTrue(App2MetricDetailProjection.diagnostics(latest: bare).isEmpty)
        XCTAssertTrue(App2MetricDetailProjection.diagnostics(latest: nil).isEmpty)
    }

    // MARK: - §53-3 七日趨勢

    func testHrvTrendNeedsThreeDaysEachSide() {
        let thin = (0..<5).map { point("2026-08-0\($0 + 1)", 50) }
        // 後 7 天有 5 筆、前 7 天只有 0 筆 → 判不了
        XCTAssertNil(App2MetricDetailProjection.hrvTrend(thin))
    }

    func testHrvTrendThresholds() {
        func series(previous: [Double], recent: [Double]) -> [App2MetricPoint] {
            let values = previous + recent
            return values.enumerated().map { index, value in
                point(String(format: "2026-08-%02d", index + 1), value)
            }
        }

        // +10% → 佳
        XCTAssertEqual(
            App2MetricDetailProjection.hrvTrend(
                series(previous: Array(repeating: 50, count: 7),
                       recent: Array(repeating: 55, count: 7))
            ),
            .up
        )
        // −10% → 偏低
        XCTAssertEqual(
            App2MetricDetailProjection.hrvTrend(
                series(previous: Array(repeating: 50, count: 7),
                       recent: Array(repeating: 45, count: 7))
            ),
            .down
        )
        // +2%（在 ±3% 門檻內）→ 持平，不報「變好」
        XCTAssertEqual(
            App2MetricDetailProjection.hrvTrend(
                series(previous: Array(repeating: 50, count: 7),
                       recent: Array(repeating: 51, count: 7))
            ),
            .flat
        )
    }

    func testRecoveryStatsUseLatestSample() {
        let hrv = [point("2026-08-25", 81), point("2026-08-26", 63)]
        let rhr = [point("2026-08-25", 48), point("2026-08-26", 42)]
        let stats = App2MetricDetailProjection.recoveryStats(hrv: hrv, restingHR: rhr)
        XCTAssertEqual(stats[0].value, "63 ms")
        XCTAssertEqual(stats[1].value, "42 bpm")
        // 序列只有兩天 → 趨勢判不了，那一格是 nil
        XCTAssertNil(stats[2].value)
    }

    // MARK: - 共用格式

    func testSignedLabel() {
        XCTAssertEqual(App2MetricDetailProjection.signedLabel(-0.3), "−0.3")
        XCTAssertEqual(App2MetricDetailProjection.signedLabel(1.26), "+1.3")
        XCTAssertEqual(App2MetricDetailProjection.signedLabel(0), "0.0")
    }

    func testShortDateLabelFallsBackToRawString() {
        XCTAssertEqual(App2DateLabel.short(isoDate: "2026-08-04"), "8/4")
        XCTAssertEqual(App2DateLabel.short(isoDate: "n/a"), "n/a")
    }

    // MARK: - 入口把關

    func testOnlyThreeMetricsHaveDetailPages() {
        XCTAssertEqual(App2MetricDetailKind.from(insightID: "weekly_volume"), .weeklyVolume)
        XCTAssertEqual(App2MetricDetailKind.from(insightID: "capability_baseline"), .capabilityBaseline)
        XCTAssertEqual(App2MetricDetailKind.from(insightID: "recovery_index"), .recoveryIndex)
        // 沒有詳情稿的指標不可點（首頁也不畫 chevron）
        XCTAssertNil(App2MetricDetailKind.from(insightID: "aerobic_endurance"))
        XCTAssertNil(App2MetricDetailKind.from(insightID: "speed_endurance"))
        XCTAssertNil(App2MetricDetailKind.from(insightID: "heat_sensitivity"))
    }
}
