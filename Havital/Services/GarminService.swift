// Havital/Services/GarminService.swift
import Foundation

final class GarminService {
    static let shared = GarminService()

    // MARK: - Dependencies
    private let httpClient: HTTPClient
    private let parser: APIParser

    private init(httpClient: HTTPClient = DefaultHTTPClient.shared,
                 parser: APIParser = DefaultAPIParser.shared) {
        self.httpClient = httpClient
        self.parser = parser
    }

    // MARK: - Unified API Call Method

    /// 統一的 API 調用方法
    private func makeAPICall<T: Codable>(
        _ type: T.Type,
        path: String,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) async throws -> T {
        do {
            let rawData = try await httpClient.request(path: path, method: method, body: body)
            return try ResponseProcessor.extractData(type, from: rawData, using: parser)
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        } catch {
            throw error
        }
    }
}

// MARK: - BackfillService Implementation

extension GarminService: BackfillService {
    /// 觸發 Garmin Backfill
    func triggerBackfill(startDate: String, days: Int) async throws -> BackfillResponse {
        let body: [String: Any] = [
            "start_date": startDate,
            "days": days
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        Logger.debug("[GarminService] 📤 觸發 Backfill: startDate=\(startDate), days=\(days)")

        return try await makeAPICall(
            BackfillResponse.self,
            path: "/garmin/backfill",
            method: .POST,
            body: bodyData
        )
    }

    /// 查詢 Backfill 狀態
    func getBackfillStatus(backfillId: String) async throws -> BackfillStatusResponse {
        Logger.debug("[GarminService] 🔍 查詢 Backfill 狀態: backfillId=\(backfillId)")

        return try await makeAPICall(
            BackfillStatusResponse.self,
            path: "/garmin/backfill/\(backfillId)",
            method: .GET
        )
    }
}
