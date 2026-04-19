import XCTest
@testable import paceriz_dev

final class RaceRemoteDataSourceTests: XCTestCase {
    private var mockHTTPClient: MockHTTPClient!
    private var mockParser: MockAPIParser!
    private var sut: RaceRemoteDataSource!

    override func setUp() {
        super.setUp()
        mockHTTPClient = MockHTTPClient()
        mockParser = MockAPIParser()
        sut = RaceRemoteDataSource(httpClient: mockHTTPClient, parser: mockParser)
    }

    override func tearDown() {
        mockHTTPClient.reset()
        mockParser.reset()
        sut = nil
        mockParser = nil
        mockHTTPClient = nil
        super.tearDown()
    }

    func testGetRacesWithoutFiltersUsesBasePath() async throws {
        let response = RaceListResponseDTO(races: [], total: 0, limit: 20, offset: 0)
        try mockHTTPClient.setJSONResponse(for: "/v2/races", response: response)

        let result = try await sut.getRaces(
            region: nil,
            distanceMin: nil,
            distanceMax: nil,
            dateFrom: nil,
            dateTo: nil,
            query: nil,
            curatedOnly: nil,
            limit: nil,
            offset: nil
        )

        XCTAssertEqual(result.total, 0)
        XCTAssertEqual(mockHTTPClient.lastRequest?.path, "/v2/races")
        XCTAssertEqual(mockHTTPClient.lastRequest?.method, .GET)
    }

    func testGetRacesBuildsExpectedQueryString() async throws {
        let path = "/v2/races?region=jp&distance_min=10.0&distance_max=42.195&date_from=2026-01-01&date_to=2026-12-31&q=Tokyo%20Marathon&curated_only=true&limit=20&offset=40"
        let response = RaceListResponseDTO(races: [], total: 0, limit: 20, offset: 40)
        try mockHTTPClient.setJSONResponse(for: path, response: response)

        _ = try await sut.getRaces(
            region: "jp",
            distanceMin: 10.0,
            distanceMax: 42.195,
            dateFrom: "2026-01-01",
            dateTo: "2026-12-31",
            query: "Tokyo Marathon",
            curatedOnly: true,
            limit: 20,
            offset: 40
        )

        XCTAssertEqual(mockHTTPClient.lastRequest?.path, path)
    }
}
