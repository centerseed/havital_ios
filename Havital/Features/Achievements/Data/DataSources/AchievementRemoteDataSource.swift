import Foundation

final class AchievementRemoteDataSource {

    private enum Endpoint {
        static let summary = "/v2/achievements/summary"
        static func feedbackSeen(_ feedbackId: String) -> String {
            "/v2/achievements/feedback/\(feedbackId)/seen"
        }
        static let backfillAck = "/v2/achievements/backfill/ack"
    }

    private let httpClient: HTTPClient
    private let parser: APIParser

    init(
        httpClient: HTTPClient = DefaultHTTPClient.shared,
        parser: APIParser = DefaultAPIParser.shared
    ) {
        self.httpClient = httpClient
        self.parser = parser
    }

    func fetchSummary() async throws -> AchievementSummaryResponse {
        Self.diagnostic("fetchSummary start path=\(Endpoint.summary)")
        let rawData: Data
        do {
            rawData = try await tracked("AchievementRemoteDataSource: fetchSummary") {
                try await httpClient.request(path: Endpoint.summary, method: .GET)
            }
        } catch {
            Self.diagnostic("fetchSummary request failed path=\(Endpoint.summary) error=\(Self.describe(error))", level: .error)
            Self.cloudFailure(
                stage: "request",
                path: Endpoint.summary,
                error: error
            )
            throw error
        }

        Self.diagnostic("fetchSummary raw bytes=\(rawData.count) preview=\(Self.preview(rawData))", level: .debug)
        do {
            let response = try ResponseProcessor.extractData(
                AchievementSummaryResponse.self,
                from: rawData,
                using: parser
            )
            Self.diagnostic(
                "fetchSummary decoded catalog=\(response.catalogVersion) groups=\(response.badgeGroups.count) badges=\(response.badgeGroups.reduce(0) { $0 + $1.badges.count })"
            )
            return response
        } catch {
            Self.diagnostic("fetchSummary decode failed path=\(Endpoint.summary) error=\(Self.describe(error)) raw=\(Self.preview(rawData, limit: 2000))", level: .error)
            Self.cloudFailure(
                stage: "decode",
                path: Endpoint.summary,
                error: error,
                responseByteCount: rawData.count
            )
            throw error
        }
    }

    func markFeedbackSeen(feedbackId: String) async throws {
        _ = try await tracked("AchievementRemoteDataSource: markFeedbackSeen") {
            try await httpClient.request(path: Endpoint.feedbackSeen(feedbackId), method: .POST)
        }
    }

    func ackBackfill() async throws {
        _ = try await tracked("AchievementRemoteDataSource: ackBackfill") {
            try await httpClient.request(path: Endpoint.backfillAck, method: .POST)
        }
    }

    private static func diagnostic(_ message: String, level: LogLevel = .info) {
        let output = "[AchievementsAPI] \(message)"
        print(output)
        Logger.log(output, level: level)
    }

    private static func cloudFailure(
        stage: String,
        path: String,
        error: Error,
        responseByteCount: Int? = nil
    ) {
        var payload: [String: Any] = [
            "stage": stage,
            "path": path,
            "error_type": String(describing: type(of: error)),
            "error": describe(error)
        ]
        if let responseByteCount {
            payload["response_byte_count"] = responseByteCount
        }

        Logger.firebase(
            "Achievements summary load failed",
            level: .error,
            labels: [
                "cloud_logging": "true",
                "component": "Achievements",
                "operation": "fetch_summary",
                "stage": stage
            ],
            jsonPayload: payload
        )
    }

    private static func preview(_ data: Data, limit: Int = 600) -> String {
        guard let raw = String(data: data, encoding: .utf8) else {
            return "<non-utf8>"
        }
        guard raw.count > limit else { return raw }
        return "\(raw.prefix(limit))...<truncated \(raw.count - limit) chars>"
    }

    private static func describe(_ error: Error) -> String {
        if let decodingError = error as? DecodingError {
            return describe(decodingError)
        }
        if let apiError = error as? APIError {
            return "\(apiError.errorCode): \(apiError.localizedDescription)"
        }
        if let httpError = error as? HTTPError {
            return "HTTPError(status=\(httpError.statusCode.map(String.init) ?? "nil")) \(httpError.localizedDescription)"
        }
        return "\(type(of: error)): \(error.localizedDescription)"
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            return "DecodingError.keyNotFound key=\(key.stringValue) path=\(path(context.codingPath)) debug=\(context.debugDescription)"
        case .typeMismatch(let type, let context):
            return "DecodingError.typeMismatch type=\(type) path=\(path(context.codingPath)) debug=\(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "DecodingError.valueNotFound type=\(type) path=\(path(context.codingPath)) debug=\(context.debugDescription)"
        case .dataCorrupted(let context):
            return "DecodingError.dataCorrupted path=\(path(context.codingPath)) debug=\(context.debugDescription)"
        @unknown default:
            return "DecodingError.unknown \(error.localizedDescription)"
        }
    }

    private static func path(_ codingPath: [CodingKey]) -> String {
        guard !codingPath.isEmpty else { return "<root>" }
        return codingPath.map(\.stringValue).joined(separator: ".")
    }
}
