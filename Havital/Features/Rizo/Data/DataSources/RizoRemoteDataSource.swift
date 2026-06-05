import Foundation

// MARK: - Rizo Remote Data Source
/// 負責從遠端 /v2/agent/* API 獲取 Rizo 數據。
/// Data Layer - Remote Data Source。
/// 每個呼叫包 tracked(...) → ResponseProcessor.extractData(DTO) → RizoMapper。
final class RizoRemoteDataSource {

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
}
