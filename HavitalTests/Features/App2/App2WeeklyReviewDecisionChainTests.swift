import XCTest
@testable import paceriz_dev

/// 規劃下週分頁走 decision-chain 的逐條清單
/// （`Docs/specs/SPEC-training-hub-and-weekly-plan-lifecycle.md` AC-TRAIN-HUB-12；
/// 端點形狀 root `docs/designs/DESIGN-app2-decision-chain-api.md` §4.1／§4.1b）。
///
/// 釘四件事：
/// 1. `run` **只在 `.generate` 態**發（別的態發出去就是寫錯週的帳本）。
/// 2. 清單讀不到就退回 AC-TRAIN-HUB-10 的既有路徑（fail-open，不得擋產生）。
/// 3. 逐條表態樂觀更新，**失敗要退回那一條**——後端沒收到卻顯示已接受是最壞的一格。
/// 4. decision-chain 路徑**不呼 apply-items**（同一件事不留兩份紀錄）。
///
/// 形狀取自 dev 真實回應（2026-09-03，demo 帳號 `ZyIP5Vx…`，revision `api-service-01051-wir`）：
/// `weekly_km_pct` 的 `current` 是 `0.0`、`proposed` 是 `15.0`；`interval_reps` 的
/// `current` 是 `null`、`proposed` 是 `14`；`rest_ratio` 的 `proposed` 是 `"1:1"`。
@MainActor
final class App2WeeklyReviewDecisionChainTests: XCTestCase {

    private var repository: MockTrainingPlanV2Repository!
    private var decisionChain: FakeDecisionChainWeekRepository!

    override func setUp() {
        super.setUp()
        repository = MockTrainingPlanV2Repository()
        decisionChain = FakeDecisionChainWeekRepository()
        // 額度檢查會從 DI 解析 `SubscriptionRepository`；沒有註冊會 fatalError。
        DependencyContainer.shared.register(
            StubDecisionChainSubscriptionRepository(),
            forProtocol: SubscriptionRepository.self
        )
        // 付費閘門判準讀的是 singleton。`.none` ⇒ `enforcementEnabled == false`
        // ⇒ 不擋——這一組驗的是清單，不是付費牆（那是 AC-PAYWALL-26 自己的測試）。
        SubscriptionStateManager.shared.applyLogoutReset()
    }

    override func tearDown() {
        repository = nil
        decisionChain = nil
        super.tearDown()
    }

    // MARK: - 1. run 只在 `.generate` 態發

    func test_generateState_runsDecisionChainAndShowsChecklist() async {
        let viewModel = makeViewModel(reviewWeek: 4, planStatus: generatableStatus(currentWeek: 5))
        decisionChain.checklistToReturn = Self.checklist()
        decisionChain.intentCardToReturn = Self.intentCard()

        await viewModel.load()
        await viewModel.decisionChainTask?.value

        XCTAssertEqual(decisionChain.runCalls.count, 1, "`.generate` 態必須跑 decision-chain")
        XCTAssertEqual(decisionChain.runCalls.first?.weekOfTraining, 5, "跑的是目標週，不是回顧週")
        XCTAssertTrue(viewModel.usesDecisionChain, "清單拿到了就走 decision-chain 路徑")
        guard case .ready(let checklist, let card) = viewModel.decisionChain else {
            return XCTFail("清單在手時狀態必須是 .ready，實際：\(viewModel.decisionChain)")
        }
        XCTAssertEqual(checklist.items.count, 3)
        XCTAssertEqual(card?.expression.pursuing, "這一段把重點放在有氧基礎。")
    }

    /// 「只能套用」態不是「要規劃下一週」——對它發 `run` 是往錯的週寫帳本。
    func test_applyOnlyState_doesNotRun() async {
        let status = PlanStatusV2Response(
            currentWeek: 5,
            totalWeeks: 22,
            nextAction: "view_plan",
            canGenerateNextWeek: false,
            currentWeekPlanId: "plan-5",     // 本週已有課表 ⇒ 不是 `.generate`
            previousWeekSummaryId: nil,
            targetType: "race",
            methodologyId: "paceriz",
            nextWeekInfo: nil,
            metadata: nil
        )
        let viewModel = makeViewModel(reviewWeek: 4, planStatus: status)

        await viewModel.load()
        await viewModel.decisionChainTask?.value

        XCTAssertTrue(decisionChain.runCalls.isEmpty, "非 `.generate` 態不得發 run")
        XCTAssertEqual(viewModel.decisionChain, .unavailable)
        XCTAssertFalse(viewModel.usesDecisionChain)
    }

    /// 歷史週唯讀回看沒有任何寫入出口，`run` 也是寫入。
    func test_readOnly_doesNotRun() async {
        let viewModel = makeViewModel(
            reviewWeek: 4,
            planStatus: generatableStatus(currentWeek: 5),
            isReadOnly: true
        )

        await viewModel.load()
        await viewModel.decisionChainTask?.value

        XCTAssertTrue(decisionChain.runCalls.isEmpty)
        XCTAssertEqual(viewModel.decisionChain, .unavailable)
    }

    // MARK: - 2. fail-open

    /// 那一週沒有清單（後端 404 → repository 回 nil）⇒ 回到 AC-TRAIN-HUB-10 的既有路徑。
    func test_checklistMissing_failsOpenToLegacyPath() async {
        let viewModel = makeViewModel(reviewWeek: 4, planStatus: generatableStatus(currentWeek: 5))
        decisionChain.checklistToReturn = nil

        await viewModel.load()
        await viewModel.decisionChainTask?.value

        XCTAssertEqual(decisionChain.runCalls.count, 1)
        XCTAssertEqual(viewModel.decisionChain, .unavailable, "讀不到清單不得停在生成中")
        XCTAssertFalse(viewModel.usesDecisionChain)
    }

    /// `run` 5xx／逾時 ⇒ 一樣 fail-open，不得擋住產生課表。
    func test_runFails_failsOpenAndStillGenerates() async {
        let viewModel = makeViewModel(reviewWeek: 4, planStatus: generatableStatus(currentWeek: 5))
        decisionChain.runError = DomainError.serverError(500, "boom")

        await viewModel.load()
        await viewModel.decisionChainTask?.value
        XCTAssertEqual(viewModel.decisionChain, .unavailable)

        _ = await viewModel.applyAndGenerate()
        XCTAssertEqual(repository.generateWeeklyPlanCallCount, 1, "decision-chain 掛掉不得擋住產生課表")
    }

    /// 說明卡讀不到不影響清單——清單才是使用者要按的東西。
    func test_intentCardMissing_stillShowsChecklist() async {
        let viewModel = makeViewModel(reviewWeek: 4, planStatus: generatableStatus(currentWeek: 5))
        decisionChain.checklistToReturn = Self.checklist()
        decisionChain.intentCardError = DomainError.serverError(500, "boom")

        await viewModel.load()
        await viewModel.decisionChainTask?.value

        guard case .ready(_, let card) = viewModel.decisionChain else {
            return XCTFail("清單在手時狀態必須是 .ready，實際：\(viewModel.decisionChain)")
        }
        XCTAssertNil(card)
    }

    // MARK: - 3. 逐條表態

    func test_answer_sendsStanceAndTakesServerAnswer() async {
        let viewModel = await readyViewModel()
        let item = Self.checklist().items[0]
        decisionChain.stanceToReturn = item.with(status: .accepted, adjustedValue: nil)

        await viewModel.answer(item: item, status: .accepted)

        XCTAssertEqual(decisionChain.stanceCalls.count, 1)
        XCTAssertEqual(decisionChain.stanceCalls.first?.itemId, "knob.weekly_km_pct@2026-09-03")
        XCTAssertEqual(decisionChain.stanceCalls.first?.status, .accepted)
        XCTAssertEqual(currentItem(viewModel, "knob.weekly_km_pct@2026-09-03")?.status, .accepted)
    }

    /// `adjusted` 帶的值必須原樣送出去，整數條目仍是整數
    /// （後端收 `StrictInt | StrictFloat | StrictStr`）。
    func test_answerAdjusted_sendsTheValue() async {
        let viewModel = await readyViewModel()
        let item = Self.checklist().items[2]     // interval_reps，`proposed` 是 Int
        decisionChain.stanceToReturn = item.with(status: .adjusted, adjustedValue: .int(10))

        await viewModel.answer(
            item: item,
            status: .adjusted,
            adjustedValue: DecisionChainValue.matchingKind(of: item.proposed, number: 10)
        )

        XCTAssertEqual(decisionChain.stanceCalls.first?.adjustedValue, .int(10))
        XCTAssertEqual(currentItem(viewModel, item.itemId)?.adjustedValue, .int(10))
    }

    /// 表態沒寫進去 ⇒ **那一條退回原狀**。顯示成已接受而後端沒收到，是使用者
    /// 按下產生課表才會發現的那種錯（設計 §4.5a：MUST NOT 靜默當成 accepted）。
    func test_answerFails_rollsBackThatItemOnly() async {
        let viewModel = await readyViewModel()
        let first = Self.checklist().items[0]
        let second = Self.checklist().items[1]

        // 先讓第二條成功變成 declined，再讓第一條失敗——回滾不得把它一起打掉。
        decisionChain.stanceToReturn = second.with(status: .declined, adjustedValue: nil)
        await viewModel.answer(item: second, status: .declined)
        XCTAssertEqual(currentItem(viewModel, second.itemId)?.status, .declined)

        decisionChain.stanceError = DomainError.serverError(500, "boom")
        await viewModel.answer(item: first, status: .accepted)

        XCTAssertEqual(currentItem(viewModel, first.itemId)?.status, .proposed, "失敗的那一條要退回原狀")
        XCTAssertEqual(currentItem(viewModel, second.itemId)?.status, .declined, "不得回滾別條的答案")
        XCTAssertNotNil(viewModel.checklistError, "沒送出去要說出來，不得靜默")
    }

    /// Rizo 回覆之後重讀清單：它記下的修正會以新的一條回來。
    func test_refreshAfterRizo_reloadsChecklist() async {
        let viewModel = await readyViewModel()
        var rizoAdded = Self.checklist()
        rizoAdded.items.append(
            DecisionChainChecklistItem(
                itemId: "rizo.blocked_days@2026-09-03",
                source: .rizo,
                field: "blocked_days",
                current: nil,
                proposed: .text("3,4"),
                title: "週三、週四不排課",
                reason: "你說那兩天有事。",
                status: .accepted,
                adjustedValue: nil
            )
        )
        decisionChain.checklistToReturn = rizoAdded

        await viewModel.refreshChecklistAfterRizo()

        guard case .ready(let checklist, _) = viewModel.decisionChain else {
            return XCTFail("狀態必須留在 .ready，實際：\(viewModel.decisionChain)")
        }
        XCTAssertEqual(checklist.items.count, 4)
        XCTAssertEqual(checklist.items.last?.source, .rizo)
    }

    // MARK: - 4. decision-chain 路徑不呼 apply-items

    func test_decisionChainPath_doesNotCallApplyItems() async {
        let viewModel = await readyViewModel()

        _ = await viewModel.applyAndGenerate()

        XCTAssertEqual(repository.applyAdjustmentItemsCallCount, 0, "decision-chain 路徑不得送 apply-items")
        XCTAssertEqual(repository.generateWeeklyPlanCallCount, 1)
    }

    /// 對照組：既有路徑仍然先送 apply-items 再產生（AC-TRAIN-HUB-10 沒有被拿掉）。
    func test_legacyPath_stillCallsApplyItems() async {
        // 既有路徑要真的有建議項才會送 apply-items（`WeeklySummaryCoordinator:139`
        // 在「根本沒有調整項」時直接 no-op 回 true）。
        let viewModel = makeViewModel(
            reviewWeek: 4,
            planStatus: generatableStatus(currentWeek: 5),
            summaryAdjustments: [Self.adjustmentItem()]
        )
        decisionChain.checklistToReturn = nil        // fail-open 到既有路徑

        await viewModel.load()
        await viewModel.decisionChainTask?.value
        _ = await viewModel.applyAndGenerate()

        XCTAssertEqual(repository.applyAdjustmentItemsCallCount, 1)
        XCTAssertEqual(repository.generateWeeklyPlanCallCount, 1)
    }

    // MARK: - `as_of` 是使用者當地的今天

    func test_asOf_usesUserTimezoneNotDevice() {
        let status = PlanStatusV2Response(
            currentWeek: 5,
            totalWeeks: 22,
            nextAction: "create_plan",
            canGenerateNextWeek: false,
            currentWeekPlanId: nil,
            previousWeekSummaryId: nil,
            targetType: "race",
            methodologyId: "paceriz",
            nextWeekInfo: nil,
            metadata: PlanStatusV2Metadata(
                trainingStartDate: nil,
                currentWeekStartDate: nil,
                currentWeekEndDate: nil,
                userTimezone: "Asia/Tokyo",
                serverTime: "2026-09-02T17:24:53.011265+00:00"
            )
        )

        // UTC 還是 9/2 晚上，東京已經是 9/3——`run` 與 `checklist` 要對到同一份週 doc。
        XCTAssertEqual(App2WeeklyReviewViewModel.asOfInUserTimezone(status), "2026-09-03")
    }

    // MARK: - 「調整」輪盤的範圍（暫定規則，AC-TRAIN-HUB-12「未決」）

    func test_adjustRange_neverProducesNonsenseForNullCurrent() {
        let intervalReps = Self.checklist().items[2]     // current: null, proposed: 14
        let options = App2DecisionChainAdjustRange.options(for: intervalReps)

        XCTAssertFalse(options.isEmpty)
        XCTAssertEqual(options.first, 7, "`current` 是 null 時不得拿 0 當基準（會推出負的趟數）")
        XCTAssertEqual(options.last, 21)
        XCTAssertEqual(App2DecisionChainAdjustRange.initialValue(for: intervalReps), 14)
    }

    func test_adjustRange_spansBothSidesOfCurrentAndProposed() {
        let weeklyKm = Self.checklist().items[0]         // current: 0.0, proposed: 15.0
        let options = App2DecisionChainAdjustRange.options(for: weeklyKm)

        XCTAssertEqual(options.first, -15)
        XCTAssertEqual(options.last, 30)
    }

    /// 離散代號沒有輪盤可以轉——畫一顆按下去無值可送的「調整」是死路。
    func test_adjust_notOfferedForTextValues() {
        let restRatio = Self.checklist().items[1]        // proposed: "1:1"
        XCTAssertFalse(restRatio.allowsAdjust)
        XCTAssertTrue(App2DecisionChainAdjustRange.options(for: restRatio).isEmpty)
    }

    // MARK: - 真實 dev payload 解得開嗎

    /// 把 dev 2026-09-03 的原始回應原封不動餵進去。手抄的形狀會漂，這一格是唯一
    /// 能證明「app 讀得懂後端現在真的回什麼」的東西。
    func test_decodesRealDevChecklistPayload() throws {
        let raw = Data("""
        {"success":true,"data":{"as_of":"2026-09-03","intent_revision":"intent/2026-09-03",
        "intent_lifecycle":"proposed","items":[
        {"item_id":"knob.weekly_km_pct@2026-09-03","source":"intent_knob","field":"weekly_km_pct",
         "current":0.0,"proposed":15.0,"title":"A","reason":"B","status":"proposed"},
        {"item_id":"knob.rest_ratio@2026-09-03","source":"intent_knob","field":"rest_ratio",
         "current":null,"proposed":"1:1","title":"C","reason":"D","status":"proposed"},
        {"item_id":"knob.interval_reps@2026-09-03","source":"intent_knob","field":"interval_reps",
         "current":null,"proposed":14,"title":"E","reason":"F","status":"proposed"}]}}
        """.utf8)

        let dto = try ResponseProcessor.extractData(
            DecisionChainChecklistDTO.self,
            from: raw,
            using: DefaultAPIParser.shared
        )
        let checklist = DecisionChainWeekMapper.toEntity(dto, asOf: "2026-09-03")

        XCTAssertEqual(checklist.intentLifecycle, "proposed")
        XCTAssertEqual(checklist.items.count, 3)
        // `JSONDecoder` 分不出 `15.0` 與 `15`——整數值一律落 `.int`，
        // 送回去的 `adjusted_value` 因此不會平白多一個小數點。
        XCTAssertEqual(checklist.items[0].proposed, .int(15))
        XCTAssertEqual(checklist.items[0].current, .int(0))
        XCTAssertEqual(checklist.items[1].proposed, .text("1:1"))
        XCTAssertNil(checklist.items[1].current)
        // 整數要留成整數：`adjusted_value` 原樣送回去時 `14.0` 是換了型別。
        XCTAssertEqual(checklist.items[2].proposed, .int(14))
        XCTAssertTrue(checklist.items[0].allowsAdjust)
        XCTAssertFalse(checklist.items[1].allowsAdjust)
    }

    func test_decodesRealDevIntentCardPayload() throws {
        let raw = Data("""
        {"success":true,"data":{"lifecycle":"proposed",
        "intent":{"intent_id":"intent.u","revision":"intent/2026-09-03","uid":"u","as_of":"2026-09-03",
                  "status":"active","primary_adaptations":[],"maintained":[],"deferred":[],
                  "dosage":{"kind":"probe_edge"},"duration":{"planned_weeks":2,"end_conditions":[]},
                  "hypothesis_ids":[],"retained_active_revision":null},
        "expression":{"pursuing":"P","maintaining":null,"abandoning":null,"rationale":"R"},
        "plan_changes":["x"],
        "hypotheses":[{"hypothesis_id":"h1","revision":"intent/2026-09-03","status":"proposed",
                       "source":null,"intervention":{"kind":null,"description":"I"},
                       "prediction":{"observation_target_id":"t","direction":"improving",
                                     "magnitude":null,"description":"Z"},
                       "confidence":0.7,"observation":{"earliest_adjudication_at":"2026-09-17","window":null},
                       "confirmation":{"prompt_count":null}}]}}
        """.utf8)

        let card = DecisionChainWeekMapper.toEntity(
            try ResponseProcessor.extractData(
                DecisionChainIntentCardDTO.self,
                from: raw,
                using: DefaultAPIParser.shared
            )
        )

        XCTAssertEqual(card.revision, "intent/2026-09-03")
        XCTAssertEqual(card.expression.pursuing, "P")
        XCTAssertNil(card.expression.maintaining, "null 的那一列不畫")
        XCTAssertEqual(card.hypotheses.first?.interventionDescription, "I")
        XCTAssertEqual(card.hypotheses.first?.predictionDescription, "Z")
        XCTAssertTrue(card.hasContent)
    }

    /// 帳本上沒有意圖時後端回 `{"success": true, "data": null}`。
    ///
    /// **它丟的是 `APIError.business(.notFound)`，而那個的 `toDomainError()` 是
    /// `.unknown` 不是 `.notFound`。** 這一格就是為了釘住這個坑：repository 若只判
    /// domain 值，「這個人還沒有意圖」會被當成後端壞掉。
    func test_nullIntentCardPayloadSurfacesAsBusinessNotFound() {
        let raw = Data(#"{"success": true, "data": null}"#.utf8)

        XCTAssertThrowsError(
            try ResponseProcessor.extractData(
                DecisionChainIntentCardDTO.self,
                from: raw,
                using: DefaultAPIParser.shared
            )
        ) { error in
            XCTAssertTrue(
                TrainingPlanV2RepositoryImpl.meansNoIntentCard(error),
                "`data: null` 必須被讀成「沒有卡」，實際：\(error)"
            )
            if case .notFound = error.toDomainError() {
                XCTFail("這一格的前提變了：`data: null` 現在是 DomainError.notFound，判準可以簡化")
            }
        }
    }

    // MARK: - 清單一條的 identifier 帶著狀態

    /// 「按了接受之後那一條真的變了」在畫面上只有左側色條的差別——走查看得到、
    /// 自動化看不到。identifier 帶狀態才有東西擋著（同 `emptyStateIdentifier`）。
    func test_checklistItemIdentifier_carriesStatus() {
        XCTAssertEqual(
            App2WeeklyReviewView.checklistItemIdentifier(field: "weekly_km_pct", status: .proposed),
            "App2_WeeklyReviewChecklistItem_weekly_km_pct_proposed"
        )
        XCTAssertEqual(
            App2WeeklyReviewView.checklistItemIdentifier(field: "weekly_km_pct", status: .accepted),
            "App2_WeeklyReviewChecklistItem_weekly_km_pct_accepted"
        )
        XCTAssertEqual(
            App2WeeklyReviewView.checklistItemIdentifier(field: "pace_sec_per_km_delta", status: .declined),
            "App2_WeeklyReviewChecklistItem_pace_sec_per_km_delta_declined"
        )
        XCTAssertEqual(
            App2WeeklyReviewView.checklistItemIdentifier(field: "interval_reps", status: .adjusted),
            "App2_WeeklyReviewChecklistItem_interval_reps_adjusted"
        )
    }

    // MARK: - Helpers

    private func makeViewModel(
        reviewWeek: Int,
        planStatus: PlanStatusV2Response,
        isReadOnly: Bool = false,
        summaryAdjustments: [AdjustmentItemV2] = []
    ) -> App2WeeklyReviewViewModel {
        repository.planStatusToReturn = planStatus
        repository.weeklySummaryV2ToReturn = Self.summary(week: reviewWeek, adjustments: summaryAdjustments)
        repository.weeklyPlanV2ToReturn = nil
        return App2WeeklyReviewViewModel(
            weekOfPlan: reviewWeek,
            isReadOnly: isReadOnly,
            repository: repository,
            decisionChainRepository: decisionChain
        )
    }

    /// 已經拿到清單的頁面。
    private func readyViewModel() async -> App2WeeklyReviewViewModel {
        let viewModel = makeViewModel(reviewWeek: 4, planStatus: generatableStatus(currentWeek: 5))
        decisionChain.checklistToReturn = Self.checklist()
        decisionChain.intentCardToReturn = Self.intentCard()
        await viewModel.load()
        await viewModel.decisionChainTask?.value
        return viewModel
    }

    private func currentItem(
        _ viewModel: App2WeeklyReviewViewModel,
        _ itemId: String
    ) -> DecisionChainChecklistItem? {
        guard case .ready(let checklist, _) = viewModel.decisionChain else { return nil }
        return checklist.items.first { $0.itemId == itemId }
    }

    /// 目標週 ＝ `currentWeek`（平日流程）且本週還沒課表 ⇒ `.generate(week: currentWeek)`。
    private func generatableStatus(currentWeek: Int) -> PlanStatusV2Response {
        PlanStatusV2Response(
            currentWeek: currentWeek,
            totalWeeks: 22,
            nextAction: "create_plan",
            canGenerateNextWeek: false,
            currentWeekPlanId: nil,
            previousWeekSummaryId: nil,
            targetType: "race",
            methodologyId: "paceriz",
            nextWeekInfo: nil,
            metadata: nil
        )
    }

    private static func checklist() -> DecisionChainChecklist {
        DecisionChainChecklist(
            asOf: "2026-09-03",
            intentRevision: "intent/2026-09-03",
            intentLifecycle: "proposed",
            items: [
                DecisionChainChecklistItem(
                    itemId: "knob.weekly_km_pct@2026-09-03",
                    source: .intentKnob,
                    field: "weekly_km_pct",
                    current: .double(0),
                    proposed: .double(15),
                    title: "週跑量 +15%（48 → 55 km）",
                    reason: "維持並微幅增加訓練量以刺激有氧基礎提升。",
                    status: .proposed,
                    adjustedValue: nil
                ),
                DecisionChainChecklistItem(
                    itemId: "knob.rest_ratio@2026-09-03",
                    source: .intentKnob,
                    field: "rest_ratio",
                    current: nil,
                    proposed: .text("1:1"),
                    title: "間歇的工作與休息比改成 1:1",
                    reason: "縮短休息時間以刺激更深層的有氧適應。",
                    status: .proposed,
                    adjustedValue: nil
                ),
                DecisionChainChecklistItem(
                    itemId: "knob.interval_reps@2026-09-03",
                    source: .intentKnob,
                    field: "interval_reps",
                    current: nil,
                    proposed: .int(14),
                    title: "間歇趟數改成 14 趟",
                    reason: "趟數增加以刺激更深層的有氧適應。",
                    status: .proposed,
                    adjustedValue: nil
                )
            ]
        )
    }

    private static func adjustmentItem() -> AdjustmentItemV2 {
        AdjustmentItemV2(
            content: "把長跑往後挪一天",
            category: "schedule",
            apply: true,
            slotType: nil,
            trainingType: nil,
            reason: "週六有事",
            impact: "長跑落在週日",
            sourceFlag: nil,
            priority: "medium"
        )
    }

    private static func intentCard() -> DecisionChainIntentCard {
        DecisionChainIntentCard(
            lifecycle: "proposed",
            revision: "intent/2026-09-03",
            expression: DecisionChainIntentCard.Expression(
                pursuing: "這一段把重點放在有氧基礎。",
                maintaining: nil,
                abandoning: nil,
                rationale: "目前能力基線 38.27 VDOT 距離目標僅差 0.03 VDOT。"
            ),
            hypotheses: [
                DecisionChainIntentCard.Hypothesis(
                    hypothesisId: "hyp.state.capability_baseline@2026-09-03",
                    interventionDescription: "維持並微幅增加訓練量以刺激有氧基礎提升",
                    predictionDescription: "能力基線 VDOT 應會提升至 38.30 VDOT 或更高。"
                )
            ]
        )
    }

    private static func summary(week: Int, adjustments: [AdjustmentItemV2] = []) -> WeeklySummaryV2 {
        WeeklySummaryV2(
            id: "summary-1",
            uid: "user-1",
            weeklyPlanId: "plan-1",
            trainingOverviewId: "overview-1",
            weekOfTraining: week,
            createdAt: nil,
            planContext: nil,
            trainingCompletion: TrainingCompletionV2(
                percentage: 85.0,
                plannedKm: 40.0,
                completedKm: 34.0,
                plannedSessions: 4,
                completedSessions: 3,
                evaluation: "Good week"
            ),
            trainingAnalysis: TrainingAnalysisV2(
                heartRate: nil,
                pace: nil,
                distance: nil,
                intensityDistribution: nil
            ),
            readinessSummary: nil,
            capabilityProgression: nil,
            milestoneProgress: nil,
            historicalComparison: nil,
            weeklyHighlights: WeeklyHighlightsV2(
                highlights: ["Completed long run"],
                achievements: [],
                areasForImprovement: []
            ),
            upcomingRaceEvaluation: nil,
            nextWeekAdjustments: NextWeekAdjustmentsV2(
                items: adjustments,
                summary: "Increase volume slightly",
                methodologyConstraintsConsidered: true,
                basedOnFlags: [],
                userNlEdit: nil,
                userNlEditStatus: .none,
                userNlEditFailReason: nil
            ),
            restWeekRecommendation: nil,
            finalTrainingReview: nil,
            promptAuditId: nil,
            observations: nil,
            weeklyStory: nil
        )
    }
}

// MARK: - Fakes

/// 記下打了什麼、回什麼。**不是第二份實作**——它替的是同一個窄協定。
private final class FakeDecisionChainWeekRepository: DecisionChainWeekRepository {

    struct RunCall: Equatable {
        let asOf: String
        let weekOfTraining: Int
    }

    struct StanceCall: Equatable {
        let asOf: String
        let itemId: String
        let status: DecisionChainChecklistItem.Status
        let adjustedValue: DecisionChainValue?
    }

    private(set) var runCalls: [RunCall] = []
    private(set) var stanceCalls: [StanceCall] = []

    var runError: Error?
    var checklistToReturn: DecisionChainChecklist?
    var checklistError: Error?
    var intentCardToReturn: DecisionChainIntentCard?
    var intentCardError: Error?
    var stanceToReturn: DecisionChainChecklistItem?
    var stanceError: Error?

    func runDecisionChainWeek(asOf: String, weekOfTraining: Int) async throws -> DecisionChainWeekRun {
        runCalls.append(RunCall(asOf: asOf, weekOfTraining: weekOfTraining))
        if let runError { throw runError }
        return DecisionChainWeekRun(asOf: asOf, status: "generated")
    }

    func fetchDecisionChainChecklist(asOf: String) async throws -> DecisionChainChecklist? {
        if let checklistError { throw checklistError }
        return checklistToReturn
    }

    func recordDecisionChainChecklistStance(
        asOf: String,
        itemId: String,
        status: DecisionChainChecklistItem.Status,
        adjustedValue: DecisionChainValue?
    ) async throws -> DecisionChainChecklistItem {
        stanceCalls.append(
            StanceCall(asOf: asOf, itemId: itemId, status: status, adjustedValue: adjustedValue)
        )
        if let stanceError { throw stanceError }
        guard let stanceToReturn else {
            throw DomainError.notFound("fake 沒有設定回應")
        }
        return stanceToReturn
    }

    func fetchDecisionChainIntentCard() async throws -> DecisionChainIntentCard? {
        if let intentCardError { throw intentCardError }
        return intentCardToReturn
    }
}

/// 只為了讓額度檢查有東西可解析。狀態 `.none` ⇒ 沒有 `rizoUsage` ⇒ 不算耗盡。
private final class StubDecisionChainSubscriptionRepository: SubscriptionRepository {
    func getStatus() async throws -> SubscriptionStatusEntity { SubscriptionStatusEntity(status: .none) }
    func refreshStatus() async throws -> SubscriptionStatusEntity { SubscriptionStatusEntity(status: .none) }
    func getCachedStatus() -> SubscriptionStatusEntity? { nil }
    func clearCache() {}
    func fetchOfferings() async throws -> [SubscriptionOfferingEntity] { [] }
    func purchase(request: SubscriptionPurchaseRequest) async throws -> PurchaseResultEntity {
        throw NSError(domain: "Stub", code: 0)
    }
    func redeemOfferCode() async throws -> PurchaseResultEntity {
        throw NSError(domain: "Stub", code: 0)
    }
    func restorePurchases() async throws {}
}
