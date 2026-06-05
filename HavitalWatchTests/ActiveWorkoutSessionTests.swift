import XCTest
@testable import HavitalWatch

final class ActiveWorkoutSessionTests: XCTestCase {
    private func snap(_ flow: WorkoutFlowType, _ segments: [WatchSegment]) -> WatchPlanSnapshot {
        WatchPlanSnapshot(
            date: "2026-06-05",
            flowType: flow,
            totalDistanceMeters: nil,
            totalSeconds: nil,
            planId: "p",
            segments: segments
        )
    }

    private func run(_ meters: Double) -> WatchSegment {
        WatchSegment(
            kind: .run,
            measure: .distance,
            targetMeters: meters,
            targetSeconds: nil,
            paceLowSecPerKm: nil,
            paceHighSecPerKm: nil,
            label: "x",
            repIndex: nil,
            repTotal: nil
        )
    }

    func test_directStart_startsInMainPhase() {
        let session = ActiveWorkoutSession(snapshot: snap(.directStart, []))

        XCTAssertEqual(session.phase, .main)
    }

    func test_structured_startsInWarmup_thenBeginPlanEntersMain() {
        let session = ActiveWorkoutSession(snapshot: snap(.warmupMainCooldown, [run(400)]))

        XCTAssertEqual(session.phase, .warmup)
        session.beginPlan()

        XCTAssertEqual(session.phase, .main)
    }

    func test_mainFinished_entersCooldown_forStructured() {
        let session = ActiveWorkoutSession(snapshot: snap(.warmupMainCooldown, [run(400)]))

        session.beginPlan()
        session.handleSegmentEvent(.finished)

        XCTAssertEqual(session.phase, .cooldown)
    }

    func test_directStart_finishGoesToFinished() {
        let session = ActiveWorkoutSession(snapshot: snap(.directStart, []))

        session.finish()

        XCTAssertEqual(session.phase, .finished)
    }

    func test_pauseFlagBlocksEngineAdvance() {
        let session = ActiveWorkoutSession(snapshot: snap(.warmupMainCooldown, [run(400), run(400)]))

        session.beginPlan()
        session.setPaused(true)
        session.ingest(totalMeters: 999, totalSeconds: 999, recentSpeedMps: 4)

        XCTAssertTrue(session.isPaused)
        XCTAssertEqual(session.currentSegmentIndex, 0)
    }

    func test_pauseDoesNotAccumulateDistanceOrTimeAcrossResume() {
        let session = ActiveWorkoutSession(snapshot: snap(.warmupMainCooldown, [run(100), run(100)]))

        session.beginPlan()
        session.ingest(totalMeters: 0, totalSeconds: 0, recentSpeedMps: 2)
        session.ingest(totalMeters: 90, totalSeconds: 10, recentSpeedMps: 2)

        session.setPaused(true)
        session.ingest(totalMeters: 500, totalSeconds: 70, recentSpeedMps: 2)

        XCTAssertEqual(session.activeDistanceMeters, 90)
        XCTAssertEqual(session.activeElapsedSeconds, 10)
        XCTAssertEqual(session.currentSegmentIndex, 0)

        session.setPaused(false)
        session.ingest(totalMeters: 509, totalSeconds: 75, recentSpeedMps: 2)

        XCTAssertEqual(session.activeDistanceMeters, 99)
        XCTAssertEqual(session.activeElapsedSeconds, 15)
        XCTAssertEqual(session.currentSegmentIndex, 0)

        session.ingest(totalMeters: 510, totalSeconds: 76, recentSpeedMps: 2)
        XCTAssertEqual(session.currentSegmentIndex, 1)
    }
}
