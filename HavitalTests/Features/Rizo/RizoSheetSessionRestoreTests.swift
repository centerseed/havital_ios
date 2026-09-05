import XCTest
@testable import paceriz_dev

/// 2.0 首頁 Rizo sheet 關掉就看不到剛聊的內容（T-0434）。
///
/// 真缺陷：`App2RizoChatSheet` 每次開都新建一個 `sessionId = nil` 的
/// `StateRizoChatViewModel`，使用者 2026-09-05 回報「聊完退出，還想再看剛剛聊什麼
/// 就看不到了」。
///
/// 判準三條：**同一天的那一段要帶回來且續聊同一個 session**、**跨日不帶回**
/// （新的一天＝新的今日卡）、**「新對話」按下去要真的忘掉 session**（不然下一句
/// 會接到舊對話上）。
@MainActor
final class RizoSheetSessionRestoreTests: XCTestCase {

    private func reply(_ text: String, session: String) -> RizoReply {
        RizoReply(
            reply: text,
            sessionId: session,
            quota: RizoQuota(
                allowed: true, used: 1, limit: nil, remaining: nil,
                resetsAt: nil, reserved: false
            ),
            safety: RizoSafety(dangerClass: "none", canned: false)
        )
    }

    private func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func turn(
        session: String, user: String, coach: String, at date: Date,
        scenario: String = "body_status"
    ) -> RizoHistoryItem {
        RizoHistoryItem(
            sessionId: session, scenario: scenario,
            userInput: user, rizoResponse: coach, ts: iso(date)
        )
    }

    // MARK: - 同一天：帶回來，而且續聊的是同一個 session

    func test_todaysSessionIsRestoredAndContinuesInTheSameSession() async {
        let now = Date()
        let fake = FakeRizoRepository(reply: reply("好的", session: "sess-today"))
        fake.historyToReturn = [
            turn(session: "sess-today", user: "今天腿很痠", coach: "那就先緩一下",
                 at: now.addingTimeInterval(-3600))
        ]
        let viewModel = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        let restored = await viewModel.restoreTodaySession(now: now)

        XCTAssertTrue(restored)
        XCTAssertEqual(viewModel.messages.map(\.text), ["今天腿很痠", "那就先緩一下"])
        XCTAssertEqual(viewModel.messages.map(\.role), [.user, .coach])

        // 續聊必須帶著那一個 session id——不帶就是另起一段，使用者下一句會失去脈絡。
        await viewModel.send("那明天呢")
        XCTAssertEqual(fake.lastSessionId, "sess-today")
    }

    /// 帶回來之後 `seedOpening` 不得再插一句開場白進去。
    func test_restoredConversationIsNotOverwrittenByTheLocalOpening() async {
        let now = Date()
        let fake = FakeRizoRepository(reply: reply("好的", session: "sess-today"))
        fake.historyToReturn = [
            turn(session: "sess-today", user: "今天腿很痠", coach: "那就先緩一下", at: now)
        ]
        let viewModel = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        _ = await viewModel.restoreTodaySession(now: now)
        viewModel.seedOpening("今天的狀態看起來不錯，想聊什麼？")

        XCTAssertEqual(viewModel.messages.count, 2)
    }

    // MARK: - 跨日：不帶回（新的一天＝新的今日卡）

    func test_yesterdaysSessionIsNotRestored() async {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let fake = FakeRizoRepository(reply: reply("好的", session: "sess-old"))
        fake.historyToReturn = [
            turn(session: "sess-old", user: "昨天聊的", coach: "昨天回的", at: yesterday)
        ]
        let viewModel = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        let restored = await viewModel.restoreTodaySession(now: now)

        XCTAssertFalse(restored)
        XCTAssertTrue(viewModel.messages.isEmpty)

        // 沒帶回就走本機開場白，而且下一句是新的 session（sessionId 仍為 nil）。
        viewModel.seedOpening("今天的狀態看起來不錯")
        await viewModel.send("好")
        XCTAssertNil(fake.lastSessionId)
    }

    /// 讀不到歷史不是失敗態：開空白對話，不擋使用者（訓練流程 fail-open）。
    func test_historyFailureFallsBackToABlankConversation() async {
        let fake = FakeRizoRepository(reply: reply("好的", session: "s"))
        fake.historyErrorToThrow = RizoRepositoryError.dataSourceUnavailable
        let viewModel = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        let restored = await viewModel.restoreTodaySession()

        XCTAssertFalse(restored)
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    /// 已經有訊息時不去讀 history——重讀會把使用者剛打的內容蓋掉。
    func test_restoreIsANoOpOnceTheConversationHasStarted() async {
        let fake = FakeRizoRepository(reply: reply("好的", session: "s"))
        fake.historyToReturn = [
            turn(session: "sess-today", user: "u", coach: "c", at: Date())
        ]
        let viewModel = StateRizoChatViewModel(scenario: "body_status", repository: fake)
        viewModel.seedOpening("開場")

        let restored = await viewModel.restoreTodaySession()

        XCTAssertFalse(restored)
        XCTAssertEqual(viewModel.historyUntouchedMessageCount, 1)
        XCTAssertEqual(fake.historyCallCount, 0)
    }

    // MARK: - 「新對話」

    func test_newConversationClearsMessagesAndForgetsTheSession() async {
        let now = Date()
        let fake = FakeRizoRepository(reply: reply("好的", session: "sess-today"))
        fake.historyToReturn = [
            turn(session: "sess-today", user: "今天腿很痠", coach: "那就先緩一下", at: now)
        ]
        let viewModel = StateRizoChatViewModel(scenario: "body_status", repository: fake)
        _ = await viewModel.restoreTodaySession(now: now)
        XCTAssertFalse(viewModel.messages.isEmpty)

        viewModel.startNewConversation()

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertTrue(viewModel.draft.isEmpty)

        // 忘掉 session 才算新對話：下一句不得接到剛剛那一段上。
        await viewModel.send("重新開始")
        XCTAssertNil(fake.lastSessionId)
    }
}

private extension StateRizoChatViewModel {
    /// 只是把 `messages.count` 講成測試在問的那件事。
    var historyUntouchedMessageCount: Int { messages.count }
}
