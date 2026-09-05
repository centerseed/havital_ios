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
        // `unknown` ＝我們沒問到。把它當成有，就是這次要修的那個謊——
        // 原本 `onboardingGarminComplete(hasHistory:)` 是寫死 `true` 的。
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
