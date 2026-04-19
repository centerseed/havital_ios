import XCTest
@testable import paceriz_dev

final class AnnouncementRemoteDataSourceTests: XCTestCase {
    private var mockHTTPClient: MockHTTPClient!
    private var mockParser: MockAPIParser!
    private var sut: AnnouncementRemoteDataSource!

    override func setUp() {
        super.setUp()
        mockHTTPClient = MockHTTPClient()
        mockParser = MockAPIParser()
        sut = AnnouncementRemoteDataSource(httpClient: mockHTTPClient, parser: mockParser)
    }

    override func tearDown() {
        mockHTTPClient.reset()
        mockParser.reset()
        sut = nil
        mockParser = nil
        mockHTTPClient = nil
        super.tearDown()
    }

    func testFetchAnnouncementsUsesListEndpoint() async throws {
        let json = """
        {
          "announcements": [
            {
              "id": "ann_1",
              "title": "Announcement",
              "body": "Body",
              "published_at": "2026-04-19T10:00:00Z",
              "is_seen": false
            }
          ]
        }
        """
        mockHTTPClient.setResponse(for: "/v2/announcements", data: Data(json.utf8))

        let result = try await sut.fetchAnnouncements()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "ann_1")
        XCTAssertTrue(mockHTTPClient.wasPathCalled("/v2/announcements", method: .GET))
    }

    func testMarkSeenUsesPostEndpointForSingleAnnouncement() async throws {
        mockHTTPClient.setResponse(for: "/v2/announcements/ann_1/seen", method: .POST, data: Data())

        try await sut.markSeen(id: "ann_1")

        XCTAssertTrue(mockHTTPClient.wasPathCalled("/v2/announcements/ann_1/seen", method: .POST))
    }

    func testMarkSeenBatchEncodesAnnouncementIds() async throws {
        mockHTTPClient.setResponse(for: "/v2/announcements/seen-batch", method: .POST, data: Data())

        try await sut.markSeenBatch(ids: ["a1", "a2"])

        XCTAssertTrue(mockHTTPClient.wasPathCalled("/v2/announcements/seen-batch", method: .POST))
        let body = try XCTUnwrap(mockHTTPClient.lastRequest?.body)
        let request = try JSONDecoder().decode(SeenBatchRequest.self, from: body)
        XCTAssertEqual(request.announcementIds, ["a1", "a2"])
    }
}
