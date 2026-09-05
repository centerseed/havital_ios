import XCTest
@testable import paceriz_dev

/// Garmin 缺歷史資料權限的 App 端判準（T-0438）。
///
/// 查過了，沒有既有測試涵蓋這條路徑：`GarminConnectionStatusResponse` 的解碼、以及
/// 「要不要提示」的判斷都沒有測（同檔的 `StravaConnectionStatusResponse` 也沒有）。
/// 寫法沿 `AchievementDTOTests` 的慣例：inline JSON、標準 `JSONDecoder`、單檔獨立。
///
/// 使用者 2026-09-05 的裁決只有一句：**提示不得誤報**。所以這一份的重心不是
/// 「該提示時有提示」，而是「不該提示的每一種都不提示」。
///
/// 後端的三個條件（權限 missing ＋ 連線 ≤7 天 ＋ 沒成功拿過歷史）由
/// `derive_history_prompt_eligible` 擁有並自己測；App 只認 `history_prompt_eligible`。
final class GarminHistoryPermissionTests: XCTestCase {

    private func decode(_ json: String) throws -> GarminConnectionStatusResponse {
        try JSONDecoder().decode(
            GarminConnectionStatusResponse.self,
            from: Data(json.utf8)
        )
    }

    private func payload(extra: String) -> String {
        """
        {
          "connected": true,
          "provider": "garmin",
          "status": "active",
          "connected_at": "2026-09-01T00:00:00+00:00",
          "last_updated": "2026-09-05T00:00:00+00:00",
          "message": "GARMIN 連接正常"\(extra)
        }
        """
    }

    // MARK: - 解碼

    func testDecodesTheThreeHistoryFields() throws {
        let response = try decode(payload(extra: """
        ,
          "historical_permission": "missing",
          "historical_permission_checked_at": "2026-09-05T04:15:59+00:00",
          "history_prompt_eligible": true
        """))

        XCTAssertEqual(response.historicalPermission, "missing")
        XCTAssertEqual(response.historicalPermissionCheckedAt, "2026-09-05T04:15:59+00:00")
        XCTAssertEqual(response.historyPromptEligible, true)
    }

    func testOlderBackendWithoutTheFieldsStillDecodes() throws {
        // 這三個欄位是 T-0438 才加的。舊版後端不回它們，解碼**不得失敗**——
        // 整個連線狀態畫面會跟著壞掉。
        let response = try decode(payload(extra: ""))

        XCTAssertNil(response.historicalPermission)
        XCTAssertNil(response.historyPromptEligible)
        XCTAssertTrue(response.connected)
    }

    // MARK: - hasHistoricalPermission（analytics 用的事實）

    func testHasPermissionOnlyWhenExplicitlyGranted() throws {
        XCTAssertTrue(try decode(payload(extra: """
        , "historical_permission": "granted"
        """)).hasHistoricalPermission)
    }

    func testUnknownIsNotTreatedAsHavingPermission() throws {
        // `unknown` ＝我們沒問到，不是「沒有權限」。
        for value in ["unknown", "missing"] {
            let response = try decode(payload(extra: """
            , "historical_permission": "\(value)"
            """))
            XCTAssertFalse(response.hasHistoricalPermission, value)
        }
        XCTAssertFalse(try decode(payload(extra: "")).hasHistoricalPermission)
    }

    // MARK: - shouldPromptForHistoryPermission（畫不畫那張卡）

    func testPromptsOnlyWhenBackendSaysEligible() throws {
        XCTAssertTrue(try decode(payload(extra: """
        , "history_prompt_eligible": true
        """)).shouldPromptForHistoryPermission)
    }

    func testDoesNotPromptWhenBackendSaysFalseOrOmitsIt() throws {
        XCTAssertFalse(try decode(payload(extra: """
        , "history_prompt_eligible": false
        """)).shouldPromptForHistoryPermission)
        XCTAssertFalse(try decode(payload(extra: "")).shouldPromptForHistoryPermission)
    }

    func testPermissionMissingAloneDoesNotPrompt() throws {
        // **這一條是這份測試的重點。** 權限 missing 只是三個條件之一；後端還要看連線
        // 是否 ≤7 天、以及有沒有成功拿過歷史。App 若自己從 `historical_permission` 推，
        // 就會對一個連線已經三個月的人跳提示。
        let response = try decode(payload(extra: """
        , "historical_permission": "missing", "history_prompt_eligible": false
        """))

        XCTAssertFalse(response.hasHistoricalPermission)
        XCTAssertFalse(response.shouldPromptForHistoryPermission)
    }
}


// MARK: - analytics 參數（T-0438）

final class GarminHistoryPermissionAnalyticsTests: XCTestCase {

    /// 事件只帶 `history_permission`；`has_history` 已於 T-0438 移除。
    func testGarminCompleteCarriesOnlyHistoryPermission() {
        let event = AnalyticsEvent.onboardingGarminComplete(historyPermission: "missing")

        XCTAssertEqual(event.name, "onboarding_garmin_complete")
        XCTAssertEqual(event.parameters["history_permission"] as? String, "missing")
        XCTAssertNil(
            event.parameters["has_history"],
            "has_history 從來沒被正確實作過（呼叫點寫死 true），2026-09-05 移除"
        )
    }

    func testHistoryPermissionCarriesAllThreeValues() {
        for value in ["granted", "missing", "unknown"] {
            let event = AnalyticsEvent.onboardingGarminComplete(historyPermission: value)
            XCTAssertEqual(event.parameters["history_permission"] as? String, value)
        }
    }
}


// MARK: - 兩個拓撲事實（T-0438 外審第二輪）

/// 這兩條讀原始碼文字，不跑 SwiftUI。
///
/// 它們釘的是「掛在哪一層」與「有沒有那道 guard」——兩個都不是行為分支，而是位置事實：
/// 提醒掛錯容器會落在 `-ui_testing_show_intro` 才走得到的死畫面（2026-09-05 就發生過），
/// 而 loader 少了取消 guard 會在被取消的那一輪把上一輪的 true 蓋掉。
/// 要用行為測試問同一件事，得先把整個 onboarding 容器與 `GarminConnectionStatusService.shared`
/// 的單例縫拆開，成本遠大於它擋住的那個回歸。
final class GarminHistoryPermissionWiringTests: XCTestCase {

    private func source(_ relativePath: String) throws -> String {
        // #file = <repo>/HavitalTests/Services/GarminHistoryPermissionTests.swift
        let root = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // Services
            .deletingLastPathComponent()   // HavitalTests
            .deletingLastPathComponent()   // repo root
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    func testHintLivesOnTheLiveApp2DeviceLinkPage() throws {
        let live = try source(
            "Havital/Features/App2/Presentation/Onboarding/App2OnboardingContainerView.swift"
        )
        XCTAssertTrue(
            live.contains("App2_OnboardingGarminHistoryHint"),
            "授權前提醒要掛在 2.0 的裝置頁——那是線上真正走到的 onboarding"
        )
        XCTAssertTrue(
            live.contains("garminHistoryHint"),
            "提醒用的是 onboarding.garmin_history_hint 這個 key"
        )
    }

    func testHintIsNotOnTheDormantOneXPage() throws {
        let dormant = try source("Havital/Views/Onboarding/DataSourceSelectionView.swift")
        XCTAssertFalse(
            dormant.contains("garminHistoryHint"),
            "1.x 的 DataSourceSelectionView 只有 -ui_testing_show_intro 走得到，掛在那等於沒做"
        )
    }

    func testHomeLoaderKeepsCancellationAndStaleGuards() throws {
        let vm = try source(
            "Havital/Features/App2/Presentation/ViewModels/App2HomeViewModel.swift"
        )
        let loader = try XCTUnwrap(
            vm.range(of: "private func loadGarminHistoryPrompt").map { range -> String in
                let tail = vm[range.lowerBound...]
                let end = tail.range(of: "private func loadWeekReview")?.lowerBound
                    ?? tail.endIndex
                return String(tail[..<end])
            }
        )
        XCTAssertTrue(
            loader.contains("isCancellationError"),
            "取消的那一輪不得把旗標寫成 false，否則會蓋掉上一輪算出來的 true"
        )
        XCTAssertTrue(
            loader.contains("isStaleRound"),
            "過期輪不得動畫面"
        )
    }
}
