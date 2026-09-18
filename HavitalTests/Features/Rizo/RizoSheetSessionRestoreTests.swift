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

    /// 今天的正午，不是「現在」。
    ///
    /// 這些案例用 `now.addingTimeInterval(-3600)` 造「同一天一小時前」的那一輪對話。
    /// 拿真正的現在當 `now`，午夜到 01:00 之間那一小時前就落在**昨天**，
    /// `restoreTodaySession` 照規格判成跨日不帶回，整批同日案例變紅——
    /// 2026-09-07 00:0x 的 T-0618 交付閘門就是這樣被擋下來的。
    /// 釘在正午之後，前後各推幾小時都還在同一天。
    private var noon: Date {
        Calendar.current.date(
            bySettingHour: 12, minute: 0, second: 0, of: Date()
        ) ?? Date()
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
        let now = noon
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
        let now = noon
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
        let now = noon
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

    // MARK: - 回覆還在路上時按了「新對話」／「歷史」

    /// 真缺陷：`startNewConversation()` 靠 `cancelAllTasks()` 停掉進行中的回覆，
    /// 但這支 ViewModel 從來沒有 `trackTask`，`taskRegistry` 恆空——送出是
    /// `RizoChatView` 裡沒註冊的 `Task { await viewModel.send(...) }`，取消不到。
    /// header 三顆鈕在回覆進行中也沒有 disabled。所以回覆落地時 `.final` 會把
    /// `sessionId` 設回舊 session：「新對話」看起來有反應，實際上又接回去了，
    /// 連免費額度的脫離方式都跟著失效。
    func test_aReplyLandingAfterNewChatDoesNotLeakIntoIt() async {
        let fake = FakeRizoRepository(reply: reply("舊的回覆", session: "sess-old"))
        fake.sendDelayNanoseconds = 300_000_000
        let viewModel = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        let inFlight = Task { await viewModel.send("舊的問題") }
        try? await Task.sleep(nanoseconds: 80_000_000)
        viewModel.startNewConversation()
        await inFlight.value

        XCTAssertTrue(
            viewModel.messages.isEmpty,
            "舊的那一輪落進了新對話：\(viewModel.messages.map(\.text))"
        )
        XCTAssertFalse(viewModel.isReplying)

        // 而且 sessionId 沒有被那一輪設回去——下一句必須是新的 session。
        await viewModel.send("新的問題")
        XCTAssertNil(fake.lastSessionId, "「新對話」之後又接回舊 session 了")
    }

    /// 同一個洞的另一個入口：回覆還在路上時從「歷史」續聊。
    func test_aReplyLandingAfterResumingFromHistoryDoesNotLeakIntoIt() async {
        let fake = FakeRizoRepository(reply: reply("舊的回覆", session: "sess-old"))
        fake.sendDelayNanoseconds = 300_000_000
        let viewModel = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        let inFlight = Task { await viewModel.send("舊的問題") }
        try? await Task.sleep(nanoseconds: 80_000_000)
        viewModel.resumeFromHistory(
            RizoHistoryFork(
                sessionId: "sess-forked",
                scenario: "body_status",
                turns: [
                    RizoHistoryItem(
                        sessionId: "sess-forked", scenario: "body_status",
                        userInput: "分岔的那一句", rizoResponse: "分岔的回覆", ts: iso(Date())
                    )
                ]
            )
        )
        await inFlight.value

        XCTAssertEqual(
            viewModel.messages.map(\.text), ["分岔的那一句", "分岔的回覆"],
            "舊的那一輪落進了 fork 出來的對話"
        )
        await viewModel.send("接著問")
        XCTAssertEqual(fake.lastSessionId, "sess-forked", "續聊接到的不是 fork 的 session")
    }

    // MARK: - 計費 session 的口徑（2026-09-06 裁決）

    /// 免費教練額度是月配額、以 `session_id` 去重
    /// （`core/policies/rizo_quota.py` 的 `DEFAULT_RIZO_FREE_COACH_LIMIT`，
    /// `rizo_quota_service.py` 同一個 session 第二次起不扣）。所以「還原沿用同一個
    /// session」＝同一天的多次開啟只扣一次，「新對話」＝開新 session＝扣一次。
    ///
    /// 這一條鎖的是那個口徑本身：app 端看不到額度，但**送出時帶不帶舊 session_id**
    /// 就是後端算不算第二次的唯一依據。裁決與代價記在
    /// `STATUS/decisions.md` 2026-09-06「T-0434 免費額度口徑」。
    func test_restoringReusesTheBillingSessionAndNewChatStartsAFreshOne() async {
        let now = noon
        let fake = FakeRizoRepository(reply: reply("好的", session: "sess-today"))
        fake.historyToReturn = [
            turn(session: "sess-today", user: "早上聊的", coach: "早上回的", at: now)
        ]
        let viewModel = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        // 第一次開：帶回今天那一段。
        let restored = await viewModel.restoreTodaySession(now: now)
        XCTAssertTrue(restored)
        await viewModel.send("下午再問一句")
        XCTAssertEqual(
            fake.lastSessionId, "sess-today",
            "還原之後送出必須帶回同一個 session——不帶就是新 session，後端會再扣一次"
        )

        // 按「新對話」：這一次才是新的計費 session。
        viewModel.startNewConversation()
        await viewModel.send("換個話題")
        XCTAssertNil(
            fake.lastSessionId,
            "「新對話」必須開新 session（＝扣一次），否則使用者沒有脫離當日那一段的辦法"
        )
    }

    // MARK: - 用完額度的那一段不還原

    /// 後端對今日卡情境有每-session 20 輪的軟上限（`application/rizo.py`
    /// 的 `_SESSION_SOFT_CAP`）：到了上限那一段只會回罐頭收尾、不進教練模型。
    ///
    /// 改動前 sheet 每次開都是新 session，這個上限碰不到；帶回當日 session 之後
    /// 同一天共用同一份預算。已經用完的那一段**不還原**，否則使用者一開 sheet
    /// 就卡在收尾語。
    func test_aSessionThatHasUsedUpItsTurnBudgetIsNotRestored() async {
        let now = noon
        let fake = FakeRizoRepository(reply: reply("好的", session: "sess-new"))
        fake.historyToReturn = (1...20).map { index in
            turn(session: "sess-today", user: "第 \(index) 句", coach: "回覆 \(index)",
                 at: now.addingTimeInterval(Double(index)))
        }
        let viewModel = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        let restored = await viewModel.restoreTodaySession(now: now)

        XCTAssertFalse(restored, "已經用完 20 輪的那一段不該被帶回來")
        XCTAssertTrue(viewModel.messages.isEmpty)

        // 開的是新的一段，所以下一句不帶舊 session。
        await viewModel.send("再問一件事")
        XCTAssertNil(fake.lastSessionId)
    }

    /// 還沒用完就照常帶回來——上面那條不得把正常情況一起擋掉。
    func test_aSessionWithBudgetLeftIsStillRestored() async {
        let now = noon
        let fake = FakeRizoRepository(reply: reply("好的", session: "sess-today"))
        fake.historyToReturn = (1...19).map { index in
            turn(session: "sess-today", user: "第 \(index) 句", coach: "回覆 \(index)",
                 at: now.addingTimeInterval(Double(index)))
        }
        let viewModel = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        let restored = await viewModel.restoreTodaySession(now: now)
        XCTAssertTrue(restored)
        await viewModel.send("再問一件事")
        XCTAssertEqual(fake.lastSessionId, "sess-today")
    }

    // MARK: - 還原還在等 history 的時候，使用者已經動作了

    /// 真缺陷：`restoreTodaySession` 在 `await getHistory()` 之後直接覆寫
    /// `messages`／`sessionId`，中間沒有再驗一次。sheet 的輸入列在 `.task` 跑的
    /// 同時就能用（`@MainActor` 允許在 `await` 期間重入），所以使用者這段時間送出的
    /// 訊息會被那份已經過期的還原蓋掉。
    func test_aMessageSentWhileRestoringIsNotOverwritten() async {
        let now = noon
        let fake = FakeRizoRepository(reply: reply("收到", session: "sess-new"))
        fake.historyDelayNanoseconds = 200_000_000
        fake.historyToReturn = [
            turn(session: "sess-today", user: "舊的那一句", coach: "舊的回覆", at: now)
        ]
        let viewModel = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        async let restored = viewModel.restoreTodaySession(now: now)
        try? await Task.sleep(nanoseconds: 50_000_000)
        await viewModel.send("我現在講的這句")
        let didRestore = await restored

        XCTAssertFalse(didRestore, "還原不得贏過使用者當下送出的訊息")
        XCTAssertTrue(
            viewModel.messages.contains { $0.text == "我現在講的這句" },
            "使用者剛送出的訊息被還原蓋掉了：\(viewModel.messages.map(\.text))"
        )
        XCTAssertFalse(viewModel.messages.contains { $0.text == "舊的那一句" })
    }

    /// 同一件事的另一半：還原還在跑的時候按「新對話」。
    func test_newConversationDuringRestoreWins() async {
        let now = noon
        let fake = FakeRizoRepository(reply: reply("收到", session: "sess-new"))
        fake.historyDelayNanoseconds = 200_000_000
        fake.historyToReturn = [
            turn(session: "sess-today", user: "舊的那一句", coach: "舊的回覆", at: now)
        ]
        let viewModel = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        async let restored = viewModel.restoreTodaySession(now: now)
        try? await Task.sleep(nanoseconds: 50_000_000)
        viewModel.startNewConversation()
        let didRestore = await restored

        XCTAssertFalse(didRestore, "按了新對話之後不得再把舊的那一段畫回來")
        XCTAssertTrue(viewModel.messages.isEmpty, "\(viewModel.messages.map(\.text))")

        // 而且下一句是新的 session，不得接到被放棄的那一段上。
        await viewModel.send("重新開始")
        XCTAssertNil(fake.lastSessionId)
    }

    // MARK: - 入口的身分不被歷史接管

    /// `GET /v2/agent/history` 不分 scenario 回全部輪次，最新那一段可能來自別的入口
    /// （週回顧的 `weekly_situation`）。AC-TRAIN-HUB-13 只授權沿用它的 `session_id`，
    /// 沒有授權讓歷史改寫這個 sheet 自己的 scenario。
    func test_restoringDoesNotLetHistoryTakeOverTheTouchpointScenario() async {
        let now = noon
        let fake = FakeRizoRepository(reply: reply("好的", session: "sess-today"))
        fake.historyToReturn = [
            turn(session: "sess-today", user: "上週狀況", coach: "了解",
                 at: now, scenario: "weekly_situation")
        ]
        let viewModel = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        let restored = await viewModel.restoreTodaySession(now: now)
        XCTAssertTrue(restored)

        await viewModel.send("那今天呢")
        XCTAssertEqual(fake.lastScenario, "body_status", "入口的 scenario 被歷史蓋掉了")
        XCTAssertEqual(fake.lastSessionId, "sess-today", "沒有沿用那一段的 session")
    }

    // MARK: - 「新對話」

    func test_newConversationClearsMessagesAndForgetsTheSession() async {
        let now = noon
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

    // MARK: - AC-TRAIN-HUB-13 And Then：還原時把 pending 提案按鈕一起畫回來

    private func pending(_ id: String) -> PendingPlanChange {
        PendingPlanChange(
            proposalId: id, summary: "Day6: lsd 15km -> easy 12km",
            safetyLevel: "none", requiresSubscription: false, diffDays: nil
        )
    }

    /// 離開 Rizo 再回來，history 裡這個 session 還有提案 → 按鈕要在。
    /// 驗法：AC-TRAIN-HUB-13（2026-09-18 增補）；後端契約 SPEC-rizo-coach §4.2a。
    func test_restoringASessionWithPendingPlanChangeRestoresTheButtons() async {
        let now = noon
        let fake = FakeRizoRepository(reply: reply("好的", session: "sess-today"))
        fake.historyToReturn = [
            turn(session: "sess-today", user: "這週太累了", coach: "那我幫你把週六改輕鬆跑",
                 at: now)
        ]
        fake.pendingPlanChangesToReturn = ["sess-today": pending("rpc_typed_5c6e0e4fdc3b2094c24f1df3")]
        let viewModel = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        let restored = await viewModel.restoreTodaySession(now: now)

        XCTAssertTrue(restored)
        XCTAssertEqual(
            viewModel.pendingPlanChange?.proposalId,
            "rpc_typed_5c6e0e4fdc3b2094c24f1df3",
            "還原必須把 history.pending_plan_changes[sessionId] 畫回接受按鈕"
        )
    }

    /// 別的 session 的提案不得落到今天這一段上。
    func test_restoringDoesNotAdoptAnotherSessionsPendingPlanChange() async {
        let now = noon
        let fake = FakeRizoRepository(reply: reply("好的", session: "sess-today"))
        fake.historyToReturn = [
            turn(session: "sess-today", user: "今天腿很痠", coach: "那就先緩一下", at: now)
        ]
        fake.pendingPlanChangesToReturn = ["sess-other": pending("rpc_other")]
        let viewModel = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        _ = await viewModel.restoreTodaySession(now: now)

        XCTAssertNil(viewModel.pendingPlanChange, "只能取 pending_plan_changes[latest.sessionId]")
    }

    /// 還原後按「接受」走既有 confirm，不是另開一條路。
    func test_acceptAfterRestoreConfirmsTheRestoredProposal() async {
        let now = noon
        let fake = FakeRizoRepository(reply: reply("好的", session: "sess-today"))
        fake.historyToReturn = [
            turn(session: "sess-today", user: "改一下週六", coach: "幫你改成輕鬆跑", at: now)
        ]
        fake.pendingPlanChangesToReturn = ["sess-today": pending("rpc_restored")]
        let viewModel = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        _ = await viewModel.restoreTodaySession(now: now)
        await viewModel.acceptPlanChange()

        XCTAssertEqual(fake.confirmCallCount, 1)
        XCTAssertEqual(fake.lastConfirmProposalId, "rpc_restored")
        XCTAssertNil(viewModel.pendingPlanChange)
    }

    // MARK: - AC-TRAIN-HUB-18：只看 plan_change_applied，不讀回覆文字

    func test_planChangeAppliedTruePublishesTrainingPlanV2() async {
        let applied = RizoReply(
            reply: "好，已經幫你改了",
            sessionId: "sess-1",
            quota: RizoQuota(
                allowed: true, used: 1, limit: nil, remaining: nil,
                resetsAt: nil, reserved: false
            ),
            safety: RizoSafety(dangerClass: "none", canned: false),
            planChangeApplied: true
        )
        let fake = FakeRizoRepository(reply: applied)
        let viewModel = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        var published = 0
        let subscriberId = "t0736-applied-\(UUID().uuidString)"
        CacheEventBus.shared.subscribe(forIdentifier: subscriberId) { reason in
            if case .dataChanged(.trainingPlanV2) = reason { published += 1 }
        }
        defer { CacheEventBus.shared.unsubscribe(forIdentifier: subscriberId) }

        await viewModel.send("好，就這樣改")
        await waitUntil(message: "data.plan_change_applied == true 必須發 .trainingPlanV2") {
            published == 1
        }

        XCTAssertEqual(published, 1, "data.plan_change_applied == true 必須發 .trainingPlanV2")
    }

    func test_planChangeAppliedAbsentDoesNotPublish() async {
        let fake = FakeRizoRepository(reply: reply("今天天氣不錯，輕鬆跑就好", session: "sess-1"))
        let viewModel = StateRizoChatViewModel(scenario: "body_status", repository: fake)

        var published = 0
        let subscriberId = "t0736-absent-\(UUID().uuidString)"
        CacheEventBus.shared.subscribe(forIdentifier: subscriberId) { reason in
            if case .dataChanged(.trainingPlanV2) = reason { published += 1 }
        }
        defer { CacheEventBus.shared.unsubscribe(forIdentifier: subscriberId) }

        await viewModel.send("今天腿很痠")
        // publish 走 Task { @MainActor }，排空後才確定這一輪沒發。
        await MainActor.run {}
        await Task.yield()
        await MainActor.run {}

        XCTAssertEqual(published, 0, "沒有 plan_change_applied 的一輪不得發課表變更事件")
        XCTAssertEqual(viewModel.messages.last?.text, "今天天氣不錯，輕鬆跑就好")
    }
}

private extension StateRizoChatViewModel {
    /// 只是把 `messages.count` 講成測試在問的那件事。
    var historyUntouchedMessageCount: Int { messages.count }
}
