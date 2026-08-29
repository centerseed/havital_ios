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

    /// 首頁那一列。`graded`／`notComputed` 對應後端的 `status`。
    private func insight(
        _ id: String,
        value: String? = nil,
        verdict: String? = nil,
        evidence: String? = nil,
        graded: Bool = true,
        notComputed: Bool = false
    ) -> App2Insight {
        App2Insight(
            id: id,
            label: id,
            value: value,
            direction: .unknown,
            verdict: verdict,
            evidence: evidence,
            isNotComputed: notComputed,
            isGraded: graded
        )
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

    // MARK: - §52 未來預估段（2026-08-27 晚走查裁決（f））

    /// `vdots` 一條序列同時裝歷史與「建計畫時生成的未來每日預估」
    /// （dev 帳號實測 45 筆中 28 筆是未來日）。切點是用戶當地的今天。
    func testSplitProjectedSeparatesFutureEstimates() {
        let series = [
            point("2026-08-24", 38.4),
            point("2026-08-26", 38.6),
            point("2026-08-27", 38.6),   // 今天仍算歷史
            point("2026-08-28", 38.7),
            point("2026-10-04", 39.6)
        ]

        let split = App2MetricDetailProjection.splitProjected(series, today: "2026-08-27")

        XCTAssertEqual(split.history.map(\.date), ["2026-08-24", "2026-08-26", "2026-08-27"])
        XCTAssertEqual(split.projectedFromIndex, 3, "索引是整條序列上的位置，圖表要用它畫")
    }

    /// 全是歷史（沒有計畫在跑）→ 不切，也不畫虛線。
    func testSplitProjectedWithoutFutureKeepsWholeSeries() {
        let series = [point("2026-08-24", 38.4), point("2026-08-26", 38.6)]
        let split = App2MetricDetailProjection.splitProjected(series, today: "2026-08-27")

        XCTAssertEqual(split.history.count, 2)
        XCTAssertNil(split.projectedFromIndex)
    }

    /// hero 的「目前跑力」與「30 天前」**只吃歷史段**。
    /// 之前取 `series.last` ＝ 顯示賽事日的預估值（bug）。
    func testHeroAndThirtyDaysAgoIgnoreFutureEstimates() {
        let series = [
            point("2026-07-20", 38.0),
            point("2026-07-27", 38.2),
            point("2026-08-27", 38.6),
            point("2026-10-04", 39.6)   // 賽事日預估，不得冒充現值
        ]
        let split = App2MetricDetailProjection.splitProjected(series, today: "2026-08-27")

        XCTAssertEqual(split.history.last?.value ?? 0, 38.6, accuracy: 0.001)
        XCTAssertEqual(
            App2MetricDetailProjection.value(in: split.history, daysAgo: 30, from: "2026-08-27") ?? 0,
            38.2,
            accuracy: 0.001
        )
    }

    /// 圖表兩段共用整條序列的座標系：實線 `0...start-1`、虛線含交界點。
    func testChartRangesCoverBothSegmentsWithoutGap() {
        let line = App2MetricLineChart.Series(
            id: "vdot",
            points: [
                point("2026-08-24", 38.4),
                point("2026-08-26", 38.6),
                point("2026-08-27", 38.6),
                point("2026-08-28", 38.7),
                point("2026-10-04", 39.6)
            ],
            tint: .blue,
            projectedFromIndex: 3
        )

        XCTAssertEqual(App2MetricLineChart.historyRange(line), 0...2)
        XCTAssertEqual(App2MetricLineChart.projectedRange(line), 2...4, "虛線要含交界那一點才接得上")
    }

    /// **兩個顯示點必須一致**：能力基準 hero 與配速區間頁的 VDOT
    /// （`VDOTManager.statistics.latestDynamicVdot`）都是「今天以前的最後一筆」。
    /// 修正前配速區間顯示 39.6（賽事日預估）、能力基準顯示 38.5（使用者回報）。
    func testVdotStatisticsLatestIgnoresFutureEstimates() {
        let now = Date(timeIntervalSince1970: 1_787_000_000)   // 切點
        func dataPoint(_ offsetDays: Double, _ value: Double) -> EnhancedVDOTDataPoint {
            EnhancedVDOTDataPoint(
                date: now.addingTimeInterval(offsetDays * 86_400),
                dynamicVdot: value,
                weightVdot: nil
            )
        }

        let statistics = VDOTStatistics(
            from: [dataPoint(-7, 38.2), dataPoint(-1, 38.5), dataPoint(1, 38.7), dataPoint(38, 39.6)],
            now: now
        )

        XCTAssertEqual(statistics.latestDynamicVdot, 38.5, accuracy: 0.001)
        XCTAssertEqual(statistics.dataPointCount, 4, "圖仍畫整條序列，只有『最新值』不吃未來")
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

    // MARK: - 入口把關（2026-08-29 裁決）

    /// 有序列端點的三頁**恆可點**：它們的圖與統計欄不吃 `insights[]` 的狀態，
    /// 那一列沒評出來時頁上仍有東西可看。
    func testSeriesBackedPagesStayTappableRegardlessOfStatus() {
        XCTAssertEqual(
            App2MetricDetailKind.from(insight: insight("weekly_volume", value: "23 km")),
            .weeklyVolume
        )
        XCTAssertEqual(
            App2MetricDetailKind.from(insight: insight("capability_baseline", graded: false)),
            .capabilityBaseline
        )
        XCTAssertEqual(
            App2MetricDetailKind.from(insight: insight("recovery_index", notComputed: true)),
            .recoveryIndex
        )
    }

    /// 母體位置那兩格整頁只有首頁那一列，所以**有值或有限制句就可點**
    /// （2026-08-29 創辦人裁決取代 2026-08-26「無詳情稿不可點」）；
    /// `not_computed` 連 envelope 都沒有 → 仍不可點。
    func testLevelMetricsAreTappableUnlessNotComputed() {
        XCTAssertEqual(
            App2MetricDetailKind.from(insight: insight("aerobic_endurance", value: "70")),
            .aerobicEndurance
        )
        XCTAssertEqual(
            App2MetricDetailKind.from(insight: insight("aerobic_endurance", graded: false)),
            .aerobicEndurance
        )
        XCTAssertEqual(
            App2MetricDetailKind.from(insight: insight("speed_endurance", graded: false)),
            .speedEndurance
        )
        XCTAssertNil(
            App2MetricDetailKind.from(insight: insight("aerobic_endurance",
                                                       graded: false, notComputed: true))
        )
        XCTAssertNil(
            App2MetricDetailKind.from(insight: insight("speed_endurance",
                                                       graded: false, notComputed: true))
        )
        // 沒有上首頁網格的指標仍然沒有頁。
        XCTAssertNil(App2MetricDetailKind.from(insight: insight("heat_sensitivity", value: "40")))
    }

    // MARK: - 母體位置兩頁的 hero

    func testLevelHeroReusesInsightFieldsWhenGraded() {
        let row = insight("aerobic_endurance", value: "70",
                          verdict: "strong", evidence: "limited")
        let hero = App2MetricDetailProjection.levelHero(insight: row)

        XCTAssertEqual(hero.valueText, "70")
        XCTAssertEqual(hero.verdict, "strong")
        XCTAssertEqual(hero.narrative, "limited")
        // 逐週對照序列還沒有 producer（SPEC-today-state §11-7）→ 右側那一格整格不畫，
        // 不掛一個永遠是「–」的標籤。
        XCTAssertNil(hero.compareLabel)
        XCTAssertNil(hero.compareValue)
    }

    func testLevelHeroHasNoNumberWhenInsufficient() {
        let row = insight("speed_endurance", verdict: "unclear",
                          evidence: "only 0 of 6", graded: false)
        let hero = App2MetricDetailProjection.levelHero(insight: row)

        // 值缺席 → 畫面畫 `placeholder`，不編數字。
        XCTAssertNil(hero.valueText)
        XCTAssertEqual(hero.verdict, "unclear")
        XCTAssertEqual(hero.narrative, "only 0 of 6")
    }

    /// insufficient 才把限制句展開成「還需要什麼」；graded 沒有這一塊。
    func testLevelShortfallOnlyWhenNotGraded() {
        XCTAssertNotNil(App2MetricDetailProjection.levelShortfall(
            insight: insight("aerobic_endurance", graded: false), kind: .aerobicEndurance
        ))
        XCTAssertNil(App2MetricDetailProjection.levelShortfall(
            insight: insight("aerobic_endurance", value: "70"), kind: .aerobicEndurance
        ))
    }

    /// 兩格量的不是同一件事，解釋不得共用同一句。
    func testLevelCopyIsPerMetric() {
        XCTAssertNotEqual(
            App2MetricDetailProjection.levelAbout(.aerobicEndurance),
            App2MetricDetailProjection.levelAbout(.speedEndurance)
        )
        XCTAssertNotEqual(
            App2MetricDetailProjection.levelShortfall(
                insight: insight("aerobic_endurance", graded: false), kind: .aerobicEndurance
            ),
            App2MetricDetailProjection.levelShortfall(
                insight: insight("speed_endurance", graded: false), kind: .speedEndurance
            )
        )
    }
}
