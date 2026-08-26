import XCTest
@testable import paceriz_dev

/// 訓練計畫總覽（設計 frame-20）與賽事管理（frame-12／13／14）的投影。
///
/// 判準集中在**畫面會說謊的那幾條**：
/// - overview 綁不上本週課表時不得畫出期程；
/// - 沒有當前週時不得說某一段「進行中」；
/// - 「約 N km / 週」不得把當週（還沒跑完）算進去，也不得在全無資料時印 0；
/// - 已過期的賽事不得出現負數倒數；
/// - 編輯全馬存回去不得把 `42.195` 悄悄變成 42。
///
/// 既有測試覆蓋的是別的層，這裡不重複：`TargetDecodingTests` 測 API→domain 的距離解碼、
/// `TargetFeatureViewModelTests` 測 1.x 支援賽事的可見窗、`PlanOverviewV2MapperTests`
/// 測 DTO→entity。本檔測的是 2.0 呈現層的投影（哪一段在跑、卡片怎麼排、表單怎麼回存）。
/// 投影方法是 `@MainActor` ViewModel 的 static（隔離會傳染），所以整個 case 標 MainActor
/// ——與 `App2HomeProjectionTests` 同一個做法。
@MainActor
final class App2PlanOverviewProjectionTests: XCTestCase {

    // MARK: - Fixtures

    private func planStatus(
        currentWeek: Int = 5,
        totalWeeks: Int = 22,
        planId: String? = "e1289e60f251_5"
    ) -> PlanStatusV2Response {
        PlanStatusV2Response(
            currentWeek: currentWeek,
            totalWeeks: totalWeeks,
            nextAction: "view_plan",
            canGenerateNextWeek: false,
            currentWeekPlanId: planId,
            previousWeekSummaryId: nil,
            targetType: "race_run",
            methodologyId: "paceriz",
            nextWeekInfo: nil,
            metadata: nil
        )
    }

    private func stage(
        id: String,
        name: String,
        start: Int,
        end: Int,
        focus: String = "有氧耐力"
    ) -> TrainingStageV2 {
        TrainingStageV2(
            stageId: id,
            stageName: name,
            stageDescription: "",
            weekStart: start,
            weekEnd: end,
            trainingFocus: focus,
            targetWeeklyKmRange: TargetWeeklyKmRangeV2(low: 40, high: 50),
            targetWeeklyKmRangeDisplay: nil,
            intensityRatio: nil,
            keyWorkouts: nil
        )
    }

    private func target(
        id: String = "t1",
        name: String = "松本マラソン 2026",
        distanceKm: Int = 42,
        targetTime: Int = 14_400,
        raceDate: Int,
        isMain: Bool = true
    ) -> Target {
        Target(
            id: id,
            type: "race_run",
            name: name,
            distanceKm: distanceKm,
            targetTime: targetTime,
            targetPace: "5:41",
            raceDate: raceDate,
            isMainRace: isMain,
            trainingWeeks: 6,
            timezone: "Asia/Taipei",
            raceId: "jp_2026_matsumoto-marathon"
        )
    }

    private func weekItem(weekStartOffsetDays: Int, km: Double, now: Date) -> WeeklySummaryItem {
        let start = Calendar.current.date(byAdding: .day, value: weekStartOffsetDays, to: now) ?? now
        return WeeklySummaryItem(
            weekIndex: 0,
            weekStart: "",
            weekStartTimestamp: start.timeIntervalSince1970,
            distanceKm: km,
            weekPlan: nil,
            weekSummary: nil,
            completionPercentage: nil
        )
    }

    // MARK: - overview 綁定

    /// `current_week_plan_id` 的前綴就是 overview id（dev 實測 `e1289e60f251_1` ↔ `e1289e60f251`）。
    func testOverviewBoundByPlanIdPrefix() {
        XCTAssertTrue(App2HomeViewModel.isOverview("e1289e60f251", boundTo: planStatus()))
        XCTAssertFalse(App2HomeViewModel.isOverview("aaaabbbbcccc", boundTo: planStatus()))
    }

    /// 本週還沒有課表時綁不了任何 overview —— 不得拿「最新那份」頂替。
    func testOverviewNotBoundWhenWeeklyPlanMissing() {
        XCTAssertFalse(App2HomeViewModel.isOverview("e1289e60f251", boundTo: planStatus(planId: nil)))
    }

    // MARK: - 期程狀態

    func testStageStatesFollowCurrentWeek() {
        let stages = App2PlanOverviewViewModel.stages(
            [
                stage(id: "s1", name: "建立耐力", start: 1, end: 6),
                stage(id: "s2", name: "練出速耐力", start: 7, end: 14),
                stage(id: "s3", name: "減量收尾", start: 15, end: 22)
            ],
            currentWeek: 8
        )

        XCTAssertEqual(stages.map(\.state), [.done, .active, .upcoming])
        XCTAssertEqual(stages[1].weeksElapsed, 2)
        XCTAssertEqual(stages[1].weekCount, 8)
        XCTAssertEqual(stages[1].weekRangeLabel, "W7–14")
        // 未進行／已完成的段不得有「走到第幾週」。
        XCTAssertNil(stages[0].weeksElapsed)
        XCTAssertNil(stages[2].weeksElapsed)
    }

    /// 沒有當前週 ＝ 判不出誰在跑。不得預設第一段「進行中」。
    func testStagesWithoutCurrentWeekAreAllUpcoming() {
        let stages = App2PlanOverviewViewModel.stages(
            [stage(id: "s1", name: "建立耐力", start: 1, end: 6)],
            currentWeek: nil
        )
        XCTAssertEqual(stages.map(\.state), [.upcoming])
        XCTAssertNil(stages[0].weeksElapsed)
    }

    /// 單週的階段：`W1`，不是 `W1–1`。
    func testSingleWeekStageLabel() {
        let stages = App2PlanOverviewViewModel.stages(
            [stage(id: "s1", name: "基礎期", start: 1, end: 1)],
            currentWeek: 1
        )
        XCTAssertEqual(stages[0].weekRangeLabel, "W1")
        XCTAssertEqual(stages[0].weekCount, 1)
    }

    /// 空的 `training_focus` 不畫空行。
    func testEmptyFocusBecomesNil() {
        let stages = App2PlanOverviewViewModel.stages(
            [stage(id: "s1", name: "建立耐力", start: 1, end: 6, focus: "   ")],
            currentWeek: 1
        )
        XCTAssertNil(stages[0].focus)
    }

    // MARK: - 近期週跑量

    /// 當週（還沒跑完）不算進平均；0 的週照算。
    func testAverageWeeklyKmExcludesCurrentWeekAndKeepsZeroes() throws {
        let now = Date()
        let items = [
            weekItem(weekStartOffsetDays: 0, km: 5.29, now: now),     // 當週，不算
            weekItem(weekStartOffsetDays: -7, km: 30, now: now),
            weekItem(weekStartOffsetDays: -14, km: 40, now: now),
            weekItem(weekStartOffsetDays: -21, km: 0, now: now),
            weekItem(weekStartOffsetDays: -28, km: 10, now: now),
            weekItem(weekStartOffsetDays: -35, km: 99, now: now)      // 第 5 舊，不在 4 週內
        ]
        let average = try XCTUnwrap(App2PlanOverviewViewModel.averageWeeklyKm(items, now: now))
        XCTAssertEqual(average, (30 + 40 + 0 + 10) / 4.0, accuracy: 0.001)
    }

    /// payload 順序換了也要取到最近的四週（不靠回應的排序）。
    func testAverageWeeklyKmIgnoresPayloadOrder() throws {
        let now = Date()
        let ascending = [
            weekItem(weekStartOffsetDays: -35, km: 99, now: now),
            weekItem(weekStartOffsetDays: -28, km: 10, now: now),
            weekItem(weekStartOffsetDays: -21, km: 0, now: now),
            weekItem(weekStartOffsetDays: -14, km: 40, now: now),
            weekItem(weekStartOffsetDays: -7, km: 30, now: now)
        ]
        let average = try XCTUnwrap(App2PlanOverviewViewModel.averageWeeklyKm(ascending, now: now))
        XCTAssertEqual(average, (30 + 40 + 0 + 10) / 4.0, accuracy: 0.001)
    }

    /// 全部都是 0 ／ 沒有資料 → nil（畫面整格不顯示，不印 `0 km / 週`）。
    func testAverageWeeklyKmNilWhenNothingRun() {
        let now = Date()
        XCTAssertNil(App2PlanOverviewViewModel.averageWeeklyKm([], now: now))
        XCTAssertNil(App2PlanOverviewViewModel.averageWeeklyKm(
            [weekItem(weekStartOffsetDays: -7, km: 0, now: now)],
            now: now
        ))
    }

    // MARK: - 賽事倒數與週數

    func testWeeksUntilRaceRoundsUpAndDropsPastRaces() {
        let now = Date()
        let inTenDays = Int(now.addingTimeInterval(10 * 86_400).timeIntervalSince1970)
        XCTAssertEqual(App2PlanOverviewViewModel.weeksUntil(epochSeconds: inTenDays, now: now), 2)

        let yesterday = Int(now.addingTimeInterval(-2 * 86_400).timeIntervalSince1970)
        XCTAssertNil(App2PlanOverviewViewModel.weeksUntil(epochSeconds: yesterday, now: now))
    }

    /// 賽事日期以**賽事時區**顯示，不是裝置時區。
    func testRaceDateUsesRaceTimezone() {
        // 2026-12-06 00:30 UTC ＝ 東京時間 09:30 同一天、紐約時間 12-05 19:30。
        let epoch = 1_796_502_600
        XCTAssertEqual(
            App2PlanOverviewViewModel.localDateString(fromEpochSeconds: epoch, timezone: "Asia/Tokyo"),
            "2026-12-06"
        )
        XCTAssertEqual(
            App2PlanOverviewViewModel.localDateString(fromEpochSeconds: epoch, timezone: "America/New_York"),
            "2026-12-05"
        )
    }

    // MARK: - 整份投影

    func testProjectionUsesPlanStatusWeeksAndMainTarget() throws {
        let now = Date()
        let raceDate = Int(now.addingTimeInterval(30 * 86_400).timeIntervalSince1970)
        let projected = App2PlanOverviewViewModel.project(
            planStatus: planStatus(currentWeek: 5, totalWeeks: 22),
            mainTarget: target(raceDate: raceDate),
            stages: [
                stage(id: "s1", name: "建立耐力", start: 1, end: 6),
                stage(id: "s2", name: "練出速耐力", start: 7, end: 14)
            ],
            methodologyName: "Paceriz 平衡訓練法",
            estimatedFinish: "4:12:30",
            weeklyVolumes: [],
            preferWeekDays: [1, 3, 5, 7],
            longRunWeekday: 7,
            now: now
        )

        XCTAssertEqual(projected.currentWeek, 5)
        XCTAssertEqual(projected.totalWeeks, 22)
        XCTAssertEqual(projected.currentStageName, "建立耐力")
        XCTAssertEqual(projected.targetTime, "4:00:00")
        XCTAssertEqual(projected.currentEstimatedFinish, "4:12:30")
        XCTAssertEqual(projected.rhythm.runDaysPerWeek, 4)
        XCTAssertEqual(projected.rhythm.methodologyName, "Paceriz 平衡訓練法")
        XCTAssertNotNil(projected.rhythm.longRunDayLabel)
        // 沒有週跑量資料 → 整格不顯示。
        XCTAssertNil(projected.currentWeeklyKm)
        XCTAssertEqual(try XCTUnwrap(projected.progress), 5.0 / 22.0, accuracy: 0.0001)
    }

    /// 沒有主要賽事：hero 換成空狀態，不得出現任何賽事欄位。
    func testProjectionWithoutMainTarget() {
        let projected = App2PlanOverviewViewModel.project(
            planStatus: planStatus(),
            mainTarget: nil,
            stages: [],
            methodologyName: nil,
            estimatedFinish: nil,
            weeklyVolumes: [],
            preferWeekDays: nil,
            longRunWeekday: nil
        )
        XCTAssertNil(projected.raceName)
        XCTAssertNil(projected.raceDateLabel)
        XCTAssertNil(projected.targetTime)
        XCTAssertNil(projected.distanceLabel)
        XCTAssertTrue(projected.stages.isEmpty)
        XCTAssertTrue(projected.rhythm.isEmpty)
    }

    /// 沒有 plan status（端點掛掉）→ 沒有週次也沒有進度條，但賽事欄位仍在。
    func testProjectionWithoutPlanStatusFallsBackToTargetWeeks() {
        let now = Date()
        let projected = App2PlanOverviewViewModel.project(
            planStatus: nil,
            mainTarget: target(
                raceDate: Int(now.addingTimeInterval(60 * 86_400).timeIntervalSince1970)
            ),
            stages: [],
            methodologyName: nil,
            estimatedFinish: nil,
            weeklyVolumes: [],
            preferWeekDays: nil,
            longRunWeekday: nil,
            now: now
        )
        XCTAssertNil(projected.currentWeek)
        XCTAssertEqual(projected.totalWeeks, 6)   // 退回 target.trainingWeeks
        XCTAssertNil(projected.progress)
        XCTAssertEqual(projected.raceName, "松本マラソン 2026")
    }

    /// 目標成績是 0（沒設）→ 不顯示「目標」那一格。
    func testProjectionDropsZeroTargetTime() {
        let projected = App2PlanOverviewViewModel.project(
            planStatus: planStatus(),
            mainTarget: target(targetTime: 0, raceDate: 1_800_000_000),
            stages: [],
            methodologyName: nil,
            estimatedFinish: nil,
            weeklyVolumes: [],
            preferWeekDays: [],
            longRunWeekday: nil
        )
        XCTAssertNil(projected.targetTime)
        // 空陣列的訓練日 ≠ 一週 0 天，那是「沒有偏好」。
        XCTAssertNil(projected.rhythm.runDaysPerWeek)
    }

    // MARK: - 賽事管理

    func testRaceCardsPutMainFirstThenSortSupportByDate() {
        let now = Date()
        func epoch(_ days: Int) -> Int {
            Int(now.addingTimeInterval(Double(days) * 86_400).timeIntervalSince1970)
        }
        let cards = App2RaceManagementViewModel.cards(
            from: [
                target(id: "s2", name: "台北半馬", distanceKm: 21, raceDate: epoch(72), isMain: false),
                target(id: "m", name: "松本", raceDate: epoch(114), isMain: true),
                target(id: "s1", name: "秋季 10K", distanceKm: 10, raceDate: epoch(37), isMain: false)
            ],
            now: now
        )

        XCTAssertEqual(cards.map(\.id), ["m", "s1", "s2"])
        XCTAssertTrue(cards[0].isMain)
        XCTAssertEqual(cards[1].countdownDays, 37)
        XCTAssertEqual(cards[2].countdownDays, 72)
    }

    /// 已過期的賽事倒數是負數 —— 畫面據此改說「已結束」，不印負天數。
    func testCountdownIsNegativeForPastRace() {
        let now = Date()
        let past = Int(now.addingTimeInterval(-3 * 86_400).timeIntervalSince1970)
        XCTAssertEqual(App2RaceManagementViewModel.countdownDays(epochSeconds: past, now: now), -3)
    }

    /// 目標成績是 0（沒設）就不顯示那一欄。
    func testNoGoalTimeWhenTargetTimeIsZero() {
        let cards = App2RaceManagementViewModel.cards(
            from: [target(targetTime: 0, raceDate: Int(Date().timeIntervalSince1970) + 86_400)]
        )
        XCTAssertNil(cards[0].goalTime)
    }

    /// 編輯全馬時距離要回到 `42.195`，不能被 `distance_km: 42` 悄悄改成 42.0 km。
    func testDistanceKeyRoundTripsStandardDistances() {
        XCTAssertEqual(App2RaceManagementViewModel.distanceKey(forKm: 42), "42.195")
        XCTAssertEqual(App2RaceManagementViewModel.distanceKey(forKm: 21), "21.0975")
        XCTAssertEqual(App2RaceManagementViewModel.distanceKey(forKm: 10), "10")
        XCTAssertEqual(App2RaceManagementViewModel.distanceKey(forKm: 5), "5")
        XCTAssertEqual(App2RaceManagementViewModel.distanceKey(forKm: 15), "15")
    }

    /// 「設為主要」只改一個欄位，其餘原樣送回（PUT 是 merge，漏帶會擦掉欄位）。
    func testPromotedToMainKeepsEveryOtherField() {
        let original = target(
            id: "s1", name: "秋季 10K", distanceKm: 10, raceDate: 1_800_000_000, isMain: false
        )
        let promoted = App2RaceManagementViewModel.promotedToMain(original)

        XCTAssertTrue(promoted.isMainRace)
        XCTAssertEqual(promoted.id, original.id)
        XCTAssertEqual(promoted.name, original.name)
        XCTAssertEqual(promoted.distanceKm, original.distanceKm)
        XCTAssertEqual(promoted.targetTime, original.targetTime)
        XCTAssertEqual(promoted.targetPace, original.targetPace)
        XCTAssertEqual(promoted.raceDate, original.raceDate)
        XCTAssertEqual(promoted.trainingWeeks, original.trainingWeeks)
        XCTAssertEqual(promoted.timezone, original.timezone)
        XCTAssertEqual(promoted.raceId, original.raceId)
    }

    // MARK: - 表單

    func testFormValidityAndPace() {
        var form = App2RaceForm()
        XCTAssertFalse(form.isValid)          // 名稱空、時間 0
        XCTAssertNil(form.paceLabel)

        form.name = "東京馬拉松"
        form.distanceKey = "42.195"
        form.hours = 4
        XCTAssertTrue(form.isValid)
        XCTAssertEqual(form.paceLabel, "5:41")

        // 只有空白的名稱不算填了。
        form.name = "   "
        XCTAssertFalse(form.isValid)
    }

    func testFormToTargetKeepsRaceIdAndTimezone() {
        var form = App2RaceForm()
        form.name = "  東京馬拉松  "
        form.distanceKey = "42.195"
        form.hours = 3
        form.minutes = 30
        form.makeMain = true
        form.raceId = "jp_2027_tokyo"
        form.timezone = "Asia/Tokyo"
        form.date = Date().addingTimeInterval(30 * 86_400)

        let target = App2RaceManagementViewModel.target(from: form)
        XCTAssertEqual(target.name, "東京馬拉松")      // 前後空白要修掉
        XCTAssertEqual(target.distanceKm, 42)
        XCTAssertEqual(target.targetTime, 3 * 3600 + 30 * 60)
        XCTAssertTrue(target.isMainRace)
        XCTAssertEqual(target.raceId, "jp_2027_tokyo")
        XCTAssertEqual(target.timezone, "Asia/Tokyo")
        XCTAssertGreaterThanOrEqual(target.trainingWeeks, 1)
    }

    /// 手動改欄位要斷開賽事庫綁定 —— 存回去時 `race_id` 不能還指著別場賽事。
    func testClearRaceBindingDropsRaceId() {
        var form = App2RaceForm()
        form.raceId = "jp_2027_tokyo"
        form.clearRaceBinding()
        XCTAssertNil(form.raceId)
    }

    // MARK: - 賽事庫挑選

    func testDatabasePickPrefersCurrentDistanceFilter() {
        let event = RaceEvent(
            raceId: "jp_2027_tokyo",
            name: "東京マラソン 2027",
            region: "jp",
            eventDate: Date().addingTimeInterval(200 * 86_400),
            city: "東京",
            location: nil,
            distances: [
                RaceDistance(distanceKm: 10, name: "10K"),
                RaceDistance(distanceKm: 42.195, name: "マラソン")
            ],
            entryStatus: nil,
            isCurated: true,
            courseType: nil,
            tags: []
        )

        // chip 選了 10K → 帶 10K，不是最長那一項。
        let tenK = App2RaceDatabaseViewModel.fill(App2RaceForm(), with: event, distance: .tenK)
        XCTAssertEqual(tenK.distanceKey, "10")
        XCTAssertEqual(tenK.raceId, "jp_2027_tokyo")
        XCTAssertEqual(tenK.name, "東京マラソン 2027")

        // chip 是「全部」→ 取最長的一項（大多數賽會的主項目）。
        let all = App2RaceDatabaseViewModel.fill(App2RaceForm(), with: event, distance: .all)
        XCTAssertEqual(all.distanceKey, "42.195")
    }

    /// 地區「全部」不帶 `region` 參數（1.x 的 picker 沒有這個選項，值不能亂編）。
    func testRegionApiValues() {
        XCTAssertNil(App2RaceDatabaseViewModel.Region.all.apiValue)
        XCTAssertEqual(App2RaceDatabaseViewModel.Region.taiwan.apiValue, "tw")
        XCTAssertEqual(App2RaceDatabaseViewModel.Region.japan.apiValue, "jp")
    }
}
