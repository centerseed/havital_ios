import XCTest
@testable import paceriz_dev

/// StateRizoChatViewModel 單元測試（卡片=Rizo hub 多輪對話）。
///
/// Task 1：先建可重用的 FakeRizoRepository（回固定 RizoReply）+ 驗證通用
/// `sendChat(scenario:message:sessionId:)` 入口。StateRizoChatViewModel 本身於 Task 2
/// 以 TDD 補上，屆時直接複用本檔的 FakeRizoRepository。
///
/// Mock 邊界：FakeRizoRepository 為純測試替身（無外部付費服務 / LLM；
/// Rizo 後端在 dev 尚未部署，本批不連真後端）。
@MainActor
final class StateRizoChatViewModelTests: XCTestCase {

    // MARK: - Task 1：通用 sendChat 入口

    func test_sendChat_returnsReply_andRecordsArgs() async throws {
        let fake = FakeRizoRepository(
            reply: makeReply(text: "最近還好嗎?", sessionId: "s1")
        )

        let reply = try await fake.sendChat(
            scenario: "weekly_situation",
            message: "這週很忙",
            sessionId: nil
        )

        XCTAssertEqual(reply.reply, "最近還好嗎?")
        XCTAssertEqual(reply.sessionId, "s1")
        XCTAssertEqual(fake.lastScenario, "weekly_situation")
        XCTAssertEqual(fake.lastMessage, "這週很忙")
        XCTAssertNil(fake.lastSessionId)
        XCTAssertEqual(fake.sendChatCallCount, 1)
    }

    // MARK: - Helpers

    private func makeReply(text: String, sessionId: String) -> RizoReply {
        RizoReply(
            reply: text,
            sessionId: sessionId,
            quota: RizoQuota(
                allowed: true, used: 1, limit: nil, remaining: nil,
                resetsAt: nil, reserved: false
            ),
            safety: RizoSafety(dangerClass: "none", canned: false)
        )
    }
}

// MARK: - Test Doubles

private enum StateRizoChatTestError: Error { case boom }

/// 通用 Rizo 測試替身：可設定固定 reply 或拋錯，記錄最後一次呼叫參數。
/// Task 2 的 StateRizoChatViewModelTests 將複用此替身驗多輪對話。
final class FakeRizoRepository: RizoRepository {

    var replyToReturn: RizoReply
    var errorToThrow: Error?
    var sendDelayNanoseconds: UInt64 = 0

    private(set) var sendChatCallCount = 0
    private(set) var lastScenario: String?
    private(set) var lastMessage: String?
    private(set) var lastSessionId: String?

    init(reply: RizoReply) {
        self.replyToReturn = reply
    }

    func sendChat(
        scenario: String,
        message: String,
        sessionId: String?
    ) async throws -> RizoReply {
        sendChatCallCount += 1
        lastScenario = scenario
        lastMessage = message
        lastSessionId = sessionId
        if sendDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: sendDelayNanoseconds)
        }
        if let errorToThrow { throw errorToThrow }
        return replyToReturn
    }

    // MARK: Unused protocol surface（本批只用 sendChat）

    func sendJournalChat(
        workoutId: String,
        message: String,
        presetSelections: [String],
        sessionId: String?
    ) async throws -> RizoReply {
        if let errorToThrow { throw errorToThrow }
        return replyToReturn
    }

    func getPresets(scenario: String) async throws -> [RizoPreset] { [] }

    func getHistory() async throws -> [RizoHistoryItem] { [] }
}
