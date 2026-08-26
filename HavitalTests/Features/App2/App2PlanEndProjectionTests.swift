import XCTest
@testable import paceriz_dev

/// 2.0 計畫結束態的投影（設計 frame-00g／frame-00g2）。
///
/// 鎖住的四件事：
/// 1. **結束態偵測只認 `next_action == "training_completed"`** —— 而且它與週回顧
///    時機卡互斥：同一份 payload 不可能同時交出結束態卡與時機卡。
/// 2. **race／maintenance 分岔**由 `target_type` 決定；maintenance 一個字都不提賽事成績。
/// 3. **降級規則**：沒有實際完賽成績 → 退「當時預估」並隱藏差值；沒有敘事 → 數字版。
/// 4. **聚合的分母**：完成率的分母是讀得到的週，不是 `total_weeks`；峰值週不濾當週。
final class App2PlanEndProjectionTests: XCTestCase {

    // MARK: - Fixtures

    private func planStatus(
        nextAction: String = "training_completed",
        currentWeek: Int = 23,
        totalWeeks: Int = 22,
        targetType: String? = "race_run",
        planId: String? = nil
    ) -> PlanStatusV2Response {
        PlanStatusV2Response(
            currentWeek: currentWeek,
            totalWeeks: totalWeeks,
            nextAction: nextAction,
            canGenerateNextWeek: false,
            currentWeekPlanId: planId,
            previousWeekSummaryId: nil,
            targetType: targetType,
            methodologyId: "paceriz",
            nextWeekInfo: nil,
            metadata: nil
        )
    }

    /// `2026-12-06` in Asia/Tokyo.
    private let raceEpoch = 1_796_558_400  // 2026-12-06 12:00 UTC

    private func target(targetTime: Int = 9_240) -> Target {
        Target(
            id: "target-1",
            type: "race_run",
            name: "Hofu Marathon",
            distanceKm: 42,
            targetTime: targetTime,
            targetPace: "3:39",
            raceDate: raceEpoch,
            isMainRace: true,
            trainingWeeks: 22,
            timezone: "Asia/Tokyo"
        )
    }

    private func bar(_ weekStart: String, _ km: Double) -> WorkoutStatsWeeklyEntry {
        WorkoutStatsWeeklyEntry(
            weekStart: weekStart,
            weekEnd: weekStart,
            distanceKm: km,
            isCurrentWeek: false
        )
    }

    private func weeklySummary(week: Int, percentage: Double, planned: Int, completed: Int)
    -> WeeklySummaryV2 {
        WeeklySummaryV2(
            id: "summary-\(week)",
            uid: "user-1",
            weeklyPlanId: "plan-\(week)",
            trainingOverviewId: "overview-1",
            weekOfTraining: week,
            createdAt: nil,
            planContext: nil,
            trainingCompletion: TrainingCompletionV2(
                percentage: percentage,
                plannedKm: 48,
                completedKm: 44,
                plannedSessions: planned,
                completedSessions: completed,
                evaluation: ""
            ),
            trainingAnalysis: TrainingAnalysisV2(
                heartRate: nil, pace: nil, distance: nil, intensityDistribution: nil
            ),
            readinessSummary: nil,
            capabilityProgression: nil,
            milestoneProgress: nil,
            historicalComparison: nil,
            weeklyHighlights: WeeklyHighlightsV2(
                highlights: [], achievements: [], areasForImprovement: []
            ),
            upcomingRaceEvaluation: nil,
            nextWeekAdjustments: NextWeekAdjustmentsV2(
                items: [], summary: "", methodologyConstraintsConsidered: true,
                basedOnFlags: [], userNlEdit: nil, userNlEditStatus: .none,
                userNlEditFailReason: nil
            ),
            restWeekRecommendation: nil,
            finalTrainingReview: nil,
            promptAuditId: nil,
            observations: nil,
            weeklyStory: nil
        )
    }

    private func workout(_ isoDateTime: String, km: Double, seconds: Int, type: String = "running")
    -> WorkoutV2 {
        WorkoutV2(
            id: isoDateTime, provider: "garmin", activityType: type,
            startTimeUtc: isoDateTime, endTimeUtc: nil,
            durationSeconds: seconds, distanceMeters: km * 1000,
            distanceDisplay: nil, distanceUnit: nil, deviceName: nil,
            basicMetrics: nil, advancedMetrics: nil, createdAt: nil,
            schemaVersion: nil, storagePath: nil, dailyPlanSummary: nil,
            aiSummary: nil, shareCardContent: nil
        )
    }

    private func card(
        kind: App2PlanEndKind = .race,
        totalWeeks: Int? = 22,
        targetTime: String? = "2:34:00"
    ) -> App2PlanEndCard {
        App2PlanEndCard(
            kind: kind, raceName: "Hofu Marathon", raceDate: "2026-12-06",
            distanceLabel: nil, totalWeeks: totalWeeks, targetTime: targetTime,
            estimatedFinish: "2:41:30", actualFinish: nil, narrative: nil
        )
    }

    // MARK: - 1. 結束態偵測（training_completed guard）

    /// 只有 `training_completed` 才是結束態。**其餘每一個 `next_action` 都不是** ——
    /// 誤判的代價是把還在跑的計畫畫成「已完成」，用戶的課表就此消失。
    func test_card_onlyWhenTrainingCompleted() {
        XCTAssertNotNil(App2PlanEndProjection.card(
            planStatus: planStatus(nextAction: "training_completed"),
            overview: nil, target: target(), estimatedFinish: nil
        ))

        for action in ["view_plan", "create_plan", "create_summary", ""] {
            XCTAssertNil(
                App2PlanEndProjection.card(
                    planStatus: planStatus(nextAction: action),
                    overview: nil, target: target(), estimatedFinish: nil
                ),
                "next_action=\(action) 不是結束態"
            )
        }

        // plan status 整個讀不到時也不准宣稱結束（讀不到 ≠ 走完了）。
        XCTAssertNil(App2PlanEndProjection.card(
            planStatus: nil, overview: nil, target: target(), estimatedFinish: nil
        ))
    }

    /// **結束態卡與週回顧時機卡互斥。** 兩者讀的是同一欄，所以同一份 payload 上
    /// 一定是「一個有、另一個沒有」——不可能兩張卡同屏，也不可能兩張都不見。
    @MainActor
    func test_planEndAndWeekReviewCardAreMutuallyExclusive() {
        let completed = planStatus(nextAction: "training_completed")
        XCTAssertNotNil(App2PlanEndProjection.card(
            planStatus: completed, overview: nil, target: target(), estimatedFinish: nil
        ))
        XCTAssertNil(
            App2HomeViewModel.weekReviewState(
                planStatus: completed, isSunday: false, summaryId: "overview_22_summary"
            ),
            "計畫走完後時機卡必須整張收掉，即使上週回顧已經生成"
        )

        // 反向：還在跑的計畫給時機卡、不給結束態卡。
        let running = planStatus(nextAction: "view_plan", currentWeek: 5, totalWeeks: 22)
        XCTAssertNil(App2PlanEndProjection.card(
            planStatus: running, overview: nil, target: target(), estimatedFinish: nil
        ))
        XCTAssertNotNil(App2HomeViewModel.weekReviewState(
            planStatus: running, isSunday: false, summaryId: nil
        ))
    }

    // MARK: - 2. race／maintenance 變體分岔

    /// `race_run` 才是賽事語意。後端交的是 overview 的原值（`race_run`），
    /// 而 DTO 註解寫的是 `race` —— 兩個拼法都要認。
    func test_kind_splitsOnTargetType() {
        XCTAssertEqual(App2PlanEndProjection.kind(targetType: "race_run"), .race)
        XCTAssertEqual(App2PlanEndProjection.kind(targetType: "RACE_RUN"), .race)
        XCTAssertEqual(App2PlanEndProjection.kind(targetType: "race"), .race)
        XCTAssertEqual(App2PlanEndProjection.kind(targetType: "maintenance"), .maintenance)
        XCTAssertEqual(App2PlanEndProjection.kind(targetType: "beginner"), .maintenance)
        // 讀不到就退保守的那一邊 —— 不提賽事成績比提錯一場賽事安全。
        XCTAssertEqual(App2PlanEndProjection.kind(targetType: nil), .maintenance)
    }

    /// `plan status` 自己就帶 `target_type`；它缺席時才退 overview。
    func test_kind_prefersPlanStatusOverOverview() {
        XCTAssertEqual(
            App2PlanEndProjection.kind(
                planStatus: planStatus(targetType: "maintenance"), overview: nil
            ),
            .maintenance
        )
        XCTAssertEqual(
            App2PlanEndProjection.kind(planStatus: planStatus(targetType: nil), overview: nil),
            .maintenance
        )
    }

    /// maintenance 變體**一個賽事欄位都不帶** —— 就算帳號裡還留著一個 target。
    func test_card_maintenanceCarriesNoRaceFields() {
        let card = App2PlanEndProjection.card(
            planStatus: planStatus(totalWeeks: 12, targetType: "maintenance"),
            overview: nil,
            target: target(),
            estimatedFinish: "2:41:30"
        )
        XCTAssertEqual(card?.kind, .maintenance)
        XCTAssertNil(card?.raceName)
        XCTAssertNil(card?.raceDate)
        XCTAssertNil(card?.distanceLabel)
        XCTAssertNil(card?.targetTime)
        XCTAssertNil(card?.estimatedFinish)
        XCTAssertEqual(card?.totalWeeks, 12)
    }

    func test_card_raceCarriesRaceFields() {
        let card = App2PlanEndProjection.card(
            planStatus: planStatus(targetType: "race_run"),
            overview: nil,
            target: target(),
            estimatedFinish: "2:41:30"
        )
        XCTAssertEqual(card?.kind, .race)
        XCTAssertEqual(card?.raceName, "Hofu Marathon")
        XCTAssertEqual(card?.targetTime, "2:34:00")
        XCTAssertEqual(card?.estimatedFinish, "2:41:30")
    }

    /// 目標未設成績（0）→ 那一欄不出現，不印 `0:00`。
    func test_card_omitsTargetTimeWhenUnset() {
        let card = App2PlanEndProjection.card(
            planStatus: planStatus(), overview: nil,
            target: target(targetTime: 0), estimatedFinish: nil
        )
        XCTAssertNil(card?.targetTime)
    }

    /// 週數以 plan status 為權威；缺席才退 target。
    func test_totalWeeks_prefersPlanStatus() {
        XCTAssertEqual(
            App2PlanEndProjection.totalWeeks(
                planStatus: planStatus(totalWeeks: 22), overview: nil, target: target()
            ),
            22
        )
        XCTAssertEqual(
            App2PlanEndProjection.totalWeeks(
                planStatus: planStatus(totalWeeks: 0), overview: nil, target: target()
            ),
            22  // target.trainingWeeks
        )
        XCTAssertNil(App2PlanEndProjection.totalWeeks(
            planStatus: nil, overview: nil, target: nil
        ))
    }

    // MARK: - 3. 降級（無賽果 → 隱藏差值；無敘事 → 數字版）

    /// **賽事實際成績沒有 producer** —— 所以 `actualFinish` 恆 nil、差值恆不顯示，
    /// 右欄退成「當時預估」。這一條擋的是「拿預估去減目標當成賽果差值」。
    func test_card_degradesToEstimateAndHidesDelta() {
        let card = App2PlanEndProjection.card(
            planStatus: planStatus(), overview: nil,
            target: target(), estimatedFinish: "2:41:30"
        )
        XCTAssertNil(card?.actualFinish, "賽事成績綁定機制不存在，producer 必須交 nil")
        XCTAssertEqual(card?.isFinishDegraded, true)
        XCTAssertEqual(card?.showsFinishDelta, false, "沒有實際成績就沒有差值可講")
        XCTAssertEqual(card?.heroSecondaryValue, "2:41:30", "右欄退成當時預估")
    }

    /// **LLM 敘事端點未落地** → `narrative` 恆 nil → 首頁的敘事子卡整卡隱藏。
    func test_card_hasNoNarrativeOnProductionPath() {
        let card = App2PlanEndProjection.card(
            planStatus: planStatus(), overview: nil, target: target(), estimatedFinish: nil
        )
        XCTAssertNil(card?.narrative, "production 路徑不得出現假造的整期敘事")
    }

    /// 賽事成績真的來了的那一天：差值成立、右欄不再是降級值。
    /// （這一條測的是**降級規則本身**，不是宣稱端點已經有了。）
    func test_finishDeltaAppearsOnlyWhenBothTargetAndActualExist() {
        let withResult = App2PlanEndCard(
            kind: .race, raceName: "Hofu", raceDate: nil, distanceLabel: nil,
            totalWeeks: 22, targetTime: "2:34:00", estimatedFinish: "2:41:30",
            actualFinish: "2:35:42", narrative: nil
        )
        XCTAssertTrue(withResult.showsFinishDelta)
        XCTAssertFalse(withResult.isFinishDegraded)
        XCTAssertEqual(withResult.heroSecondaryValue, "2:35:42")

        let noTarget = App2PlanEndCard(
            kind: .race, raceName: "Hofu", raceDate: nil, distanceLabel: nil,
            totalWeeks: 22, targetTime: nil, estimatedFinish: nil,
            actualFinish: "2:35:42", narrative: nil
        )
        XCTAssertFalse(noTarget.showsFinishDelta, "沒設目標成績就沒有「距目標」可講")

        // 兩個值都沒有 → 整組兩欄不出現（畫面據此決定畫不畫）。
        let empty = App2PlanEndCard(
            kind: .race, raceName: "Hofu", raceDate: nil, distanceLabel: nil,
            totalWeeks: 22, targetTime: nil, estimatedFinish: nil,
            actualFinish: nil, narrative: nil
        )
        XCTAssertNil(empty.heroSecondaryValue)
    }

    // MARK: - 3b. 完賽數字卡的降級階梯（2026-08-27 裁決：不得整塊省略）

    /// 成績 → 當時預估 → 目標，**一路退到最後一個講得出來的量**。
    /// 之前的版本在「只剩目標」時就整塊收掉了 —— 那正是這條裁決要擋的情形。
    @MainActor
    func test_degradedFinish_fallsThroughResultThenEstimateThenTarget() {
        func card(actual: String?, estimate: String?, target: String?) -> App2PlanEndCard {
            App2PlanEndCard(
                kind: .race, raceName: "Hofu", raceDate: nil, distanceLabel: nil,
                totalWeeks: 22, targetTime: target, estimatedFinish: estimate,
                actualFinish: actual, narrative: nil
            )
        }

        // 有成績 → 大字是成績，底下標來源。
        let withResult = App2PeriodSummaryView.degradedFinish(
            card(actual: "2:35:42", estimate: "2:41:30", target: "2:34:00")
        )
        XCTAssertEqual(withResult?.value, "2:35:42")
        XCTAssertNotNil(withResult?.target, "有成績時右側仍要標目標")

        // 沒成績、有預估 → 大字是預估，底下那句要明說它不是成績。
        let withEstimate = App2PeriodSummaryView.degradedFinish(
            card(actual: nil, estimate: "2:41:30", target: "2:34:00")
        )
        XCTAssertEqual(withEstimate?.value, "2:41:30")
        XCTAssertNotNil(withEstimate?.note, "降級成預估時一定要有那句說明")

        // 連預估都沒有 → **仍然畫**，退到目標；這一格沒有話要補。
        let targetOnly = App2PeriodSummaryView.degradedFinish(
            card(actual: nil, estimate: nil, target: "2:34:00")
        )
        XCTAssertEqual(targetOnly?.value, "2:34:00", "只剩目標時不得整塊省略")
        XCTAssertNil(targetOnly?.target, "右欄已經是目標本身,不再重複一次")
        XCTAssertNil(targetOnly?.note)

        // 什麼都沒有 → 這時才整塊不畫（連降級形都沒有東西可講）。
        XCTAssertNil(App2PeriodSummaryView.degradedFinish(
            card(actual: nil, estimate: nil, target: nil)
        ))

        // maintenance 一格都不畫 —— 不提賽事成績。
        XCTAssertNil(App2PeriodSummaryView.degradedFinish(
            App2PlanEndCard(
                kind: .maintenance, raceName: nil, raceDate: nil, distanceLabel: nil,
                totalWeeks: 12, targetTime: "2:34:00", estimatedFinish: "2:41:30",
                actualFinish: "2:35:42", narrative: nil
            )
        ))
    }

    // MARK: - 4. 整期聚合

    func test_summary_aggregatesFromLiveSeries() {
        let summary = App2PlanEndProjection.summary(
            card: card(),
            weeklySeries: [
                bar("2026-08-03", 30), bar("2026-08-10", 78), bar("2026-08-17", 52)
            ],
            weeklySummaries: [
                weeklySummary(week: 1, percentage: 100, planned: 5, completed: 5),
                weeklySummary(week: 2, percentage: 80, planned: 5, completed: 4)
            ],
            workouts: [
                workout("2026-08-05T06:00:00Z", km: 12, seconds: 3600),
                workout("2026-08-12T06:00:00Z", km: 34, seconds: 10800),
                // 計畫期之前的那一筆不計 —— 它屬於上一份計畫。
                workout("2026-07-01T06:00:00Z", km: 40, seconds: 14400),
                // 非跑步不計。
                workout("2026-08-13T06:00:00Z", km: 60, seconds: 7200, type: "cycling")
            ],
            vdots: [
                VDOTEntry(datetime: 1_785_931_200, dynamicVdot: 39.0, paceVdot: 39.0),
                VDOTEntry(datetime: 1_786_968_000, dynamicVdot: 45.2, paceVdot: 45.2)
            ]
        )

        XCTAssertEqual(summary.totalDistanceKm, 160)
        XCTAssertEqual(summary.peakWeekKm, 78)
        XCTAssertEqual(summary.completionRate, 90)          // (100 + 80) / 2
        XCTAssertEqual(summary.sessionCount, 9)             // 5 + 4
        XCTAssertEqual(summary.plannedSessionCount, 10)     // 5 + 5
        XCTAssertEqual(summary.totalDurationSeconds, 14_400)// 3600 + 10800
        XCTAssertEqual(summary.longestRunKm, 34)
        XCTAssertEqual(summary.bars.count, 3)
    }

    /// **完成率的分母是讀得到的週，不是 `total_weeks`。**
    /// 沒生成回顧的那幾週沒有完成率可講，當成 0 會把「沒做回顧」講成「一堂都沒跑」。
    func test_completionRate_denominatorIsAvailableWeeksOnly() {
        // 22 週的計畫只讀到 2 週 → 平均是那兩週的，不是 /22。
        XCTAssertEqual(
            App2PlanEndProjection.completionRate([
                weeklySummary(week: 1, percentage: 100, planned: 5, completed: 5),
                weeklySummary(week: 2, percentage: 90, planned: 5, completed: 5)
            ]),
            95
        )
        // 一份都讀不到 → nil（畫「–」），不是 0。
        XCTAssertNil(App2PlanEndProjection.completionRate([]))
        XCTAssertNil(App2PlanEndProjection.completedSessions([]))
        XCTAssertNil(App2PlanEndProjection.plannedSessions([]))
    }

    /// 峰值週**不濾掉「本週」** —— 計畫已經走完，這段裡的每一根柱都是完整週。
    func test_peakWeek_doesNotDropTheCurrentWeekFlag() {
        let bars = App2MetricDetailProjection.bars([
            bar("2026-08-03", 30),
            WorkoutStatsWeeklyEntry(
                weekStart: "2026-08-10", weekEnd: "2026-08-16",
                distanceKm: 78, isCurrentWeek: true
            )
        ])
        XCTAssertEqual(App2PlanEndProjection.peakWeekKm(bars), 78)
        XCTAssertEqual(App2PlanEndProjection.totalDistanceKm(bars), 108)
    }

    /// 一根柱都沒有 → 每一格都是 nil（畫「–」），不是 0。
    func test_summary_allNilWhenNoData() {
        let summary = App2PlanEndProjection.summary(
            card: card(), weeklySeries: [], weeklySummaries: [], workouts: [], vdots: []
        )
        XCTAssertNil(summary.totalDistanceKm)
        XCTAssertNil(summary.peakWeekKm)
        XCTAssertNil(summary.completionRate)
        XCTAssertNil(summary.sessionCount)
        XCTAssertNil(summary.totalDurationSeconds)
        XCTAssertNil(summary.longestRunKm)
        XCTAssertNil(summary.vdotDelta)
        XCTAssertTrue(summary.bars.isEmpty)
    }

    /// VDOT 增量要**兩個點**才成立；窗口內只有一點時不拿窗外的值湊一個「變化」。
    func test_vdotDelta_needsTwoPointsInsideThePeriod() {
        let inside = App2PlanEndProjection.vdotSeries(
            [
                // 計畫期之前 —— 不得被當成「起點」。
                VDOTEntry(datetime: 1_782_907_200, dynamicVdot: 30.0, paceVdot: 30.0),
                VDOTEntry(datetime: 1_786_968_000, dynamicVdot: 45.2, paceVdot: 45.2)
            ],
            onOrAfter: "2026-08-03"
        )
        XCTAssertEqual(inside.count, 1)
        XCTAssertNil(App2PlanEndProjection.vdotDelta(inside), "只有一點畫不出「變化」")
    }

    /// 課表 tab 的那一行小計：**缺哪一段就少那一段**，三段都缺就整行不畫。
    func test_stripStatsLine_dropsMissingParts() {
        let full = App2PlanEndStrip(
            kind: .race, raceName: "Hofu", totalWeeks: 22, bars: [],
            plannedSessionCount: 128, completionRate: 91, peakWeekKm: 78
        )
        let line = App2PlanEndProjection.stripStatsLine(full)
        XCTAssertEqual(line?.components(separatedBy: " · ").count, 3)

        let partial = App2PlanEndStrip(
            kind: .race, raceName: "Hofu", totalWeeks: 22, bars: [],
            plannedSessionCount: nil, completionRate: nil, peakWeekKm: 78
        )
        XCTAssertEqual(
            App2PlanEndProjection.stripStatsLine(partial)?.components(separatedBy: " · ").count,
            1
        )

        let empty = App2PlanEndStrip(
            kind: .maintenance, raceName: nil, totalWeeks: nil, bars: [],
            plannedSessionCount: nil, completionRate: nil, peakWeekKm: nil
        )
        XCTAssertNil(App2PlanEndProjection.stripStatsLine(empty))
    }

    /// 課表 tab 的卡與整期總結頁取的是**同一份投影的子集** ——
    /// 兩個畫面上的完成率／峰值不可能長得不一樣。
    func test_strip_isASubsetOfTheSameSummary() {
        let summary = App2PlanEndProjection.summary(
            card: card(),
            weeklySeries: [bar("2026-08-03", 30), bar("2026-08-10", 78)],
            weeklySummaries: [weeklySummary(week: 1, percentage: 91, planned: 128, completed: 116)],
            workouts: [],
            vdots: []
        )
        XCTAssertEqual(summary.strip.completionRate, summary.completionRate)
        XCTAssertEqual(summary.strip.peakWeekKm, summary.peakWeekKm)
        XCTAssertEqual(summary.strip.plannedSessionCount, summary.plannedSessionCount)
        XCTAssertEqual(summary.strip.bars, summary.bars)
        XCTAssertEqual(summary.strip.kind, summary.kind)
    }

    // MARK: - 5. 峰值高亮（整期總結頁的柱狀圖）

    /// 高亮的是**峰值週**，不是「本週」。兩週同量時只亮第一根 ——
    /// 亮兩根會讓「峰值」讀起來像兩個值。
    func test_highlightPeak_marksTheFirstPeakBarOnly() {
        let bars = App2MetricDetailProjection.bars([
            bar("2026-08-03", 30), bar("2026-08-10", 78), bar("2026-08-17", 78)
        ])
        let marked = App2PeriodSummaryView.highlightPeak(bars, peakKm: 78)
        XCTAssertEqual(marked.map(\.isCurrentWeek), [false, true, false])

        // 峰值算不出來 → 一根都不亮（不隨便亮最後一根）。
        XCTAssertEqual(
            App2PeriodSummaryView.highlightPeak(bars, peakKm: nil).map(\.isCurrentWeek),
            [false, false, false]
        )
    }
}
