import XCTest
@testable import paceriz_dev

final class RizoConversationGroupingTests: XCTestCase {

    private func item(_ sid: String, _ ts: String,
                      scenario: String = "body_status",
                      user: String = "", coach: String = "r") -> RizoHistoryItem {
        RizoHistoryItem(sessionId: sid, scenario: scenario,
                        userInput: user, rizoResponse: coach, ts: ts)
    }

    func test_groupsBySession_turnsAscending_sessionsByLatestDescending() {
        let items = [
            item("s1", "2026-07-01T10:00:00+00:00", user: "", coach: "opener1"),
            item("s2", "2026-07-02T09:00:00+00:00", user: "hey", coach: "hi"),
            item("s1", "2026-07-01T10:05:00+00:00", user: "tired", coach: "take it easy"),
        ]
        let convos = RizoConversationSummary.group(from: items)

        XCTAssertEqual(convos.count, 2)
        XCTAssertEqual(convos[0].sessionId, "s2")        // latest first
        XCTAssertEqual(convos[1].sessionId, "s1")
        XCTAssertEqual(convos[1].turns.map(\.ts),
                       ["2026-07-01T10:00:00+00:00", "2026-07-01T10:05:00+00:00"])
        XCTAssertEqual(convos[1].turnCount, 2)
        XCTAssertEqual(convos[1].updatedAt, "2026-07-01T10:05:00+00:00")
        XCTAssertEqual(convos[1].startedAt, "2026-07-01T10:00:00+00:00")
        XCTAssertEqual(convos[1].lastResponse, "take it easy")
    }

    func test_titleSeed_isFirstNonEmptyUserInput_truncatedTo20() {
        let long = "this is a very very long user message exceeding twenty chars"
        let items = [
            item("s1", "t1", user: "", coach: "opener"),
            item("s1", "t2", user: long, coach: "ok"),
        ]
        let convo = RizoConversationSummary.group(from: items)[0]
        XCTAssertEqual(convo.titleSeed, String(long.prefix(20)))
    }

    func test_titleSeed_nil_whenOnlyOpener() {
        let items = [ item("s1", "t1", user: "", coach: "opener") ]
        XCTAssertNil(RizoConversationSummary.group(from: items)[0].titleSeed)
    }

    func test_empty_returnsEmpty() {
        XCTAssertTrue(RizoConversationSummary.group(from: []).isEmpty)
    }
}
