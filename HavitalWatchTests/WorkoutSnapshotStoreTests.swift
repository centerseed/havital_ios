import Foundation
import XCTest
@testable import HavitalWatch

private final class InMemoryCache: SnapshotPersisting {
    var data: Data?

    func save(_ data: Data) {
        self.data = data
    }

    func load() -> Data? {
        data
    }
}

final class WorkoutSnapshotStoreTests: XCTestCase {
    func test_saveThenLoad_roundTrips() {
        let store = WorkoutSnapshotStore(cache: InMemoryCache())
        let dto = WatchPlanSnapshotDTO(
            date: "2026-06-05",
            runType: "interval",
            totalDistanceMeters: 6400,
            totalSeconds: nil,
            planId: "p",
            segments: []
        )

        store.save(dto)
        let loaded = store.currentSnapshot()

        XCTAssertEqual(loaded?.date, "2026-06-05")
        XCTAssertEqual(loaded?.flowType, .warmupMainCooldown)
    }

    func test_emptyCache_returnsNil() {
        XCTAssertNil(WorkoutSnapshotStore(cache: InMemoryCache()).currentSnapshot())
    }
}
