import XCTest
@testable import paceriz_dev

/// 2.0 設定頁的「聯絡 Paceriz／社群」列（T-0432、AC-SETTINGS-09）。
///
/// 修前缺陷：2.0 設定頁一路到發表前都沒有任何回饋或社群入口，1.4 的入口
/// （`FeedbackReportView` 裡的 Threads／Facebook）還在，但 2.0 走不到。
///
/// **判準是「那一列還掛在畫面上」**，不是「有一組常數」。所以這裡讀
/// `App2SettingsView.swift` 的原始碼斷言接線——本 repo 既有的畫面層 AC 就是這樣鎖的
/// （`MessageCenterViewExpansionTests`、`SpecCompliance/*ACTests`）。
/// 把那一列從 view 刪掉、常數留著，下面每一條都會紅。
final class App2SettingsSupportEntryTests: XCTestCase {

    private let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // App2
        .deletingLastPathComponent()   // Features
        .deletingLastPathComponent()   // HavitalTests
        .deletingLastPathComponent()   // <repo root>

    private func settingsViewSource() throws -> String {
        try String(
            contentsOf: projectRoot.appendingPathComponent(
                "Havital/Features/App2/Presentation/Views/App2SettingsView.swift"
            ),
            encoding: .utf8
        )
    }

    /// 系統段真的掛了這一列，而且掛的是走查與 Maestro 找的那個 id。
    func test_settingsViewMountsTheFeedbackRowInTheSystemSection() throws {
        let source = try settingsViewSource()

        let systemSection = try XCTUnwrap(
            source.range(of: "private var systemSection: some View {").map {
                String(source[$0.lowerBound...])
            },
            "找不到系統段"
        )
        // 只看到下一段（帳戶段）為止——列掛在別段不算數。
        let sectionBody = systemSection.components(
            separatedBy: "private var accountSection: some View {"
        ).first ?? systemSection

        XCTAssertTrue(
            sectionBody.contains(
                ".accessibilityIdentifier(App2SettingsSupportEntry.identifier)"
            ),
            "系統段沒有掛聯絡／社群那一列的 a11y id"
        )
        XCTAssertTrue(
            sectionBody.contains("title: App2SettingsSupportEntry.titleKey.localized"),
            "那一列的標題沒有走 App2SettingsSupportEntry.titleKey"
        )
        XCTAssertTrue(
            sectionBody.contains("systemImage: App2SettingsSupportEntry.systemImage"),
            "那一列沒有用宣告的圖示"
        )
    }

    /// 點下去開的是 1.4 既有的回饋畫面，不是 2.0 自己新做的一頁。
    func test_theRowOpensTheExistingFeedbackReportView() throws {
        let source = try settingsViewSource()

        XCTAssertTrue(
            source.contains(".onTapGesture { isPresentingFeedback = true }"),
            "那一列點下去沒有觸發回饋畫面"
        )
        XCTAssertTrue(
            source.contains(".sheet(isPresented: $isPresentingFeedback) {")
                && source.contains("FeedbackReportView(userEmail:"),
            "回饋畫面不是 1.4 既有的 FeedbackReportView"
        )
        // 不得在 2.0 自己重寫一份社群連結——那兩條只住在 FeedbackReportView 裡。
        XCTAssertFalse(source.contains("threads.com"), "2.0 設定頁不得自己放 Threads 連結")
        XCTAssertFalse(source.contains("facebook.com"), "2.0 設定頁不得自己放 Facebook 連結")
    }

    /// 標題走既有的 `feedback.*` 命名空間，且當下語言拿得到真正的字（不是 key）。
    /// 三語覆蓋由 `LocalizationCoverageTests` 對每個 `L10n` 常數掃，不在這裡重寫一份。
    func test_supportEntryTitleUsesFeedbackKeyAndResolves() {
        XCTAssertEqual(App2SettingsSupportEntry.identifier, "App2_SettingsFeedbackEntry")
        XCTAssertEqual(App2SettingsSupportEntry.titleKey, "feedback.settings_entry")

        let rendered = App2SettingsSupportEntry.titleKey.localized
        XCTAssertFalse(rendered.isEmpty)
        XCTAssertNotEqual(rendered, App2SettingsSupportEntry.titleKey, "沒有翻譯，畫面會印出 key")
    }
}
