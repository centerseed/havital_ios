// Havital/Services/GarminService.swift
import Foundation

/// Garmin integration service
/// Uses APICallHelper for unified error handling
final class GarminService {
    static let shared = GarminService()

    // MARK: - Dependencies

    private let apiHelper: APICallHelper

    private init(httpClient: HTTPClient = DefaultHTTPClient.shared,
                 parser: APIParser = DefaultAPIParser.shared) {
        self.apiHelper = APICallHelper(
            httpClient: httpClient,
            parser: parser,
            moduleName: "GarminService"
        )
    }
}

// MARK: - BackfillServiceProtocol Implementation

extension GarminService: BackfillServiceProtocol {
    /// 觸發 Garmin Backfill
    func triggerBackfill(startDate: String, days: Int) async throws -> BackfillResponse {
        Logger.debug("[GarminService] Triggering Backfill: startDate=\(startDate), days=\(days)")

        return try await apiHelper.post(
            BackfillResponse.self,
            path: "/garmin/backfill",
            bodyDict: [
                "start_date": startDate,
                "days": days
            ]
        )
    }

    /// 查詢 Backfill 狀態
    func getBackfillStatus(backfillId: String) async throws -> BackfillStatusResponse {
        Logger.debug("[GarminService] Querying Backfill status: backfillId=\(backfillId)")

        return try await apiHelper.get(
            BackfillStatusResponse.self,
            path: "/garmin/backfill/\(backfillId)"
        )
    }
}
