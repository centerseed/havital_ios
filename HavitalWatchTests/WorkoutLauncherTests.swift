import XCTest
@testable import HavitalWatch

final class WorkoutLauncherTests: XCTestCase {
    private func snapshot(flow: WorkoutFlowType, date: String) -> WatchPlanSnapshot {
        WatchPlanSnapshot(
            date: date,
            flowType: flow,
            totalDistanceMeters: 1000,
            totalSeconds: nil,
            planId: "p",
            segments: []
        )
    }

    func test_noSnapshot_blocked() {
        XCTAssertEqual(
            WorkoutLauncher.evaluate(snapshot: nil, today: "2026-06-05", permissionsGranted: true),
            .blockedNeedSyncFromPhone
        )
    }

    func test_restDay_blocked() {
        XCTAssertEqual(
            WorkoutLauncher.evaluate(
                snapshot: snapshot(flow: .rest, date: "2026-06-05"),
                today: "2026-06-05",
                permissionsGranted: true
            ),
            .blockedRestDay
        )
    }

    func test_unsupported_blocked() {
        XCTAssertEqual(
            WorkoutLauncher.evaluate(
                snapshot: snapshot(flow: .unsupported, date: "2026-06-05"),
                today: "2026-06-05",
                permissionsGranted: true
            ),
            .blockedUnsupportedType
        )
    }

    func test_staleSnapshot_blocked() {
        XCTAssertEqual(
            WorkoutLauncher.evaluate(
                snapshot: snapshot(flow: .directStart, date: "2026-06-04"),
                today: "2026-06-05",
                permissionsGranted: true
            ),
            .blockedNeedSyncFromPhone
        )
    }

    func test_permissionsMissing_requiresPermission() {
        XCTAssertEqual(
            WorkoutLauncher.evaluate(
                snapshot: snapshot(flow: .directStart, date: "2026-06-05"),
                today: "2026-06-05",
                permissionsGranted: false
            ),
            .requiresPermission
        )
    }

    func test_allGood_canStart() {
        XCTAssertEqual(
            WorkoutLauncher.evaluate(
                snapshot: snapshot(flow: .warmupMainCooldown, date: "2026-06-05"),
                today: "2026-06-05",
                permissionsGranted: true
            ),
            .canStart
        )
    }
}
