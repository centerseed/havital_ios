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
        basis: String? = nil,
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
            basis: basis,
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
        // 後端交來是新→舊；三欄取的是**日期最新**那一天，不是陣列第一筆。
        let records = [
            HealthRecord(date: "2026-08-26", atl: 56, ctl: 42, tsb: -14),
            HealthRecord(date: "2026-08-25", atl: 50, ctl: 41, tsb: -9)
        ]
        let block = App2MetricDetailProjection.loadBlock(records)
        XCTAssertEqual(block?.tsb, -14)
        XCTAssertEqual(block?.ctl, 42)
        XCTAssertEqual(block?.atl, 56)
    }

    func testHealthSeriesKeepsSharedDatesWhenEachMetricHasAMissingDay() {
        let records = [
            HealthRecord(date: "2026-09-01", hrvLastNightAvg: 48, restingHeartRate: nil),
            HealthRecord(date: "2026-09-02", hrvLastNightAvg: nil, restingHeartRate: 52)
        ]

        let hrv = App2MetricDetailProjection.healthSeries(records) { $0.hrvLastNightAvg }
        let restingHeartRate = App2MetricDetailProjection.healthSeries(records) {
            $0.restingHeartRate.map(Double.init)
        }

        XCTAssertEqual(hrv.map(\.date), ["2026-09-01", "2026-09-02"])
        XCTAssertEqual(restingHeartRate.map(\.date), hrv.map(\.date))
        XCTAssertNotNil(hrv.first { $0.date == "2026-09-02" }, "HRV's missing day must stay on the shared x axis")
        XCTAssertNotNil(restingHeartRate.first { $0.date == "2026-09-01" }, "RHR's missing day must stay on the shared x axis")
    }

    func testTsbSeriesUsesThirtyCalendarDaysAndKeepsMissingValues() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let end = try XCTUnwrap(formatter.date(from: "2026-09-30"))
        let records = try (0..<35).map { offset -> HealthRecord in
            let date = try XCTUnwrap(calendar.date(byAdding: .day, value: offset - 34, to: end))
            return HealthRecord(
                date: formatter.string(from: date),
                tsb: offset == 20 ? nil : Double(offset)
            )
        }.reversed()

        let series = App2MetricDetailProjection.tsbSeries(Array(records), asof: "2026-09-30")

        XCTAssertEqual(series.count, 30)
        XCTAssertEqual(series.first?.date, "2026-09-01")
        XCTAssertEqual(series.last?.date, "2026-09-30")
        XCTAssertNil(series[15].value, "A missing TSB day stays on the x axis as a gap")
        XCTAssertEqual(series.last?.value, 34)
    }

    func testTsbBandBoundariesMatchTheDesign() {
        let labels = ["myachievement.text_3", "myachievement.text_4", "myachievement.text_5"]
            .map { NSLocalizedString($0, comment: "") }
        XCTAssertEqual(App2MetricDetailProjection.tsbBandLabel(for: -7.01), labels[0])
        XCTAssertEqual(App2MetricDetailProjection.tsbBandLabel(for: -7), labels[1])
        XCTAssertEqual(App2MetricDetailProjection.tsbBandLabel(for: 1), labels[1])
        XCTAssertEqual(App2MetricDetailProjection.tsbBandLabel(for: 1.01), labels[2])

        let bands = App2MetricDetailProjection.tsbBands()
        XCTAssertEqual(bands.count, 3)
        XCTAssertNil(bands[0].lower)
        XCTAssertEqual(bands[0].upper, -7)
        XCTAssertEqual(bands[1].lower, -7)
        XCTAssertEqual(bands[1].upper, 1)
        XCTAssertEqual(bands[2].lower, 1)
        XCTAssertNil(bands[2].upper)
    }

    @MainActor
    func testTsbBandLabelsUseJapaneseOneFourLegendStrings() {
        let previousLanguage = LanguageManager.shared.currentLanguage.rawValue
        Bundle.setLanguage("ja")
        defer { Bundle.setLanguage(previousLanguage) }

        XCTAssertEqual(
            App2MetricDetailProjection.tsbBands().map(\.legendLabel),
            ["疲労蓄積", "バランス状態", "最適状態"]
        )
        XCTAssertEqual(App2MetricDetailProjection.tsbBandLabel(for: -8), "疲労蓄積")
    }

    func testTsbBoundsKeepAllThreeThresholdsVisibleWhenValuesAreBelowMinusSeven() {
        let points = [point("2026-09-30", -10)]
        let bounds = App2MetricLineChart.bounds(
            points,
            including: App2MetricDetailProjection.tsbBands(),
            referenceValues: [-7, 0, 1]
        )

        XCTAssertNotNil(bounds)
        XCTAssertLessThan(bounds!.lower, -10)
        XCTAssertGreaterThan(bounds!.upper, 1)
        for threshold in [-7.0, 0, 1] {
            XCTAssertGreaterThanOrEqual(threshold, bounds!.lower)
            XCTAssertLessThanOrEqual(threshold, bounds!.upper)
        }
    }

    func testMetricReadoutSelectionSkipsMissingPointsAndIsOffByDefault() {
        let forecast = App2MetricLineChart.Series(
            id: "vdot",
            points: [
                point("2026-09-01", 38),
                App2MetricPoint(date: "2026-09-02", value: nil),
                point("2026-09-03", 39),
                point("2026-09-04", 40)
            ],
            tint: .purple,
            projectedFromIndex: 2,
            projectedLegend: "Projected"
        )

        XCTAssertEqual(
            App2MetricLineChart.nearestSelectableIndex(atFraction: 0.5, series: [forecast]),
            2
        )
        XCTAssertEqual(App2MetricLineChart.projectedRange(forecast), 1...3)
        XCTAssertNil(App2MetricLineChart.nearestSelectableIndex(
            atFraction: 0.5,
            series: [.init(id: "empty", points: [
                App2MetricPoint(date: "2026-09-01", value: nil),
                App2MetricPoint(date: "2026-09-02", value: nil)
            ], tint: .blue)]
        ))
        XCTAssertFalse(App2MetricLineChart(series: []).allowsReadout)
        XCTAssertFalse(App2WeeklyVolumeChart(bars: []).allowsReadout)
    }

    func testTapOutsideInteractiveChartsClearsSelectedReadout() {
        let selected = App2ChartReadoutSelection(chartID: "volume-acwr", index: 4)
        let chartFrames = [
            App2ChartReadoutFrame(chartID: "volume-acwr", frame: CGRect(x: 16, y: 80, width: 358, height: 190)),
            App2ChartReadoutFrame(chartID: "volume-tsb", frame: CGRect(x: 16, y: 290, width: 358, height: 210))
        ]

        let selectionAfterChartTap = App2ChartReadoutDismissal.selection(
            afterTapAt: CGPoint(x: 180, y: 120),
            current: selected,
            chartFrames: chartFrames
        )
        XCTAssertEqual(selectionAfterChartTap, selected, "A tap inside the selected chart keeps its readout")

        let selectionAfterOtherChartTap = App2ChartReadoutDismissal.selection(
            afterTapAt: CGPoint(x: 180, y: 380),
            current: selected,
            chartFrames: chartFrames
        )
        XCTAssertNil(selectionAfterOtherChartTap, "A different chart is outside the selected chart")

        let selectionAfterOutsideTap = App2ChartReadoutDismissal.selection(
            afterTapAt: CGPoint(x: 180, y: 540),
            current: selected,
            chartFrames: chartFrames
        )
        XCTAssertNil(selectionAfterOutsideTap, "A tap on another card or page whitespace dismisses the readout")
    }

    func testWeeklyReadoutSelectsNearestBarCenterAcrossSpacing() {
        XCTAssertEqual(App2WeeklyVolumeChart.nearestBarIndex(atX: 41, slotWidth: 40, spacing: 6, count: 4), 0)
        XCTAssertEqual(App2WeeklyVolumeChart.nearestBarIndex(atX: 46, slotWidth: 40, spacing: 6, count: 4), 1)
        XCTAssertEqual(App2WeeklyVolumeChart.nearestBarIndex(atX: 184, slotWidth: 40, spacing: 6, count: 4), 3)
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

    /// 相對能力那兩格整頁只有首頁那一列，所以**有值或有限制句就可點**
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

    // MARK: - 相對能力兩頁的 hero

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

    // MARK: - T-0617 分級尺／依據句／30 天線

    /// 尺的兩個切點是 SPEC-today-state §5.1 的 `35`／`65`，**逐字抄自 spec**：
    /// 從實作 import 會讓這條 assert 恆真。
    func testLevelScaleUsesTheSpecCutpointsAndMarksTheUser() {
        let scale = App2MetricDetailProjection.levelScale(
            insight: insight("aerobic_endurance", value: "24")
        )

        XCTAssertEqual(scale?.developingMax, 35)
        XCTAssertEqual(scale?.strongMin, 65)
        XCTAssertEqual(scale?.position, 24)
    }

    /// 沒有數字就沒有指針。整條尺照畫（那是固定的判準），但不得把位置編出來。
    func testLevelScaleHasNoPositionWithoutAValue() {
        let scale = App2MetricDetailProjection.levelScale(
            insight: insight("speed_endurance", graded: false)
        )
        XCTAssertNil(scale?.position)
    }

    /// 依據句是後端組好的一句（`basis`），app 端不改寫也不自己拼。
    func testLevelBasisComesStraightFromTheInsightRow() {
        let row = insight("aerobic_endurance", value: "24",
                          basis: "近 70 天算進 35 堂輕鬆跑")
        XCTAssertEqual(App2MetricDetailProjection.levelBasis(insight: row),
                       "近 70 天算進 35 堂輕鬆跑")
        XCTAssertNil(App2MetricDetailProjection.levelBasis(
            insight: insight("aerobic_endurance", value: "24")
        ))
    }

    /// 30 天線取該項逐日 `index`，缺則 `level_index`；沒有 envelope 的那一天
    /// （`not_computed`）**跳過**，不補前一天的值（那是 LOCF，後端明令禁止）。
    func testLevelSeriesTakesIndexPerDayAndSkipsDaysWithoutARow() {
        let response = AthleteStateSeriesResponse(
            startDay: "2026-09-01",
            endDay: "2026-09-04",
            series: [
                "aerobic_endurance": [
                    .init(day: "2026-09-01", deliveryStatus: "active",
                          envelope: .init(index: 28.5, levelIndex: nil)),
                    .init(day: "2026-09-02", deliveryStatus: "not_computed", envelope: nil),
                    .init(day: "2026-09-03", deliveryStatus: "active",
                          envelope: .init(index: nil, levelIndex: 61.0)),
                    .init(day: "2026-09-04", deliveryStatus: "active",
                          envelope: .init(index: 23.7, levelIndex: 99.0))
                ]
            ]
        )

        let points = App2MetricDetailProjection.levelSeries(response, key: "aerobic_endurance")

        XCTAssertEqual(points.map(\.date), ["2026-09-01", "2026-09-03", "2026-09-04"])
        XCTAssertEqual(points.map(\.value), [28.5, 61.0, 23.7])
    }

    /// wire 形狀本身要被驗一次：四個 snake_case key 與巢狀 `series` 字典
    /// 若對不上，memberwise init 建的測試永遠看不出來（後端改欄名時全綠出貨）。
    func testLevelSeriesDecodesTheRealWireShape() throws {
        let json = """
        {"uid":"u","maturity":"observable","start_day":"2026-08-08","end_day":"2026-08-10",
         "series":{"aerobic_endurance":[
            {"day":"2026-08-08","item_id":"metric.aerobic_endurance","delivery_status":"active",
             "envelope":{"index":28.5,"level_index":null}},
            {"day":"2026-08-09","item_id":"metric.aerobic_endurance","delivery_status":"not_computed",
             "envelope":null},
            {"day":"2026-08-10","item_id":"metric.aerobic_endurance","delivery_status":"active",
             "envelope":{"index":null,"level_index":61.0}}]}}
        """
        let decoded = try JSONDecoder().decode(AthleteStateSeriesResponse.self,
                                               from: Data(json.utf8))

        XCTAssertEqual(decoded.startDay, "2026-08-08")
        XCTAssertEqual(decoded.endDay, "2026-08-10")
        XCTAssertEqual(decoded.series["aerobic_endurance"]?.first?.deliveryStatus, "active")

        let points = App2MetricDetailProjection.levelSeries(decoded, key: "aerobic_endurance")
        XCTAssertEqual(points.map(\.date), ["2026-08-08", "2026-08-10"])
        XCTAssertEqual(points.map(\.value), [28.5, 61.0])
    }

    /// 該項不在回應裡（後端沒有這一列）→ 空陣列，頁面畫佔位、不擋。
    func testLevelSeriesIsEmptyWhenTheItemIsAbsent() {
        let response = AthleteStateSeriesResponse(
            startDay: nil, endDay: nil, series: [:]
        )
        XCTAssertTrue(
            App2MetricDetailProjection.levelSeries(response, key: "speed_endurance").isEmpty
        )
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

    // MARK: - §51-6 近 30 天負荷比（T-0618）

    private func acwrDay(
        _ day: String, raw: Double?, side: String = "sweet",
        low: Double? = 0.8, high: Double? = 1.3
    ) -> AthleteStateSeriesResponse.Day {
        .init(
            day: day,
            deliveryStatus: raw == nil ? "insufficient_data" : "active",
            envelope: .init(
                index: 95.0,
                levelIndex: nil,
                channels: .init(acwr: .init(
                    raw: raw, available: raw != nil, side: side,
                    sweetLow: low, sweetHigh: high
                ))
            )
        )
    }

    /// 線讀的是 `channels.acwr.raw`，不是 `index`：兩個是不同的量，
    /// index 是 0–100 的「剛好程度」，比值才是使用者在圖上看的那條線。
    func testAcwrBlockTakesTheRatioNotTheIndex() {
        let response = AthleteStateSeriesResponse(
            startDay: nil, endDay: nil,
            series: ["load_index": [acwrDay("2026-09-05", raw: 1.38),
                                    acwrDay("2026-09-06", raw: 1.71)]]
        )
        let block = App2MetricDetailProjection.acwrBlock(response)
        XCTAssertEqual(block?.series.map(\.value), [1.38, 1.71])
        XCTAssertEqual(block?.series.map(\.date), ["2026-09-05", "2026-09-06"])
    }

    /// 比值算不出來的那天沒有點 —— 不補鄰日的值（後端 §4.10.7 禁 LOCF）。
    func testDaysWithoutARatioAreSkippedNotCarriedForward() {
        let response = AthleteStateSeriesResponse(
            startDay: nil, endDay: nil,
            series: ["load_index": [
                acwrDay("2026-09-04", raw: 1.2),
                acwrDay("2026-09-05", raw: nil, side: "basis_too_low", low: nil, high: nil),
                acwrDay("2026-09-06", raw: 1.4, side: "overload")
            ]]
        )
        let block = App2MetricDetailProjection.acwrBlock(response)
        XCTAssertEqual(block?.series.map(\.date), ["2026-09-04", "2026-09-06"])
    }

    /// 甜區上下界**由後端逐列帶**（依訓練期變），app 不寫死；取最新一天那一列。
    func testTheSweetBandComesFromTheLatestRowNotAConstant() {
        let response = AthleteStateSeriesResponse(
            startDay: nil, endDay: nil,
            series: ["load_index": [
                acwrDay("2026-09-05", raw: 1.1, low: 0.8, high: 1.3),
                acwrDay("2026-09-06", raw: 0.9, side: "sweet", low: 0.5, high: 1.0)
            ]]
        )
        let block = App2MetricDetailProjection.acwrBlock(response)
        XCTAssertEqual(block?.sweetLow, 0.5)
        XCTAssertEqual(block?.sweetHigh, 1.0)
    }

    /// 一天都算不出比值 → nil（畫佔位句，不畫空圖）。
    func testAcwrBlockIsNilWhenNoDayHasARatio() {
        let response = AthleteStateSeriesResponse(
            startDay: nil, endDay: nil,
            series: ["load_index": [
                acwrDay("2026-09-06", raw: nil, side: "basis_too_low", low: nil, high: nil)
            ]]
        )
        XCTAssertNil(App2MetricDetailProjection.acwrBlock(response))
        XCTAssertNil(App2MetricDetailProjection.acwrBlock(
            AthleteStateSeriesResponse(startDay: nil, endDay: nil, series: [:])
        ))
    }

    /// wire 形狀要被驗一次：`channels.acwr` 的 snake_case key 對不上時，
    /// memberwise init 建的測試永遠看不出來（後端改欄名就全綠出貨）。
    func testAcwrBlockDecodesTheRealWireShape() throws {
        let json = """
        {"uid":"u","maturity":"observable","start_day":"2026-09-05","end_day":"2026-09-06",
         "series":{"load_index":[
           {"day":"2026-09-05","delivery_status":"active",
            "envelope":{"index":95.3,"channels":{
              "tss":{"raw":80.0,"available":true},
              "acwr":{"raw":1.39,"available":true,"side":"overload",
                      "sweet_low":0.8,"sweet_high":1.3,"phase":"unknown"}}}},
           {"day":"2026-09-06","delivery_status":"active",
            "envelope":{"index":87.0,"channels":{
              "acwr":{"raw":1.71,"available":true,"side":"overload",
                      "sweet_low":0.8,"sweet_high":1.3,"phase":"unknown"}}}}]}}
        """
        let decoded = try JSONDecoder().decode(AthleteStateSeriesResponse.self,
                                               from: Data(json.utf8))
        let block = App2MetricDetailProjection.acwrBlock(decoded)

        XCTAssertEqual(block?.series.map(\.value), [1.39, 1.71])
        XCTAssertEqual(block?.sweetLow, 0.8)
        XCTAssertEqual(block?.sweetHigh, 1.3)
    }

    /// 甜區帶只有兩端都在才畫 —— 只有一端等於編另一端。
    func testTheSweetBandIsNotDrawnWithOnlyOneEdge() {
        XCTAssertNil(App2MetricDetailProjection.sweetBand(
            App2AcwrBlock(series: [], sweetLow: 0.8, sweetHigh: nil)
        ))
        XCTAssertNil(App2MetricDetailProjection.sweetBand(
            App2AcwrBlock(series: [], sweetLow: nil, sweetHigh: 1.3)
        ))
        let band = App2MetricDetailProjection.sweetBand(
            App2AcwrBlock(series: [], sweetLow: 0.8, sweetHigh: 1.3)
        )
        XCTAssertEqual(band?.lower, 0.8)
        XCTAssertEqual(band?.upper, 1.3)
    }

    /// 區帶把 y 上下界撐開到看得見自己 —— 一個負荷比全在 1.4 以上的人，
    /// 甜區若被裁掉，那張圖就只剩一條沒有參照的線。
    func testTheBandWidensTheChartBoundsSoItStaysVisible() {
        let points = [point("2026-09-05", 1.5), point("2026-09-06", 1.7)]
        let plain = App2MetricLineChart.bounds(points)
        let withBand = App2MetricLineChart.bounds(
            points,
            including: [App2MetricLineChart.Band(
                lower: 0.8, upper: 1.3, label: nil, tint: .green
            )]
        )
        XCTAssertNotNil(plain)
        XCTAssertGreaterThan(plain!.lower, 0.8)
        XCTAssertLessThan(withBand!.lower, 0.8)
        XCTAssertGreaterThanOrEqual(withBand!.upper, 1.7)
    }
}
