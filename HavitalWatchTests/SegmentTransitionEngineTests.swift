import XCTest
@testable import HavitalWatch

final class SegmentTransitionEngineTests: XCTestCase {
    private func seg(
        _ kind: WatchSegment.Kind,
        _ measure: WatchSegment.Measure,
        m: Double? = nil,
        s: Int? = nil
    ) -> WatchSegment {
        WatchSegment(
            kind: kind,
            measure: measure,
            targetMeters: m,
            targetSeconds: s,
            paceLowSecPerKm: nil,
            paceHighSecPerKm: nil,
            label: "x",
            repIndex: nil,
            repTotal: nil
        )
    }

    func test_distanceSegment_advancesAtTarget() {
        let engine = SegmentTransitionEngine(segments: [
            seg(.run, .distance, m: 800),
            seg(.rest, .time, s: 120)
        ])
        XCTAssertEqual(engine.update(totalMeters: 775, totalSeconds: 200, recentSpeedMps: 4, isPaused: false), [])
        XCTAssertEqual(engine.currentIndex, 0)

        let events = engine.update(totalMeters: 800, totalSeconds: 201, recentSpeedMps: 4, isPaused: false)
        XCTAssertEqual(events, [.advanced(toIndex: 1)])
        XCTAssertEqual(engine.currentIndex, 1)
    }

    func test_timeSegment_advancesAtTargetSeconds() {
        let engine = SegmentTransitionEngine(segments: [
            seg(.rest, .time, s: 120),
            seg(.run, .distance, m: 800)
        ])
        _ = engine.update(totalMeters: 0, totalSeconds: 10, recentSpeedMps: 0, isPaused: false)
        let events = engine.update(totalMeters: 0, totalSeconds: 130, recentSpeedMps: 0, isPaused: false)
        XCTAssertEqual(events, [.advanced(toIndex: 1)])
    }

    func test_lastSegment_emitsFinished() {
        let engine = SegmentTransitionEngine(segments: [seg(.run, .distance, m: 400)])
        let events = engine.update(totalMeters: 400, totalSeconds: 100, recentSpeedMps: 4, isPaused: false)
        XCTAssertEqual(events, [.finished])
    }

    func test_paused_doesNotAdvance() {
        let engine = SegmentTransitionEngine(segments: [
            seg(.run, .distance, m: 400),
            seg(.rest, .time, s: 60)
        ])
        XCTAssertEqual(engine.update(totalMeters: 500, totalSeconds: 100, recentSpeedMps: 4, isPaused: true), [])
        XCTAssertEqual(engine.currentIndex, 0)
    }
}

extension SegmentTransitionEngineTests {
    func test_timeSegment_countdownAt5sRemaining() {
        let engine = SegmentTransitionEngine(segments: [
            seg(.rest, .time, s: 60),
            seg(.run, .distance, m: 400)
        ])
        XCTAssertEqual(engine.update(totalMeters: 0, totalSeconds: 54, recentSpeedMps: 0, isPaused: false), [])
        XCTAssertEqual(engine.update(totalMeters: 0, totalSeconds: 55, recentSpeedMps: 0, isPaused: false), [.countdownCue])
        XCTAssertEqual(engine.update(totalMeters: 0, totalSeconds: 56, recentSpeedMps: 0, isPaused: false), [])
    }

    func test_distanceSegment_countdownByEstimatedTime() {
        let engine = SegmentTransitionEngine(segments: [
            seg(.run, .distance, m: 800),
            seg(.rest, .time, s: 60)
        ])
        XCTAssertEqual(engine.update(totalMeters: 776, totalSeconds: 200, recentSpeedMps: 4, isPaused: false), [])
        XCTAssertEqual(engine.update(totalMeters: 780, totalSeconds: 201, recentSpeedMps: 4, isPaused: false), [.countdownCue])
    }

    func test_countdownResetsAfterAdvance() {
        let engine = SegmentTransitionEngine(segments: [
            seg(.run, .distance, m: 400),
            seg(.run, .distance, m: 400)
        ])
        _ = engine.update(totalMeters: 381, totalSeconds: 100, recentSpeedMps: 4, isPaused: false)
        _ = engine.update(totalMeters: 400, totalSeconds: 105, recentSpeedMps: 4, isPaused: false)
        XCTAssertEqual(engine.update(totalMeters: 780, totalSeconds: 200, recentSpeedMps: 4, isPaused: false), [.countdownCue])
    }
}
