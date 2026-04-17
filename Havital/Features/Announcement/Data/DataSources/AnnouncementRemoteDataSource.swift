import Foundation

final class AnnouncementRemoteDataSource {

    // MARK: - Endpoints

    private enum Endpoint {
        static let list = "/v2/announcements"
        static func seen(_ id: String) -> String { "/v2/announcements/\(id)/seen" }
        static let seenBatch = "/v2/announcements/seen-batch"
    }

    // MARK: - Dependencies

    private let httpClient: HTTPClient
    private let parser: APIParser

    // MARK: - Initialization

    init(
        httpClient: HTTPClient = DefaultHTTPClient.shared,
        parser: APIParser = DefaultAPIParser.shared
    ) {
        self.httpClient = httpClient
        self.parser = parser
    }

    // MARK: - API Methods

    func fetchAnnouncements() async throws -> [AnnouncementDTO] {
        let rawData = try await tracked("AnnouncementRemoteDataSource: fetchAnnouncements") {
            try await httpClient.request(path: Endpoint.list, method: .GET)
        }
        let response = try ResponseProcessor.extractData(
            AnnouncementListResponse.self, from: rawData, using: parser
        )
        return response.announcements
    }

    func markSeen(id: String) async throws {
        _ = try await tracked("AnnouncementRemoteDataSource: markSeen") {
            try await httpClient.request(path: Endpoint.seen(id), method: .POST)
        }
    }

    func markSeenBatch(ids: [String]) async throws {
        let body = try JSONEncoder().encode(SeenBatchRequest(announcementIds: ids))
        _ = try await tracked("AnnouncementRemoteDataSource: markSeenBatch") {
            try await httpClient.request(path: Endpoint.seenBatch, method: .POST, body: body)
        }
    }
}
