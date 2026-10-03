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

    func testRaceCountdownUsesUserLocalDatesAcrossTokyoAndTaipei() {
        let now = ISO8601DateFormatter().date(from: "2026-10-02T15:30:00Z")!
        let raceDate = ISO8601DateFormatter().date(from: "2026-10-03T00:00:00Z")!

        XCTAssertEqual(
            TrainingDateUtils.calculateDaysBetween(
                raceDate: raceDate,
                now: now,
                timezone: TimeZone(identifier: "Asia/Tokyo")!
            ),
            0
        )
        XCTAssertEqual(
            TrainingDateUtils.calculateDaysBetween(
                raceDate: raceDate,
                now: now,
                timezone: TimeZone(identifier: "Asia/Taipei")!
            ),
            1
        )
    }

    func testRaceCountdownHandlesNextDayAndSevenDays() {
        let now = ISO8601DateFormatter().date(from: "2026-10-02T15:30:00Z")!
        let nextDay = ISO8601DateFormatter().date(from: "2026-10-04T00:00:00Z")!
        let sevenDays = ISO8601DateFormatter().date(from: "2026-10-10T00:00:00Z")!
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!

        XCTAssertEqual(TrainingDateUtils.calculateDaysBetween(raceDate: nextDay, now: now, timezone: tokyo), 1)
        XCTAssertEqual(TrainingDateUtils.calculateDaysBetween(raceDate: sevenDays, now: now, timezone: tokyo), 7)
    }

    func testRaceCountdownPreservesCatalogDateInWesternTimezone() {
        let dto = RaceDTO(
            raceId: "la-race",
            name: "Los Angeles Race",
            region: "us",
            eventDate: "2026-10-03",
            city: "Los Angeles",
            location: nil,
            distances: [],
            entryStatus: nil,
            isCurated: true,
            courseType: nil,
            tags: nil
        )
        let entity = RaceMapper.toEntity(from: dto)!
        let now = ISO8601DateFormatter().date(from: "2026-10-02T19:00:00Z")!
        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!

        XCTAssertEqual(
            TrainingDateUtils.calculateCatalogDaysRemaining(
                raceDate: entity.eventDate,
                timezone: losAngeles,
                now: now
            ),
            1
        )
    }

    func testTimestampCountdownKeepsTokyoLocalMidnightDate() {
        let now = ISO8601DateFormatter().date(from: "2026-10-02T15:30:00Z")!
        let targetAtTokyoMidnight = Int(
            ISO8601DateFormatter().date(from: "2026-10-03T15:00:00Z")!.timeIntervalSince1970
        )

        XCTAssertEqual(
            TrainingDateUtils.calculateDaysRemaining(
                raceDate: targetAtTokyoMidnight,
                timezone: "Asia/Tokyo",
                now: now
            ),
            1
        )
    }

    func testRacePickerDefaultRegionFollowsTimezoneOrJapaneseLocale() {
        XCTAssertEqual(RacePickerDefaults.defaultRegion(timeZoneIdentifier: "Asia/Tokyo", localeIdentifier: "en-US"), "jp")
        XCTAssertEqual(RacePickerDefaults.defaultRegion(timeZoneIdentifier: "America/Los_Angeles", localeIdentifier: "ja-JP"), "jp")
        XCTAssertEqual(RacePickerDefaults.defaultRegion(timeZoneIdentifier: "America/Los_Angeles", localeIdentifier: "en-US"), "tw")
    }
}
