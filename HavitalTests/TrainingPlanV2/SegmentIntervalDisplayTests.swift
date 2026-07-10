import XCTest
@testable import paceriz_dev

final class SegmentIntervalDisplayTests: XCTestCase {

    private func effort(distanceKm: Double? = nil, distanceM: Int? = nil,
                        durationMinutes: Int? = nil, durationSeconds: Int? = nil,
                        pace: String? = nil, recoveryType: String? = nil) -> SegmentEffort {
        SegmentEffort(distanceKm: distanceKm, distanceM: distanceM,
                      durationMinutes: durationMinutes, durationSeconds: durationSeconds,
                      pace: pace, basePace: nil, paceZone: nil, targetHrr: nil,
                      recoveryType: recoveryType)
    }

    /// `kind` is the raw wire string, mirroring the entity. Pass nil for a legacy segment.
    private func segment(kind: String?, repeats: Int? = nil,
                         work: SegmentEffort? = nil, recovery: SegmentEffort? = nil) -> RunSegment {
        RunSegment(distanceKm: 1.0, distanceM: nil, distanceDisplay: nil, distanceUnit: nil,
                   durationMinutes: nil, durationSeconds: nil, pace: "4:05", basePace: nil,
                   climateAdjustedPace: nil, climateMeta: nil, heartRateRange: nil,
                   intensity: nil, description: nil,
                   kind: kind, repeats: repeats, work: work, recovery: recovery)
    }

    // MARK: - reps

    func test_steadySegment_hasNoRepsOrRest() {
        let seg = segment(kind: "steady")
        XCTAssertNil(SegmentIntervalDisplay.reps(seg))
        XCTAssertNil(SegmentIntervalDisplay.rest(seg))
        XCTAssertNil(SegmentIntervalDisplay.workLabel(seg))
    }

    func test_legacySegmentWithoutKind_hasNoRepsOrRest() {
        let seg = segment(kind: nil)
        XCTAssertNil(SegmentIntervalDisplay.reps(seg))
        XCTAssertNil(SegmentIntervalDisplay.rest(seg))
    }

    func test_unknownKind_treatedAsSteady() {
        // A future backend kind must not be rendered as an interval group.
        let seg = segment(kind: "pyramid", repeats: 6, work: effort(distanceM: 400))
        XCTAssertNil(SegmentIntervalDisplay.reps(seg),
                     "unknown kind degrades to steady, so no reps are shown")
    }

    func test_intervalSegment_reps() {
        let seg = segment(kind: "interval", repeats: 6, work: effort(distanceM: 400, pace: "4:05"))
        XCTAssertEqual(SegmentIntervalDisplay.reps(seg), 6)
    }

    // MARK: - rest

    func test_jogRecovery_isMoving() {
        let seg = segment(kind: "interval", repeats: 6,
                          work: effort(distanceM: 400),
                          recovery: effort(durationSeconds: 90, pace: "6:30", recoveryType: "jog"))
        XCTAssertEqual(SegmentIntervalDisplay.rest(seg),
                       SegmentIntervalDisplay.Rest(value: 90, unit: .seconds, isMoving: true))
    }

    func test_staticRecovery_isNotMoving() {
        let seg = segment(kind: "interval", repeats: 4,
                          work: effort(distanceM: 200),
                          recovery: effort(durationSeconds: 60, recoveryType: "static"))
        XCTAssertEqual(SegmentIntervalDisplay.rest(seg),
                       SegmentIntervalDisplay.Rest(value: 60, unit: .seconds, isMoving: false))
    }

    func test_walkJogRecovery_countsAsMoving() {
        let seg = segment(kind: "interval", repeats: 4,
                          work: effort(distanceM: 200),
                          recovery: effort(durationMinutes: 2, recoveryType: "walk_jog"))
        XCTAssertEqual(SegmentIntervalDisplay.rest(seg),
                       SegmentIntervalDisplay.Rest(value: 2, unit: .minutes, isMoving: true))
    }

    func test_unknownRecoveryType_defaultsToMoving() {
        let seg = segment(kind: "interval", repeats: 4,
                          work: effort(distanceM: 200),
                          recovery: effort(durationSeconds: 45, recoveryType: "future_type"))
        XCTAssertEqual(SegmentIntervalDisplay.rest(seg)?.isMoving, true,
                       "only static is stationary; unknown types default to moving recovery")
    }

    func test_intervalWithoutRecovery_hasNoRest() {
        let seg = segment(kind: "interval", repeats: 6, work: effort(distanceM: 400))
        XCTAssertNil(SegmentIntervalDisplay.rest(seg))
    }

    func test_recoveryWithoutDuration_hasNoRest() {
        let seg = segment(kind: "interval", repeats: 6,
                          work: effort(distanceM: 400),
                          recovery: effort(distanceM: 200, recoveryType: "jog"))
        XCTAssertNil(SegmentIntervalDisplay.rest(seg),
                     "rest is expressed in time; a distance-only recovery has no rest label")
    }

    // MARK: - workLabel

    func test_workLabel_prefersMeters() {
        let seg = segment(kind: "interval", repeats: 6, work: effort(distanceM: 400))
        XCTAssertEqual(SegmentIntervalDisplay.workLabel(seg), "400m")
    }

    func test_workLabel_fallsBackToKilometres() {
        let seg = segment(kind: "interval", repeats: 3, work: effort(distanceKm: 1.2))
        XCTAssertEqual(SegmentIntervalDisplay.workLabel(seg), "1.2km")
    }

    func test_workLabel_fallsBackToMinutes() {
        let seg = segment(kind: "interval", repeats: 5, work: effort(durationMinutes: 3))
        let label = try? XCTUnwrap(SegmentIntervalDisplay.workLabel(seg))
        XCTAssertNotNil(label)
        XCTAssertTrue(label!.hasPrefix("3"), "minute-based work segment should lead with the count")
    }
}
