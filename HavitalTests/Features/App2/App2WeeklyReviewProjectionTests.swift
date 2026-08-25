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
        story: WeeklyStory? = nil
    ) -> WeeklySummaryV2 {
        WeeklySummaryV2(
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
        XCTAssertNil(projection.storyHeadline)
        XCTAssertEqual(projection.storyBody, "全達成")
    }

    func test_story_usesWeeklyStoryWhenPresent() {
        let projection = App2WeeklyReviewProjection.make(
            summary(story: WeeklyStory(text: "本文", thread: "大標", callback: nil))
        )
        XCTAssertEqual(projection.storyHeadline, "大標")
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
}
