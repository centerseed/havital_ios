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

    /// `GET /v2/state/today` 的 `insights[]` 一列（wire → domain 走既有 mapper 的形狀）。
    private func insightRow(
        key: String,
        label: String,
        valueText: String? = nil,
        arrow: DailyStateInsight.Arrow = .unknown,
        verdict: String? = nil,
        change: String? = nil,
        status: String? = "graded"
    ) -> DailyStateInsight {
        DailyStateInsight(
            key: key, label: label, valueText: valueText, arrow: arrow,
            verdict: verdict, change: change, evidence: nil, status: status
        )
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
            upsellReason: nil, benchmarkCalibration: nil, insights: []
        )
    }

    /// `GET /v2/plan/status` 的最小 fixture（只有這幾欄影響週回顧 CTA）。
    private func planStatus(
        currentWeek: Int,
        planId: String?,
        previousSummaryId: String? = nil
    ) -> PlanStatusV2Response {
        let json = """
        { "current_week": \(currentWeek), "total_weeks": 17, "next_action": "view_plan",
          "can_generate_next_week": false,
          "current_week_plan_id": \(planId.map { "\"\($0)\"" } ?? "null"),
          "previous_week_summary_id": \(previousSummaryId.map { "\"\($0)\"" } ?? "null") }
        """
        // 解不出來就讓測試爆在這裡 —— fixture 壞掉不該靜靜跳過。
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(PlanStatusV2Response.self, from: Data(json.utf8))
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

    /// dev `a60e2c6cb83a_1` 的 day_index 5（實際 payload 節錄）。
    private let qualityDay = """
    { "day_index": 5, "day_target": "組合訓練", "reason": "基礎期第一週",
      "warmup": { "distance_km": 1.0, "pace": "7:55" },
      "cooldown": { "distance_km": 1.0, "pace": "7:55" },
      "primary": { "run_type": "steady_intervals", "distance_km": 4.2,
        "segments": [
          { "kind": "steady", "distance_km": 3.0, "pace": "7:55" },
          { "kind": "interval", "repeats": 6,
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

    // MARK: - 指標膠囊列（producer ＝ /v2/state/today 的 insights[]）

    func test_insights_keepsBackendOrderAndLabels() {
        let rows = [
            insightRow(key: "capability_baseline", label: "能力基準", status: "not_computed"),
            insightRow(key: "weekly_volume", label: "訓練量", valueText: "23 km",
                       arrow: .up, verdict: "上升", change: "23 vs 上週 0 km")
        ]
        let insights = App2HomeViewModel.insights(rows: rows)
        // 順序、名稱、評級全部照後端；app 端不排序也不改名。
        XCTAssertEqual(insights.map(\.id), ["capability_baseline", "weekly_volume"])
        XCTAssertEqual(insights.map(\.label), ["能力基準", "訓練量"])
    }

    /// 回歸：**有真值就要有箭頭與評級**，不得整排灰。
    /// 2026-08-25 首頁綁到 `/v2/athlete-state/metrics`（依規格不評級）→ 五顆膠囊
    /// 全是灰 icon ＋ 小點，而同一個帳號的 `state/today` 明明帶著 `arrow: up`。
    func test_insights_gradedRow_carriesArrowAndVerdict() {
        let insights = App2HomeViewModel.insights(rows: [
            insightRow(key: "weekly_volume", label: "訓練量", valueText: "23 km",
                       arrow: .up, verdict: "上升", change: "23 vs 上週 0 km")
        ])
        XCTAssertEqual(insights.first?.direction, .up)
        XCTAssertEqual(insights.first?.arrowGlyph, "↑")
        XCTAssertEqual(insights.first?.value, "23 km")
        XCTAssertEqual(insights.first?.verdict, "上升")
        XCTAssertEqual(insights.first?.change, "23 vs 上週 0 km")
        XCTAssertFalse(insights.first?.isNotComputed ?? true)
    }

    func test_insights_notComputedRow_isMarkedAndHasNoValue() {
        let insights = App2HomeViewModel.insights(rows: [
            insightRow(key: "recovery_index", label: "恢復", verdict: "尚未計算",
                       status: "not_computed")
        ])
        XCTAssertNil(insights.first?.value)
        XCTAssertEqual(insights.first?.direction, .unknown)
        XCTAssertTrue(insights.first?.isNotComputed ?? false)
        // 「尚未計算」是後端的話，畫面要說出來，不是靜靜地灰掉。
        XCTAssertEqual(insights.first?.verdict, "尚未計算")
    }

    func test_insights_emptyRows_returnsEmpty() {
        XCTAssertTrue(App2HomeViewModel.insights(rows: []).isEmpty)
    }

    // MARK: - 回歸：週數 chrome 不得來自樣本

    /// 樣本檔已經不帶週數欄位，`offlineTrainingStatus` 只准把真週數填進去。
    func test_offlineTrainingStatus_usesRealWeeks_notSampleWeeks() {
        let status = App2HomeViewModel.offlineTrainingStatus(currentWeek: 1, totalWeeks: 17)
        XCTAssertEqual(status.currentWeek, 1)
        XCTAssertEqual(status.totalWeeks, 17)
        // 敘事是樣本，週數不是。
        XCTAssertEqual(status.headline, App2StubFixtures.trainingStatus.headline)
    }

    /// 真週數拿不到時寧可不顯示，也不拿樣本的週數頂上。
    func test_offlineTrainingStatus_withoutPlanStatus_leavesWeeksNil() {
        let status = App2HomeViewModel.offlineTrainingStatus(currentWeek: nil, totalWeeks: nil)
        XCTAssertNil(status.currentWeek)
        XCTAssertNil(status.totalWeeks)
    }

    func test_stubTrainingStatus_carriesNoWeekNumbers() {
        XCTAssertNil(App2StubFixtures.trainingStatus.currentWeek)
        XCTAssertNil(App2StubFixtures.trainingStatus.totalWeeks)
    }

    // MARK: - 回歸：課表存在時首頁不得說「尚未產生」

    /// 「本週課表尚未產生」只有在 `current_week_plan_id` 真的是 nil 時才准講。
    /// 週課表讀得到今天的課 → 一定要是 `.session`。
    func test_todayState_planExists_isSessionNotNotGenerated() throws {
        let session = App2HomeViewModel.todaySession(
            days: [try day(easyRunDay)], todayIndex: 2, dayLabel: "週二 · 8/25"
        )
        let state = App2TodaySessionState.session(try XCTUnwrap(session))
        XCTAssertNotEqual(state, .notGenerated)
        if case .session(let value) = state {
            XCTAssertEqual(value.summary, "9.0 km · 7:55/km")
        } else {
            XCTFail("課表存在時不得落到 notGenerated／unavailable")
        }
    }

    /// 讀取失敗與「沒有課表」是兩件事 —— 型別上就分得開。
    func test_todayState_unavailableIsNotNotGenerated() {
        XCTAssertNotEqual(App2TodaySessionState.unavailable, .notGenerated)
        XCTAssertNotEqual(App2TodaySessionState.noSessionToday, .notGenerated)
    }

    // MARK: - 週回顧 CTA 的時機與狀態

    /// 出現條件只有一條：目標週是「可回顧的訓練週」，而且回顧還沒生成。
    /// 三態各鎖一條。

    /// demo 帳號現況：課表第 1 週才開始，平日看的上週根本沒有課表 → 整張卡不顯示。
    func test_weekReview_targetWeekHasNoPlan_cardIsHidden() {
        let status = planStatus(currentWeek: 1, planId: "a60e2c6cb83a_1")
        XCTAssertNil(
            App2HomeViewModel.weekReviewState(planStatus: status, isSunday: false, summaryId: nil)
        )
    }

    /// 上週有課表、回顧還沒生成 → 「產生上週回顧」。
    func test_weekReview_lastWeekHasPlanNoSummary_offersGenerate() {
        let status = planStatus(currentWeek: 5, planId: "ov_5")
        XCTAssertEqual(
            App2HomeViewModel.weekReviewState(planStatus: status, isSunday: false, summaryId: nil),
            .notGenerated(isCurrentWeek: false)
        )
    }

    /// 已生成 → 「查看回顧」。
    func test_weekReview_summaryExists_offersView() {
        let status = planStatus(currentWeek: 5, planId: "ov_5", previousSummaryId: "ov_4_summary")
        XCTAssertEqual(
            App2HomeViewModel.weekReviewState(
                planStatus: status, isSunday: false, summaryId: status.previousWeekSummaryId
            ),
            .available(summaryId: "ov_4_summary", isCurrentWeek: false)
        )
    }

    /// 週日看的是本週；本週沒有課表一樣不顯示。
    func test_weekReview_sunday_usesCurrentWeekAndNeedsPlan() {
        let withPlan = planStatus(currentWeek: 1, planId: "ov_1")
        XCTAssertEqual(
            App2HomeViewModel.weekReviewState(planStatus: withPlan, isSunday: true, summaryId: nil),
            .notGenerated(isCurrentWeek: true)
        )
        let withoutPlan = planStatus(currentWeek: 1, planId: nil)
        XCTAssertNil(
            App2HomeViewModel.weekReviewState(planStatus: withoutPlan, isSunday: true, summaryId: nil)
        )
    }

    /// 設計 dc.html:5112：週日看本週，週一～週六看上週。
    func test_isSunday_matchesDesignRule() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei") ?? .current
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.hour = 12

        components.day = 30            // 2026-08-30 是週日
        if let sunday = calendar.date(from: components) {
            XCTAssertTrue(App2HomeViewModel.isSunday(date: sunday, calendar: calendar))
        }
        components.day = 25            // 2026-08-25 是週二
        if let tuesday = calendar.date(from: components) {
            XCTAssertFalse(App2HomeViewModel.isSunday(date: tuesday, calendar: calendar))
        }
    }

    // MARK: - 今日課表卡的分段與結構預覽

    func test_segments_intervalDay_listsWorkAndRecovery() throws {
        let segments = App2HomeViewModel.segments(day: try day(intervalDay))
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments.first?.detail, "6 × 200m @ 5:25")
        XCTAssertTrue(segments.first?.isWork ?? false)
        XCTAssertFalse(segments.last?.isWork ?? true)
    }

    /// 單段課只有一行主課、前後沒有熱身緩和 → 與卡片上的「課表」列重複，不畫表。
    func test_segments_singleSegmentDay_isEmpty() throws {
        XCTAssertTrue(App2HomeViewModel.segments(day: try day(easyRunDay)).isEmpty)
    }

    func test_structureBars_intervalDay_hasOneWorkBarPerRep() throws {
        let bars = App2HomeViewModel.structureBars(day: try day(intervalDay))
        XCTAssertEqual(bars.filter { $0.kind == .interval }.count, 6)
        // 最後一趟後面不接恢復柱。
        XCTAssertEqual(bars.last?.kind, .interval)
    }

    /// dev 第 1 週的質課日（day_index 5）：熱身 ＋ 穩定段 ＋ 6×200m ＋ 恢復 ＋ 緩和。
    /// 依 payload 的實際順序全部展開，不是只挑間歇段。
    func test_segments_qualityDay_expandsWarmupSteadyIntervalCooldown() throws {
        let segments = App2HomeViewModel.segments(day: try day(qualityDay))
        XCTAssertEqual(segments.count, 5)
        XCTAssertEqual(segments.map(\.isWork), [false, true, true, false, false])
        XCTAssertEqual(segments[1].detail, "3.0 km @ 7:55")
        XCTAssertEqual(segments[2].detail, "6 × 200m @ 5:25")
        XCTAssertEqual(segments[4].detail, "1.0 km @ 7:55")
    }

    /// 回歸：**只有衝刺的 repeat 算「趟」**。`6 × 200m` 的課要畫 6 根橘柱，
    /// 主課穩定段／熱身／恢復／緩和都是淺柱 —— 之前把穩定段也算進去，
    /// 卡上寫成「趟數 × 7 趟」（2026-08-25 用戶在截圖上抓到）。
    func test_structureBars_qualityDay_countsOnlySprintReps() throws {
        let bars = App2HomeViewModel.structureBars(day: try day(qualityDay))
        XCTAssertEqual(bars.first?.kind, .support)      // 熱身
        XCTAssertEqual(bars.last?.kind, .support)       // 緩和
        XCTAssertEqual(bars.filter { $0.kind == .interval }.count, 6) // 只有 6 趟衝刺
    }

    /// 單段輕鬆跑（沒有熱身緩和）也要畫得出配速結構：一整塊綠色穩定段，塊上標配速。
    /// 2026-08-25 用戶裁決：結構圖不是間歇專屬。
    func test_structureBars_singleSegmentEasyRun_isOneSteadyBlockWithPace() throws {
        let bars = App2HomeViewModel.structureBars(day: try day(easyRunDay))
        XCTAssertEqual(bars.count, 1)
        XCTAssertEqual(bars.first?.kind, .steady)
        XCTAssertNotNil(bars.first?.paceLabel)
    }

    /// 沒有衝刺段的課（輕鬆跑＋熱身緩和）→ 一根橘柱都沒有，畫面也不寫趟數。
    func test_structureBars_nonIntervalDay_hasNoWorkBars() throws {
        let json = """
        { "day_index": 2, "day_target": "輕鬆跑", "reason": "有氧",
          "warmup": { "distance_km": 1.0, "pace": "7:55" },
          "cooldown": { "distance_km": 1.0, "pace": "7:55" },
          "primary": { "run_type": "easy", "distance_km": 8.0, "pace": "7:55" } }
        """
        let bars = App2HomeViewModel.structureBars(day: try day(json))
        XCTAssertFalse(bars.isEmpty)
        XCTAssertEqual(bars.filter { $0.kind == .interval }.count, 0)
        // 前後淺色塊 ＋ 中間一塊綠色穩定段。
        XCTAssertEqual(bars.map(\.kind), [.support, .steady, .support])
    }

    func test_structureBars_restDay_isEmpty() throws {
        XCTAssertTrue(App2HomeViewModel.structureBars(day: try day(restDay)).isEmpty)
    }

    // MARK: - Rizo 推話只用既有句子

    func test_rizoOpeningLine_prefersCollapsedReason() {
        let line = App2HomeViewModel.rizoOpeningLine(
            card: card(collapsedReason: "今天安排休息日，本週訓練完成 0/3。")
        )
        XCTAssertEqual(line, "今天安排休息日，本週訓練完成 0/3。")
    }

    /// 組不出句子就回 nil —— 畫面把 Rizo 區退成純入口，不寫假對話。
    func test_rizoOpeningLine_withoutSentences_isNil() {
        XCTAssertNil(App2HomeViewModel.rizoOpeningLine(card: card(narrative: nil)))
    }
}
