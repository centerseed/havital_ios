import SwiftUI
import UIKit
import XCTest
@testable import paceriz_dev

/// 2.0 設定頁的「聯絡 Paceriz／社群」列（T-0432）。
///
/// 這一組鎖的是一個真缺陷：2.0 設定頁一路到發表前都沒有任何回饋或社群入口，
/// 1.4 的入口（`FeedbackReportView` 裡的 Threads／Facebook）還在，但 2.0 走不到。
/// 判準兩條 —— **列的 a11y id 還在**（走查與 Maestro 都靠它找列），
/// **點下去的目的地仍是 1.4 那一頁**（不得有人另做第二份社群入口）。
///
/// 三語覆蓋不在這裡重寫一份：`L10n.Feedback.settingsEntry` 是 `L10n` 常數，
/// `LocalizationCoverageTests` 已經對每個 `L10n` 常數掃三語存在且非空。
final class App2SettingsSupportEntryTests: XCTestCase {

    func test_supportEntry_identifierIsTheOneWalkthroughsLookFor() {
        XCTAssertEqual(App2SettingsSupportEntry.identifier, "App2_SettingsFeedbackEntry")
    }

    /// 目的地是 1.4 既有的回饋畫面，不是 2.0 自己的新頁。
    func test_supportEntry_destinationIsTheExistingFeedbackReport() {
        XCTAssertEqual(App2SettingsSupportEntry.destination, .feedbackReport)
    }

    /// 標題走既有的 `feedback.*` 命名空間，且當下語言拿得到真正的字（不是 key）。
    func test_supportEntry_titleUsesFeedbackKeyAndResolves() {
        XCTAssertEqual(App2SettingsSupportEntry.titleKey, "feedback.settings_entry")
        let rendered = App2SettingsSupportEntry.titleKey.localized
        XCTAssertFalse(rendered.isEmpty)
        XCTAssertNotEqual(rendered, App2SettingsSupportEntry.titleKey, "沒有翻譯，畫面會印出 key")
    }
}

// MARK: - 為什麼這裡沒有「把設定頁畫出來找 a11y id」那一條
//
// 試過了，量不到：`UIHostingController` ＋ 真 `UIWindow` ＋ layout ＋
// `accessibilityElementCount()`／`accessibilityElement(at:)` 逐層走，回來是**空集合**
// ——連設定頁本來就有的 `App2_SettingsLanguageRow`、`App2_SettingsClose` 都找不到。
// SwiftUI 的 a11y element 不在這條路上建，硬寫一條會是「量不到任何東西也綠」的假斷言。
//
// 這一列**掛在畫面上**的證據因此走實走：`.maestro/flows/t0432-settings-feedback-entry.yaml`
// 在真的模擬器上找 `App2_SettingsFeedbackEntry` 這一列、點下去、確認開的是 1.4 的
// 回饋畫面（Threads／Facebook）。修前那棵樹沒有這一列，那支 flow 會紅。
// 跑過的截圖在 `STATUS/evidence/T-0432/`。
