import XCTest
@testable import paceriz_dev

final class RaceRepositoryImplTests: XCTestCase {

    func testGetRacesMapsAndFiltersInvalidRaceDates() async throws {
        let remote = MockRaceRemoteDataSource()
        remote.response = RaceListResponseDTO(
            races: [
                RaceDTO(
                    raceId: "valid",
                    name: "Valid Race",
                    region: "jp",
                    eventDate: "2026-03-01",
                    city: "Tokyo",
                    location: nil,
                    distances: [RaceDistanceDTO(distanceKm: 10.0, label: nil)],
                    entryStatus: "open",
                    isCurated: true,
                    courseType: "road",
                    tags: ["fast"]
                ),
                RaceDTO(
                    raceId: "invalid",
                    name: "Invalid Race",
                    region: "jp",
                    eventDate: "broken-date",
                    city: "Tokyo",
                    location: nil,
                    distances: [],
                    entryStatus: nil,
                    isCurated: nil,
                    courseType: nil,
                    tags: nil
                )
            ],
            total: 2,
            limit: 20,
            offset: 0
        )
        let sut = RaceRepositoryImpl(remoteDataSource: remote)

        let result = try await sut.getRaces(
            region: "jp",
            distanceMin: 5,
            distanceMax: 42.195,
            dateFrom: nil,
            dateTo: nil,
            query: "Tokyo",
            curatedOnly: true,
            limit: 20,
            offset: 0
        )

        XCTAssertEqual(result.map(\.raceId), ["valid"])
        XCTAssertEqual(remote.lastRegion, "jp")
        XCTAssertEqual(remote.lastQuery, "Tokyo")
        XCTAssertEqual(remote.lastCuratedOnly, true)
    }

    func testGetRacesConvertsRemoteErrorsToDomainError() async {
        let remote = MockRaceRemoteDataSource()
        remote.error = HTTPError.noConnection
        let sut = RaceRepositoryImpl(remoteDataSource: remote)

        do {
            _ = try await sut.getRaces(
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
            XCTFail("Expected getRaces to throw")
        } catch let error as DomainError {
            XCTAssertEqual(error, .noConnection)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class MockRaceRemoteDataSource: RaceRemoteDataSourceProtocol {
    var response = RaceListResponseDTO(races: [], total: 0, limit: 20, offset: 0)
    var error: Error?

    private(set) var lastRegion: String?
    private(set) var lastDistanceMin: Double?
    private(set) var lastDistanceMax: Double?
    private(set) var lastDateFrom: String?
    private(set) var lastDateTo: String?
    private(set) var lastQuery: String?
    private(set) var lastCuratedOnly: Bool?
    private(set) var lastLimit: Int?
    private(set) var lastOffset: Int?

    func getRaces(
        region: String?,
        distanceMin: Double?,
        distanceMax: Double?,
        dateFrom: String?,
        dateTo: String?,
        query: String?,
        curatedOnly: Bool?,
        limit: Int?,
        offset: Int?
    ) async throws -> RaceListResponseDTO {
        lastRegion = region
        lastDistanceMin = distanceMin
        lastDistanceMax = distanceMax
        lastDateFrom = dateFrom
        lastDateTo = dateTo
        lastQuery = query
        lastCuratedOnly = curatedOnly
        lastLimit = limit
        lastOffset = offset

        if let error {
            throw error
        }

        return response
    }
}
