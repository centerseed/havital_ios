import XCTest
@testable import paceriz_dev

// MARK: - 課表頁往前翻到「已產生的下一週」
/// **週日的缺口**（2026-09-06 prod）：使用者在週回顧按下「產生下週課表」，後端已經把
/// 第 11 週寫進 `weekly_plans_v2` 並把它設為 `active_weekly_plan_id`，但週日在使用者時區
/// 仍屬第 10 週 —— `GET /v2/plan/status` 回 `current_week = 10`，課表頁錨在當週，
/// 右箭頭（`canGoNextHistoryWeek`）在非歷史模式一律停用，所以剛產好的那一週
/// **整個週日都看不到**，要等到週一才出現。
///
/// 判準用後端已經給的那一格：`next_week_info.has_plan == true`
/// （`domains/plan_week/service.py:1323-1351`）。它為真才多開一週的可達範圍，
/// 不新開端點、不改後端。
@MainActor
final class App2PlanNextWeekBrowsingTests: XCTestCase {

    private func planStatus(
        currentWeek: Int = 10,
        nextWeekHasPlan: Bool?,
        nextWeekNumber: Int = 11
    ) -> PlanStatusV2Response {
        PlanStatusV2Response(
            currentWeek: currentWeek,
            totalWeeks: 16,
            nextAction: "view_plan",
            canGenerateNextWeek: false,
            currentWeekPlanId: "overview-1_\(currentWeek)",
            previousWeekSummaryId: nil,
            targetType: "race_run",
            methodologyId: "paceriz",
            nextWeekInfo: nextWeekHasPlan.map {
                NextWeekInfoV2(
                    weekNumber: nextWeekNumber,
                    hasPlan: $0,
                    canGenerate: !$0,
                    requiresCurrentWeekSummary: false,
                    nextAction: nil
                )
            },
            metadata: nil
        )
    }

    private func overview() -> PlanOverviewV2 {
        PlanOverviewV2(
            id: "overview-1", targetId: nil, targetType: "race_run", targetDescription: nil,
            methodologyId: "paceriz", totalWeeks: 16, startFromStage: "base",
            raceDate: nil, distanceKm: nil, distanceKmDisplay: nil, distanceUnit: nil,
            targetPace: nil, targetTime: nil, isMainRace: nil, targetName: nil,
            methodologyOverview: nil, targetEvaluate: nil, approachSummary: nil,
            trainingStages: [], milestones: [], createdAt: Date(),
            methodologyVersion: nil, milestoneBasis: nil
        )
    }

    private func weeklyPlan(week: Int, totalDistance: Double = 42) -> WeeklyPlanV2 {
        WeeklyPlanV2(
            planId: "overview-1_\(week)", weekOfTraining: week, id: "overview-1_\(week)",
            purpose: "week \(week)", weekOfPlan: week, totalWeeks: 16, totalDistance: totalDistance,
            totalDistanceDisplay: nil, totalDistanceUnit: nil, totalDistanceReason: nil,
            designReason: nil, mileageProgressionNote: nil, coachNote: nil, days: [],
            intensityTotalMinutes: nil, currentVdot: nil, vdotSource: nil,
            createdAt: Date(), updatedAt: Date(), trainingLoadAnalysis: nil,
            personalizedRecommendations: nil, realTimeAdjustments: nil, apiVersion: "2.0"
        )
    }

    private func makeViewModel(
        nextWeekHasPlan: Bool?
    ) -> (App2PlanViewModel, MockTrainingPlanV2Repository) {
        let repository = MockTrainingPlanV2Repository()
        repository.planStatusToReturn = planStatus(nextWeekHasPlan: nextWeekHasPlan)
        repository.overviewToReturn = overview()
        repository.weeklyPlanV2ToReturn = weeklyPlan(week: 10)
        repository.weeklyPlansByWeekToReturn = [
            9: weeklyPlan(week: 9), 10: weeklyPlan(week: 10), 11: weeklyPlan(week: 11)
        ]
        repository.cachedWeeklyPlansByWeek = [:]
        let viewModel = App2PlanViewModel(
            planRepository: repository,
            workoutRepository: MockWorkoutRepository(),
            targetRepository: nil
        )
        return (viewModel, repository)
    }

    private static func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    // MARK: - 右箭頭的可達範圍

    /// 下週課表已產生 → **看本週時右箭頭就要能按**。修前非歷史模式一律 false。
    func test_forwardArrowIsEnabledOnCurrentWeekWhenNextWeekPlanExists() async {
        let (viewModel, _) = makeViewModel(nextWeekHasPlan: true)
        await viewModel.revalidate()

        XCTAssertFalse(viewModel.isHistoryMode, "起點是本週，不是歷史模式")
        XCTAssertEqual(viewModel.selectedWeekOfPlan, 10)
        XCTAssertTrue(viewModel.canGoNextHistoryWeek, "下週已有課表 ⇒ 右箭頭可按")
    }

    /// 下週還沒產生 → 維持原行為（右箭頭停用，按了不動）。
    func test_forwardArrowStaysDisabledWhenNextWeekHasNoPlan() async {
        let (viewModel, repository) = makeViewModel(nextWeekHasPlan: false)
        await viewModel.revalidate()

        XCTAssertFalse(viewModel.canGoNextHistoryWeek)

        repository.lastRequestedWeeklyPlanWeekOfTraining = nil
        await viewModel.goToHistoryWeek(offset: 1)
        XCTAssertNil(viewModel.historyWeek, "沒有下週課表時往後翻是 no-op")
        XCTAssertEqual(viewModel.selectedWeekOfPlan, 10)
        XCTAssertNil(repository.lastRequestedWeeklyPlanWeekOfTraining, "不得去要一份不存在的週")
    }

    /// 後端沒給 `next_week_info` → 也維持原行為。
    func test_forwardArrowStaysDisabledWhenNextWeekInfoIsAbsent() async {
        let (viewModel, _) = makeViewModel(nextWeekHasPlan: nil)
        await viewModel.revalidate()

        XCTAssertFalse(viewModel.canGoNextHistoryWeek)
        await viewModel.goToHistoryWeek(offset: 1)
        XCTAssertNil(viewModel.historyWeek)
    }

    // MARK: - 往前翻與返程

    /// 本週按右箭頭 → 走既有的 `getWeeklyPlan(weekOfTraining:overviewId:)` 進第 11 週。
    func test_goingForwardShowsTheAlreadyGeneratedNextWeek() async {
        let (viewModel, repository) = makeViewModel(nextWeekHasPlan: true)
        await viewModel.revalidate()

        await viewModel.goToHistoryWeek(offset: 1)

        XCTAssertEqual(viewModel.selectedWeekOfPlan, 11, "週次標要是第 11 週")
        XCTAssertEqual(viewModel.historyWeek, 11)
        XCTAssertEqual(repository.lastRequestedWeeklyPlanWeekOfTraining, 11)
        XCTAssertEqual(viewModel.week?.value.weekLabel.contains("11"), true, "週次標是下週那一份")
        XCTAssertFalse(viewModel.isHistoryWeekMissing)
    }

    /// 第 11 週再往前 → 不動（那一週是可達範圍的盡頭）。
    func test_theNextWeekIsTheEndOfTheForwardRange() async {
        let (viewModel, _) = makeViewModel(nextWeekHasPlan: true)
        await viewModel.revalidate()
        await viewModel.goToHistoryWeek(offset: 1)

        XCTAssertFalse(viewModel.canGoNextHistoryWeek, "第 11 週的右箭頭停用")
        await viewModel.goToHistoryWeek(offset: 1)
        XCTAssertEqual(viewModel.historyWeek, 11, "按了也不動")
    }

    /// 第 11 週按左箭頭 → 回到本週的現行畫面（退出該模式並重驗）。
    func test_goingBackFromTheNextWeekReturnsToTheCurrentWeek() async {
        let (viewModel, _) = makeViewModel(nextWeekHasPlan: true)
        await viewModel.revalidate()
        await viewModel.goToHistoryWeek(offset: 1)
        XCTAssertEqual(viewModel.historyWeek, 11)

        await viewModel.goToHistoryWeek(offset: -1)

        XCTAssertNil(viewModel.historyWeek, "回到本週＝退出回看模式")
        XCTAssertFalse(viewModel.isHistoryMode)
        XCTAssertEqual(viewModel.selectedWeekOfPlan, 10)
        XCTAssertEqual(viewModel.week?.value.weekLabel.contains("10"), true)
    }

    /// 往回翻仍然走既有路徑（第 9 週），不被下週那條分支吃掉。
    func test_goingBackwardFromCurrentWeekIsUnchanged() async {
        let (viewModel, repository) = makeViewModel(nextWeekHasPlan: true)
        await viewModel.revalidate()

        await viewModel.goToHistoryWeek(offset: -1)

        XCTAssertEqual(viewModel.historyWeek, 9)
        XCTAssertEqual(repository.lastRequestedWeeklyPlanWeekOfTraining, 9)
        XCTAssertTrue(viewModel.canGoNextHistoryWeek, "第 9 週往後仍然翻得回去")
    }

    // MARK: - 產完下週之後，右箭頭要立刻活過來

    /// 產生課表發的是 `.dataChanged(.trainingPlanV2)`
    /// （`App2WeeklyReviewViewModel.applyAndGenerate()`）。課表頁收到它就重讀 plan status
    /// ——否則 `next_week_info` 還是產生前那一份，右箭頭要等下一次冷啟才會亮。
    func test_planGeneratedEventReloadsPlanStatusSoTheArrowLightsUp() async {
        let (viewModel, repository) = makeViewModel(nextWeekHasPlan: false)
        await viewModel.revalidate()
        XCTAssertFalse(viewModel.canGoNextHistoryWeek)

        let baseline = repository.getPlanStatusCallCount
        repository.planStatusToReturn = planStatus(nextWeekHasPlan: true)
        CacheEventBus.shared.publish(.dataChanged(.trainingPlanV2))

        await Self.waitUntil { repository.getPlanStatusCallCount > baseline }
        XCTAssertGreaterThan(repository.getPlanStatusCallCount, baseline, "要重讀 plan status")
        await Self.waitUntil { viewModel.canGoNextHistoryWeek }
        XCTAssertTrue(viewModel.canGoNextHistoryWeek, "產完下週，右箭頭立刻可按")
    }

    // MARK: - 產完之後這一頁要停在剛產生的那一週（AC-TRAIN-HUB-19）

    /// 週日流程：產的是第 11 週 → 這一頁直接畫第 11 週，不是還停在第 10 週。
    /// 修前使用者退回課表分頁看到的是本週，以為課表沒產出來（2026-09-20 回報）。
    func test_generatedWeekLandsOnPlanTabForTheSundayFlow() async {
        let (viewModel, repository) = makeViewModel(nextWeekHasPlan: true)
        await viewModel.revalidate()
        XCTAssertEqual(viewModel.selectedWeekOfPlan, 10, "起點是本週")

        await viewModel.showGeneratedWeek(11)

        XCTAssertEqual(viewModel.selectedWeekOfPlan, 11)
        XCTAssertEqual(viewModel.historyWeek, 11)
        XCTAssertEqual(repository.lastRequestedWeeklyPlanWeekOfTraining, 11)
        XCTAssertEqual(viewModel.week?.value.weekLabel.contains("11"), true, "畫的是剛產生的那一份")
    }

    /// 平日流程：產的就是當週 → 維持現行畫面，不得被推進回看模式。
    func test_generatedWeekLandsOnPlanTabForTheWeekdayFlow() async {
        let (viewModel, _) = makeViewModel(nextWeekHasPlan: false)
        await viewModel.revalidate()

        await viewModel.showGeneratedWeek(10)

        XCTAssertNil(viewModel.historyWeek, "當週不是回看")
        XCTAssertFalse(viewModel.isHistoryMode)
        XCTAssertEqual(viewModel.selectedWeekOfPlan, 10)
    }

    /// 剛好在回看第 9 週時產出當週課表 → 收掉回看，回到當週的現行畫面。
    func test_generatedCurrentWeekLeavesHistoryMode() async {
        let (viewModel, _) = makeViewModel(nextWeekHasPlan: false)
        await viewModel.revalidate()
        await viewModel.goToHistoryWeek(offset: -1)
        XCTAssertEqual(viewModel.historyWeek, 9)

        await viewModel.showGeneratedWeek(10)

        XCTAssertNil(viewModel.historyWeek)
        XCTAssertEqual(viewModel.selectedWeekOfPlan, 10)
    }

    /// **從首頁產生**：這一頁可能連載都還沒載過，`current_week` 未知，
    /// 那時分不出第 11 週是不是當週。要記著，等 plan status 回來的那一輪用掉——
    /// 丟掉它等於使用者被送到課表分頁卻還是看到這週。
    func test_generatedWeekIsHonouredWhenPlanStatusArrivesLater() async {
        let (viewModel, _) = makeViewModel(nextWeekHasPlan: true)
        XCTAssertFalse(viewModel.hasLoaded, "還沒載過，currentWeek 未知")

        await viewModel.showGeneratedWeek(11)
        XCTAssertNil(viewModel.historyWeek, "還不知道當週是第幾週，先不動畫面")

        await viewModel.revalidate()

        XCTAssertEqual(viewModel.historyWeek, 11)
        XCTAssertEqual(viewModel.selectedWeekOfPlan, 11)
        // 不斷言 `lastRequestedWeeklyPlanWeekOfTraining`：冷啟那一輪還會在背景預抓
        // 第 1…10 週（`schedulePrefetchAllWeeks`，不 await），最後一筆請求是誰不固定。
        // 要驗的是畫面上是哪一週。
        XCTAssertEqual(viewModel.week?.value.weekLabel.contains("11"), true)
    }

    /// 落到那一週之後，既有的週次切換照常帶得走（AC-TRAIN-HUB-19 第三句）。
    func test_userCanStillLeaveTheGeneratedWeek() async {
        let (viewModel, _) = makeViewModel(nextWeekHasPlan: true)
        await viewModel.revalidate()
        await viewModel.showGeneratedWeek(11)
        XCTAssertEqual(viewModel.historyWeek, 11)

        await viewModel.goToHistoryWeek(offset: -1)

        XCTAssertNil(viewModel.historyWeek, "回到本週＝退出回看模式")
        XCTAssertEqual(viewModel.selectedWeekOfPlan, 10)
    }

    func test_pullToRefreshOnTheNextWeekShowsTheServerCopy() async {
        let (viewModel, repository) = makeViewModel(nextWeekHasPlan: true)
        let cachedPlan = weeklyPlan(week: 11, totalDistance: 56)
        let serverPlan = weeklyPlan(week: 11, totalDistance: 44)
        repository.simulatesCacheFirstReads = true
        repository.cachedWeeklyPlansByWeek = [11: cachedPlan]
        repository.weeklyPlansByWeekToReturn = [10: weeklyPlan(week: 10), 11: serverPlan]

        await viewModel.revalidate()
        await viewModel.goToHistoryWeek(offset: 1)
        XCTAssertEqual(viewModel.week?.value.targetDistanceKm, 56)

        let refreshCount = repository.refreshWeeklyPlanCallCount
        await viewModel.revalidate()

        XCTAssertEqual(viewModel.week?.value.targetDistanceKm, 44)
        XCTAssertGreaterThan(repository.refreshWeeklyPlanCallCount, refreshCount)
        XCTAssertEqual(repository.lastRefreshedWeeklyPlanWeekOfTraining, 11)
    }

    func test_planChangedWhileOnCurrentWeekThenNextWeekShowsTheServerCopy() async {
        let (viewModel, repository) = makeViewModel(nextWeekHasPlan: true)
        repository.simulatesCacheFirstReads = true
        repository.cachedWeeklyPlansByWeek = [11: weeklyPlan(week: 11, totalDistance: 56)]
        repository.weeklyPlansByWeekToReturn = [10: weeklyPlan(week: 10), 11: weeklyPlan(week: 11, totalDistance: 44)]
        await viewModel.revalidate()

        CacheEventBus.shared.publish(.dataChanged(.trainingPlanV2))
        await Self.waitUntil { repository.clearedWeeklyPlanCacheWeeks.contains(11) }
        XCTAssertTrue(repository.clearedWeeklyPlanCacheWeeks.contains(10))
        await viewModel.goToHistoryWeek(offset: 1)

        XCTAssertEqual(viewModel.week?.value.targetDistanceKm, 44)
    }

    func test_revalidateOnTheNextWeekKeepsPrepaintedPlanWhenRefreshFails() async {
        let (viewModel, repository) = makeViewModel(nextWeekHasPlan: true)
        repository.simulatesCacheFirstReads = true
        repository.cachedWeeklyPlansByWeek = [11: weeklyPlan(week: 11, totalDistance: 56)]
        repository.weeklyPlansByWeekToReturn = [10: weeklyPlan(week: 10), 11: weeklyPlan(week: 11, totalDistance: 44)]
        await viewModel.revalidate()
        await viewModel.goToHistoryWeek(offset: 1)
        XCTAssertEqual(viewModel.week?.value.targetDistanceKm, 56)

        let refreshCount = repository.refreshWeeklyPlanCallCount
        repository.refreshWeeklyPlanErrorToThrow = NSError(domain: "test", code: 500)
        await viewModel.revalidate()

        XCTAssertGreaterThan(repository.refreshWeeklyPlanCallCount, refreshCount)
        XCTAssertEqual(viewModel.week?.value.targetDistanceKm, 56)
        XCTAssertFalse(viewModel.isHistoryWeekMissing)
    }
}
