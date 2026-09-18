import XCTest
@testable import paceriz_dev

/// Rizo Data Layer 單元測試（S01 AC stub）。
/// 涵蓋：
/// 1. RizoChatRequest 編碼成 snake_case JSON。
/// 2. RizoChatResponseDTO 從後端樣本 JSON decode + RizoMapper → RizoReply。
/// 3. RizoRemoteDataSource.sendJournalChat 打對 path / method / body。
///
/// Mock 邊界：MockHTTPClient / MockAPIParser 為純測試替身（無外部付費服務 / LLM）。
final class RizoDataLayerTests: XCTestCase {

    private var mockHTTPClient: MockHTTPClient!
    private var mockParser: MockAPIParser!
    private var sut: RizoRemoteDataSource!

    override func setUp() {
        super.setUp()
        mockHTTPClient = MockHTTPClient()
        mockParser = MockAPIParser()
        sut = RizoRemoteDataSource(httpClient: mockHTTPClient, parser: mockParser)
    }

    override func tearDown() {
        mockHTTPClient.reset()
        mockParser.reset()
        sut = nil
        mockParser = nil
        mockHTTPClient = nil
        super.tearDown()
    }

    // MARK: - 1. Request encodes to snake_case

    func testChatRequestEncodesSnakeCaseKeys() throws {
        let request = RizoChatRequest(
            scenario: "journal",
            message: "今天跑得很累",
            sessionId: "sess-123",
            workoutId: "wk-456",
            presetSelections: ["too_tired", "pace_off"]
        )

        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(json["scenario"] as? String, "journal")
        XCTAssertEqual(json["message"] as? String, "今天跑得很累")
        XCTAssertEqual(json["session_id"] as? String, "sess-123")
        XCTAssertEqual(json["workout_id"] as? String, "wk-456")
        XCTAssertEqual(json["preset_selections"] as? [String], ["too_tired", "pace_off"])

        // 確認沒有 camelCase 殘留
        XCTAssertNil(json["sessionId"])
        XCTAssertNil(json["workoutId"])
        XCTAssertNil(json["presetSelections"])
    }

    // MARK: - 2. Response DTO decode + Mapper

    func testChatResponseDTODecodesAndMapsToEntity() throws {
        let sampleJSON = """
        {
            "response": "聽起來你今天很疲勞，先恢復一下。",
            "session_id": "sess-789",
            "quota": {
                "allowed": true,
                "used": 2,
                "limit": 5,
                "remaining": 3,
                "resets_at": "2026-06-06T00:00:00Z",
                "reserved": true
            },
            "safety": {
                "danger_class": "none",
                "canned": false
            }
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(RizoChatResponseDTO.self, from: sampleJSON)

        XCTAssertEqual(dto.response, "聽起來你今天很疲勞，先恢復一下。")
        XCTAssertEqual(dto.sessionId, "sess-789")
        XCTAssertEqual(dto.quota.used, 2)
        XCTAssertEqual(dto.quota.limit, 3 + 2)
        XCTAssertEqual(dto.quota.resetsAt, "2026-06-06T00:00:00Z")
        XCTAssertTrue(dto.quota.reserved)
        XCTAssertEqual(dto.safety.dangerClass, "none")
        XCTAssertFalse(dto.safety.canned)

        // Mapper → Entity
        let reply = RizoMapper.toReply(from: dto)
        XCTAssertEqual(reply.reply, "聽起來你今天很疲勞，先恢復一下。")
        XCTAssertEqual(reply.sessionId, "sess-789")
        XCTAssertTrue(reply.quota.allowed)
        XCTAssertEqual(reply.quota.used, 2)
        XCTAssertEqual(reply.quota.limit, 5)
        XCTAssertEqual(reply.quota.remaining, 3)
        XCTAssertEqual(reply.quota.resetsAt, "2026-06-06T00:00:00Z")
        XCTAssertTrue(reply.quota.reserved)
        XCTAssertEqual(reply.safety.dangerClass, "none")
        XCTAssertFalse(reply.safety.canned)
    }

    func testQuotaDecodesNullableFieldsAsNil() throws {
        let sampleJSON = """
        {
            "response": "無限方案回覆",
            "session_id": "sess-unlimited",
            "quota": {
                "allowed": true,
                "used": 10,
                "limit": null,
                "remaining": null,
                "resets_at": null,
                "reserved": false
            },
            "safety": { "danger_class": "none", "canned": false }
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(RizoChatResponseDTO.self, from: sampleJSON)
        let reply = RizoMapper.toReply(from: dto)

        XCTAssertNil(reply.quota.limit)
        XCTAssertNil(reply.quota.remaining)
        XCTAssertNil(reply.quota.resetsAt)
        XCTAssertEqual(reply.quota.used, 10)
    }

    // MARK: - 3. RemoteDataSource hits correct path / method / body

    func testSendJournalChatHitsChatEndpoint() async throws {
        // 後端回應走標準 success_response 包裝。
        let wrappedJSON = """
        {
            "success": true,
            "data": {
                "response": "好的，繼續加油！",
                "session_id": "sess-abc",
                "quota": {
                    "allowed": true, "used": 1, "limit": 5,
                    "remaining": 4, "resets_at": null, "reserved": true
                },
                "safety": { "danger_class": "none", "canned": false }
            }
        }
        """.data(using: .utf8)!
        mockHTTPClient.setResponse(for: "/v2/agent/chat", method: .POST, data: wrappedJSON)

        let reply = try await sut.sendChat(
            scenario: "journal",
            message: "今天 LSD 完成",
            sessionId: nil,
            workoutId: "wk-001",
            presetSelections: ["felt_good"]
        )

        // 回應正確映射
        XCTAssertEqual(reply.reply, "好的，繼續加油！")
        XCTAssertEqual(reply.sessionId, "sess-abc")
        XCTAssertEqual(reply.quota.remaining, 4)

        // path / method
        let last = try XCTUnwrap(mockHTTPClient.lastRequest)
        XCTAssertEqual(last.path, "/v2/agent/chat")
        XCTAssertEqual(last.method, .POST)

        // body 為 snake_case JSON，含正確欄位
        let body = try XCTUnwrap(last.body)
        let bodyJSON = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        XCTAssertEqual(bodyJSON["scenario"] as? String, "journal")
        XCTAssertEqual(bodyJSON["message"] as? String, "今天 LSD 完成")
        XCTAssertEqual(bodyJSON["workout_id"] as? String, "wk-001")
        XCTAssertEqual(bodyJSON["preset_selections"] as? [String], ["felt_good"])
    }

    func testFetchPresetsHitsPresetsEndpointWithScenarioQuery() async throws {
        let wrappedJSON = """
        {
            "success": true,
            "data": {
                "scenario": "journal",
                "presets": [
                    { "id": "p1", "category": "feeling", "danger_class": "none", "label": "今天很累" }
                ]
            }
        }
        """.data(using: .utf8)!
        mockHTTPClient.setResponse(for: "/v2/agent/presets?scenario=journal", method: .GET, data: wrappedJSON)

        let presets = try await sut.fetchPresets(scenario: "journal")

        XCTAssertEqual(presets.count, 1)
        XCTAssertEqual(presets.first?.id, "p1")
        XCTAssertEqual(presets.first?.category, "feeling")
        XCTAssertEqual(presets.first?.dangerClass, "none")
        XCTAssertEqual(presets.first?.label, "今天很累")

        let last = try XCTUnwrap(mockHTTPClient.lastRequest)
        XCTAssertEqual(last.path, "/v2/agent/presets?scenario=journal")
        XCTAssertEqual(last.method, .GET)
        XCTAssertNil(last.body)
    }

    func testForkHistoryPostsAnchorAndMapsNewSessionPrefix() async throws {
        let wrappedJSON = """
        {
          "success": true,
          "data": {
            "session_id": "fork-new",
            "scenario": "body_status",
            "turns": [{
              "session_id": "fork-new",
              "ts": "2026-07-20T01:00:00+00:00",
              "scenario": "body_status",
              "user_input": "How was yesterday's run?",
              "rizo_response": "You completed 5 km yesterday."
            }]
          }
        }
        """.data(using: .utf8)!
        mockHTTPClient.setResponse(
            for: "/v2/agent/history/fork", method: .POST, data: wrappedJSON
        )

        let fork = try await sut.forkHistory(
            sourceSessionId: "source-old", throughTurnIndex: 0
        )

        XCTAssertEqual(fork.sessionId, "fork-new")
        XCTAssertEqual(fork.scenario, "body_status")
        XCTAssertEqual(fork.turns.map(\.userInput), ["How was yesterday's run?"])
        let request = try XCTUnwrap(mockHTTPClient.lastRequest)
        XCTAssertEqual(request.path, "/v2/agent/history/fork")
        XCTAssertEqual(request.method, .POST)
        let body = try XCTUnwrap(request.body)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["source_session_id"] as? String, "source-old")
        XCTAssertEqual(json["through_turn_index"] as? Int, 0)
    }

    // MARK: - #1 structured diff_days

    func testPendingPlanChangeDecodesDiffDays() throws {
        let json = """
        {
          "response": "建議減量",
          "session_id": "s1",
          "quota": {"allowed": true, "used": 1, "limit": null, "remaining": null, "resets_at": null, "reserved": false},
          "safety": {"danger_class": "none", "canned": false},
          "pending_plan_change": {
            "proposal_id": "rpc_1",
            "summary": "Day6: lsd 15km -> lsd 12km",
            "safety_level": "none",
            "requires_subscription": true,
            "diff_days": [
              {"day_index": 6,
               "from": {"category": "run", "run_type": "lsd", "distance_km": 15.0},
               "to": {"category": "run", "run_type": "lsd", "distance_km": 12.0}}
            ]
          }
        }
        """
        let dto = try JSONDecoder().decode(RizoChatResponseDTO.self, from: Data(json.utf8))
        let reply = RizoMapper.toReply(from: dto)
        XCTAssertEqual(reply.pendingPlanChange?.diffDays?.count, 1)
        XCTAssertEqual(reply.pendingPlanChange?.diffDays?.first?.dayIndex, 6)
        XCTAssertEqual(reply.pendingPlanChange?.diffDays?.first?.to?.distanceKm, 12.0)
        XCTAssertEqual(reply.pendingPlanChange?.diffDays?.first?.from?.runType, "lsd")
    }

    func testPendingPlanChangeWithoutDiffDaysIsNil() throws {
        let json = """
        {"response":"x","session_id":"s1",
         "quota":{"allowed":true,"used":1,"limit":null,"remaining":null,"resets_at":null,"reserved":false},
         "safety":{"danger_class":"none","canned":false},
         "pending_plan_change":{"proposal_id":"rpc_2","summary":"x","safety_level":"none","requires_subscription":true}}
        """
        let dto = try JSONDecoder().decode(RizoChatResponseDTO.self, from: Data(json.utf8))
        let reply = RizoMapper.toReply(from: dto)
        XCTAssertNil(reply.pendingPlanChange?.diffDays)
    }

    /// SPEC-rizo-coach §4.2a：這一輪寫進已生成週才帶 plan_change_applied: true。
    func testChatResponseMapsPlanChangeAppliedTrue() throws {
        let json = """
        {"response":"applied","session_id":"s1",
         "quota":{"allowed":true,"used":1,"limit":null,"remaining":null,"resets_at":null,"reserved":false},
         "safety":{"danger_class":"none","canned":false},
         "plan_change_applied":true}
        """
        let dto = try JSONDecoder().decode(RizoChatResponseDTO.self, from: Data(json.utf8))
        let reply = RizoMapper.toReply(from: dto)
        XCTAssertEqual(dto.planChangeApplied, true)
        XCTAssertTrue(reply.planChangeApplied)
    }

    func testChatResponseOmitsPlanChangeAppliedWhenAbsent() throws {
        let json = """
        {"response":"just chatting","session_id":"s1",
         "quota":{"allowed":true,"used":1,"limit":null,"remaining":null,"resets_at":null,"reserved":false},
         "safety":{"danger_class":"none","canned":false}}
        """
        let dto = try JSONDecoder().decode(RizoChatResponseDTO.self, from: Data(json.utf8))
        let reply = RizoMapper.toReply(from: dto)
        XCTAssertNil(dto.planChangeApplied)
        XCTAssertFalse(reply.planChangeApplied)
    }

    func testSSEDeltaResetAndFinalUsesAuthoritativeResponse() throws {
        let sse = """
        event: delta\r
        data: {"text":"old"}\r
        \r
        event: reset\r
        data: {}\r
        \r
        event: delta\r
        data: {"text":"new"}\r
        \r
        event: final\r
        data: {"success":true,"data":{"response":"new final","session_id":"s1","quota":{"allowed":true,"used":1,"limit":null,"remaining":null,"resets_at":null,"reserved":false},"safety":{"danger_class":"none","canned":false}}}\r
        \r
        """
        var partials: [String] = []
        var final: RizoReply?
        try RizoRemoteDataSource.parseSSE(Data(sse.utf8)) { update in
            switch update {
            case .partial(let text): partials.append(text)
            case .final(let reply): final = reply
            }
        }
        XCTAssertEqual(partials, ["old", "", "new"])
        XCTAssertEqual(final?.reply, "new final")
        XCTAssertEqual(final?.sessionId, "s1")
    }

    func testSSESupportsMultilineDataAndTrailingFrameWithoutBlankLine() throws {
        let sse = "event: delta\ndata: {\ndata: \"text\": \"hi\"\ndata: }"
        var partials: [String] = []
        try RizoRemoteDataSource.parseSSE(Data(sse.utf8)) { update in
            if case .partial(let text) = update { partials.append(text) }
        }
        XCTAssertEqual(partials, ["hi"])
    }

    func testStreamEndpointMissingFallsBackToLegacyChat() async throws {
        let wrappedJSON = """
        {"success":true,"data":{"response":"Legacy answer","session_id":"s3","quota":{"allowed":true,"used":1,"limit":null,"remaining":null,"resets_at":null,"reserved":false},"safety":{"danger_class":"none","canned":false}}}
        """.data(using: .utf8)!
        mockHTTPClient.setError(
            for: "/v2/agent/chat/stream",
            method: .POST,
            error: HTTPError.notFound("stream endpoint missing")
        )
        mockHTTPClient.setResponse(for: "/v2/agent/chat", method: .POST, data: wrappedJSON)

        var updates: [RizoChatUpdate] = []
        for try await update in sut.streamChat(
            scenario: "body_status",
            message: "hello",
            sessionId: nil,
            workoutId: nil,
            presetSelections: []
        ) {
            updates.append(update)
        }

        guard case .final(let reply) = updates.first else {
            return XCTFail("Expected one legacy final reply")
        }
        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(reply.reply, "Legacy answer")
        XCTAssertTrue(mockHTTPClient.wasPathCalled("/v2/agent/chat/stream", method: .POST))
        XCTAssertTrue(mockHTTPClient.wasPathCalled("/v2/agent/chat", method: .POST))
    }
}
