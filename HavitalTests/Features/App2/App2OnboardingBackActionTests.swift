import XCTest
@testable import paceriz_dev

/// 「重新設定計畫」進來的 onboarding 必須有出口（T-0364）。
///
/// 2026-08-31 使用者實機回報：從訓練計劃按「重新設定計畫」之後，
/// **沒辦法上一頁回到訓練計劃、直接卡死**。成因是目標類型頁在 re-onboarding
/// 時是 `NavigationStack` 的根頁，返回鍵被寫死成 `nil`（→ disabled 的灰鈕），
/// 而整條流程開在 `fullScreenCover` ＋ `navigationBarHidden`，既沒有系統返回鍵
/// 也沒有邊緣滑回 —— 唯一的出口是把整條流程走完。
///
/// 「先查既有的」：這個 repo 對 onboarding 的返回／離開**沒有任何覆蓋**
/// （`App2OnboardingViewModel.pop()`、`App2OnboardingHeader.onBack`、
/// maestro `app2-onboarding.yaml` 都只走 happy path），所以這是新的一格，不是第二份。
@MainActor
final class App2OnboardingBackActionTests: XCTestCase {

    func test_reonboardingRoot_hasBackAction_thatLeavesTheFlow() {
        var cancelled = false
        var popped = false

        let action = App2OnboardingContainerView.goalTypeBackAction(
            isReonboarding: true,
            onCancel: { cancelled = true },
            pop: { popped = true }
        )

        XCTAssertNotNil(
            action,
            "re-onboarding 的目標類型頁是根頁，沒有這個動作使用者就出不去（用戶原話：直接卡死）"
        )
        action?()
        XCTAssertTrue(cancelled, "根頁的返回＝離開整條流程，回到進來的那一頁")
        XCTAssertFalse(popped, "根頁沒有上一頁可退，不得改成 pop")
    }

    func test_firstRunGoalType_stillPopsToWelcome() {
        var cancelled = false
        var popped = false

        let action = App2OnboardingContainerView.goalTypeBackAction(
            isReonboarding: false,
            onCancel: { cancelled = true },
            pop: { popped = true }
        )

        XCTAssertNotNil(action, "首次 onboarding 的目標類型頁是被推出來的，本來就有上一頁")
        action?()
        XCTAssertTrue(popped, "首次 onboarding 的返回＝退回開場頁")
        XCTAssertFalse(cancelled, "首次 onboarding 不得因為返回就關掉整條流程")
    }

    func test_reonboardingWithoutExit_keepsBackDisabled() {
        // 呼叫端沒給出口時維持原狀（disabled），不畫一顆按了沒反應的鈕。
        let action = App2OnboardingContainerView.goalTypeBackAction(
            isReonboarding: true,
            onCancel: nil,
            pop: { XCTFail("根頁不得 pop") }
        )

        XCTAssertNil(action)
    }
}
