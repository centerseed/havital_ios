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

    // MARK: - Task 2：scenario 多輪 + 開場

    func test_opening_then_user_reply_appends_messages() async {
        let fake = FakeRizoRepository(
            reply: makeReply(text: "最近還好嗎?", sessionId: "s1")
        )
        let vm = StateRizoChatViewModel(scenario: "weekly_situation", repository: fake)

        await vm.startOpening()                          // 教練先說話
        XCTAssertEqual(vm.messages.last?.role, .coach)
        XCTAssertEqual(vm.messages.count, 1)
        XCTAssertEqual(fake.lastMessage, "", "開場 message 應為空字串，由後端依 scenario 注入")
        XCTAssertNil(fake.lastSessionId, "首回合 sessionId 為 nil")

        await vm.send("這週很忙")                          // 用戶回
        XCTAssertEqual(vm.messages.filter { $0.role == .user }.count, 1)
        XCTAssertEqual(vm.messages.last?.role, .coach)    // 教練再回
        XCTAssertEqual(fake.sendChatCallCount, 2)
        XCTAssertEqual(fake.lastScenario, "weekly_situation")
    }

    func test_startOpening_isIdempotent_whenMessagesPresent() async {
        let fake = FakeRizoRepository(
            reply: makeReply(text: "嗨", sessionId: "s1")
        )
        let vm = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        await vm.startOpening()
        await vm.startOpening()                           // 第二次不應再呼叫後端

        XCTAssertEqual(fake.sendChatCallCount, 1)
        XCTAssertEqual(vm.messages.count, 1)
    }

    func test_send_threadsSessionIdOnSecondTurn() async {
        let fake = FakeRizoRepository(
            reply: makeReply(text: "了解", sessionId: "sess-9")
        )
        let vm = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        await vm.startOpening()
        XCTAssertNil(fake.lastSessionId)

        await vm.send("膝蓋有點緊")
        XCTAssertEqual(fake.lastSessionId, "sess-9", "續談應沿用前一回合回的 sessionId")
    }

    func test_send_emptyText_doesNothing() async {
        let fake = FakeRizoRepository(
            reply: makeReply(text: "嗨", sessionId: "s1")
        )
        let vm = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        await vm.send("   \n ")

        XCTAssertTrue(vm.messages.isEmpty)
        XCTAssertEqual(fake.sendChatCallCount, 0)
    }

    func test_send_clearsDraftOnSubmit() async {
        let fake = FakeRizoRepository(
            reply: makeReply(text: "收到", sessionId: "s1")
        )
        let vm = StateRizoChatViewModel(scenario: "body_status", repository: fake)
        vm.draft = "今天很累"

        await vm.send(vm.draft)

        XCTAssertEqual(vm.draft, "")
    }

    func test_send_failure_appendsCoachFallbackMessage() async {
        let fake = FakeRizoRepository(
            reply: makeReply(text: "不會用到", sessionId: "s1")
        )
        fake.errorToThrow = StateRizoChatTestError.boom
        let vm = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        await vm.send("這週很忙")

        // 用戶訊息仍在，教練回覆為 fallback（不可吞錯導致對話卡住）。
        XCTAssertEqual(vm.messages.filter { $0.role == .user }.count, 1)
        XCTAssertEqual(vm.messages.last?.role, .coach)
        XCTAssertFalse(vm.isReplying, "失敗後應釋放 loading 狀態")
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
