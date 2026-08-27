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

    /// 真實 payload 形狀 → domain entity。走的是正式路徑上的同一支 mapper
    /// （`TrainingSessionMapper`），投影測到的東西才跟 App 看到的一致。
    private func day(_ json: String) throws -> DayDetail {
        TrainingSessionMapper.toEntity(
            from: try JSONDecoder().decode(DayDetailDTO.self, from: Data(json.utf8))
        )
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

    /// `GET /v2/plan/status` 的 fixture。欄位名照後端 wire format 並走正式路徑上的
    /// 同一個 `Codable` —— 這樣 decode 容錯也一併被測到（§A.4 坑 `dd07409f`）。
    ///
    /// `metadata` 預設帶 `Asia/Tokyo`（dev 實查值）＋ 可指定的 `server_time`：
    /// 週回顧的時機**只能**由這兩欄決定，不看裝置星期。
    private func planStatus(
        currentWeek: Int,
        planId: String?,
        previousSummaryId: String? = nil,
        totalWeeks: Int = 17,
        nextAction: String = "view_plan",
        canGenerateNextWeek: Bool = false,
        userTimezone: String? = "Asia/Tokyo",
        serverTime: String? = nil,
        nextWeekInfoJSON: String = "null",
        includeMetadata: Bool = true
    ) -> PlanStatusV2Response {
        func quoted(_ value: String?) -> String { value.map { "\"\($0)\"" } ?? "null" }
        let metadata = includeMetadata
            ? "{ \"user_timezone\": \(quoted(userTimezone)), \"server_time\": \(quoted(serverTime)) }"
            : "null"
        let json = """
        { "current_week": \(currentWeek), "total_weeks": \(totalWeeks),
          "next_action": "\(nextAction)",
          "can_generate_next_week": \(canGenerateNextWeek),
          "current_week_plan_id": \(quoted(planId)),
          "previous_week_summary_id": \(quoted(previousSummaryId)),
          "next_week_info": \(nextWeekInfoJSON),
          "metadata": \(metadata) }
        """
        // 解不出來就讓測試爆在這裡 —— fixture 壞掉不該靜靜跳過。
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(PlanStatusV2Response.self, from: Data(json.utf8))
    }

    /// 使用者時區 `Asia/Tokyo` 的某一天中午，寫成後端會給的 UTC ISO `server_time`。
    /// 2026-08 的 Tokyo 是 UTC+9 且無日光節約，所以當地 12:00 ＝ UTC 03:00。
    /// 2026-08：24 一 · 25 二 · 26 三 · 27 四 · 28 五 · 29 六 · 30 日。
    private func tokyoNoon(day: Int) -> String {
        String(format: "2026-08-%02dT03:00:00.000000+00:00", day)
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

    /// 2026-08-26 裁決：2.0 的訓練狀況卡標題一律是 `/v2/state/today` 的 `headline`。
    /// `collapsed_reason` 的融合句規則（T-0241）只留給 1.4 的 `DailyStateCardView`
    /// ——Android 沒有那條規則，2.0 跟著用會讓同一份 payload 兩平台標題不同。
    func test_trainingStatus_usesHeadlineNotCollapsedReason() {
        let status = App2HomeViewModel.trainingStatus(
            card: card(headline: "H", collapsedReason: "收合句"),
            currentWeek: 5, totalWeeks: 22
        )
        XCTAssertEqual(status.headline, "H")
        XCTAssertEqual(status.currentWeek, 5)
        XCTAssertEqual(status.totalWeeks, 22)
    }

    func test_trainingStatus_narrativeComesFromNarrativeText() {
        let status = App2HomeViewModel.trainingStatus(
            card: card(headline: "H", collapsedReason: "收合句", narrative: "本週穩定累積"),
            currentWeek: 5, totalWeeks: 22
        )
        XCTAssertEqual(status.narrative, "本週穩定累積")
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
        // 休息日的 chip 是「恢復」（設計 dc.html「今日課表 · 休息日卡片」）。
        XCTAssertEqual(session?.intensityLabel, L10n.App2.Session.effortChipRecovery.localized)
        XCTAssertNil(session?.summary)
        XCTAssertEqual(session?.dayLabel, "週三 · 8/26")
    }

    func test_todaySession_easyRun_buildsDistanceAndPaceLine() throws {
        let session = App2HomeViewModel.todaySession(
            days: [try day(easyRunDay)], todayIndex: 2, dayLabel: "週二"
        )
        XCTAssertEqual(session?.summary, "9.0 km · 7:55/km")
        XCTAssertEqual(session?.intensityLabel, L10n.App2.Session.effortChipLow.localized)
    }

    func test_todaySession_interval_buildsStructuredLine() throws {
        let session = App2HomeViewModel.todaySession(
            days: [try day(intervalDay)], todayIndex: 5, dayLabel: "週五"
        )
        // 2026-08-26 裁決：間歇日的「課表」行＝主課段（含組間恢復）總距離 ＋ 該段總時間。
        // 6 × 200m @ 5:25 ＝ 1.2 km、6×65s ＋ 5×90s 組間 ＝ 840 秒。
        XCTAssertEqual(session?.summary, "1.2 km · 14:00")
        XCTAssertEqual(session?.intensityLabel, L10n.App2.Session.effortChipHigh.localized)
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

    /// 沒有 `target_intensity` 時強度 chip 退到**課型**（2026-08-26 裁決：
    /// 這顆 chip 每張今日卡都要有）。退法是 `DayType` 對照，不是對顯示字比對。
    func test_todaySession_missingIntensity_fallsBackToDayType() throws {
        let json = """
        { "day_index": 1, "day_target": "輕鬆跑", "reason": "r",
          "primary": { "run_type": "easy", "distance_km": 5.0 } }
        """
        let session = App2HomeViewModel.todaySession(
            days: [try day(json)], todayIndex: 1, dayLabel: "週一"
        )
        XCTAssertEqual(session?.intensityLabel, L10n.App2.Session.effortChipLow.localized)
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

    /// 未知的 `run_type` 不得把識別字印上畫面：`DayType` 對不到就退 `day_target`
    /// （後端已在地化的人話）。**不得退成「休息」** —— 那會把一堂未知的課說成休息日。
    func test_todaySession_unknownRunType_fallsBackToDayTarget() throws {
        let json = """
        { "day_index": 1, "day_target": "特殊課", "reason": "r", "category": "run",
          "primary": { "run_type": "totally_new_type", "distance_km": 3 } }
        """
        let session = App2HomeViewModel.todaySession(
            days: [try day(json)], todayIndex: 1, dayLabel: "週一"
        )
        XCTAssertEqual(session?.title, "特殊課")
        XCTAssertNotEqual(session?.title, DayType.rest.localizedName)
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

    // MARK: - 週回顧 CTA：週日判定的權威是後端時區,不是裝置
    //
    // 規格：`docs/designs/DESIGN-app2-weekly-review-and-plan-end-inventory.md` §A.1。
    // 時機與週次全部由 `/v2/plan/status` 決定，client 不算週界、不看裝置星期。

    /// 週一～週六：使用者時區判出來都不是週日。
    func test_isSunday_weekdaysAreNotSunday() {
        for day in 24...29 {
            XCTAssertFalse(
                App2HomeViewModel.isSundayInUserTimezone(
                    planStatus(currentWeek: 3, planId: "ov_3", serverTime: tokyoNoon(day: day))
                ),
                "2026-08-\(day) 在 Asia/Tokyo 不是週日"
            )
        }
    }

    /// 週日：判出來是週日。
    func test_isSunday_sundayIsSunday() {
        XCTAssertTrue(
            App2HomeViewModel.isSundayInUserTimezone(
                planStatus(currentWeek: 3, planId: "ov_3", serverTime: tokyoNoon(day: 30))
            )
        )
    }

    /// **裝置時區與使用者時區不同時,以使用者時區為準**（§A.1；dev 實查
    /// `metadata.user_timezone == "Asia/Tokyo"`，與裝置時區無關）。
    ///
    /// 取一個 Tokyo 已經是週日、洛杉磯還在週六的瞬間：Tokyo 08/30 08:00
    /// ＝ UTC 08/29 23:00 ＝ LA 08/29 16:00。裝置日曆刻意傳 LA。
    func test_isSunday_usesUserTimezoneNotDeviceTimezone() throws {
        let status = planStatus(
            currentWeek: 3, planId: "ov_3", serverTime: "2026-08-29T23:00:00.000000+00:00"
        )
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let instant = try XCTUnwrap(App2WeekCalendar.parseISO8601(status.metadata?.serverTime))

        XCTAssertFalse(
            App2WeekCalendar.isSunday(date: instant, calendar: losAngeles),
            "前提檢查：這個瞬間在洛杉磯是週六"
        )
        XCTAssertTrue(
            App2HomeViewModel.isSundayInUserTimezone(status, deviceCalendar: losAngeles),
            "時區權威是 metadata.user_timezone，不是裝置時區"
        )
    }

    /// 反向：Tokyo 已經是週一、UTC 還在週日。裝置若跑 UTC 會誤判成週日。
    func test_isSunday_mondayInUserTimezoneWhileSundayElsewhere() throws {
        // Tokyo 08/31 07:00（週一）＝ UTC 08/30 22:00（週日）。
        let status = planStatus(
            currentWeek: 3, planId: "ov_3", serverTime: "2026-08-30T22:00:00.000000+00:00"
        )
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let instant = try XCTUnwrap(App2WeekCalendar.parseISO8601(status.metadata?.serverTime))

        XCTAssertTrue(
            App2WeekCalendar.isSunday(date: instant, calendar: utc),
            "前提檢查：這個瞬間在 UTC 是週日"
        )
        XCTAssertFalse(App2HomeViewModel.isSundayInUserTimezone(status, deviceCalendar: utc))
    }

    /// 跨週界：Tokyo 週日 23:59:59 仍是週日，往後一秒（週一 00:00:00）就不是。
    /// 那個 UTC 邊界值就是 dev 實查到的 `current_week_end_date` 形狀。
    func test_isSunday_weekBoundaryToTheSecond() {
        XCTAssertTrue(
            App2HomeViewModel.isSundayInUserTimezone(
                planStatus(currentWeek: 3, planId: "ov_3",
                           serverTime: "2026-08-30T14:59:59.999999+00:00")
            ),
            "Tokyo 08/30 23:59:59 還是週日"
        )
        XCTAssertFalse(
            App2HomeViewModel.isSundayInUserTimezone(
                planStatus(currentWeek: 3, planId: "ov_3",
                           serverTime: "2026-08-30T15:00:00.000000+00:00")
            ),
            "Tokyo 08/31 00:00:00 已經是週一"
        )
    }

    /// **`can_generate_next_week == false` 不等於不是週日。**
    /// 後端在同一個 if 多壓了 `current_week < total_weeks`
    /// （`domains/plan_week/service.py:1227-1230`），所以**最後一週的週日**那個
    /// flag 固定是 false。§A.5 必測清單第 1 條。
    func test_isSunday_lastWeekSundayStillDetected() {
        XCTAssertTrue(
            App2HomeViewModel.isSundayInUserTimezone(
                planStatus(currentWeek: 6, planId: "ov_6", totalWeeks: 6,
                           canGenerateNextWeek: false, serverTime: tokyoNoon(day: 30))
            ),
            "最後一週的週日不得因為 can_generate_next_week=false 就被當成平日"
        )
    }

    /// `can_generate_next_week == true` 本身就是後端在使用者時區判過的週日訊號，
    /// 即使 `server_time` 缺席也採信。
    func test_isSunday_trustsCanGenerateNextWeekFlag() {
        XCTAssertTrue(
            App2HomeViewModel.isSundayInUserTimezone(
                planStatus(currentWeek: 3, planId: "ov_3",
                           canGenerateNextWeek: true, serverTime: nil)
            )
        )
    }

    /// 時區名解不開（後端給了 app 不認得的 identifier）→ 退回裝置日曆，
    /// **不得整段崩掉或硬當成平日**。
    func test_isSunday_unknownTimezoneFallsBackToDeviceCalendar() throws {
        let status = planStatus(
            currentWeek: 3, planId: "ov_3",
            userTimezone: "Mars/Olympus_Mons", serverTime: tokyoNoon(day: 30)
        )
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let sunday = try XCTUnwrap(App2WeekCalendar.parseISO8601(tokyoNoon(day: 30)))
        XCTAssertTrue(
            App2HomeViewModel.isSundayInUserTimezone(
                status, deviceNow: sunday, deviceCalendar: tokyo
            )
        )
    }

    // MARK: - 週回顧 CTA：§A.5 狀態機表逐格

    /// 第 1 列：`current_week == 1` 且非週日 → 沒有可回顧的週,**整卡隱藏**。
    /// 2026-08-25 的 demo 帳號正是這一格，畫面卻掛著一張按下去無事可做的卡。
    func test_weekReview_row1_week1OnWeekdayIsHidden() {
        let status = planStatus(currentWeek: 1, planId: "a60e2c6cb83a_1",
                                serverTime: tokyoNoon(day: 26))
        XCTAssertNil(
            App2HomeViewModel.weekReviewState(planStatus: status, isSunday: false, summaryId: nil)
        )
    }

    /// 第 2 列：`next_action == create_summary`（回顧擋著課表）→「產生上週回顧」，
    /// 週次＝`current_week − 1`。
    func test_weekReview_row2_createSummaryOffersPreviousWeek() {
        let status = planStatus(currentWeek: 4, planId: nil, nextAction: "create_summary",
                                serverTime: tokyoNoon(day: 26))
        XCTAssertEqual(
            App2HomeViewModel.weekReviewState(planStatus: status, isSunday: false, summaryId: nil),
            .notGenerated(isCurrentWeek: false, targetWeek: 3)
        )
    }

    /// 第 3 列：平日、有本週課表、`previous_week_summary_id == null`、`current_week ≥ 2`
    /// →「產生上週回顧」。**這是 2.0 新增的主動時機卡**（1.4 這一格不給入口，
    /// 只在 `create_summary` 擋課表時才給）。
    func test_weekReview_row3_weekdayWithPlanButNoSummaryStillOffers() {
        let status = planStatus(currentWeek: 5, planId: "ov_5", serverTime: tokyoNoon(day: 26))
        XCTAssertEqual(
            App2HomeViewModel.weekReviewState(
                planStatus: status, isSunday: false, summaryId: status.previousWeekSummaryId
            ),
            .notGenerated(isCurrentWeek: false, targetWeek: 4)
        )
    }

    /// 第 4 列：平日、`previous_week_summary_id != null` →「查看回顧」。
    func test_weekReview_row4_weekdayWithSummaryOffersView() {
        let status = planStatus(currentWeek: 5, planId: "ov_5",
                                previousSummaryId: "ov_4_summary",
                                serverTime: tokyoNoon(day: 26))
        XCTAssertEqual(
            App2HomeViewModel.weekReviewState(
                planStatus: status, isSunday: false, summaryId: status.previousWeekSummaryId
            ),
            .available(summaryId: "ov_4_summary", isCurrentWeek: false, targetWeek: 4)
        )
    }

    /// 第 5 列：週日、`next_week_info.requires_current_week_summary == true`
    /// →「產生**本週**回顧」，週次＝`current_week`。
    func test_weekReview_row5_sundayRequiringCurrentWeekSummary() {
        let status = planStatus(
            currentWeek: 4, planId: "ov_4", canGenerateNextWeek: true,
            serverTime: tokyoNoon(day: 30),
            nextWeekInfoJSON: """
            { "week_number": 5, "has_plan": false, "can_generate": true,
              "requires_current_week_summary": true,
              "next_action": "create_summary_for_week_4" }
            """
        )
        XCTAssertTrue(App2HomeViewModel.isSundayInUserTimezone(status))
        XCTAssertEqual(status.nextWeekInfo?.requiresCurrentWeekSummary, true)
        XCTAssertEqual(
            App2HomeViewModel.weekReviewState(planStatus: status, isSunday: true, summaryId: nil),
            .notGenerated(isCurrentWeek: true, targetWeek: 4)
        )
    }

    /// 第 6 列：週日、本週回顧已完成 →「查看回顧」，週次仍是 `current_week`。
    func test_weekReview_row6_sundayWithCurrentWeekSummary() {
        let status = planStatus(
            currentWeek: 4, planId: "ov_4", canGenerateNextWeek: true,
            serverTime: tokyoNoon(day: 30),
            nextWeekInfoJSON: """
            { "week_number": 5, "has_plan": false, "can_generate": true,
              "requires_current_week_summary": false,
              "next_action": "create_plan_for_week_5" }
            """
        )
        XCTAssertEqual(
            App2HomeViewModel.weekReviewState(
                planStatus: status, isSunday: true, summaryId: "ov_4_summary"
            ),
            .available(summaryId: "ov_4_summary", isCurrentWeek: true, targetWeek: 4)
        )
    }

    /// 第 7 列：`next_action == training_completed` → 進「計畫結束」狀態（§B），
    /// **時機卡整張收掉**。計畫結束後首頁不得還掛著「產生上週回顧」。
    func test_weekReview_row7_trainingCompletedHidesCard() {
        let status = planStatus(
            currentWeek: 7, planId: nil, previousSummaryId: "ov_6_summary",
            totalWeeks: 6, nextAction: "training_completed", serverTime: tokyoNoon(day: 26)
        )
        XCTAssertNil(
            App2HomeViewModel.weekReviewState(
                planStatus: status, isSunday: false, summaryId: status.previousWeekSummaryId
            ),
            "計畫結束是另一條路（§B），不是時機卡的第五個狀態"
        )
        XCTAssertNil(
            App2HomeViewModel.weekReviewState(
                planStatus: status, isSunday: true, summaryId: "ov_6_summary"
            ),
            "週日也一樣收掉"
        )
    }

    /// **平日看上週、週日看本週** —— `targetWeek` 就是週回顧頁要打的
    /// `week_of_plan`。算錯一週＝看到別週的回顧。
    func test_weekReview_targetWeekIsPreviousWeekOnWeekdays() {
        let status = planStatus(currentWeek: 5, planId: "ov_5")
        XCTAssertEqual(
            App2HomeViewModel.weekReviewState(
                planStatus: status, isSunday: false, summaryId: nil
            )?.targetWeek,
            4
        )
        XCTAssertEqual(
            App2HomeViewModel.weekReviewState(
                planStatus: status, isSunday: true, summaryId: nil
            )?.targetWeek,
            5
        )
    }

    /// `current_week == 1` 的週日：本週有課表就給「產生本週回顧」，沒有就整卡隱藏。
    func test_weekReview_week1Sunday() {
        let withPlan = planStatus(currentWeek: 1, planId: "ov_1", canGenerateNextWeek: true,
                                  serverTime: tokyoNoon(day: 30))
        XCTAssertEqual(
            App2HomeViewModel.weekReviewState(planStatus: withPlan, isSunday: true, summaryId: nil),
            .notGenerated(isCurrentWeek: true, targetWeek: 1)
        )
        let withoutPlan = planStatus(currentWeek: 1, planId: nil, canGenerateNextWeek: true,
                                     serverTime: tokyoNoon(day: 30))
        XCTAssertNil(
            App2HomeViewModel.weekReviewState(planStatus: withoutPlan, isSunday: true, summaryId: nil)
        )
    }

    /// 最後一週的週日：`can_generate_next_week=false`、`next_week_info=null`，
    /// 但**本週回顧仍然可以做**（§A.5 必測清單）。
    func test_weekReview_lastWeekSundayStillOffersCurrentWeekReview() {
        let status = planStatus(currentWeek: 6, planId: "ov_6", totalWeeks: 6,
                                canGenerateNextWeek: false, serverTime: tokyoNoon(day: 30))
        let isSunday = App2HomeViewModel.isSundayInUserTimezone(status)
        XCTAssertTrue(isSunday)
        XCTAssertEqual(
            App2HomeViewModel.weekReviewState(
                planStatus: status, isSunday: isSunday, summaryId: nil
            ),
            .notGenerated(isCurrentWeek: true, targetWeek: 6)
        )
    }

    // MARK: - 週回顧 CTA：§A.4 七個歷史坑的回歸 case

    /// 坑 `90fee63e` —— 快取帶回 stale `current_week=1`，API 已經刷到 13，
    /// 而 `selectedWeek` 永遠卡在 1。
    ///
    /// 斷言：同一支 `weekReviewState` 餵新舊兩份 status 會得到不同的週次 ——
    /// 它完全跟著傳進來的那一份走，沒有任何被記住的狀態。
    func test_weekReviewPit_90fee63e_staleCurrentWeekDoesNotStick() {
        let stale = planStatus(currentWeek: 1, planId: "ov_1", serverTime: tokyoNoon(day: 26))
        let fresh = planStatus(currentWeek: 13, planId: "ov_13", serverTime: tokyoNoon(day: 26))

        XCTAssertNil(
            App2HomeViewModel.weekReviewState(planStatus: stale, isSunday: false, summaryId: nil)
        )
        XCTAssertEqual(
            App2HomeViewModel.weekReviewState(planStatus: fresh, isSunday: false, summaryId: nil),
            .notGenerated(isCurrentWeek: false, targetWeek: 12),
            "新的 status 一定要贏過先前那一份"
        )
    }

    /// 坑 `576c60e6` —— `next_action` 是**時間敏感 flag**，快取的那一份會過期，
    /// 冷啟時按鈕閃爍；修法是 plan entity 優先於 nextAction flag。
    ///
    /// 斷言：`view_plan` 與 `create_summary` 在同一組實體事實（有上週、回顧未生成）
    /// 下給出**同一格**。flag 過期就不再改變畫面，也就不會閃。
    func test_weekReviewPit_576c60e6_nextActionFlagDoesNotFlipTheCard() {
        let asCreateSummary = planStatus(currentWeek: 4, planId: nil,
                                         nextAction: "create_summary",
                                         serverTime: tokyoNoon(day: 26))
        let asViewPlan = planStatus(currentWeek: 4, planId: "ov_4",
                                    nextAction: "view_plan",
                                    serverTime: tokyoNoon(day: 26))
        XCTAssertEqual(
            App2HomeViewModel.weekReviewState(
                planStatus: asCreateSummary, isSunday: false, summaryId: nil
            ),
            App2HomeViewModel.weekReviewState(
                planStatus: asViewPlan, isSunday: false, summaryId: nil
            )
        )
    }

    /// 坑 `dd07409f`／`59fd1aff` —— 解碼 bug 讓週回顧**整頁掛掉**（1.4.10 發版前）。
    ///
    /// 斷言：只有必填欄的最小 payload 也要解得開，且沒有時區可依據時不得崩。
    func test_weekReviewPit_dd07409f_minimalPayloadStillDecodes() throws {
        let json = """
        { "current_week": 2, "total_weeks": 6, "next_action": "create_summary",
          "can_generate_next_week": false,
          "current_week_plan_id": null, "previous_week_summary_id": null }
        """
        let status = try JSONDecoder().decode(PlanStatusV2Response.self, from: Data(json.utf8))
        XCTAssertNil(status.metadata)
        XCTAssertNil(status.nextWeekInfo)
        _ = App2HomeViewModel.isSundayInUserTimezone(status)   // 不得丟例外
        XCTAssertEqual(
            App2HomeViewModel.weekReviewState(planStatus: status, isSunday: false, summaryId: nil),
            .notGenerated(isCurrentWeek: false, targetWeek: 1)
        )
    }

    /// 坑 `422aa744` —— **休息週的 summary 欄位是 null**，decode 不容忍就炸。
    ///
    /// 斷言：週回顧 payload 的可選區塊全給 null 時，投影仍組得出來（只是內容少），
    /// 而不是丟例外或整頁空白。
    ///
    /// 休息週的真實形狀：量全是 0、亮點與建議都空、所有 optional 區塊是 null。
    /// `weekly_highlights.achievements` 刻意給 null（後端 validator 會把它壓成
    /// `[]`，但 client 不該賭上游一定有壓）。
    func test_weekReviewPit_422aa744_restWeekNullSectionsStillProject() throws {
        let json = """
        {
          "id": "ov_3_summary", "week_of_training": 3,
          "training_completion": { "completed_km": 0, "planned_km": 0,
            "completed_sessions": 0, "planned_sessions": 0, "percentage": 0,
            "evaluation": "本週是排定的休息週" },
          "training_analysis": { "pace": null, "heart_rate": null, "distance": null,
            "intensity_distribution": null },
          "weekly_highlights": { "highlights": [], "achievements": null,
            "areas_for_improvement": [] },
          "next_week_adjustments": { "items": [], "summary": "",
            "methodology_constraints_considered": false, "based_on_flags": [] },
          "weekly_story": null, "observations": null,
          "capability_progression": null, "plan_context": null
        }
        """
        let dto = try JSONDecoder().decode(WeeklySummaryV2DTO.self, from: Data(json.utf8))
        let projection = App2WeeklyReviewProjection.make(WeeklySummaryV2Mapper.toEntity(from: dto))

        XCTAssertEqual(projection.storyBody, "本週是排定的休息週", "null 敘事要退到完成度評語")
        XCTAssertTrue(projection.highlights.isEmpty)
        XCTAssertTrue(projection.observations.isEmpty)
        XCTAssertTrue(projection.analysisNotes.isEmpty)
        XCTAssertTrue(projection.suggestions.isEmpty)
        XCTAssertNil(projection.phaseLabel)
    }

    /// 坑 `2451e5be` —— 無訂閱時 paywall 蓋在 sheet teardown 上，Close 失效。
    ///
    /// 斷言：付費閘門旗標與「這一頁能不能關掉」是**兩件事**。`onClose` 是呼叫端
    /// 持有的 closure，不經過任何 gate 旗標，所以旗標亮著也關得掉。
    func test_weekReviewPit_2451e5be_closeIsIndependentOfPaywallFlags() {
        var closed = false
        let view = App2WeeklyReviewView(weekOfPlan: 3, onClose: { closed = true })
        view.onClose()
        XCTAssertTrue(closed, "關閉不得被 paywall／額度旗標攔住")
    }

    /// 坑 `cdab0b79` —— needsWeeklySummary 的**提示文案與實際動作不一致**。
    ///
    /// 斷言：文案與週次出自同一個狀態值 —— `isCurrentWeek` 決定講「本週」還是
    /// 「上週」，`targetWeek` 決定按下去打哪一週，兩者不可能各自為政。
    func test_weekReviewPit_cdab0b79_copyMatchesTheAction() {
        let previousWeek = App2WeekReviewState.notGenerated(isCurrentWeek: false, targetWeek: 3)
        let currentWeek = App2WeekReviewState.notGenerated(isCurrentWeek: true, targetWeek: 4)
        let generated = App2WeekReviewState.available(
            summaryId: "ov_3_summary", isCurrentWeek: false, targetWeek: 3
        )

        XCTAssertEqual(previousWeek.title, L10n.App2.Home.weekReviewGenerateLast.localized)
        XCTAssertEqual(previousWeek.subtitle, L10n.App2.Home.weekReviewSubLast.localized)
        XCTAssertEqual(currentWeek.title, L10n.App2.Home.weekReviewGenerateCurrent.localized)
        XCTAssertEqual(currentWeek.subtitle, L10n.App2.Home.weekReviewSubCurrent.localized)
        XCTAssertEqual(generated.title, L10n.App2.Home.weekReviewView.localized)
        XCTAssertEqual(generated.subtitle, L10n.App2.Home.weekReviewViewSub.localized)

        // 三態的文案必須互相不同,否則「一致」是靠巧合成立的。
        XCTAssertNotEqual(previousWeek.title, currentWeek.title)
        XCTAssertNotEqual(previousWeek.title, generated.title)
    }

    /// 坑 `8a9cf4d7`→`1c2cdb21` —— 單頁／兩頁版式反覆改。
    /// 2.0 定案是 8/26 設計包的**兩張稿**（frame-18 回顧本週／frame-19 規劃下週）。
    func test_weekReviewPit_1c2cdb21_exactlyTwoTabs() {
        XCTAssertEqual(
            App2WeeklyReviewView.Tab.allCases.map(\.rawValue), ["review", "plan"]
        )
    }

    // MARK: - 今日課表卡的分段與結構預覽

    func test_segments_intervalDay_listsWorkAndRecovery() throws {
        let segments = App2HomeViewModel.segments(day: try day(intervalDay))
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments.first?.detail, "6 × 200m @ 5:25")
        XCTAssertTrue(segments.first?.isWork ?? false)
        XCTAssertFalse(segments.last?.isWork ?? true)
    }

    /// 單段課也有一列分段（8/25 版設計的「全程勻速 8.0 km · 6:50」那一列）。
    /// 舊版把單列濾掉，是因為當時卡片沒有這一排分段列、只有右側的結構圖。
    func test_segments_singleSegmentDay_hasOneMainRow() throws {
        let segments = App2HomeViewModel.segments(day: try day(easyRunDay))
        XCTAssertEqual(segments.count, 1)
        XCTAssertTrue(segments.first?.isWork ?? false)
        XCTAssertEqual(segments.first?.detail, "9.0 km · 7:55/km")
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
        XCTAssertEqual(bars.first?.kind, .warmup)       // 熱身（綠柱）
        XCTAssertEqual(bars.last?.kind, .warmup)        // 緩和（綠柱）
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
    /// 配速結構圖下方的段落標註列（2026-08-25 用戶退件：單段課看起來像按鈕，
    /// 補上圖表容器與標註列後才讀得出是圖）。單段課要有一列、量與卡片「課表」那一行同字串。
    func test_structureBars_singleSegmentEasyRun_carriesOneAnnotationRow() throws {
        let detail = try day(easyRunDay)
        let bars = App2HomeViewModel.structureBars(day: detail)
        let notes = bars.filter { $0.noteLabel != nil }

        XCTAssertEqual(notes.count, 1, "單段課只該有一列標註")
        XCTAssertEqual(notes.first?.kind, .steady)
        XCTAssertEqual(
            notes.first?.noteDetail,
            App2PlanViewModel.contentLine(detail.session?.primary),
            "標註列的量必須與卡片「課表」那一行同一支字串，不得另組一份"
        )
    }

    /// 間歇課：十根橘柱只掛一列標註（去重後畫面上不會出現十行「間歇」）。
    func test_structureBars_intervalDay_annotatesFirstRepOnly() throws {
        let bars = App2HomeViewModel.structureBars(day: try day(intervalDay))
        let intervalNotes = bars.filter { $0.kind == .interval && $0.noteLabel != nil }

        XCTAssertEqual(intervalNotes.count, 1, "間歇的每一趟不各自掛一列")
        XCTAssertGreaterThan(bars.filter { $0.kind == .interval }.count, 1)
    }

    /// 暖身／組間／緩和不進標註列。
    func test_structureBars_supportBarsHaveNoAnnotation() throws {
        let bars = App2HomeViewModel.structureBars(day: try day(qualityDay))
        XCTAssertTrue(
            bars.filter { $0.kind == .support || $0.kind == .warmup }
                .allSatisfy { $0.noteLabel == nil },
            "輔助段不進標註列"
        )
    }

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
        // 前後綠色熱身／緩和塊 ＋ 中間一塊綠色穩定段（灰柱只留給組間恢復）。
        XCTAssertEqual(bars.map(\.kind), [.warmup, .steady, .warmup])
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

    // MARK: - 期別膠囊（設計 frame-00 右上「基礎期」）

    private func stages(_ json: String) throws -> [TrainingStageV2] {
        try JSONDecoder().decode([TrainingStageDTO].self, from: Data(json.utf8)).map {
            TrainingStageV2(
                stageId: $0.stageId,
                stageName: $0.stageName,
                stageDescription: $0.stageDescription,
                weekStart: $0.weekStart,
                weekEnd: $0.weekEnd,
                trainingFocus: $0.trainingFocus,
                targetWeeklyKmRange: TargetWeeklyKmRangeV2(
                    low: $0.targetWeeklyKmRange.low, high: $0.targetWeeklyKmRange.high
                ),
                targetWeeklyKmRangeDisplay: nil,
                intensityRatio: nil,
                keyWorkouts: nil
            )
        }
    }

    private let threeStagesJSON = """
    [ { "stage_id": "base",  "stage_name": "基礎期", "stage_description": "d",
        "week_start": 1, "week_end": 1, "training_focus": "f", "target_weekly_km_range": { "low": 8, "high": 10 } },
      { "stage_id": "build", "stage_name": "強化期", "stage_description": "d",
        "week_start": 2, "week_end": 3, "training_focus": "f", "target_weekly_km_range": { "low": 8, "high": 10 } },
      { "stage_id": "peak",  "stage_name": "巔峰期", "stage_description": "d",
        "week_start": 4, "week_end": 6, "training_focus": "f", "target_weekly_km_range": { "low": 8, "high": 10 } } ]
    """

    /// 期別顯示字走 `stage_id` 的既有在地化表（`training.stage.*`），
    /// **不是 payload 的 `stage_name`** —— 後者由後端依 `content_lang` 生成，
    /// App 切語言時不會跟著換（2026-08-26 裁決：chip 譯名全 App 同一份）。
    func test_stageName_localizesByStageIdNotBackendString() throws {
        let stages = try stages(threeStagesJSON)
        XCTAssertEqual(
            App2HomeViewModel.stageName(stages: stages, currentWeek: 1),
            L10n.Training.Stage.base.localized
        )
        XCTAssertEqual(
            App2HomeViewModel.stageName(stages: stages, currentWeek: 3),
            L10n.Training.Stage.build.localized
        )
        XCTAssertEqual(
            App2HomeViewModel.stageName(stages: stages, currentWeek: 6),
            L10n.Training.Stage.peak.localized
        )
    }

    /// 落不進任何一段就沒有期別 —— 不猜最近的那一段。
    func test_stageName_weekOutsideEveryStage_isNil() throws {
        XCTAssertNil(App2HomeViewModel.stageName(stages: try stages(threeStagesJSON), currentWeek: 9))
        XCTAssertNil(App2HomeViewModel.stageName(stages: [], currentWeek: 1))
    }
}
