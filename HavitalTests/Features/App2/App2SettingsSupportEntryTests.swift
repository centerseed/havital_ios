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
