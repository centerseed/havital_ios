import XCTest
@testable import paceriz_dev

/// 「規劃下週」的產生入口判準（P0：修復前這一頁根本沒有產生課表的出口，
/// 使用者走完週回顧就卡死）。
///
/// 這一組釘住的是 `App2WeeklyReviewViewModel.nextWeekAction` —— 什麼時候該出現
/// 「產生第 N 週課表」、什麼時候只能「套用」、什麼時候一個出口都不給。判準全部
/// 來自後端 `build_plan_status`（`domains/plan_week/service.py`）的既有欄位，
/// 這裡不重寫一份週次推算；與課表頁的 `App2PlanViewModel
/// .requiresWeeklyReviewBeforeGenerate` 讀的是同一組 `next_action` 事實。
final class App2WeeklyReviewNextWeekActionTests: XCTestCase {

    // MARK: - Helpers

    private func status(
        currentWeek: Int,
        totalWeeks: Int = 22,
        nextAction: String,
        currentWeekPlanId: String? = nil,
        nextWeekInfo: NextWeekInfoV2? = nil
    ) -> PlanStatusV2Response {
        PlanStatusV2Response(
            currentWeek: currentWeek,
            totalWeeks: totalWeeks,
            nextAction: nextAction,
            canGenerateNextWeek: nextWeekInfo != nil,
            currentWeekPlanId: currentWeekPlanId,
            previousWeekSummaryId: nil,
            targetType: "race",
            methodologyId: "paceriz",
            nextWeekInfo: nextWeekInfo,
            metadata: nil
        )
    }

    private func nextWeek(
        _ weekNumber: Int,
        hasPlan: Bool = false,
        requiresCurrentWeekSummary: Bool? = false
    ) -> NextWeekInfoV2 {
        NextWeekInfoV2(
            weekNumber: weekNumber,
            hasPlan: hasPlan,
            canGenerate: !hasPlan,
            requiresCurrentWeekSummary: requiresCurrentWeekSummary,
            nextAction: nil
        )
    }

    private func action(
        reviewWeek: Int,
        status: PlanStatusV2Response?,
        hasSuggestions: Bool = true,
        isReadOnly: Bool = false
    ) -> App2WeeklyReviewViewModel.NextWeekAction {
        App2WeeklyReviewViewModel.nextWeekAction(
            reviewWeek: reviewWeek,
            planStatus: status,
            hasSuggestions: hasSuggestions,
            isReadOnly: isReadOnly
        )
    }

    // MARK: - 週日流程：回顧本週 → 產生下週

    /// 週日流程是這次 P0 的主線：使用者回顧第 5 週，要能在同一頁產生第 6 週課表。
    /// 後端只在使用者時區的週日給 `next_week_info`，所以它在就代表視窗開著。
    func testSundayFlowGeneratesNextWeek() {
        let result = action(
            reviewWeek: 5,
            status: status(
                currentWeek: 5,
                nextAction: "view_plan",
                currentWeekPlanId: "ov_5",
                nextWeekInfo: nextWeek(6)
            )
        )
        XCTAssertEqual(result, .generate(week: 6))
    }

    /// 下週已經有課表了 —— `can_generate == false`。再產一次不是這顆鈕的語意，
    /// 這時只留「套用」。
    func testNextWeekAlreadyHasPlanFallsBackToApply() {
        let result = action(
            reviewWeek: 5,
            status: status(
                currentWeek: 5,
                nextAction: "view_plan",
                currentWeekPlanId: "ov_5",
                nextWeekInfo: nextWeek(6, hasPlan: true)
            )
        )
        XCTAssertEqual(result, .applyOnly)
    }

    /// 平日：後端不給 `next_week_info`（產生視窗未開）。**不得畫一顆按下去必然
    /// 失敗的產生鈕**（同走查裁決（k）的精神、AC-TRAIN-HUB-06）。
    func testGenerationWindowClosedFallsBackToApply() {
        let result = action(
            reviewWeek: 5,
            status: status(
                currentWeek: 5,
                nextAction: "view_plan",
                currentWeekPlanId: "ov_5",
                nextWeekInfo: nil
            )
        )
        XCTAssertEqual(result, .applyOnly)
    }

    // MARK: - 平日流程：回顧上週 → 產生本週

    /// 平日 CTA 開的是**上週**回顧（`current_week − 1`），所以它的「規劃下週」
    /// 分頁目標是**本週**。回顧補完後 `next_action` 從 `create_summary` 變
    /// `create_plan`，本週課表就該能在這一頁直接產出來。
    func testWeekdayFlowGeneratesCurrentWeek() {
        let result = action(
            reviewWeek: 4,
            status: status(currentWeek: 5, nextAction: "create_plan", currentWeekPlanId: nil)
        )
        XCTAssertEqual(result, .generate(week: 5))
    }

    /// 上週回顧仍缺（`create_summary`）時本週課表產不出來 —— 後端會擋。
    func testCurrentWeekBlockedByMissingSummaryFallsBackToApply() {
        let result = action(
            reviewWeek: 4,
            status: status(currentWeek: 5, nextAction: "create_summary", currentWeekPlanId: nil)
        )
        XCTAssertEqual(result, .applyOnly)
    }

    /// 本週已經有課表了。
    func testCurrentWeekAlreadyGeneratedFallsBackToApply() {
        let result = action(
            reviewWeek: 4,
            status: status(currentWeek: 5, nextAction: "view_plan", currentWeekPlanId: "ov_5")
        )
        XCTAssertEqual(result, .applyOnly)
    }

    /// 計畫已走完 —— 沒有下一週可產。
    func testTrainingCompletedFallsBackToApply() {
        let result = action(
            reviewWeek: 21,
            status: status(currentWeek: 22, nextAction: "training_completed", currentWeekPlanId: nil)
        )
        XCTAssertEqual(result, .applyOnly)
    }

    // MARK: - 沒有出口的情形

    /// 歷史週唯讀回看（走查裁決（q））：產生課表是寫入路徑，一個出口都不給。
    /// 連建議項都不能套用 —— 過去那一週的建議套到下週是錯的時間軸。
    func testReadOnlyHasNoAction() {
        XCTAssertEqual(
            action(
                reviewWeek: 5,
                status: status(
                    currentWeek: 5,
                    nextAction: "view_plan",
                    currentWeekPlanId: "ov_5",
                    nextWeekInfo: nextWeek(6)
                ),
                isReadOnly: true
            ),
            .none
        )
    }

    /// 不能產生、又沒有建議項 —— 整條 footer 不出現，不畫空按鈕。
    func testNoSuggestionsAndCannotGenerateHasNoAction() {
        XCTAssertEqual(
            action(
                reviewWeek: 5,
                status: status(
                    currentWeek: 5,
                    nextAction: "view_plan",
                    currentWeekPlanId: "ov_5",
                    nextWeekInfo: nil
                ),
                hasSuggestions: false
            ),
            .none
        )
    }

    /// **沒有建議項但可以產生 —— 還是要給產生鈕。** 修復前的 footer 被
    /// `!suggestions.isEmpty` 守著，後端沒給建議項時整頁零出口，這是本次 P0
    /// 的第二個致死點。
    func testNoSuggestionsStillGeneratesWhenWindowOpen() {
        let result = action(
            reviewWeek: 5,
            status: status(
                currentWeek: 5,
                nextAction: "view_plan",
                currentWeekPlanId: "ov_5",
                nextWeekInfo: nextWeek(6)
            ),
            hasSuggestions: false
        )
        XCTAssertEqual(result, .generate(week: 6))
    }

    /// plan status 還沒回來：不知道能不能產生，就不宣稱能產生。
    func testMissingPlanStatusFallsBackToApply() {
        XCTAssertEqual(action(reviewWeek: 5, status: nil), .applyOnly)
        XCTAssertEqual(action(reviewWeek: 5, status: nil, hasSuggestions: false), .none)
    }

    /// `next_week_info.week_number` 與這一頁的目標週對不上時不產生 —— 產錯週比
    /// 不產更糟。
    func testMismatchedNextWeekNumberFallsBackToApply() {
        let result = action(
            reviewWeek: 5,
            status: status(
                currentWeek: 5,
                nextAction: "view_plan",
                currentWeekPlanId: "ov_5",
                nextWeekInfo: nextWeek(9)
            )
        )
        XCTAssertEqual(result, .applyOnly)
    }

    // MARK: - 回顧產生視窗（T-0362）
    //
    // 這一組釘住的是**另一顆 CTA**：不是「產生下週課表」（上面那些），是空態上的
    // 「產生週回顧」。後端 `POST /v2/summary/weekly` 有週次窗口閘門
    // （`core/training_rules/plan_generation_window.py:37 allowed_week_for_kind`
    // ＋ `:58 decide_week_generation` 的週日 catch-up），下面每一格都對著它。

    private func windowOpen(
        reviewWeek: Int,
        currentWeek: Int,
        isSunday: Bool
    ) -> Bool {
        App2WeeklyReviewViewModel.isGenerationWindowOpen(
            reviewWeek: reviewWeek,
            planStatus: status(currentWeek: currentWeek, nextAction: "view_plan"),
            isSunday: isSunday
        )
    }

    /// **本次 P0 的形狀**：週一（平日）進本週回顧，後端只准產 `current_week − 1`
    /// ——那顆「產生」鈕按下去必然回 400 `weekly_summary_generation_window_denied`。
    func testWeekdayCannotGenerateCurrentWeekReview() {
        XCTAssertFalse(windowOpen(reviewWeek: 5, currentWeek: 5, isSunday: false))
    }

    /// 平日的正常路徑：回顧上週（`current_week − 1`）是後端唯一允許的週次。
    func testWeekdayCanGeneratePreviousWeekReview() {
        XCTAssertTrue(windowOpen(reviewWeek: 4, currentWeek: 5, isSunday: false))
    }

    /// 平日、第 1 週：後端算出的 `allowed_week` 是 0，等於沒有可產的週。
    func testWeekdayFirstWeekHasNoGeneratableReview() {
        XCTAssertFalse(windowOpen(reviewWeek: 1, currentWeek: 1, isSunday: false))
        XCTAssertFalse(windowOpen(reviewWeek: 0, currentWeek: 1, isSunday: false))
    }

    /// 週日：本週回顧就是這一天要做的事。
    func testSundayCanGenerateCurrentWeekReview() {
        XCTAssertTrue(windowOpen(reviewWeek: 5, currentWeek: 5, isSunday: true))
        XCTAssertTrue(windowOpen(reviewWeek: 1, currentWeek: 1, isSunday: true))
    }

    /// 週日的 catch-up：上週那份沒做的也還能補
    /// （後端 `allowed_sunday_previous_week_summary_catch_up`）。
    func testSundayCatchUpAllowsPreviousWeekReview() {
        XCTAssertTrue(windowOpen(reviewWeek: 4, currentWeek: 5, isSunday: true))
        // 週次 0 不是可補的週。
        XCTAssertFalse(windowOpen(reviewWeek: 0, currentWeek: 1, isSunday: true))
    }

    /// 更早的週（歷史）任何一天都不在視窗內。
    func testOlderWeeksAreNeverInsideTheWindow() {
        XCTAssertFalse(windowOpen(reviewWeek: 2, currentWeek: 5, isSunday: false))
        XCTAssertFalse(windowOpen(reviewWeek: 2, currentWeek: 5, isSunday: true))
    }

    /// **status 讀不到時 fail-open**：什麼都判不出來時擋掉按鈕＝把使用者鎖在一個
    /// 沒有出口的畫面（harness §1.2 鐵則 7）。真撞到 400 仍有既有那句話接住。
    func testMissingPlanStatusKeepsGenerateAvailable() {
        XCTAssertTrue(
            App2WeeklyReviewViewModel.isGenerationWindowOpen(
                reviewWeek: 5,
                planStatus: nil,
                isSunday: false
            )
        )
    }

    // MARK: - 「規劃下週」分頁在不在（T-0369，2026-09-01 使用者裁決）
    //
    // 使用者原話：「我看歷史的週回顧為什麼還會有下週規劃，到底在搞什麼東西啊」
    // ——裁決：「不該啊」。修復前 `App2WeeklyReviewView` 無條件畫兩個分頁，
    // 所以第 2 週的回顧上掛著一個「規劃第 3 週」，而使用者已經在第 10 週。

    private func showsPlanTab(
        reviewWeek: Int,
        currentWeek: Int?,
        isReadOnly: Bool = false
    ) -> Bool {
        App2WeeklyReviewView.showsPlanTab(
            reviewWeek: reviewWeek,
            planStatus: currentWeek.map { status(currentWeek: $0, nextAction: "view_plan") },
            isReadOnly: isReadOnly
        )
    }

    /// **本次缺陷的形狀**：歷史回看（課表頁 header 進來、`isReadOnly`）沒有規劃分頁。
    func testHistoryReviewHasNoPlanTab() {
        XCTAssertFalse(showsPlanTab(reviewWeek: 2, currentWeek: 10, isReadOnly: true))
        XCTAssertFalse(showsPlanTab(reviewWeek: 8, currentWeek: 10, isReadOnly: true))
        // 連「目標週剛好是本週」也不給——歷史回看是唯讀入口，沒有任何規劃出口。
        XCTAssertFalse(showsPlanTab(reviewWeek: 9, currentWeek: 10, isReadOnly: true))
    }

    /// 目標週已經過去（`reviewWeek + 1 < current_week`）＝那一頁規劃不了任何東西。
    func testPastTargetWeekHasNoPlanTab() {
        XCTAssertFalse(showsPlanTab(reviewWeek: 2, currentWeek: 10))
        XCTAssertFalse(showsPlanTab(reviewWeek: 8, currentWeek: 10))
    }

    /// **防退化**：平日流程回顧的是**上週**，它的規劃分頁目標是**本週**——
    /// 那正是 T-0341 補上的產生出口。判準若寫成「非本週即歷史」會把它一起收掉，
    /// 訓練流程重新斷在這一頁。
    func testWeekdayFlowKeepsPlanTabForCurrentWeek() {
        XCTAssertTrue(showsPlanTab(reviewWeek: 9, currentWeek: 10))
    }

    /// 週日流程：回顧本週、規劃下週。
    func testSundayFlowKeepsPlanTab() {
        XCTAssertTrue(showsPlanTab(reviewWeek: 10, currentWeek: 10))
    }

    /// `planStatus` 讀不到時 fail-open（harness §1.2 鐵則 7）：判不出週次就不收出口。
    func testMissingPlanStatusKeepsPlanTab() {
        XCTAssertTrue(showsPlanTab(reviewWeek: 3, currentWeek: nil))
    }
}
