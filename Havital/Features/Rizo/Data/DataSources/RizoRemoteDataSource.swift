import Foundation

// MARK: - Rizo Remote Data Source
/// 負責從遠端 /v2/agent/* API 獲取 Rizo 數據。
/// Data Layer - Remote Data Source。
/// 每個呼叫包 tracked(...) → ResponseProcessor.extractData(DTO) → RizoMapper。
final class RizoRemoteDataSource {

    private struct SSEFrame {
        var event: String?
        var data: [String] = []
    }

    // MARK: - Properties

    private let httpClient: any HTTPClient
    private let parser: any APIParser

    // MARK: - Initialization

    init(httpClient: any HTTPClient = DefaultHTTPClient.shared,
         parser: any APIParser = DefaultAPIParser.shared) {
        self.httpClient = httpClient
        self.parser = parser
    }

    // MARK: - Chat

    /// 送出對話訊息。
    /// API: POST /v2/agent/chat
    func sendChat(
        scenario: String,
        message: String,
        sessionId: String?,
        workoutId: String?,
        presetSelections: [String]
    ) async throws -> RizoReply {
        let path = "/v2/agent/chat"

        Logger.debug("[RizoRemoteDataSource] sendChat - scenario: \(scenario), workoutId: \(workoutId ?? "nil")")

        let request = RizoChatRequest(
            scenario: scenario,
            message: message,
            sessionId: sessionId,
            workoutId: workoutId,
            presetSelections: presetSelections
        )
        let bodyData = try JSONEncoder().encode(request)

        let rawData = try await tracked("RizoRemoteDataSource: sendChat") {
            try await httpClient.request(path: path, method: .POST, body: bodyData)
        }
        let dto = try ResponseProcessor.extractData(RizoChatResponseDTO.self, from: rawData, using: parser)
        return RizoMapper.toReply(from: dto)
    }

    func streamChat(
        scenario: String,
        message: String,
        sessionId: String?,
        workoutId: String?,
        presetSelections: [String]
    ) -> AsyncThrowingStream<RizoChatUpdate, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = RizoChatRequest(scenario: scenario, message: message, sessionId: sessionId,
                                                  workoutId: workoutId, presetSelections: presetSelections)
                    let body = try JSONEncoder().encode(request)
                    let response = try await tracked("RizoRemoteDataSource: streamChat") {
                        try await httpClient.stream(
                            path: "/v2/agent/chat/stream", method: .POST, body: body,
                            customHeaders: ["Accept": "text/event-stream"]
                        )
                    }
                    if !response.contentType.hasPrefix("text/event-stream") {
                        var data = Data()
                        for try await byte in response.bytes { data.append(byte) }
                        let dto = try ResponseProcessor.extractData(RizoChatResponseDTO.self, from: data, using: parser)
                        continuation.yield(.final(RizoMapper.toReply(from: dto)))
                        continuation.finish()
                        return
                    }
                    var frame = SSEFrame()
                    var partial = ""
                    var line = Data()
                    for try await byte in response.bytes {
                        if byte == 10 {
                            var value = String(data: line, encoding: .utf8) ?? ""
                            if value.last == "\r" { value.removeLast() }
                            line.removeAll(keepingCapacity: true)
                            if value.isEmpty {
                                try Self.dispatch(frame: frame, partial: &partial) { continuation.yield($0) }
                                frame = SSEFrame()
                            } else if value.hasPrefix("event:") {
                                frame.event = value.dropFirst(6).trimmingCharacters(in: .whitespaces)
                            } else if value.hasPrefix("data:") {
                                frame.data.append(String(value.dropFirst(5)).trimmingCharacters(in: .whitespaces))
                            }
                        } else { line.append(byte) }
                    }
                    try Self.dispatch(frame: frame, partial: &partial) { continuation.yield($0) }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch let error as URLError where error.code == .cancelled {
                    continuation.finish(throwing: CancellationError())
                } catch let error as HTTPError where error.statusCode == 404 || error.statusCode == 405 {
                    do {
                        let reply = try await self.sendChat(
                            scenario: scenario,
                            message: message,
                            sessionId: sessionId,
                            workoutId: workoutId,
                            presetSelections: presetSelections
                        )
                        continuation.yield(.final(reply))
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func parseSSE(_ data: Data, emit: (RizoChatUpdate) -> Void) throws {
        guard let text = String(data: data, encoding: .utf8) else { throw RizoRepositoryError.invalidDataFormat("SSE UTF-8") }
        var partial = ""
        var frame = SSEFrame()
        for rawLine in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            if rawLine.isEmpty { try dispatch(frame: frame, partial: &partial, emit: emit); frame = SSEFrame() }
            else if rawLine.hasPrefix("event:") { frame.event = rawLine.dropFirst(6).trimmingCharacters(in: .whitespaces) }
            else if rawLine.hasPrefix("data:") { frame.data.append(String(rawLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)) }
        }
        try dispatch(frame: frame, partial: &partial, emit: emit)
    }

    private static func dispatch(frame: SSEFrame, partial: inout String,
                                 emit: (RizoChatUpdate) -> Void) throws {
        guard let event = frame.event, !frame.data.isEmpty else { return }
        let payload = Data(frame.data.joined(separator: "\n").utf8)
        let object = try JSONSerialization.jsonObject(with: payload) as? [String: Any] ?? [:]
        switch event {
        case "delta": partial += object["text"] as? String ?? ""; emit(.partial(partial))
        case "reset": partial = ""; emit(.partial(""))
        case "final":
            let wrapper = try JSONSerialization.data(withJSONObject: object)
            let dto = try ResponseProcessor.extractData(RizoChatResponseDTO.self, from: wrapper, using: DefaultAPIParser.shared)
            emit(.final(RizoMapper.toReply(from: dto)))
        case "error": throw RizoRepositoryError.dataSourceUnavailable
        default: break
        }
    }

    // MARK: - Plan Change

    /// 確認並套用先前提出的改課表提案。
    /// API: POST /v2/agent/plan-change/confirm
    func confirmPlanChange(proposalId: String) async throws -> PlanChangeConfirmResult {
        let path = "/v2/agent/plan-change/confirm"

        Logger.debug("[RizoRemoteDataSource] confirmPlanChange - proposalId: \(proposalId)")

        let bodyData = try JSONEncoder().encode(["proposal_id": proposalId])

        let rawData = try await tracked("RizoRemoteDataSource: confirmPlanChange") {
            try await httpClient.request(path: path, method: .POST, body: bodyData)
        }
        let dto = try ResponseProcessor.extractData(PlanChangeConfirmResponseDTO.self, from: rawData, using: parser)
        return RizoMapper.toConfirmResult(from: dto)
    }

    // MARK: - Presets

    /// 取得指定情境的預設快捷選項。
    /// API: GET /v2/agent/presets?scenario=...
    func fetchPresets(scenario: String) async throws -> [RizoPreset] {
        let path = URLBuilderHelper.buildPath(
            "/v2/agent/presets",
            queryItems: [URLQueryItem(name: "scenario", value: scenario)]
        )

        Logger.debug("[RizoRemoteDataSource] fetchPresets - path: \(path)")

        let rawData = try await tracked("RizoRemoteDataSource: fetchPresets") {
            try await httpClient.request(path: path, method: .GET, body: nil)
        }
        let dto = try ResponseProcessor.extractData(RizoPresetsResponseDTO.self, from: rawData, using: parser)
        return RizoMapper.toPresets(from: dto)
    }

    // MARK: - History

    /// 取得歷史對話清單。
    /// API: GET /v2/agent/history
    func fetchHistory() async throws -> [RizoHistoryItem] {
        let path = "/v2/agent/history"

        Logger.debug("[RizoRemoteDataSource] fetchHistory")

        let rawData = try await tracked("RizoRemoteDataSource: fetchHistory") {
            try await httpClient.request(path: path, method: .GET, body: nil)
        }
        let dto = try ResponseProcessor.extractData(RizoHistoryResponseDTO.self, from: rawData, using: parser)
        return RizoMapper.toHistory(from: dto)
    }

    /// 以已擁有的歷史 session 某一回合為錨點建立新 session；不重播 LLM。
    /// API: POST /v2/agent/history/fork
    func forkHistory(sourceSessionId: String, throughTurnIndex: Int) async throws -> RizoHistoryFork {
        let path = "/v2/agent/history/fork"
        let request = RizoHistoryForkRequest(
            sourceSessionId: sourceSessionId,
            throughTurnIndex: throughTurnIndex
        )
        let bodyData = try JSONEncoder().encode(request)
        let rawData = try await tracked("RizoRemoteDataSource: forkHistory") {
            try await httpClient.request(path: path, method: .POST, body: bodyData)
        }
        let dto = try ResponseProcessor.extractData(
            RizoHistoryForkResponseDTO.self, from: rawData, using: parser
        )
        return RizoMapper.toHistoryFork(from: dto)
    }
}
