import XCTest
import SwiftUI
@testable import paceriz_dev

/// 指標第二層（checklist §51–53）的現算欄。
///
/// 鎖住的是四件會被「順手改」壞掉的事：
/// 1. 8 週平均與週高點**不含本週**（半週不能參與平均）；
/// 2. 負荷比圖的三區門檻讀後端、缺才用 0.8／1.3；
/// 3. 「30 天前」只讀 decision-chain 序列那一天的點（沒有就沒有）；
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
        change: String? = nil,
        graded: Bool = true,
        notComputed: Bool = false
    ) -> App2Insight {
        App2Insight(
            id: id,
            label: id,
            value: value,
            direction: .unknown,
            verdict: verdict,
            change: change,
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
            App2ChartReadoutFrame(chartID: "volume-acwr-2", frame: CGRect(x: 16, y: 290, width: 358, height: 210))
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

    // MARK: - §52 30 天前（decision-chain 序列）

    func testBaselineValueReadsCenterValueOnThatExactDay() throws {
        let json = """
        {"uid":"u","start_day":"2026-08-30","end_day":"2026-08-30",
         "series":{"capability_baseline":[
           {"day":"2026-08-30","item_id":"capability_baseline","delivery_status":"active",
            "envelope":{"center":{"value":39.0,"unit":"vdot"},"confidence":"high"}}]}}
        """
        let decoded = try JSONDecoder().decode(AthleteStateSeriesResponse.self, from: Data(json.utf8))
        XCTAssertEqual(
            App2MetricDetailProjection.baselineValue(decoded, on: "2026-08-30") ?? 0, 39.0, accuracy: 0.001)
        XCTAssertNil(App2MetricDetailProjection.baselineValue(decoded, on: "2026-08-31"), "沒有那天的點就是沒有，不用鄰日補")
    }

    func testBaselineValueIsNilWhenTheDayHasNoCenter() throws {
        let json = """
        {"uid":"u","series":{"capability_baseline":[
           {"day":"2026-08-30","delivery_status":"not_computed","envelope":null},
           {"day":"2026-08-31","delivery_status":"active","envelope":{"center":null}}]}}
        """
        let decoded = try JSONDecoder().decode(AthleteStateSeriesResponse.self, from: Data(json.utf8))
        XCTAssertNil(App2MetricDetailProjection.baselineValue(decoded, on: "2026-08-30"))
        XCTAssertNil(App2MetricDetailProjection.baselineValue(decoded, on: "2026-08-31"))
    }

    @MainActor
    func testCapabilityHeroCompareUsesCurrentMinusThirtyDaysAgo() {
        let hero = App2CapabilityDetailViewModel.hero(
            insight: insight("capability_baseline", value: "38.7"),
            narrative: nil, current: 38.7, previous: 39.0
        )
        XCTAssertEqual(hero.compareValue, String(
            format: L10n.App2.Metric.capabilityCompareFormat.localized, "39.0",
            App2MetricDetailProjection.signedLabel(38.7 - 39.0)))
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

    /// 圖與診斷欄的「目前」**只吃歷史段**。
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
        let hero = App2MetricDetailProjection.levelHero(insight: row, kind: .aerobicEndurance)

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
        let hero = App2MetricDetailProjection.levelHero(insight: row, kind: .speedEndurance)

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
            App2MetricDetailProjection.aboutText(.aerobicEndurance, thresholds: (0.8, 1.3)),
            App2MetricDetailProjection.aboutText(.speedEndurance, thresholds: (0.8, 1.3))
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

    // MARK: - 指標詳情可讀性（§51–53）

    func testSignedLabelNeverShowsNegativeZero() {
        XCTAssertEqual(App2MetricDetailProjection.signedLabel(-0.3, fractionDigits: 0), "0")
        XCTAssertEqual(App2MetricDetailProjection.signedLabel(-0.04), "0.0")
        XCTAssertEqual(App2MetricDetailProjection.signedLabel(0.4, fractionDigits: 0), "0")
        XCTAssertEqual(App2MetricDetailProjection.signedLabel(-12.4, fractionDigits: 0), "−12")
    }

    func testAxisTicksDropALabelThatWouldOverlapAHigherPriorityOne() {
        // range −15…5 over 118pt：0 與 +1 只差約 6pt，0 讓位
        let kept = App2MetricLineChart.visibleTickValues(
            [1, -7, 0], bounds: (lower: -15, upper: 5), height: 118, minGap: 11
        )
        XCTAssertEqual(kept, [1, -7])
        // 範圍窄（−8…2）時三顆都留
        let roomy = App2MetricLineChart.visibleTickValues(
            [1, -7, 0], bounds: (lower: -8, upper: 2), height: 118, minGap: 11
        )
        XCTAssertEqual(roomy, [1, -7, 0])
    }

    @MainActor
    func testRecoveryHeroDrawsNoBaselineCellWithoutAValue() {
        let hero = App2RecoveryDetailViewModel.hero(insight: insight("recovery_index", value: "61"), narrative: nil)
        XCTAssertNil(hero.compareLabel)
        XCTAssertNil(hero.compareValue)
    }

    func testLevelHeroTitleNamesTheMetric() {
        let aerobic = App2MetricDetailProjection.levelHero(
            insight: insight("aerobic_endurance", value: "70"), kind: .aerobicEndurance)
        let speed = App2MetricDetailProjection.levelHero(
            insight: insight("speed_endurance", value: "70"), kind: .speedEndurance)
        XCTAssertEqual(aerobic.title, L10n.App2.Metric.levelHeroTitleAerobic.localized)
        XCTAssertEqual(speed.title, L10n.App2.Metric.levelHeroTitleSpeed.localized)
        XCTAssertNotEqual(aerobic.title, speed.title)
        XCTAssertFalse(aerobic.title.contains("0–100"))
    }

    // MARK: - 詳情頁 hero 的近 7 天趨勢

    func testTrendLineUsesTheSameChangeStringAsTheHomeRow() {
        XCTAssertEqual(
            App2MetricDetailProjection.trendLine(change: "97.5 → 80.2"),
            String(format: L10n.App2.Metric.heroTrendFormat.localized, "97.5 → 80.2"))
        XCTAssertNil(App2MetricDetailProjection.trendLine(change: nil))
        XCTAssertNil(App2MetricDetailProjection.trendLine(change: ""))
    }

    @MainActor
    func testFourHeroesCarryTheTrendAndVolumeDoesNot() {
        let row = insight("x", value: "80.2", change: "97.5 → 80.2")
        let expected = App2MetricDetailProjection.trendLine(change: "97.5 → 80.2")
        XCTAssertEqual(App2MetricDetailProjection.levelHero(insight: row, kind: .aerobicEndurance).trendText, expected)
        XCTAssertEqual(App2MetricDetailProjection.levelHero(insight: row, kind: .speedEndurance).trendText, expected)
        XCTAssertEqual(App2RecoveryDetailViewModel.hero(insight: row, narrative: nil).trendText, expected)
        XCTAssertEqual(App2CapabilityDetailViewModel.hero(
            insight: row, narrative: nil, current: 80.2, previous: nil).trendText, expected)
        // 訓練量的 change 是「上週 27 km」敘事句，不是起訖趨勢
        XCTAssertNil(App2VolumeDetailViewModel.hero(insight: row, narrative: nil).trendText)
    }

    func testRecoveryTrendStatIsNamedHrvTrend() {
        let stats = App2MetricDetailProjection.recoveryStats(hrv: [], restingHR: [])
        XCTAssertEqual(stats[2].label, L10n.App2.Metric.recoveryStatTrend.localized)
        XCTAssertTrue(stats[2].label.contains("HRV"))
    }

    // MARK: - 近期負荷比圖（1.4 TSB 圖畫法，門檻讀後端）

    private func acwr(low: Double? = 0.8, high: Double? = 1.3, values: [Double?] = [1.0, 0.9]) -> App2AcwrBlock {
        App2AcwrBlock(
            series: values.enumerated().map { App2MetricPoint(date: "2026-09-2\($0.offset)", value: $0.element) },
            sweetLow: low, sweetHigh: high
        )
    }

    func testAcwrThresholdsPreferBackendBoundsElseDefaults() {
        let backend = App2MetricDetailProjection.acwrThresholds(acwr(low: 0.7, high: 1.2))
        XCTAssertEqual(backend.low, 0.7)
        XCTAssertEqual(backend.high, 1.2)
        for block in [acwr(low: nil, high: nil), acwr(low: 0.7, high: nil), acwr(low: 1.3, high: 0.8)] {
            let fallback = App2MetricDetailProjection.acwrThresholds(block)
            XCTAssertEqual(fallback.low, 0.8)
            XCTAssertEqual(fallback.high, 1.3)
        }
    }

    func testAcwrBandsAreThreeZonesWithThresholdText() {
        let bands = App2MetricDetailProjection.acwrBands(acwr())
        XCTAssertEqual(bands.count, 3)
        XCTAssertNil(bands[0].lower); XCTAssertEqual(bands[0].upper, 0.8)
        XCTAssertEqual(bands[1].lower, 0.8); XCTAssertEqual(bands[1].upper, 1.3)
        XCTAssertEqual(bands[2].lower, 1.3); XCTAssertNil(bands[2].upper)
        XCTAssertEqual(bands.map(\.legendLabel), [
            L10n.App2.Metric.acwrZoneLight.localized,
            L10n.App2.Metric.acwrZoneOk.localized,
            L10n.App2.Metric.acwrZoneHeavy.localized
        ])
        XCTAssertEqual(bands.map(\.legendDetail), ["< 0.8", "0.8–1.3", "> 1.3"])
    }

    func testAcwrZoneBoundaries() {
        let t = (low: 0.8, high: 1.3)
        XCTAssertEqual(App2MetricDetailProjection.acwrZoneLabel(for: 0.79, thresholds: t), L10n.App2.Metric.acwrZoneLight.localized)
        XCTAssertEqual(App2MetricDetailProjection.acwrZoneLabel(for: 0.8, thresholds: t), L10n.App2.Metric.acwrZoneOk.localized)
        XCTAssertEqual(App2MetricDetailProjection.acwrZoneLabel(for: 1.3, thresholds: t), L10n.App2.Metric.acwrZoneOk.localized)
        XCTAssertEqual(App2MetricDetailProjection.acwrZoneLabel(for: 1.31, thresholds: t), L10n.App2.Metric.acwrZoneHeavy.localized)
    }

    func testAcwrCurrentZoneUsesTheLatestPointWithAValue() {
        let zone = App2MetricDetailProjection.acwrCurrentZone(acwr(values: [1.5, 1.0, nil]))
        XCTAssertEqual(zone, String(format: L10n.App2.Metric.currentZoneFormat.localized,
                                    L10n.App2.Metric.acwrZoneOk.localized))
        XCTAssertNil(App2MetricDetailProjection.acwrCurrentZone(acwr(values: [nil, nil])))
    }

    func testAcwrAxisTicksAreOnlyTheTwoBoundaries() {
        XCTAssertEqual(App2MetricDetailProjection.acwrAxisTicks(acwr(low: 0.7, high: 1.2)), [1.2, 0.7])
    }

    // MARK: - 恢復分數近 30 天線（使用者 2026-09-29 裁決）

    func testRecoveryIndexSeriesUsesIndexPerDayAndSkipsDaysWithoutAnEnvelope() throws {
        let json = """
        {"uid":"u","start_day":"2026-09-04","end_day":"2026-09-06",
         "series":{"recovery_index":[
            {"day":"2026-09-04","delivery_status":"active","envelope":{"index":81.5}},
            {"day":"2026-09-05","delivery_status":"not_computed","envelope":null},
            {"day":"2026-09-06","delivery_status":"active","envelope":{"index":64.0}}]}}
        """
        let decoded = try JSONDecoder().decode(AthleteStateSeriesResponse.self, from: Data(json.utf8))
        let points = App2MetricDetailProjection.levelSeries(decoded, key: "recovery_index")
        XCTAssertEqual(points.map(\.date), ["2026-09-04", "2026-09-06"], "沒有 envelope 的那天跳過，不補值")
        XCTAssertEqual(points.map(\.value), [81.5, 64.0])
    }

    func testScoreAxisIsZeroThroughHundred() {
        XCTAssertEqual(App2MetricDetailProjection.scoreAxisRange, 0...100)
    }

    // MARK: - 恢復分數逐日柱狀圖（使用者 2026-09-29 二次裁決）

    func testLevelSeriesCarriesTheEnvelopeBand() throws {
        let json = """
        {"uid":"u","series":{"recovery_index":[
            {"day":"2026-09-04","delivery_status":"active","envelope":{"index":90.0,"band":"normal"}},
            {"day":"2026-09-05","delivery_status":"active","envelope":{"index":50.0,"band":"attention"}},
            {"day":"2026-09-06","delivery_status":"active","envelope":{"index":20.0,"band":"overtraining_risk"}}],
          "aerobic_endurance":[
            {"day":"2026-09-06","delivery_status":"active","envelope":{"index":61.0}}]}}
        """
        let decoded = try JSONDecoder().decode(AthleteStateSeriesResponse.self, from: Data(json.utf8))
        let recovery = App2MetricDetailProjection.levelSeries(decoded, key: "recovery_index")
        XCTAssertEqual(recovery.map(\.band), ["normal", "attention", "overtraining_risk"])
        XCTAssertEqual(recovery.map(\.value), [90, 50, 20])
        let aerobic = App2MetricDetailProjection.levelSeries(decoded, key: "aerobic_endurance")
        XCTAssertEqual(aerobic.map(\.band), [nil], "有氧／速度頁不帶 band，行為不變")
        XCTAssertEqual(aerobic.map(\.value), [61])
    }

    func testRecoveryBandMapsTheThreeWireValuesToTheJudgmentWords() {
        XCTAssertEqual(App2RecoveryBand(wire: "normal")?.label, L10n.App2.Metric.recoveryBandNormal.localized)
        XCTAssertEqual(App2RecoveryBand(wire: "attention")?.label, L10n.App2.Metric.recoveryBandAttention.localized)
        XCTAssertEqual(App2RecoveryBand(wire: "overtraining_risk")?.label, L10n.App2.Metric.recoveryBandRisk.localized)
        XCTAssertNil(App2RecoveryBand(wire: "something_new"))
        XCTAssertNil(App2RecoveryBand(wire: nil))
        XCTAssertEqual(
            Set([L10n.App2.Metric.recoveryBandNormal, L10n.App2.Metric.recoveryBandAttention,
                 L10n.App2.Metric.recoveryBandRisk].map { $0.localized }).count, 3)
    }

    func testRecoveryBarsCoverThirtyDaysLeaveMissingDaysEmptyAndMarkToday() {
        let points = [
            App2MetricPoint(date: "2026-09-06", value: 80, band: "normal"),
            App2MetricPoint(date: "2026-09-04", value: 40, band: "attention"),
            App2MetricPoint(date: "2026-09-07", value: 15, band: "overtraining_risk")
        ].sorted { $0.date < $1.date }
        let bars = App2MetricDetailProjection.recoveryBars(points, asof: "2026-09-07")

        XCTAssertEqual(bars.count, 30)
        XCTAssertEqual(bars.first?.date, "2026-08-09")
        XCTAssertEqual(bars.last?.date, "2026-09-07")
        XCTAssertEqual(bars.filter(\.isToday).map(\.date), ["2026-09-07"])
        XCTAssertEqual(bars.compactMap(\.value), [40, 80, 15])
        let gap = bars.first { $0.date == "2026-09-05" }
        XCTAssertNil(gap?.value, "沒有 envelope 的那天留空，不補值")
        XCTAssertNil(gap?.band)
        XCTAssertEqual(bars.last?.band, .overtrainingRisk)
        XCTAssertEqual(bars.first { $0.date == "2026-09-04" }?.band, .attention)
    }

    func testDualAxisTintsFollowEachLineOnlyWhenThereAreTwo() {
        let hrv = App2MetricLineChart.Series(id: "hrv", points: [], tint: .green)
        let rhr = App2MetricLineChart.Series(id: "rhr", points: [], tint: .red)
        let two = App2MetricLineChart.axisTints(for: [hrv, rhr])
        XCTAssertEqual(two.left, Color.green)
        XCTAssertEqual(two.right, Color.red)
        let one = App2MetricLineChart.axisTints(for: [hrv])
        XCTAssertNil(one.left)
        XCTAssertNil(one.right)
    }

    func testRecoveryLegendNamesTheUnits() {
        XCTAssertTrue(L10n.App2.Metric.recoveryHrvLegend.localized.contains("ms"))
        XCTAssertTrue(L10n.App2.Metric.recoveryRhrLegend.localized.contains("bpm"))
    }

    // MARK: - 統一版型（五頁：hero／趨勢圖／這個指標量什麼／怎麼算出來的／專屬區塊）

    func testAboutTextIsDefinedForAllFivePagesAndDiffersPerPage() {
        let t = (low: 0.8, high: 1.3)
        let kinds: [App2MetricDetailKind] = [.capabilityBaseline, .aerobicEndurance, .speedEndurance,
                                             .recoveryIndex, .weeklyVolume]
        let texts = kinds.map { App2MetricDetailProjection.aboutText($0, thresholds: t) }
        XCTAssertFalse(texts.contains(""))
        XCTAssertEqual(Set(texts).count, 5, "五頁各有自己的一段，不共用")
        XCTAssertEqual(App2MetricDetailProjection.aboutText(.aerobicEndurance, thresholds: t),
                       L10n.App2.Metric.levelAboutAerobic.localized)
        XCTAssertEqual(App2MetricDetailProjection.aboutText(.speedEndurance, thresholds: t),
                       L10n.App2.Metric.levelAboutSpeed.localized)
    }

    func testVolumeAboutUsesTheBackendThresholdsAndSixWeeks() {
        let text = App2MetricDetailProjection.aboutText(.weeklyVolume, thresholds: (low: 0.7, high: 1.2))
        XCTAssertTrue(text.contains("0.7"))
        XCTAssertTrue(text.contains("1.2"))
        XCTAssertFalse(text.contains("1.3"), "門檻讀後端，不寫死")
        XCTAssertFalse(text.contains("前四週"))
    }

    func testLoadRatioCopyNoLongerSaysFourWeeks() {
        for text in [L10n.App2.Metric.volumeAcwrCaption.localized, L10n.App2.Metric.acwrInfoFormula.localized] {
            XCTAssertFalse(text.contains("前四週"), text)
            XCTAssertFalse(text.contains("四週"), text)
            XCTAssertTrue(text.contains("6"), text)
        }
    }

    func testHowTextIsStaticForThreePagesAndTheBackendBasisForTheLevelPages() {
        XCTAssertEqual(App2MetricDetailProjection.howText(.capabilityBaseline, insight: insight("capability_baseline")),
                       L10n.App2.Metric.howCapability.localized)
        XCTAssertEqual(App2MetricDetailProjection.howText(.recoveryIndex, insight: insight("recovery_index")),
                       L10n.App2.Metric.howRecovery.localized)
        XCTAssertEqual(App2MetricDetailProjection.howText(.weeklyVolume, insight: insight("weekly_volume")),
                       L10n.App2.Metric.howVolume.localized)
        let aerobic = insight("aerobic_endurance", basis: "根據近 70 天 12 堂輕鬆跑…")
        XCTAssertEqual(App2MetricDetailProjection.howText(.aerobicEndurance, insight: aerobic), "根據近 70 天 12 堂輕鬆跑…")
        XCTAssertEqual(App2MetricDetailProjection.howText(.speedEndurance, insight: insight("speed_endurance", basis: "x")), "x")
        XCTAssertNil(App2MetricDetailProjection.howText(.aerobicEndurance, insight: insight("aerobic_endurance")),
                     "後端沒給依據句就沒有這一段，app 不自己編")
    }

    func testHowCardStartsCollapsed() {
        XCTAssertFalse(App2MetricDetailProjection.howCardStartsExpanded)
    }
}
