import Foundation
import XCTest
@testable import HavitalWatch

private final class InMemoryWatchSessionCache: SnapshotPersisting {
    var data: Data?

    func save(_ data: Data) {
        self.data = data
    }

    func load() -> Data? {
        data
    }
}

final class WCSessionClientTests: XCTestCase {
    func test_applyIncomingTodayPlanPayloadSavesSnapshot() throws {
        let cache = InMemoryWatchSessionCache()
        let store = WorkoutSnapshotStore(cache: cache)
        let client = WCSessionClient(store: store)
        let dto = makeTodayPlanDTO()

        let applied = client.applyIncomingPayload(try makeTodayPlanPayload(dto))

        XCTAssertTrue(applied)
        let snapshot = try XCTUnwrap(store.currentSnapshot())
        XCTAssertEqual(snapshot.date, "2026-06-05")
        XCTAssertEqual(snapshot.totalDistanceMeters, 3_000)
        XCTAssertEqual(snapshot.planId, "plan-today")
    }

    func test_applyIncomingAuthPayloadUpdatesLoginState() {
        let client = WCSessionClient(store: WorkoutSnapshotStore(cache: InMemoryWatchSessionCache()))

        let applied = client.applyIncomingPayload([
            "type": "auth",
            "logged_in": true
        ])

        XCTAssertTrue(applied)
        XCTAssertTrue(client.isLoggedIn)
    }

    func test_applyIncomingUnknownPayloadReturnsFalse() {
        let client = WCSessionClient(store: WorkoutSnapshotStore(cache: InMemoryWatchSessionCache()))

        XCTAssertFalse(client.applyIncomingPayload(["type": "unknown"]))
    }

    private func makeTodayPlanPayload(_ dto: WatchPlanSnapshotDTO) throws -> [String: Any] {
        [
            "type": "today_plan",
            "payload": try JSONEncoder().encode(dto)
        ]
    }

    private func makeTodayPlanDTO() -> WatchPlanSnapshotDTO {
        WatchPlanSnapshotDTO(
            date: "2026-06-05",
            runType: "easy",
            totalDistanceMeters: 3_000,
            totalSeconds: nil,
            planId: "plan-today",
            segments: [
                WatchSegmentDTO(
                    kind: "run",
                    measure: "distance",
                    targetMeters: 3_000,
                    targetSeconds: nil,
                    paceLowSecPerKm: 395,
                    paceHighSecPerKm: 435,
                    label: "輕鬆跑",
                    repIndex: nil,
                    repTotal: nil
                )
            ]
        )
    }
}
