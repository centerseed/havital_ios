import XCTest
@testable import paceriz_dev

/// 2.0 週回顧的投影（設計 frame-18／19）。
///
/// 鎖住的三件事：
/// 1. **建議項的 index 是身分** —— 它就是送回 `applied_indices` 的值。重排或過濾就是
///    採納到別項；那是會改到使用者下週課表的錯。
/// 2. 設計稿有、payload 沒有的欄位不出現（總時間／總爬升／近 6 週里程）。
/// 3. 「這一週還沒有回顧」（404／產生視窗未開）不是錯誤狀態。
final class App2WeeklyReviewProjectionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AppLanguagePin.traditionalChinese()
    }

    // MARK: - Helpers

    private func adjustment(
        _ content: String,
        apply: Bool = true,
        priority: String = "medium"
    ) -> AdjustmentItemV2 {
        AdjustmentItemV2(
            content: content,
            category: "volume",
            apply: apply,
            slotType: nil,
            trainingType: nil,
            reason: "reason-\(content)",
            impact: "impact-\(content)",
            sourceFlag: nil,
            priority: priority
        )
    }

    private func summary(
        week: Int = 5,
        completion: TrainingCompletionV2? = nil,
        highlights: WeeklyHighlightsV2? = nil,
        observations: [String]? = nil,
        planContext: PlanContextSummary? = nil,
        items: [AdjustmentItemV2] = [],
        story: WeeklyStory? = nil,
        decisionChain: DecisionChainWeeklySummary? = nil
    ) -> WeeklySummaryV2 {
        var result = WeeklySummaryV2(
            id: "summary-1",
            uid: "user-1",
            weeklyPlanId: "plan-1",
            trainingOverviewId: "overview-1",
            weekOfTraining: week,
            createdAt: nil,
            planContext: planContext,
            trainingCompletion: completion ?? TrainingCompletionV2(
                percentage: 100,
                plannedKm: 48,
                completedKm: 52.3,
                plannedSessions: 5,
                completedSessions: 5,
                evaluation: "全達成"
            ),
            trainingAnalysis: TrainingAnalysisV2(
                heartRate: nil,
                pace: nil,
                distance: nil,
                intensityDistribution: nil
            ),
            readinessSummary: nil,
            capabilityProgression: nil,
            milestoneProgress: nil,
            historicalComparison: nil,
            weeklyHighlights: highlights ?? WeeklyHighlightsV2(
                highlights: [],
                achievements: [],
                areasForImprovement: []
            ),
            upcomingRaceEvaluation: nil,
            nextWeekAdjustments: NextWeekAdjustmentsV2(
                items: items,
                summary: "把里程再往上帶一點",
                methodologyConstraintsConsidered: true,
                basedOnFlags: [],
                userNlEdit: nil,
                userNlEditStatus: .none,
                userNlEditFailReason: nil
            ),
            restWeekRecommendation: nil,
            finalTrainingReview: nil,
            promptAuditId: nil,
            observations: observations,
            weeklyStory: story
        )
        result.decisionChain = decisionChain
        return result
    }

    func test_decisionChain_projection_keeps_weeklyStory_and_exposes_four_blocks() {
        let chain = DecisionChainWeeklySummary(
            focus: DecisionChainFocus(
                kind: "adjudication",
                metric: "capability_baseline",
                direction: "improving",
                startDay: "2026-09-06",
                endDay: "2026-09-20",
                hypothesisId: "hyp.state.capability_baseline@2026-09-06",
                intervention: "維持每週 25.5 公里訓練量",
                verdict: "supported",
                reason: nil
            ),
            narrative: DecisionChainNarrative(
                headline: "能力基線正在變好",
                retrospect: "這週的觀察支持能力基線往上。",
                nextWeek: "下週維持目前方向。"
            ),
            execution: DecisionChainExecution(
                completedKm: 40.3,
                plannedKm: 41.5,
                runCount: 6,
                qualityCount: 1
            )
        )

        let projection = App2WeeklyReviewProjection.make(
            summary(
                story: WeeklyStory(text: "舊版故事仍在", thread: "thread", callback: nil),
                decisionChain: chain
            )
        )

        XCTAssertEqual(projection.storyBody, "舊版故事仍在")
        XCTAssertEqual(projection.decisionChain?.focus?.metric, "capability_baseline")
        XCTAssertEqual(projection.decisionChain?.narrative?.headline, "能力基線正在變好")
        XCTAssertEqual(projection.decisionChain?.execution?.qualityCount, 1)
    }

    func test_decisionChain_series_points_use_display_value_not_decision_index() {
        let response = AthleteStateSeriesResponse(
            startDay: "2026-08-01",
            endDay: "2026-09-20",
            series: [
                "capability_baseline": [
                    AthleteStateSeriesResponse.Day(
                        day: "2026-09-06",
                        itemId: "r1",
                        asOf: "2026-09-06",
                        estimatorVersion: "v1",
                        displayValue: 38.4,
                        deliveryStatus: "delivered",
                        envelope: AthleteStateMetricEnvelope(
                            index: 0.42,
                            levelIndex: nil,
                            channels: nil,
                            center: .init(value: 38.4, unit: "VDOT"),
                            band: nil
                        )
                    )
                ]
            ]
        )

        let points = App2WeeklyReviewProjection.decisionChainPoints(
            metric: "capability_baseline",
            response: response
        )

        XCTAssertEqual(points.map(\.value), [38.4])
        XCTAssertEqual(points.first?.unit, "VDOT")
        XCTAssertEqual(
            App2WeeklyReviewProjection.decisionChainDisplayUnit("index_points"),
            "點"
        )
        XCTAssertEqual(
            App2WeeklyReviewProjection.decisionChainDisplayUnit("z_score"),
            "標準差"
        )
        XCTAssertEqual(
            App2WeeklyReviewProjection.decisionChainDisplayUnit("burden"),
            "負荷"
        )
        XCTAssertNil(App2WeeklyReviewProjection.decisionChainDisplayUnit("unknown_unit"))
        XCTAssertEqual(App2WeeklyReviewProjection.decisionChainDisplayUnit("vdot"), "VDOT")
    }

    func test_openHypothesis_afterValue_uses_exact_reviewDay_andNotLaterPoint() {
        let points = [
            App2DecisionChainPoint(day: "2026-09-20", value: 38.4),
            App2DecisionChainPoint(day: "2026-09-25", value: 42.1)
        ]

        XCTAssertEqual(
            App2WeeklyReviewProjection.decisionChainValue(on: "2026-09-20", points: points),
            38.4
        )
        XCTAssertNil(
            App2WeeklyReviewProjection.decisionChainValue(on: "2026-09-21", points: points)
        )
    }

    func test_decisionChain_reviewDay_usesRoundLocalAsOf_acrossTaipeiUtcBoundary() {
        let chain = DecisionChainWeeklySummary(
            asOf: "2026-09-21",
            focus: DecisionChainFocus(
                kind: "open_hypothesis",
                metric: "capability_baseline",
                direction: "improving",
                startDay: "2026-09-06",
                endDay: "2026-09-28",
                hypothesisId: "h1",
                intervention: nil,
                verdict: nil,
                reason: nil
            ),
            narrative: nil,
            execution: nil
        )
        var fixture = summary(decisionChain: chain)
        fixture.localWeekEndExclusive = "2026-09-21T00:00:00Z"
        fixture.inputAsOf = "2026-09-20T16:30:00Z"

        let projection = App2WeeklyReviewProjection.make(fixture)

        XCTAssertEqual(projection.reviewDay, "2026-09-21")
    }

    func test_decisionChain_reviewDay_usesOlderRoundAsOf_notRereadGenerationDay() {
        let chain = DecisionChainWeeklySummary(
            asOf: "2026-09-20",
            focus: DecisionChainFocus(
                kind: "metric",
                metric: "capability_baseline",
                direction: "improving",
                startDay: "2026-08-23",
                endDay: "2026-09-20",
                hypothesisId: nil,
                intervention: nil,
                verdict: nil,
                reason: nil
            ),
            narrative: nil,
            execution: nil
        )
        var fixture = summary(decisionChain: chain)
        fixture.localWeekEndExclusive = "2026-09-21T00:00:00Z"
        fixture.inputAsOf = "2026-09-22T00:00:00Z"

        let projection = App2WeeklyReviewProjection.make(fixture)

        XCTAssertEqual(projection.reviewDay, "2026-09-20")
    }

    func test_decisionChain_display_helpers_translate_reasons_and_format_dates() {
        for reason in [
            "confounded", "not_prescribed", "not_executed", "declined_by_user",
            "insufficient_signal", "not_discriminating"
        ] {
            XCTAssertNotEqual(
                App2WeeklyReviewView.localizedDecisionReason(reason), reason
            )
        }
        XCTAssertFalse(
            App2WeeklyReviewView.decisionWaitUntilRowText("2026-10-04").contains("%@")
        )
        XCTAssertTrue(
            App2WeeklyReviewView.decisionWaitUntilRowText("2026-10-04").contains("2026-10-04")
        )
    }

    func test_decisionChain_reason_copy_includes_next_step_and_confounded_interference() {
        let expectedFragments: [String: [String]] = [
            "confounded": ["干擾", "延長觀察"],
            "not_prescribed": ["沒有排出預定的訓練刺激", "無法比較"],
            "not_executed": ["沒有完成", "不能判斷"],
            "declined_by_user": ["沒有被採用", "沒有足夠材料"],
            "insufficient_signal": ["資料還不夠多", "不能確定"],
            "not_discriminating": ["變化太小", "不能分辨"],
        ]

        for (reason, fragments) in expectedFragments {
            let copy = App2WeeklyReviewView.localizedDecisionReason(reason)
            for fragment in fragments {
                XCTAssertTrue(copy.contains(fragment), "\(reason) must include \(fragment): \(copy)")
            }
        }
        XCTAssertFalse(
            App2WeeklyReviewView.localizedDecisionReason("not_executed").contains("還要等的原因")
        )
        XCTAssertFalse(
            App2WeeklyReviewView.localizedDecisionReason("insufficient_signal").contains("補資料")
        )
        XCTAssertFalse(
            App2WeeklyReviewView.localizedDecisionReason("insufficient_signal").contains("修正觀察安排")
        )
        XCTAssertFalse(
            App2WeeklyReviewView.localizedDecisionReason("confounded").contains("檢討觀察條件")
        )
    }

    func test_metricFocus_marks_startAndReviewValues_onChart_withoutL2Card() {
        let focus = DecisionChainFocus(
            kind: "metric",
            metric: "capability_baseline",
            direction: "improving",
            startDay: "2026-09-06",
            endDay: "2026-09-20",
            hypothesisId: nil,
            intervention: nil,
            verdict: nil,
            reason: nil
        )
        let points = [
            App2DecisionChainPoint(day: "2026-09-06", value: 38.4),
            App2DecisionChainPoint(day: "2026-09-13", value: 39.1),
            App2DecisionChainPoint(day: "2026-09-20", value: 40.2),
        ]

        XCTAssertFalse(App2WeeklyReviewView.decisionChainShowsL2(for: focus))
        XCTAssertEqual(
            App2WeeklyReviewView.decisionChainAnchorDays(focus: focus, reviewDay: "2026-09-20"),
            Set(["2026-09-06", "2026-09-20"])
        )
        XCTAssertEqual(
            App2WeeklyReviewView.decisionChainGraphValuePoints(
                focus: focus,
                reviewDay: "2026-09-20",
                points: points
            ).map { App2WeeklyReviewView.decisionChainGraphValueLabel($0.value) },
            ["38.4", "40.2"]
        )
    }

    func test_openHypothesis_chartLeavesReviewDayToEndDay_asBlankDateSpan() {
        let focus = DecisionChainFocus(
            kind: "open_hypothesis",
            metric: "capability_baseline",
            direction: "improving",
            startDay: "2026-09-06",
            endDay: "2026-09-28",
            hypothesisId: "h1",
            intervention: nil,
            verdict: nil,
            reason: nil
        )

        XCTAssertEqual(
            App2WeeklyReviewView.decisionChainChartEndDay(focus: focus, reviewDay: "2026-09-20"),
            "2026-09-28"
        )
        XCTAssertEqual(
            App2WeeklyReviewView.decisionChainChartPoints(
                focus: focus,
                reviewDay: "2026-09-20",
                points: [
                    App2DecisionChainPoint(day: "2026-09-20", value: 38.4),
                    App2DecisionChainPoint(day: "2026-09-25", value: 42.1),
                ]
            ).map(\.day),
            ["2026-09-20"]
        )
        let reviewFraction = App2WeeklyReviewView.decisionChainChartXFraction(
            day: "2026-09-20",
            seriesStartDay: "2026-08-01",
            focus: focus,
            reviewDay: "2026-09-20"
        )
        XCTAssertNotNil(reviewFraction)
        XCTAssertLessThan(reviewFraction ?? 1, 1)
        XCTAssertEqual(
            App2WeeklyReviewView.decisionChainChartXFraction(
                day: "2026-09-28",
                seriesStartDay: "2026-08-01",
                focus: focus,
                reviewDay: "2026-09-20"
            ),
            1
        )
    }

    func test_chartStartDay_usesFixedEightWeekWindow_notFirstMeasuredPoint() {
        let focus = DecisionChainFocus(
            kind: "metric",
            metric: "capability_baseline",
            direction: "improving",
            startDay: "2026-09-06",
            endDay: "2026-09-20",
            hypothesisId: nil,
            intervention: nil,
            verdict: nil,
            reason: nil
        )
        XCTAssertEqual(
            App2WeeklyReviewView.decisionChainChartStartDay(
                focus: focus,
                reviewDay: "2026-09-20"
            ),
            "2026-07-26"
        )
    }

    func test_chartCoordinate_keepsSingleDateMeasurementVisible() {
        let focus = DecisionChainFocus(
            kind: "adjudication",
            metric: "capability_baseline",
            direction: "improving",
            startDay: "2026-09-20",
            endDay: "2026-09-20",
            hypothesisId: nil,
            intervention: nil,
            verdict: "supported",
            reason: nil
        )

        XCTAssertEqual(
            App2WeeklyReviewView.decisionChainChartXFraction(
                day: "2026-09-20",
                seriesStartDay: "2026-09-20",
                focus: focus,
                reviewDay: "2026-09-20"
            ),
            0.5
        )
    }

    func test_adjudication_chartDropsPointsAfterJudgementDay() {
        let focus = DecisionChainFocus(
            kind: "adjudication",
            metric: "capability_baseline",
            direction: "improving",
            startDay: "2026-09-06",
            endDay: "2026-09-20",
            hypothesisId: nil,
            intervention: nil,
            verdict: "supported",
            reason: nil
        )

        XCTAssertEqual(
            App2WeeklyReviewView.decisionChainChartPoints(
                focus: focus,
                reviewDay: "2026-09-20",
                points: [
                    App2DecisionChainPoint(day: "2026-09-20", value: 40.1),
                    App2DecisionChainPoint(day: "2026-09-27", value: 42.0),
                ]
            ).map(\.day),
            ["2026-09-20"]
        )
    }

    func test_unknownMetricLabel_usesLocalizedGenericName_withoutRawKey() {
        let label = App2WeeklyReviewView.localizedMetricLabel("hr_drift")

        XCTAssertEqual(label, "這個指標")
        XCTAssertNotEqual(label, "hr_drift")
    }

    func test_decisionChain_seriesWindow_anchorsEightWeekHistoryOnReviewDayForOpenHypothesis() {
        let window = App2WeeklyReviewViewModel.decisionChainSeriesWindow(
            focus: DecisionChainFocus(
                kind: "open_hypothesis",
                metric: "capability_baseline",
                direction: "improving",
                startDay: "2026-09-06",
                endDay: "2026-10-04",
                hypothesisId: "h1",
                intervention: nil,
                verdict: nil,
                reason: nil
            ),
            reviewDay: "2026-09-20"
        )

        XCTAssertEqual(window?.startDay, "2026-07-26")
        XCTAssertEqual(window?.endDay, "2026-10-04")
    }

    // MARK: - 建議項：index 即身分

    /// **不要重排、不要過濾。** index 就是 `applied_indices` 送出去的值。
    func test_suggestions_indexIsTheOriginalOffset() {
        let projection = App2WeeklyReviewProjection.make(
            summary(items: [adjustment("A"), adjustment("B"), adjustment("C")])
        )
        XCTAssertEqual(projection.suggestions.map(\.index), [0, 1, 2])
        XCTAssertEqual(projection.suggestions.map(\.content), ["A", "B", "C"])
    }

    /// 後端說「這項預設不採納」時，畫面上的預設就是不採納 —— 不強制全勾。
    func test_suggestions_carriesBackendDefaultApply() {
        let projection = App2WeeklyReviewProjection.make(
            summary(items: [adjustment("A", apply: true), adjustment("B", apply: false)])
        )
        XCTAssertEqual(projection.suggestions.map(\.defaultApply), [true, false])
    }

    func test_suggestions_emptyWhenNoAdjustments() {
        XCTAssertTrue(App2WeeklyReviewProjection.make(summary()).suggestions.isEmpty)
    }

    // MARK: - 本週成績

    /// 設計有四格（總距離／總時間／跑次／總爬升），payload 只給得出距離、跑次與
    /// 完成率 —— 少的兩格不出現，不用 `--` 補。
    func test_stats_onlyWhatThePayloadActuallyHas() {
        let projection = App2WeeklyReviewProjection.make(summary())
        XCTAssertEqual(projection.stats.map(\.key), ["distance", "sessions", "completion"])
        XCTAssertFalse(projection.stats.contains { $0.key == "duration" })
        XCTAssertFalse(projection.stats.contains { $0.key == "elevation" })
    }

    func test_stats_distanceUsesCompletedNotPlanned() {
        let stats = App2WeeklyReviewProjection.stats(
            TrainingCompletionV2(
                percentage: 100,
                plannedKm: 48,
                completedKm: 52.3,
                plannedSessions: 5,
                completedSessions: 5,
                evaluation: ""
            )
        )
        let distance = stats.first { $0.key == "distance" }
        XCTAssertEqual(distance?.value, "52.3")
        XCTAssertEqual(distance?.unit, "km")
    }

    /// 沒有計畫量時不顯示「計畫 0.0 km」—— 那會被讀成「這週本來就沒安排」。
    func test_stats_omitsPlannedFootnoteWhenNoPlannedVolume() {
        let stats = App2WeeklyReviewProjection.stats(
            TrainingCompletionV2(
                percentage: 0,
                plannedKm: 0,
                completedKm: 12,
                plannedSessions: 0,
                completedSessions: 2,
                evaluation: ""
            )
        )
        XCTAssertNil(stats.first { $0.key == "distance" }?.footnote)
        XCTAssertNil(stats.first { $0.key == "sessions" }?.footnote)
    }

    // MARK: - 敘事與亮點

    /// `weekly_story` 缺席時退成完成度評語 —— 那也是後端寫的句子，不是 client 拼的。
    func test_story_fallsBackToCompletionEvaluation() {
        let projection = App2WeeklyReviewProjection.make(summary())
        XCTAssertEqual(projection.storyBody, "全達成")
    }

    /// `thread` 是機器分類 key（dev 實測值 `campaign`），不得上畫面。
    func test_story_usesWeeklyStoryWhenPresent() {
        let projection = App2WeeklyReviewProjection.make(
            summary(story: WeeklyStory(text: "本文", thread: "campaign", callback: nil))
        )
        XCTAssertEqual(projection.storyBody, "本文")
    }

    /// 空字串在畫面上是一個佔位的空洞，不是資料。
    func test_highlights_dropsBlankEntries() {
        let projection = App2WeeklyReviewProjection.make(
            summary(
                highlights: WeeklyHighlightsV2(
                    highlights: ["新 PB 10K", "   "],
                    achievements: ["最長跑 22 km"],
                    areasForImprovement: ["不該出現在亮點"]
                )
            )
        )
        XCTAssertEqual(projection.highlights, ["新 PB 10K", "最長跑 22 km"])
    }

    func test_observations_dropsBlankEntries() {
        let projection = App2WeeklyReviewProjection.make(
            summary(observations: ["Z2 佔比 68%", ""])
        )
        XCTAssertEqual(projection.observations, ["Z2 佔比 68%"])
    }

    // MARK: - 期別

    func test_phaseLabel_combinesPhaseAndWeek() {
        XCTAssertEqual(
            App2WeeklyReviewProjection.phaseLabel(
                PlanContextSummary(
                    targetType: "race_run",
                    methodologyId: "paceriz",
                    methodologyName: "Paceriz",
                    currentPhase: "強化期",
                    phaseWeek: 1,
                    phaseTotalWeeks: 6,
                    totalWeeks: 22,
                    weeksRemaining: 17,
                    currentStageDescription: "",
                    upcomingMilestone: nil
                )
            ),
            "強化期 W1"
        )
    }

    func test_phaseLabel_nilWhenNoPlanContext() {
        XCTAssertNil(App2WeeklyReviewProjection.phaseLabel(nil))
    }

    /// 回歸（2026-08-28 走查 D22）：後端有時給的是**識別字**（dev 實查 `base`），
    /// 直接印就變成「base W2」＝把識別字端到用戶面前。認得出來的走全 App 同一份
    /// 期別譯名（`training.stage.*`）。
    func test_phaseLabel_translatesRawStageId() {
        XCTAssertEqual(
            App2WeeklyReviewProjection.phaseLabel(planContext(currentPhase: "base", week: 2)),
            "\(L10n.Training.Stage.base.localized) W2"
        )
        XCTAssertEqual(
            App2WeeklyReviewProjection.phaseLabel(planContext(currentPhase: "BUILD", week: 1)),
            "\(L10n.Training.Stage.build.localized) W1",
            "大小寫不影響對照"
        )
    }

    /// 認不出來的是後端的自由文字，原樣留著 —— 不得一律翻成「訓練中」。
    func test_phaseLabel_keepsUnknownPhaseTextAsIs() {
        XCTAssertEqual(
            App2WeeklyReviewProjection.phaseLabel(planContext(currentPhase: "賽前調整", week: 3)),
            "賽前調整 W3"
        )
    }

    private func planContext(currentPhase: String, week: Int) -> PlanContextSummary {
        PlanContextSummary(
            targetType: "race_run",
            methodologyId: "paceriz",
            methodologyName: "Paceriz",
            currentPhase: currentPhase,
            phaseWeek: week,
            phaseTotalWeeks: 6,
            totalWeeks: 22,
            weeksRemaining: 17,
            currentStageDescription: "",
            upcomingMilestone: nil
        )
    }

    // MARK: - 「還沒產生」不是錯誤

    /// 後端對還沒產生的週回 404，對「還不到能產生的時候」回 400 + 穩定的 code。
    /// 兩個都是正常狀態，畫面該顯示「產生回顧」而不是紅字。
    func test_meansNotGeneratedYet_recognisesNotFoundAndClosedWindow() {
        XCTAssertTrue(
            App2WeeklyReviewViewModel.meansNotGeneratedYet(.notFound("Weekly summary not found"))
        )
        XCTAssertTrue(
            App2WeeklyReviewViewModel.meansNotGeneratedYet(
                .badRequest(#"{"code":"weekly_summary_generation_window_denied"}"#)
            )
        )
    }

    /// 真的壞掉時不要偽裝成「還沒產生」—— 那會讓使用者一直按產生鈕。
    func test_meansNotGeneratedYet_realFailuresStayFailures() {
        XCTAssertFalse(App2WeeklyReviewViewModel.meansNotGeneratedYet(.serverError(500, "boom")))
        XCTAssertFalse(App2WeeklyReviewViewModel.meansNotGeneratedYet(.noConnection))
        XCTAssertFalse(App2WeeklyReviewViewModel.meansNotGeneratedYet(.badRequest("something else")))
    }

    // MARK: - 歷史週唯讀（裁決（q）；外審第七輪 A06／B02）

    /// 唯讀回看不得有任何寫入出口。F15 討論區的送出會打
    /// `RizoRepository.streamChat`（`weekly_situation`），所以歷史週整區不畫。
    func test_showsDiscussSection_historicalWeekIsReadOnly() {
        XCTAssertFalse(
            App2WeeklyReviewView.showsDiscussSection(isReadOnly: true),
            "歷史週是唯讀回看，不得留著會送出的 F15 討論區"
        )
        XCTAssertTrue(
            App2WeeklyReviewView.showsDiscussSection(isReadOnly: false),
            "現行週仍要能說出自己的狀況（F15 本來要補的就是這個）"
        )
    }

    /// 光有判準不夠——畫面要真的用它。
    ///
    /// F15 這一區當初就是**無條件**被加進 `planTab` 的，其他寫入出口（產生／套用／採納）
    /// 各自擋了 `isReadOnly`，只有它漏掉。判準對但沒接上去，使用者一樣送得出去，
    /// 所以這裡直接盯著呼叫點。
    func test_planTab_appliesReadOnlyGateToDiscussSection() throws {
        let source = try Self.weeklyReviewViewSource()

        XCTAssertTrue(
            source.contains("if Self.showsDiscussSection(isReadOnly: isReadOnly) {"),
            "`planTab` 必須經過唯讀判準才畫 F15 討論區"
        )
        XCTAssertFalse(
            source.contains("\n        discussSection\n    }"),
            "`discussSection` 不得再被無條件加進 `planTab`"
        )
    }

    /// **哪一個入口才是「歷史週」**——唯讀只屬於訓練計劃頁的歷史瀏覽那一個。
    ///
    /// 外審第八輪要求首頁（`App2HomeView`）與「先完成上週回顧」CTA（`App2PlanView`）也傳
    /// `isReadOnly: true`。**那會弄壞已裁決的行為**，所以沒有照做，理由釘在這裡：
    ///
    /// - 首頁那個入口拿的是**上週那一份還在生效的回顧**（週日則是本週）。它的
    ///   `onApplied` 就是把建議套用到接下來的課表、然後刷新首頁——套用是預期行為，
    ///   設成唯讀等於把它拔掉。
    /// - `App2PlanView` 的「先完成上週回顧才產本週課表」CTA 是**使用者必須完成**的那一份
    ///   （裁決（k）：`next_action == create_summary` 時先導週回顧）。設成唯讀就永遠完成不了，
    ///   課表也就永遠產不出來。
    /// - 真正的歷史回看只有訓練計劃頁的歷史模式，它**本來就**傳了 `isHistoryMode`。
    func test_planView_passesReadOnlyOnlyForHistoryBrowsing() throws {
        let planSource = try Self.source(at: "Havital/Features/App2/Presentation/Views/App2PlanView.swift")

        XCTAssertTrue(
            planSource.contains("if viewModel.showsHeaderWeeklyReview, let week = viewModel.selectedWeekOfPlan"),
            "header 週回顧鈕只在歷史週出現（裁決（q）2026-09-01：當週不畫）"
        )
        XCTAssertTrue(
            planSource.contains("isReadOnly: true"),
            "歷史週入口必須唯讀，直接顯示已存 V2，不生成"
        )
        XCTAssertTrue(
            planSource.contains("startsOnPlanTab: startsOnPlanTab"),
            "未產生態主鈕開的是要完成的那一份（非唯讀），且分頁由 VM 的去處決定（T-0405）"
        )
        XCTAssertFalse(
            planSource.contains("isReadOnly: true, startsOnPlanTab"),
            "唯讀回看不得帶著規劃分頁一起開"
        )
    }

    // MARK: - 課表頁不得自己產生課表（T-0405，2026-09-03 使用者裁決）

    /// 裁決：課表頁那顆鈕改成**進入**該週的「規劃下週」分頁（run → 清單 → 產生），
    /// 不再直接產生。產生的唯一出口是週回顧頁的
    /// `App2WeeklyReviewViewModel.applyAndGenerate()`——留第二條就是把使用者送回
    /// 那條看不到 L0 調整的路（鐵則 0）。
    func test_planPage_hasNoDirectWeeklyPlanGeneration() throws {
        let planSource = try Self.source(at: "Havital/Features/App2/Presentation/Views/App2PlanView.swift")
        let planViewModelSource = try Self.source(
            at: "Havital/Features/App2/Presentation/ViewModels/App2PlanViewModel.swift"
        )

        for (name, source) in [("App2PlanView", planSource), ("App2PlanViewModel", planViewModelSource)] {
            XCTAssertFalse(
                source.contains("generateWeeklyPlan"),
                "\(name) 不得有直接產生課表的路徑（T-0405）"
            )
            XCTAssertFalse(
                source.contains("generateCurrentWeekPlan"),
                "\(name) 的產生入口已刪除，殘留即第二條路徑"
            )
        }
    }

    /// 開頁停在哪個分頁由呼叫端帶（T-0405）：課表頁的未產生態主鈕帶 `true`，
    /// 直接落在規劃分頁；第 1 週沒有回顧時也直接落在規劃分頁。
    func test_weeklyReviewView_startsOnPlanTabWhenAsked() throws {
        let source = try Self.weeklyReviewViewSource()

        XCTAssertTrue(
            source.contains("_tab = State(initialValue: startsOnPlanTab || weekOfPlan == 0 ? .plan : .review)"),
            "開頁分頁的初值要由 `startsOnPlanTab` 決定"
        )
        XCTAssertTrue(
            source.contains("guard Self.showsReviewTab(weekOfPlan: weekOfPlan) else { return .plan }") &&
            source.contains("return showsPlanTab ? tab : .review"),
            "規劃分頁被收掉時初值不得把畫面帶進不存在的分頁"
        )
    }

    // MARK: - 產完課表要把人送到課表分頁的那一週（AC-TRAIN-HUB-19，2026-09-20 使用者裁決）

    /// 產生成功之後這一頁只負責說出「產了第幾週」，去哪裡由殼層決定。
    /// 修前這裡只有 `onApplied?()` + `onClose()`，沒有人決定退回去之後要看哪一週。
    func test_weeklyReviewView_reportsTheGeneratedWeekOnSuccess() throws {
        let source = try Self.weeklyReviewViewSource()

        XCTAssertTrue(
            source.contains("var onPlanGenerated: ((Int) -> Void)?"),
            "產生成功要帶著週次交出去，這一頁不自己決定導航"
        )
        XCTAssertTrue(
            source.contains("onPlanGenerated?(week)"),
            "`applyAndGenerate()` 成功分支要發出那一週"
        )
    }

    /// 殼層是唯一寫得到分頁選取的地方：產完切到課表分頁，並讓它停在那一週。
    func test_rootView_landsOnThePlanTabForTheGeneratedWeek() throws {
        let rootSource = try Self.source(at: "Havital/Features/App2/Presentation/App2RootView.swift")

        XCTAssertTrue(
            rootSource.contains("selection = .plan"),
            "產完要切到課表分頁（修前 `selection` 沒有任何外部寫入口）"
        )
        XCTAssertTrue(
            rootSource.contains("planViewModel.showGeneratedWeek(week)"),
            "切過去之後要停在剛產生的那一週，不是停在本週"
        )
    }

    /// 課表頁自己的那個入口（未產生態主鈕）走同一條，不另寫一套。
    func test_planView_alsoLandsOnTheGeneratedWeek() throws {
        let planSource = try Self.source(at: "Havital/Features/App2/Presentation/Views/App2PlanView.swift")

        XCTAssertTrue(
            planSource.contains("viewModel.showGeneratedWeek(week)"),
            "從課表頁產生的一樣要落在那一週（週日開的是下一週）"
        )
    }

    /// 規劃分頁與主 CTA 不得整個掛在 `projection` 上（T-0405 外審 E03）：
    /// 第 1 週的使用者被送進第 0 週的回顧，那一週永遠沒有 `projection`。
    func test_weeklyReviewView_planSurfacesDoNotRequireAReview() throws {
        let source = try Self.weeklyReviewViewSource()

        XCTAssertTrue(
            source.contains(
                "if activeTab == .plan, viewModel.projection != nil || showsPlanTabWithoutReview {"
            ),
            "主 CTA 的閘門要放行「沒有回顧但產得出來」那一格"
        )
        XCTAssertTrue(
            source.contains("} else if activeTab == .plan, showsPlanTabWithoutReview {"),
            "內容區同樣要放行——只留 CTA 而不畫分頁等於一顆孤兒按鈕"
        )
    }

    // MARK: - 歷史週不得出現「規劃下週」（T-0372，2026-09-01 使用者裁決）

    /// 使用者原話：「我看歷史的週回顧為什麼還會有下週規劃，到底在搞什麼東西啊」
    /// ——裁決：「不該啊」。三個表面都要跟著同一個判準收掉：分頁切換器、
    /// 回顧分頁底部的「繼續 → 規劃第 N 週」，以及規劃分頁的主 CTA。
    func test_weeklyReviewView_gatesEveryPlanSurfaceBehindShowsPlanTab() throws {
        let source = try Self.weeklyReviewViewSource()

        XCTAssertTrue(
            source.contains(
                "if showsPlanTab && Self.showsReviewTab(weekOfPlan: weekOfPlan) {\n                segmentedTabs"
            ),
            "只剩回顧一個分頁時，分頁切換器整組不得出現"
        )
        XCTAssertTrue(
            source.contains("if showsPlanTab {\n            continueToPlanButton"),
            "「繼續 → 規劃第 N 週」唯一的作用是切到規劃分頁，那一頁收掉它就要跟著收"
        )
        XCTAssertTrue(
            source.contains("if activeTab == .plan, viewModel.projection != nil"),
            "主 CTA 要看 `activeTab`——`tab` 的殘值不得把畫面帶進一個不存在的分頁"
        )
        XCTAssertTrue(
            source.contains("switch activeTab {"),
            "內容區同上"
        )
    }

    /// 首頁那支「本週回顧存在嗎」的探測必須唯讀（T-0372 C）。
    ///
    /// `getWeeklySummary` 在 404 時 fallback 到 `POST`
    /// （`TrainingPlanV2RepositoryImpl.fetchOrGenerateWeeklySummary`），所以
    /// **計畫最後一週的週日**（`next_week_info` 是 null 且
    /// `next_action != create_summary`，兩個 early return 都接不住）光是打開首頁
    /// 就會靜默生成一份本週回顧。
    func test_homeViewModel_probesCurrentWeekReviewReadOnly() throws {
        let source = try Self.source(
            at: "Havital/Features/App2/Presentation/ViewModels/App2HomeViewModel.swift"
        )

        XCTAssertTrue(
            source.contains(
                "planRepository.fetchWeeklySummary(weekOfPlan: planStatus.currentWeek)?.id"
            ),
            "首頁的週回顧探測必須走唯讀路徑"
        )
        XCTAssertFalse(
            source.contains("planRepository.getWeeklySummary("),
            "首頁不得再走會在 404 時 POST 的那一支"
        )
    }

    /// 從測試檔位置往上找 repo 根，不寫死絕對路徑（worktree 每次不同）。
    private static func weeklyReviewViewSource() throws -> String {
        try source(at: "Havital/Features/App2/Presentation/Views/App2WeeklyReviewView.swift")
    }

    private static func source(at relative: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // App2
            .deletingLastPathComponent()   // Features
            .deletingLastPathComponent()   // HavitalTests
        for _ in 0..<4 {
            let candidate = dir.appendingPathComponent(relative)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
            dir = dir.deletingLastPathComponent()
        }
        throw XCTSkip("找不到 \(relative)，跳過源碼層斷言")
    }
}
