import Foundation

// MARK: - HeartRateRecomputeRepositoryImpl
/// Data Layer - 純 HTTP，沒有快取（進度要看即時的）。
final class HeartRateRecomputeRepositoryImpl: HeartRateRecomputeRepository {

    private let httpClient: HTTPClient
    private let parser: APIParser

    init(httpClient: HTTPClient = DefaultHTTPClient.shared, parser: APIParser = DefaultAPIParser.shared) {
        self.httpClient = httpClient
        self.parser = parser
    }

    // MARK: - Wire shapes

    private struct StartPayload: Decodable {
        let outcome: String
        let job: HeartRateRecomputeJob?
        let message: String?
    }

    private struct StatusPayload: Decodable {
        let job: HeartRateRecomputeJob?
        let message: String?
    }

    private struct WatchCheckPayload: Decodable {
        let reminder: HeartRateWatchReminder?
        let autoUpdate: HeartRateWatchAutoUpdate?

        enum CodingKeys: String, CodingKey {
            case reminder
            case autoUpdate = "auto_update"
        }
    }

    private struct Envelope<T: Decodable>: Decodable {
        let data: T
    }

    private func decode<T: Decodable>(_ type: T.Type, from raw: Data) throws -> T {
        try JSONDecoder().decode(Envelope<T>.self, from: raw).data
    }

    // MARK: - API

    func startRecompute(days: HeartRateRecomputeDays) async throws -> HeartRateRecomputeOutcome {
        let body = try JSONSerialization.data(withJSONObject: ["days": days.rawValue])
        do {
            let raw = try await tracked("HeartRateRecomputeRepository: startRecompute") {
                try await httpClient.request(path: "/user/heart-rate/recompute", method: .POST, body: body)
            }
            return try Self.outcome(from: decode(StartPayload.self, from: raw))
        } catch HTTPError.httpError(let status, let errorBody) where status == 409 || status == 422 {
            // 這兩個是後端的正常回答（進行中／沒設心率），body 與成功回應同形。
            let payload = try decode(StartPayload.self, from: Data(errorBody.utf8))
            return try Self.outcome(from: payload)
        }
    }

    func latestStatus() async throws -> HeartRateRecomputeStatus {
        let raw = try await tracked("HeartRateRecomputeRepository: latestStatus") {
            try await httpClient.request(path: "/user/heart-rate/recompute", method: .GET)
        }
        let payload = try decode(StatusPayload.self, from: raw)
        return HeartRateRecomputeStatus(job: payload.job, message: payload.message)
    }

    func watchCheck() async throws -> HeartRateWatchCheck {
        let raw = try await tracked("HeartRateRecomputeRepository: watchCheck") {
            try await httpClient.request(path: "/user/heart-rate/watch-check", method: .GET)
        }
        let payload = try decode(WatchCheckPayload.self, from: raw)
        return HeartRateWatchCheck(reminder: payload.reminder, autoUpdate: payload.autoUpdate)
    }

    func dismissWatchReminder() async throws {
        _ = try await tracked("HeartRateRecomputeRepository: dismissWatchReminder") {
            try await httpClient.request(path: "/user/heart-rate/watch-check/dismiss", method: .POST, body: nil)
        }
    }

    private static func outcome(from payload: StartPayload) throws -> HeartRateRecomputeOutcome {
        switch payload.outcome {
        case "queued":
            guard let job = payload.job else { throw HTTPError.invalidResponse("queued without job") }
            return .queued(job: job, message: payload.message)
        case "already_running":
            guard let job = payload.job else { throw HTTPError.invalidResponse("already_running without job") }
            return .alreadyRunning(job: job, message: payload.message)
        case "nothing_to_recompute":
            return .nothingToRecompute(message: payload.message)
        case "no_hr_params":
            return .noHeartRateParameters(message: payload.message)
        default:
            throw HTTPError.invalidResponse("unknown recompute outcome \(payload.outcome)")
        }
    }
}
