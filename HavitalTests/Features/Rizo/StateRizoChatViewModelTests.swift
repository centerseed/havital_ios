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

    func test_streamingShowsPartialBeforeFinalThenFinalOverwritesIt() async throws {
        let fake = FakeRizoRepository(reply: makeReply(text: "Authoritative answer", sessionId: "s1"))
        fake.streamPartial = "Partial answer"
        fake.streamPauseNanoseconds = 200_000_000
        let vm = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        let task = Task { await vm.startOpening() }
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.messages.last?.text, "Partial answer")
        XCTAssertTrue(vm.isReplying)
        await task.value
        XCTAssertEqual(vm.messages.count, 1)
        XCTAssertEqual(vm.messages.last?.text, "Authoritative answer")
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

    func test_resumeFromHistoryRendersPrefixAndSendsNextTurnToForkSession() async {
        let fake = FakeRizoRepository(reply: makeReply(text: "Continuing answer", sessionId: "fork-1"))
        let vm = StateRizoChatViewModel(scenario: "weekly_situation", repository: fake)
        let fork = RizoHistoryFork(
            sessionId: "fork-1",
            scenario: "body_status",
            turns: [RizoHistoryItem(
                sessionId: "fork-1", scenario: "body_status",
                userInput: "How far did I run yesterday?", rizoResponse: "You ran 5 km yesterday.",
                ts: "2026-07-20T01:00:00+00:00"
            )]
        )

        vm.resumeFromHistory(fork)
        XCTAssertEqual(vm.messages.map(\.text), ["How far did I run yesterday?", "You ran 5 km yesterday."])

        await vm.send("What about the pace?")
        XCTAssertEqual(fake.lastSessionId, "fork-1")
        XCTAssertEqual(fake.lastScenario, "body_status", "Resumed chat must preserve the source scenario")
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

    // MARK: - #3 user-confirmed bubble

    func test_accept_success_appends_user_confirmed_bubble_before_coach_applied() async {
        let pending = PendingPlanChange(proposalId: "rpc_1", summary: "x",
                                        safetyLevel: "none", requiresSubscription: false, diffDays: nil)
        let base = makeReply(text: "建議減量", sessionId: "s1")
        let reply = RizoReply(reply: base.reply, sessionId: base.sessionId,
                              quota: base.quota, safety: base.safety, pendingPlanChange: pending)
        let fake = FakeRizoRepository(reply: reply)
        let vm = StateRizoChatViewModel(scenario: "weekly_situation", repository: fake)
        await vm.startOpening()
        XCTAssertNotNil(vm.pendingPlanChange, "前置：VM 應已進入 pending 態")

        await vm.acceptPlanChange()

        let userConfirmed = NSLocalizedString("rizo.plan_change.user_confirmed", comment: "")
        let applied = NSLocalizedString("rizo.plan_change.applied_deferred", comment: "")
        let texts = vm.messages.map { $0.text }
        let iUser = texts.firstIndex(of: userConfirmed)
        let iApplied = texts.firstIndex(of: applied)
        XCTAssertNotNil(iUser, "成功後應有 user 確認泡泡")
        XCTAssertNotNil(iApplied, "weekly_situation should use deferred semantics applied_deferred")
        XCTAssertLessThan(iUser!, iApplied!, "user 確認須在 coach 已套用之前")
        XCTAssertEqual(vm.messages.first(where: { $0.text == userConfirmed })?.role, .user)
        XCTAssertNil(vm.pendingPlanChange)
    }

    func test_accept_success_bodyStatus_uses_immediate_applied_text() async {
        let pending = PendingPlanChange(proposalId: "rpc_2", summary: "x",
                                        safetyLevel: "none", requiresSubscription: false, diffDays: nil)
        let base = makeReply(text: "let's ease it up a bit", sessionId: "s1")
        let reply = RizoReply(reply: base.reply, sessionId: base.sessionId,
                              quota: base.quota, safety: base.safety, pendingPlanChange: pending)
        let fake = FakeRizoRepository(reply: reply)
        let vm = StateRizoChatViewModel(scenario: "body_status", repository: fake)
        await vm.startOpening()

        await vm.acceptPlanChange()

        let immediate = NSLocalizedString("rizo.plan_change.applied", comment: "")
        let deferred = NSLocalizedString("rizo.plan_change.applied_deferred", comment: "")
        let texts = vm.messages.map { $0.text }
        XCTAssertTrue(texts.contains(immediate), "body_status should keep immediate semantics (applied now)")
        XCTAssertFalse(texts.contains(deferred), "body_status should not show deferred semantics")
    }

    func test_accept_not_applied_does_not_append_user_confirmed() async {
        let pending = PendingPlanChange(proposalId: "rpc_1", summary: "x",
                                        safetyLevel: "none", requiresSubscription: false, diffDays: nil)
        let base = makeReply(text: "建議減量", sessionId: "s1")
        let reply = RizoReply(reply: base.reply, sessionId: base.sessionId,
                              quota: base.quota, safety: base.safety, pendingPlanChange: pending)
        let fake = FakeRizoRepository(reply: reply)
        fake.confirmResultToReturn = PlanChangeConfirmResult(applied: false, status: "rejected")
        let vm = StateRizoChatViewModel(scenario: "weekly_situation", repository: fake)
        await vm.startOpening()

        await vm.acceptPlanChange()

        let userConfirmed = NSLocalizedString("rizo.plan_change.user_confirmed", comment: "")
        XCTAssertFalse(vm.messages.contains { $0.text == userConfirmed },
                       "失敗路徑不可出現 user 確認泡泡（避免對話說謊）")
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
    var streamPartial: String?
    var streamPauseNanoseconds: UInt64 = 0

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

    func streamChat(scenario: String, message: String, sessionId: String?) -> AsyncThrowingStream<RizoChatUpdate, Error> {
        guard let streamPartial else {
            return AsyncThrowingStream { continuation in
                let task = Task {
                    do { continuation.yield(.final(try await sendChat(scenario: scenario, message: message, sessionId: sessionId))); continuation.finish() }
                    catch { continuation.finish(throwing: error) }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
        return AsyncThrowingStream { continuation in
            let task = Task {
                continuation.yield(.partial(streamPartial))
                try? await Task.sleep(nanoseconds: streamPauseNanoseconds)
                continuation.yield(.final(replyToReturn))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
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

    var historyToReturn: [RizoHistoryItem] = []
    var pendingPlanChangesToReturn: [String: PendingPlanChange] = [:]
    var historyErrorToThrow: Error?
    /// 讓測試在 history 還沒回來的那段時間裡插進別的操作。
    var historyDelayNanoseconds: UInt64 = 0
    private(set) var historyCallCount = 0

    func getHistory() async throws -> (
        items: [RizoHistoryItem],
        pendingPlanChanges: [String: PendingPlanChange]
    ) {
        historyCallCount += 1
        if historyDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: historyDelayNanoseconds)
        }
        if let historyErrorToThrow { throw historyErrorToThrow }
        return (historyToReturn, pendingPlanChangesToReturn)
    }

    // MARK: confirmPlanChange（#3 測試用）

    var confirmResultToReturn: PlanChangeConfirmResult = PlanChangeConfirmResult(applied: true, status: "applied")
    var confirmErrorToThrow: Error?
    private(set) var confirmCallCount = 0
    private(set) var lastConfirmProposalId: String?

    func confirmPlanChange(proposalId: String) async throws -> PlanChangeConfirmResult {
        confirmCallCount += 1
        lastConfirmProposalId = proposalId
        if let confirmErrorToThrow { throw confirmErrorToThrow }
        return confirmResultToReturn
    }
}
