import XCTest
@testable import paceriz_dev

final class RaceMapperTests: XCTestCase {

    func testToEntityMapsFieldsAndDistanceFallbacks() {
        let dto = RaceDTO(
            raceId: "race_1",
            name: "Test Race",
            region: "jp",
            eventDate: "2026-11-08",
            city: "Tokyo",
            location: nil,
            distances: [
                RaceDistanceDTO(distanceKm: 10.0, label: nil),
                RaceDistanceDTO(distanceKm: 7.5, label: nil),
                RaceDistanceDTO(distanceKm: 21.0975, label: "Half Marathon")
            ],
            entryStatus: "open",
            isCurated: nil,
            courseType: "road",
            tags: nil
        )

        let entity = RaceMapper.toEntity(from: dto)

        XCTAssertEqual(entity?.raceId, "race_1")
        XCTAssertEqual(entity?.name, "Test Race")
        XCTAssertEqual(entity?.distances.map(\.name), ["10K", "7.5 km", "Half Marathon"])
        XCTAssertEqual(entity?.isCurated, false)
        XCTAssertEqual(entity?.tags, [])
    }

    func testToEntityReturnsNilWhenDateCannotBeParsed() {
        let dto = RaceDTO(
            raceId: "race_2",
            name: "Broken Date Race",
            region: "tw",
            eventDate: "not-a-date",
            city: "Taipei",
            location: nil,
            distances: [],
            entryStatus: nil,
            isCurated: true,
            courseType: nil,
            tags: []
        )

        XCTAssertNil(RaceMapper.toEntity(from: dto))
    }

    func testToEntitiesSkipsEntriesWithInvalidDates() {
        let valid = RaceDTO(
            raceId: "valid",
            name: "Valid",
            region: "jp",
            eventDate: "2026-01-01",
            city: "Tokyo",
            location: nil,
            distances: [],
            entryStatus: nil,
            isCurated: false,
            courseType: nil,
            tags: []
        )
        let invalid = RaceDTO(
            raceId: "invalid",
            name: "Invalid",
            region: "jp",
            eventDate: "not-a-date",
            city: "Tokyo",
            location: nil,
            distances: [],
            entryStatus: nil,
            isCurated: false,
            courseType: nil,
            tags: []
        )

        let entities = RaceMapper.toEntities(from: [valid, invalid])

        XCTAssertEqual(entities.map(\.raceId), ["valid"])
    }
}
