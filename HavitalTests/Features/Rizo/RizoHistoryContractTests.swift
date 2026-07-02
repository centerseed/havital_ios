import XCTest
@testable import paceriz_dev

/// 驗證 GET /v2/agent/history 的 data 物件真實 shape 能 decode，且 Mapper 正確對版。
/// 無 mock（純 JSON decode + 純函式 mapper）。
final class RizoHistoryContractTests: XCTestCase {

    func test_decodesBackendShape_andMapsToTurnEntities() throws {
        // 純 JSON decode + 純函式 mapper 的 contract test；fixture 內容為任意字串
        // （非 UI 顯示文字），故用 ASCII 值以免誤觸 i18n pre-commit 的寫死 CJK gate。
        let json = """
        { "items": [
          { "session_id": "s1", "ts": "2026-07-01T10:00:00.000000+00:00",
            "scenario": "body_status", "user_input": "", "rizo_response": "Good morning! Feeling great today." },
          { "session_id": "s1", "ts": "2026-07-01T10:01:00.000000+00:00",
            "scenario": "body_status", "user_input": "a bit tired", "rizo_response": "Let's take it easy then." }
        ] }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(RizoHistoryResponseDTO.self, from: json)
        let items = RizoMapper.toHistory(from: dto)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].sessionId, "s1")
        XCTAssertEqual(items[0].scenario, "body_status")
        XCTAssertEqual(items[0].userInput, "")
        XCTAssertEqual(items[0].rizoResponse, "Good morning! Feeling great today.")
        XCTAssertEqual(items[1].userInput, "a bit tired")
        XCTAssertEqual(items[1].ts, "2026-07-01T10:01:00.000000+00:00")
    }

    func test_dropsItemWithoutSessionId() throws {
        let json = """
        { "items": [ { "ts": "2026-07-01T10:00:00+00:00", "scenario": "journal",
                       "user_input": "hi", "rizo_response": "hello" } ] }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(RizoHistoryResponseDTO.self, from: json)
        XCTAssertTrue(RizoMapper.toHistory(from: dto).isEmpty)
    }
}
