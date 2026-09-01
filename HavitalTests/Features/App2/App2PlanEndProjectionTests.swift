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
        planId: String? = nil,
        startDate: String? = nil
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
            metadata: startDate.map {
                PlanStatusV2Metadata(
                    trainingStartDate: $0,
                    currentWeekStartDate: nil,
                    currentWeekEndDate: nil,
                    userTimezone: "Asia/Tokyo",
                    serverTime: nil
                )
            }
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
        // 平日無回顧時，產生 CTA 只在後端擋課表（`create_summary`）時出現
        // （2026-08-28 裁決）；`view_plan` 平日無回顧＝整張卡收掉。
        let blocked = planStatus(nextAction: "create_summary", currentWeek: 5, totalWeeks: 22)
        XCTAssertNil(App2PlanEndProjection.card(
            planStatus: blocked, overview: nil, target: target(), estimatedFinish: nil
        ))
        XCTAssertNotNil(App2HomeViewModel.weekReviewState(
            planStatus: blocked, isSunday: false, summaryId: nil
        ))
        let running = planStatus(nextAction: "view_plan", currentWeek: 5, totalWeeks: 22)
        XCTAssertNil(App2HomeViewModel.weekReviewState(
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

    // MARK: - 6. 歷史課表回看（2026-08-27 裁決（b）（e））

    /// 唯讀的判準是**「這份計畫結束了沒」**，不是「現在畫的是不是結束卡」。
    ///
    /// 這一條是裁決（b）的本體：按下「瀏覽這期的歷史課表」之後結束卡讓位給週課表，
    /// 若判準看的是結束卡，鉛筆就會跟著回來，而那些週是已完結的課表。
    func test_allowsEditing_isFalseForTheWholePlanEndState_historyModeIncluded() {
        XCTAssertTrue(App2PlanEndProjection.allowsEditing(planEnd: nil))
        // 結束卡在畫時唯讀。
        XCTAssertFalse(App2PlanEndProjection.allowsEditing(planEnd: card()))
        // 歷史模式時結束卡不畫，但 `planEnd` 還在 —— 判準不變，仍然唯讀。
        XCTAssertFalse(App2PlanEndProjection.allowsEditing(planEnd: card(kind: .maintenance)))
    }

    /// 回看區間 ＝ `1…total_weeks`。週數缺席／非正 → nil：那時整條入口不該出現，
    /// 而不是給一個猜的上限讓使用者一路撞 404。
    func test_historyWeekRange_isOneThroughTotalWeeks() {
        XCTAssertEqual(App2PlanEndProjection.historyWeekRange(totalWeeks: 22), 1...22)
        XCTAssertNil(App2PlanEndProjection.historyWeekRange(totalWeeks: nil))
        XCTAssertNil(App2PlanEndProjection.historyWeekRange(totalWeeks: 0))
        XCTAssertNil(App2PlanEndProjection.historyWeekRange(totalWeeks: -3))
    }

    func test_clampHistoryWeek_staysInsideTheRange() {
        XCTAssertEqual(App2PlanEndProjection.clampHistoryWeek(0, totalWeeks: 17), 1)
        XCTAssertEqual(App2PlanEndProjection.clampHistoryWeek(9, totalWeeks: 17), 9)
        XCTAssertEqual(App2PlanEndProjection.clampHistoryWeek(99, totalWeeks: 17), 17)
        XCTAssertNil(App2PlanEndProjection.clampHistoryWeek(3, totalWeeks: nil))
    }

    /// 歷史週的日卡日期要按**那一週**標。權威是 `training_start_date`。
    func test_historyWeekStart_anchorsOnTrainingStartDate() {
        let status = planStatus(currentWeek: 18, totalWeeks: 17, startDate: "2026-01-05")
        let calendar = Calendar(identifier: .gregorian)
        let week1 = App2PlanEndProjection.historyWeekStart(
            week: 1, planStatus: status, calendar: calendar
        )
        let week3 = App2PlanEndProjection.historyWeekStart(
            week: 3, planStatus: status, calendar: calendar
        )
        // 2026-01-05 是週一 → 第 1 週就是它，第 3 週是 +14 天。
        XCTAssertEqual(calendar.dateComponents([.month, .day], from: week1).day, 5)
        XCTAssertEqual(calendar.dateComponents([.month, .day], from: week3).day, 19)
        XCTAssertEqual(
            week3.timeIntervalSince(week1), 14 * 24 * 3600, accuracy: 3600
        )
    }

    /// `training_start_date` 缺席 → 退「本週週一往回推 `current_week − N` 週」。
    /// 那是近似，但形狀一樣（一個週一），下游不必分辨。
    func test_historyWeekStart_fallsBackToCurrentWeekOffset() {
        let status = planStatus(currentWeek: 18, totalWeeks: 17)
        let calendar = Calendar(identifier: .gregorian)
        let reference = Date(timeIntervalSince1970: 1_787_000_000)
        let thisMonday = App2WeekCalendar.currentWeekStart(reference: reference, calendar: calendar)
        let week17 = App2PlanEndProjection.historyWeekStart(
            week: 17, planStatus: status, reference: reference, calendar: calendar
        )
        // current_week 18、看第 17 週 → 往回一週。
        XCTAssertEqual(thisMonday.timeIntervalSince(week17), 7 * 24 * 3600, accuracy: 3600)
    }
}

// MARK: - App2PlanViewModel 的歷史回看
/// 課表 tab 的歷史模式（裁決（e））—— **走既有的
/// `getWeeklyPlan(weekOfTraining:overviewId:)`**，唯讀，且 404 是空態不是錯誤。
@MainActor
final class App2PlanHistoryModeTests: XCTestCase {

    private func planStatus(
        currentWeek: Int = 18,
        totalWeeks: Int = 17,
        nextAction: String = "training_completed"
    ) -> PlanStatusV2Response {
        PlanStatusV2Response(
            currentWeek: currentWeek,
            totalWeeks: totalWeeks,
            nextAction: nextAction,
            canGenerateNextWeek: false,
            currentWeekPlanId: nil,
            previousWeekSummaryId: nil,
            targetType: "maintenance",
            methodologyId: "paceriz",
            nextWeekInfo: nil,
            metadata: nil
        )
    }

    private func overview(id: String = "overview-1") -> PlanOverviewV2 {
        PlanOverviewV2(
            id: id, targetId: nil, targetType: "maintenance", targetDescription: nil,
            methodologyId: "paceriz", totalWeeks: 17, startFromStage: "base",
            raceDate: nil, distanceKm: nil, distanceKmDisplay: nil, distanceUnit: nil,
            targetPace: nil, targetTime: nil, isMainRace: nil, targetName: nil,
            methodologyOverview: nil, targetEvaluate: nil, approachSummary: nil,
            trainingStages: [], milestones: [], createdAt: Date(),
            methodologyVersion: nil, milestoneBasis: nil
        )
    }

    private func weeklyPlan(week: Int) -> WeeklyPlanV2 {
        WeeklyPlanV2(
            planId: "overview-1_\(week)", weekOfTraining: week, id: "overview-1_\(week)",
            purpose: "history", weekOfPlan: week, totalWeeks: 17, totalDistance: 42,
            totalDistanceDisplay: nil, totalDistanceUnit: nil, totalDistanceReason: nil,
            designReason: nil, mileageProgressionNote: nil, coachNote: nil, days: [],
            intensityTotalMinutes: nil, currentVdot: nil, vdotSource: nil,
            createdAt: Date(), updatedAt: Date(), trainingLoadAnalysis: nil,
            personalizedRecommendations: nil, realTimeAdjustments: nil, apiVersion: "2.0"
        )
    }

    private func makeViewModel(
        plan: WeeklyPlanV2?,
        status: PlanStatusV2Response? = nil
    ) -> (App2PlanViewModel, MockTrainingPlanV2Repository) {
        let (viewModel, repository, _) = makeViewModelWithWorkouts(plan: plan, status: status)
        return (viewModel, repository)
    }

    /// 切週的成本在 workout 補史那一段（T-0374），所以要拿得到那個 mock。
    private func makeViewModelWithWorkouts(
        plan: WeeklyPlanV2?,
        status: PlanStatusV2Response? = nil
    ) -> (App2PlanViewModel, MockTrainingPlanV2Repository, MockWorkoutRepository) {
        let repository = MockTrainingPlanV2Repository()
        repository.planStatusToReturn = status ?? planStatus()
        repository.overviewToReturn = overview()
        repository.weeklyPlanV2ToReturn = plan
        let workouts = MockWorkoutRepository()
        let viewModel = App2PlanViewModel(
            planRepository: repository,
            workoutRepository: workouts,
            targetRepository: nil
        )
        return (viewModel, repository, workouts)
    }

    private static func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    /// 結束態預設不在歷史模式；進去之後從**最後一週**開始，且結束卡讓位給週課表。
    func test_enterHistoryMode_startsAtTheLastWeekAndYieldsTheEndCard() async {
        let (viewModel, repository) = makeViewModel(plan: weeklyPlan(week: 17))
        await viewModel.revalidate()

        XCTAssertNotNil(viewModel.planEnd)
        XCTAssertTrue(viewModel.showsPlanEnd)
        XCTAssertFalse(viewModel.isHistoryMode)

        await viewModel.enterHistoryMode()

        XCTAssertEqual(viewModel.historyWeek, 17)
        XCTAssertTrue(viewModel.isHistoryMode)
        XCTAssertFalse(viewModel.showsPlanEnd)          // 結束卡讓位
        XCTAssertNotNil(viewModel.planEnd)              // 但結束態本身還在
        XCTAssertEqual(repository.lastRequestedWeeklyPlanWeekOfTraining, 17)
        XCTAssertNotNil(viewModel.week)
    }

    /// **唯讀**（裁決（b））：歷史模式下結束卡不畫，但 `allowsEditing` 仍為 false ——
    /// 鉛筆不會跟著週次切換器一起回來。
    func test_historyMode_isReadOnly() async {
        let (viewModel, _) = makeViewModel(plan: weeklyPlan(week: 17))
        await viewModel.revalidate()
        XCTAssertFalse(viewModel.allowsEditing)

        await viewModel.enterHistoryMode()
        XCTAssertFalse(viewModel.allowsEditing)

        await viewModel.goToHistoryWeek(offset: -1)
        XCTAssertEqual(viewModel.historyWeek, 16)
        XCTAssertFalse(viewModel.allowsEditing)
    }

    /// 週次切換夾在 `1…total_weeks`：第 1 週不能再往前，最後一週不能再往後。
    func test_historyWeekStepping_isClampedToThePlanLength() async {
        let (viewModel, _) = makeViewModel(plan: weeklyPlan(week: 1))
        await viewModel.revalidate()
        await viewModel.enterHistoryMode()

        XCTAssertFalse(viewModel.canGoNextHistoryWeek)   // 已在最後一週
        XCTAssertTrue(viewModel.canGoPreviousHistoryWeek)

        for _ in 0..<20 { await viewModel.goToHistoryWeek(offset: -1) }
        XCTAssertEqual(viewModel.historyWeek, 1)
        XCTAssertFalse(viewModel.canGoPreviousHistoryWeek)
    }

    /// **404 ＝ 該週從沒生成過課表，不是錯誤**：那一週顯示空態，模式與週次都留著，
    /// 而且**不退樣本**（拿一份假課表頂上去比空著更糟）。
    func test_historyWeek404_showsAnEmptyWeekWithoutFallingBackToStubs() async {
        let (viewModel, repository) = makeViewModel(plan: weeklyPlan(week: 17))
        await viewModel.revalidate()
        await viewModel.enterHistoryMode()
        XCTAssertNotNil(viewModel.week)

        // 第 16 週後端沒有 → `getWeeklyPlan` 丟 `weeklyPlanNotFound`。
        repository.weeklyPlanV2ToReturn = nil
        await viewModel.goToHistoryWeek(offset: -1)

        XCTAssertEqual(viewModel.historyWeek, 16)
        XCTAssertTrue(viewModel.isHistoryMode)
        XCTAssertTrue(viewModel.isHistoryWeekMissing)
        XCTAssertNil(viewModel.week)                     // 空態，沒有樣本課表
        XCTAssertTrue(viewModel.dayDetails.isEmpty)
        XCTAssertFalse(viewModel.allowsEditing)          // 空態也唯讀

        // 有課表的那一週回得去，空態不會卡住整個模式。
        repository.weeklyPlanV2ToReturn = weeklyPlan(week: 17)
        await viewModel.goToHistoryWeek(offset: 1)
        XCTAssertFalse(viewModel.isHistoryWeekMissing)
        XCTAssertNotNil(viewModel.week)
    }

    /// 返程：回到計畫完成畫面 —— 結束卡回來，週課表收掉。
    func test_exitHistoryMode_returnsToTheCompletionScreen() async {
        let (viewModel, _) = makeViewModel(plan: weeklyPlan(week: 17))
        await viewModel.revalidate()
        await viewModel.enterHistoryMode()
        XCTAssertFalse(viewModel.showsPlanEnd)

        viewModel.exitHistoryMode()

        XCTAssertNil(viewModel.historyWeek)
        XCTAssertFalse(viewModel.isHistoryMode)
        XCTAssertTrue(viewModel.showsPlanEnd)
        XCTAssertNil(viewModel.week)
    }

    /// 2026-09-01：當週不畫 header 週回顧鈕；歷史週才畫。
    func test_headerWeeklyReview_hiddenOnCurrentWeekShownInHistory() async {
        let (ended, _) = makeViewModel(plan: weeklyPlan(week: 17))
        await ended.revalidate()
        XCTAssertFalse(ended.showsHeaderWeeklyReview, "結束卡當週不畫週回顧鈕")

        await ended.enterHistoryMode()
        XCTAssertTrue(ended.showsHeaderWeeklyReview, "結束後歷史回看要能看該週 V2 回顧")

        let (live, _) = makeViewModel(
            plan: weeklyPlan(week: 9),
            status: planStatus(currentWeek: 9, totalWeeks: 12, nextAction: "ready")
        )
        await live.revalidate()
        XCTAssertFalse(live.showsHeaderWeeklyReview, "進行中當週不畫週回顧鈕")

        await live.goToHistoryWeek(offset: -1)
        XCTAssertEqual(live.historyWeek, 8)
        XCTAssertTrue(live.showsHeaderWeeklyReview, "進行中往回翻才畫週回顧鈕")
    }

    // MARK: - 切週的成本（T-0374，2026-09-01 裁決）
    //
    // 使用者原話：「載入一張課表不應該這麼慢」。修前每切一次週就同步
    // `await ensureMonthLoaded` 一到兩個月，而近 45 天的月份無條件打一趟
    // `GET /v2/workouts?page_size=50`（`WorkoutRepositoryImpl:158-163`），
    // 而且沒有任何去重。這一段在 `week` 發布之前，所以按下箭頭就是在等網路。

    /// **切週不得等補史。** gate 讓補史在切週返回之後才完成 —— 修前補史在
    /// `applyHistory` 內被 `await`，這個旗標一定已經是 true。
    func test_switchingWeekPublishesBeforeTheBackfillFinishes() async {
        let (viewModel, _, workouts) = makeViewModelWithWorkouts(plan: weeklyPlan(week: 17))
        let probe = BackfillProbe()
        workouts.ensureMonthLoadedGate = {
            try? await Task.sleep(nanoseconds: 300_000_000)
            probe.finished = true
        }
        await viewModel.revalidate()

        await viewModel.enterHistoryMode()

        XCTAssertEqual(viewModel.historyWeek, 17)
        XCTAssertNotNil(viewModel.week, "切週當下就要有那一週的課表")
        XCTAssertFalse(probe.finished, "切週不得等 ensureMonthLoaded —— 那正是使用者感受到的 lag")

        await viewModel.waitForCompletedDistanceBackfillForTesting()
        XCTAssertTrue(probe.finished)
    }

    /// **同一個月在這個 session 裡只補一次。** 來回翻八次，零新增往返。
    func test_revisitedMonthsAreBackfilledOnlyOnce() async {
        let (viewModel, _, workouts) = makeViewModelWithWorkouts(plan: weeklyPlan(week: 17))
        await viewModel.revalidate()

        await viewModel.enterHistoryMode()                     // 第 17 週
        await viewModel.waitForCompletedDistanceBackfillForTesting()
        await viewModel.goToHistoryWeek(offset: -1)            // 第 16 週
        await viewModel.waitForCompletedDistanceBackfillForTesting()

        let baseline = workouts.ensureMonthLoadedCallCount
        XCTAssertGreaterThan(baseline, 0, "第一次看某一週仍然要補史")

        for _ in 0..<4 {
            await viewModel.goToHistoryWeek(offset: 1)
            await viewModel.waitForCompletedDistanceBackfillForTesting()
            await viewModel.goToHistoryWeek(offset: -1)
            await viewModel.waitForCompletedDistanceBackfillForTesting()
        }

        XCTAssertEqual(
            workouts.ensureMonthLoadedCallCount, baseline,
            "已經補過的月份不得每切一次週就重跑一次"
        )
    }

    /// 去重只擋「來回翻」那種零新增資訊的重跑：**下拉刷新／SWR 重驗仍然重新補史**。
    func test_revalidateDropsTheBackfilledMonths() async {
        let (viewModel, _, workouts) = makeViewModelWithWorkouts(plan: weeklyPlan(week: 17))
        await viewModel.revalidate()
        await viewModel.enterHistoryMode()
        await viewModel.waitForCompletedDistanceBackfillForTesting()
        let afterFirst = workouts.ensureMonthLoadedCallCount
        XCTAssertGreaterThan(afterFirst, 0)

        await viewModel.revalidate()                            // 歷史模式下重驗的是那一週
        await viewModel.waitForCompletedDistanceBackfillForTesting()

        XCTAssertGreaterThan(
            workouts.ensureMonthLoadedCallCount, afterFirst,
            "重驗必須重新補史，去重水位不得吃掉下拉刷新"
        )
    }

    /// **快取有那一週就立刻畫。** `getWeeklyPlan` 還在飛的時候，畫面上已經是目標週。
    func test_switchingToACachedWeekPaintsBeforeTheFetchReturns() async {
        let (viewModel, repository, _) = makeViewModelWithWorkouts(plan: weeklyPlan(week: 17))
        repository.cachedWeeklyPlansByWeek = [17: weeklyPlan(week: 17), 16: weeklyPlan(week: 16)]
        await viewModel.revalidate()
        await viewModel.enterHistoryMode()

        let probe = WeekSnapshotProbe()
        repository.onGetWeeklyPlan = { [weak viewModel] in
            await MainActor.run { probe.week = viewModel?.week?.value }
        }
        await viewModel.goToHistoryWeek(offset: -1)

        XCTAssertNotNil(probe.week, "快取命中時，抓取還沒回來就該有內容")
        XCTAssertEqual(
            probe.week?.weekLabel,
            String(format: L10n.WeekSelector.weekNumber.localized, 16),
            "預畫的必須是目標週，不是上一週"
        )
    }

    /// **沒有快取就清空，不得殘留上一週。** 修前 `loadHistoryWeek` 只設 `historyWeek`，
    /// 週次標跳到目標週、七張日卡還是上一週的內容（`App2PlanView.weekLabelText`
    /// 優先讀 `week`）。
    func test_switchingToAnUncachedWeekClearsThePreviousWeek() async {
        let (viewModel, repository, _) = makeViewModelWithWorkouts(plan: weeklyPlan(week: 17))
        repository.cachedWeeklyPlansByWeek = [17: weeklyPlan(week: 17)]   // 第 16 週沒有快取
        await viewModel.revalidate()
        await viewModel.enterHistoryMode()
        XCTAssertNotNil(viewModel.week)

        let probe = WeekSnapshotProbe()
        repository.onGetWeeklyPlan = { [weak viewModel] in
            await MainActor.run { probe.week = viewModel?.week?.value }
        }
        repository.weeklyPlanV2ToReturn = weeklyPlan(week: 16)
        await viewModel.goToHistoryWeek(offset: -1)

        XCTAssertTrue(probe.observed, "測試沒有觀察到抓取中的狀態")
        XCTAssertNil(probe.week, "抓取期間不得停在上一週的日卡上")
        XCTAssertEqual(viewModel.historyWeek, 16)
    }

    /// 新紀錄推播：去重水位作廢並重算目前這一週的已完成量。
    func test_workoutsChangedInvalidatesTheBackfillAndRecomputes() async {
        let (viewModel, _, workouts) = makeViewModelWithWorkouts(plan: weeklyPlan(week: 17))
        await viewModel.revalidate()
        await viewModel.enterHistoryMode()
        await viewModel.waitForCompletedDistanceBackfillForTesting()

        let backfillsBefore = workouts.ensureMonthLoadedCallCount
        let readsBefore = workouts.getWorkoutsInDateRangeCallCount

        CacheEventBus.shared.publish(.dataChanged(.workouts))

        await Self.waitUntil {
            workouts.ensureMonthLoadedCallCount > backfillsBefore
                && workouts.getWorkoutsInDateRangeCallCount > readsBefore
        }
        XCTAssertGreaterThan(workouts.ensureMonthLoadedCallCount, backfillsBefore)
        XCTAssertGreaterThan(workouts.getWorkoutsInDateRangeCallCount, readsBefore)
    }

    // MARK: - 整期預抓（T-0378，2026-09-01 裁決）
    //
    // 使用者原話：「切換週課表還是會有一到兩秒的lag」。T-0374 之後切週不再等
    // workout 補史，但**沒看過的那一週仍然要等 `GET /v2/plan/weekly/{overviewId}_{week}`**。
    // 進課表頁時在背景把整期填進 repository 快取，之後每一次切週都是快取命中。

    /// 冷啟一週快取都沒有時，進課表頁會把 `1…total_weeks` 全部填進快取。
    private func makeViewModelForPrefetch(
        totalWeeks: Int = 17,
        currentWeek: Int? = nil,
        notFoundWeeks: Set<Int> = []
    ) -> (App2PlanViewModel, MockTrainingPlanV2Repository) {
        let repository = MockTrainingPlanV2Repository()
        repository.planStatusToReturn = planStatus(currentWeek: currentWeek ?? totalWeeks + 1, totalWeeks: totalWeeks)
        repository.overviewToReturn = overview()
        repository.cachedWeeklyPlansByWeek = [:]              // 冷啟：一週都沒有
        repository.simulatesWriteThroughCache = true          // 抓回來就落快取（真 repo 的行為）
        repository.weeklyPlanNotFoundWeeks = notFoundWeeks
        repository.weeklyPlansByWeekToReturn = Dictionary(
            uniqueKeysWithValues: (1...totalWeeks).map { ($0, weeklyPlan(week: $0)) }
        )
        let viewModel = App2PlanViewModel(
            planRepository: repository,
            workoutRepository: MockWorkoutRepository(),
            targetRepository: nil
        )
        return (viewModel, repository)
    }

    /// **整期都預抓。** 進課表頁一次，`1…17` 全部進快取，每一週各一趟、不重複。
    func test_prefetchFillsEveryWeekOfThePlan() async {
        let (viewModel, repository) = makeViewModelForPrefetch()

        await viewModel.revalidate()
        await viewModel.waitForWeeklyPlanPrefetchForTesting()

        XCTAssertEqual(
            Set(repository.cachedWeeklyPlansByWeek?.keys.map { $0 } ?? []), Set(1...17),
            "整期每一週都要落進 repository 快取"
        )
        XCTAssertEqual(
            repository.requestedWeeklyPlanWeeks.sorted(), Array(1...17),
            "每一週各問一次，不重不漏"
        )
        XCTAssertEqual(
            repository.cachedWeeklyPlansByWeek?[9]?.weekOfTraining, 9,
            "第 9 週的快取要是第 9 週的課表"
        )
    }

    /// **未來週不抓。** V2 課表逐週生成，本週之後的週**根本還不存在**——抓了只會
    /// 產生一整排 404 並被 client 錯誤回報灌進 cloud logging
    /// （2026-09-01 使用者帳號被監控標成「反覆失敗」的那一波）。
    func test_prefetchStopsAtTheCurrentWeek() async {
        let (viewModel, repository) = makeViewModelForPrefetch(totalWeeks: 27, currentWeek: 10)

        await viewModel.revalidate()
        await viewModel.waitForWeeklyPlanPrefetchForTesting()

        XCTAssertEqual(
            repository.requestedWeeklyPlanWeeks.sorted(), Array(1...10),
            "只抓到本週——未來週的課表還不存在，抓了只會製造 404 錯誤回報"
        )
    }

    /// **預抓過的週切過去零網路等待。** `getWeeklyPlan` 掛住不返回的那一刻，
    /// 畫面已經是目標週 —— 那一週在這次 session 從來沒被看過。
    func test_prefetchedWeekPaintsWithoutWaitingForTheNetwork() async {
        let (viewModel, repository) = makeViewModelForPrefetch()
        await viewModel.revalidate()
        await viewModel.waitForWeeklyPlanPrefetchForTesting()

        await viewModel.enterHistoryMode()                     // 第 17 週
        XCTAssertEqual(viewModel.historyWeek, 17)

        // 第 16 週從沒被看過 —— 修前這裡要等一趟 GET 才會有內容。
        let probe = WeekSnapshotProbe()
        repository.onGetWeeklyPlan = { [weak viewModel] in
            await MainActor.run { probe.week = viewModel?.week?.value }
        }
        await viewModel.goToHistoryWeek(offset: -1)

        XCTAssertEqual(viewModel.historyWeek, 16)
        XCTAssertNotNil(probe.week, "預抓過的週，抓取還沒回來就該有內容")
        XCTAssertEqual(
            probe.week?.weekLabel,
            String(format: L10n.WeekSelector.weekNumber.localized, 16),
            "預畫的必須是目標週"
        )
    }

    /// **一個 session 只跑一次。** 下拉刷新／SWR 重驗不得把整期再抓一遍
    /// ——快取已經有了，那是純浪費。
    func test_prefetchRunsOnlyOncePerSession() async {
        let (viewModel, repository) = makeViewModelForPrefetch()
        await viewModel.revalidate()
        await viewModel.waitForWeeklyPlanPrefetchForTesting()
        let afterFirst = repository.getWeeklyPlanCallCount
        XCTAssertEqual(afterFirst, 17)

        await viewModel.revalidate()
        await viewModel.waitForWeeklyPlanPrefetchForTesting()
        await viewModel.revalidate()
        await viewModel.waitForWeeklyPlanPrefetchForTesting()

        XCTAssertEqual(
            repository.getWeeklyPlanCallCount, afterFirst,
            "整期預抓一個 session 只排一次"
        )
    }

    /// **404 容忍。** 某幾週從沒生成過課表不是錯誤，其餘的週照樣預抓完。
    func test_prefetchTolerates404AndKeepsGoing() async {
        let (viewModel, repository) = makeViewModelForPrefetch(notFoundWeeks: [4, 11])

        await viewModel.revalidate()
        await viewModel.waitForWeeklyPlanPrefetchForTesting()

        XCTAssertEqual(
            repository.requestedWeeklyPlanWeeks.sorted(), Array(1...17),
            "404 不得讓預抓停在那一週"
        )
        XCTAssertEqual(
            Set(repository.cachedWeeklyPlansByWeek?.keys.map { $0 } ?? []),
            Set(1...17).subtracting([4, 11])
        )
    }
}

/// 背景補史有沒有跑完（T-0374）。`@unchecked Sendable`：只在測試裡跨 actor 記一個旗標。
private final class BackfillProbe: @unchecked Sendable {
    var finished = false
}

/// `getWeeklyPlan` 還在飛的那一刻，畫面上是哪一週（T-0374）。
private final class WeekSnapshotProbe: @unchecked Sendable {
    var observed = false
    var week: App2PlanWeek? {
        didSet { observed = true }
    }
}

// MARK: - DEBUG fixture 的 N
#if DEBUG
/// 故事版 fixture 的 hero 句與章節標籤**吃同一個 N**（2026-08-27 補修）。
final class App2PlanEndStoryFixtureTests: XCTestCase {

    /// 稿面那份是 22 週的 1／9／18／22 —— N=22 時逐字相同。
    func test_chapterWeeks_matchesTheDesignAtTwentyTwo() {
        XCTAssertEqual(App2PlanEndStoryFixture.chapterWeeks(totalWeeks: 22), [1, 9, 18, 22])
    }

    /// N 變小時一起縮，且單調不遞減 —— 不會出現「第 3 週」排在「第 5 週」前面。
    func test_chapterWeeks_scaleDownAndStayMonotonic() {
        for weeks in 1...40 {
            let chapters = App2PlanEndStoryFixture.chapterWeeks(totalWeeks: weeks)
            XCTAssertEqual(chapters.count, 4)
            XCTAssertEqual(chapters.first, 1)
            XCTAssertEqual(chapters.last, max(weeks, 1))
            XCTAssertEqual(chapters, chapters.sorted(), "weeks=\(weeks)")
        }
    }

    /// hero 句的 N 就是章節最後一週的 N —— 先前 hero 寫死 22、同屏章節是 17。
    func test_make_heroLineAndChapterLabelsAgreeOnN() {
        let story = App2PlanEndStoryFixture.make(weeks: 17)
        XCTAssertTrue(story.heroLine.hasPrefix("17 週"), story.heroLine)
        XCTAssertEqual(story.chapters.last?.weekLabel, "第 17 週 · 賽事日")
        XCTAssertEqual(story.chapters.first?.weekLabel, "第 1 週 · 起點")
        XCTAssertFalse(story.chapters.contains { $0.weekLabel.contains("22") })
    }
}

// MARK: - 產生本週課表（2026-08-27 晚走查裁決（i））
/// 裁決前的死循環：首頁叫用戶「到課表頁產生」，課表頁的未產生態卻沒有任何入口。
@MainActor
final class App2PlanGenerateWeekTests: XCTestCase {

    private func planStatus(planId: String?, nextAction: String? = nil) -> PlanStatusV2Response {
        PlanStatusV2Response(
            currentWeek: 2,
            totalWeeks: 6,
            nextAction: nextAction ?? (planId == nil ? "create_plan" : "view_plan"),
            canGenerateNextWeek: true,
            currentWeekPlanId: planId,
            previousWeekSummaryId: nil,
            targetType: "race_run",
            methodologyId: "paceriz",
            nextWeekInfo: nil,
            metadata: nil
        )
    }

    private func weeklyPlan() -> WeeklyPlanV2 {
        WeeklyPlanV2(
            planId: "e1289e60f251_2", weekOfTraining: 2, id: "e1289e60f251_2",
            purpose: "base", weekOfPlan: 2, totalWeeks: 6, totalDistance: 30,
            totalDistanceDisplay: nil, totalDistanceUnit: nil, totalDistanceReason: nil,
            designReason: nil, mileageProgressionNote: nil, coachNote: nil, days: [],
            intensityTotalMinutes: nil, currentVdot: nil, vdotSource: nil,
            createdAt: Date(), updatedAt: Date(), trainingLoadAnalysis: nil,
            personalizedRecommendations: nil, realTimeAdjustments: nil, apiVersion: "2.0"
        )
    }

    private func makeViewModel(
        _ repository: MockTrainingPlanV2Repository
    ) -> App2PlanViewModel {
        App2PlanViewModel(
            planRepository: repository,
            workoutRepository: MockWorkoutRepository(),
            targetRepository: nil
        )
    }

    /// 未產生 → 按下去 → `isPlanGenerated` 翻真，且週次取自 plan status。
    func test_generateCurrentWeekPlan_flipsIsPlanGenerated() async {
        let repository = MockTrainingPlanV2Repository()
        repository.planStatusToReturn = planStatus(planId: nil)
        repository.weeklyPlanV2ToReturn = weeklyPlan()

        let viewModel = makeViewModel(repository)
        await viewModel.revalidate()
        XCTAssertFalse(viewModel.isPlanGenerated, "本週沒有課表 → 未產生態")

        // 產生成功之後後端就有本週課表了。
        repository.planStatusToReturn = planStatus(planId: "e1289e60f251_2")
        let ok = await viewModel.generateCurrentWeekPlan()

        XCTAssertTrue(ok)
        XCTAssertEqual(repository.generateWeeklyPlanCallCount, 1)
        XCTAssertTrue(viewModel.isPlanGenerated)
        XCTAssertFalse(viewModel.isGeneratingPlan)
        XCTAssertNil(viewModel.generateError)
        XCTAssertNotNil(viewModel.week)
    }

    /// 失敗可重試：狀態不變、錯誤訊息出得來、按鈕沒有被鎖住。
    func test_generateCurrentWeekPlan_failureKeepsEmptyStateAndReportsError() async {
        let repository = MockTrainingPlanV2Repository()
        repository.planStatusToReturn = planStatus(planId: nil)

        let viewModel = makeViewModel(repository)
        await viewModel.revalidate()

        repository.generateWeeklyPlanErrors = [TrainingPlanV2Error.unknown("boom")]
        let ok = await viewModel.generateCurrentWeekPlan()

        XCTAssertFalse(ok)
        XCTAssertFalse(viewModel.isPlanGenerated)
        XCTAssertFalse(viewModel.isGeneratingPlan, "失敗之後不得卡在 loading")
        XCTAssertNotNil(viewModel.generateError)
    }

    // MARK: - CTA 依 next_action 分流（2026-08-27 晚走查裁決（k））

    /// `create_summary`（上週回顧未生成，`service.py:1242`）→ CTA 語意換成週回顧，
    /// **且按下去不得呼叫 generate**（那條路在這個狀態下只會走進失敗重試）。
    func test_needsWeeklySummary_routesToReviewAndSkipsGenerate() async {
        let repository = MockTrainingPlanV2Repository()
        repository.planStatusToReturn = planStatus(planId: nil, nextAction: "create_summary")

        let viewModel = makeViewModel(repository)
        await viewModel.revalidate()

        XCTAssertFalse(viewModel.isPlanGenerated, "本週沒有課表 → 未產生態")
        XCTAssertTrue(viewModel.requiresWeeklyReviewBeforeGenerate, "CTA 要換成「先完成週回顧」")
        // 目標是上一週（current_week 2 → 第 1 週的回顧）。
        XCTAssertEqual(viewModel.weeklyReviewTargetWeek, 1)

        let ok = await viewModel.generateCurrentWeekPlan()
        XCTAssertFalse(ok)
        XCTAssertEqual(repository.generateWeeklyPlanCallCount, 0, "不得呼叫產生課表")
        XCTAssertNil(viewModel.generateError, "沒送出請求就不該有失敗訊息")
    }

    /// 其他未產生態（`create_plan`）維持原行為：CTA 是「產生本週課表」，按下去真的產。
    func test_createPlanAction_keepsGenerateCTA() async {
        let repository = MockTrainingPlanV2Repository()
        repository.planStatusToReturn = planStatus(planId: nil, nextAction: "create_plan")
        repository.weeklyPlanV2ToReturn = weeklyPlan()

        let viewModel = makeViewModel(repository)
        await viewModel.revalidate()

        XCTAssertFalse(viewModel.requiresWeeklyReviewBeforeGenerate)
        XCTAssertNil(viewModel.weeklyReviewTargetWeek)

        repository.planStatusToReturn = planStatus(planId: "e1289e60f251_2")
        let ok = await viewModel.generateCurrentWeekPlan()
        XCTAssertTrue(ok)
        XCTAssertEqual(repository.generateWeeklyPlanCallCount, 1)
    }
}

#endif
