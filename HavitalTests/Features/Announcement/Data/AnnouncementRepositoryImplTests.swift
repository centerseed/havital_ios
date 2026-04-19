import XCTest
@testable import paceriz_dev

final class AnnouncementRepositoryImplTests: XCTestCase {
    private var mockHTTPClient: MockHTTPClient!
    private var mockParser: MockAPIParser!
    private var remoteDataSource: AnnouncementRemoteDataSource!
    private var sut: AnnouncementRepositoryImpl!

    override func setUp() {
        super.setUp()
        mockHTTPClient = MockHTTPClient()
        mockParser = MockAPIParser()
        remoteDataSource = AnnouncementRemoteDataSource(httpClient: mockHTTPClient, parser: mockParser)
        sut = AnnouncementRepositoryImpl(dataSource: remoteDataSource)
    }

    override func tearDown() {
        mockHTTPClient.reset()
        mockParser.reset()
        sut = nil
        remoteDataSource = nil
        mockParser = nil
        mockHTTPClient = nil
        super.tearDown()
    }

    func testFetchAnnouncementsFiltersEntriesThatMapperCannotConvert() async throws {
        let json = """
        {
          "announcements": [
            {
              "id": "valid",
              "title": "Valid",
              "body": "Body",
              "published_at": "2026-04-19T10:00:00Z",
              "is_seen": false
            },
            {
              "id": "missing-published-at",
              "title": "Broken",
              "body": "Body",
              "is_seen": false
            }
          ]
        }
        """
        mockHTTPClient.setResponse(for: "/v2/announcements", data: Data(json.utf8))

        let result = try await sut.fetchAnnouncements()

        XCTAssertEqual(result.map(\.id), ["valid"])
    }

    func testFetchAnnouncementsWrapsRemoteError() async {
        mockHTTPClient.setError(for: "/v2/announcements", error: HTTPError.noConnection)

        do {
            _ = try await sut.fetchAnnouncements()
            XCTFail("Expected fetchAnnouncements to throw")
        } catch let error as AnnouncementError {
            switch error {
            case .fetchFailed(let message):
                XCTAssertFalse(message.isEmpty)
            default:
                XCTFail("Unexpected error case: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMarkSeenBatchReturnsEarlyWhenIdsAreEmpty() async throws {
        try await sut.markSeenBatch(ids: [])

        XCTAssertEqual(mockHTTPClient.requestCount, 0)
    }
}
