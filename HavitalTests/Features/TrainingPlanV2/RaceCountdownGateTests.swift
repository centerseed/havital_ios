import XCTest
@testable import paceriz_dev

/// Test protection for the race-countdown card visibility gate.
/// Covers the rule: default shows only within 42 days of the race; settings can force
/// always/off; and a missing/past race date hides it. `daysLeft` is recomputed from the
/// current race date upstream, so changing the target date / re-onboarding re-drives this.
final class RaceCountdownGateTests: XCTestCase {

    // MARK: - auto (default, 42 days)

    func test_auto_showsWhenWithinThreshold() {
        XCTAssertTrue(RaceCountdownGate.shouldShow(mode: .auto, daysBefore: 42, daysLeft: 42))
        XCTAssertTrue(RaceCountdownGate.shouldShow(mode: .auto, daysBefore: 42, daysLeft: 41))
        XCTAssertTrue(RaceCountdownGate.shouldShow(mode: .auto, daysBefore: 42, daysLeft: 0))
    }

    func test_auto_hidesWhenBeyondThreshold() {
        XCTAssertFalse(RaceCountdownGate.shouldShow(mode: .auto, daysBefore: 42, daysLeft: 43))
        XCTAssertFalse(RaceCountdownGate.shouldShow(mode: .auto, daysBefore: 42, daysLeft: 177))
    }

    func test_auto_customThreshold() {
        XCTAssertTrue(RaceCountdownGate.shouldShow(mode: .auto, daysBefore: 14, daysLeft: 14))
        XCTAssertFalse(RaceCountdownGate.shouldShow(mode: .auto, daysBefore: 14, daysLeft: 15))
    }

    // MARK: - always / off

    func test_always_showsRegardlessOfThreshold() {
        XCTAssertTrue(RaceCountdownGate.shouldShow(mode: .always, daysBefore: 42, daysLeft: 365))
        XCTAssertTrue(RaceCountdownGate.shouldShow(mode: .always, daysBefore: 42, daysLeft: 0))
    }

    func test_off_neverShows() {
        XCTAssertFalse(RaceCountdownGate.shouldShow(mode: .off, daysBefore: 42, daysLeft: 1))
        XCTAssertFalse(RaceCountdownGate.shouldShow(mode: .off, daysBefore: 42, daysLeft: 365))
    }

    // MARK: - no upcoming race (nil / past)

    func test_noRaceDate_hidesInEveryMode() {
        for mode in RaceCountdownDisplayMode.allCases {
            XCTAssertFalse(
                RaceCountdownGate.shouldShow(mode: mode, daysBefore: 42, daysLeft: nil),
                "mode \(mode) should hide when there is no race date"
            )
        }
    }

    func test_pastRace_negativeDaysLeft_hides() {
        XCTAssertFalse(RaceCountdownGate.shouldShow(mode: .auto, daysBefore: 42, daysLeft: -1))
        XCTAssertFalse(RaceCountdownGate.shouldShow(mode: .always, daysBefore: 42, daysLeft: -3))
    }

    // MARK: - target date change / re-onboarding (gate reacts to new daysLeft)

    func test_dateChange_flipsVisibility() {
        // Race 100 days out under default → hidden.
        XCTAssertFalse(RaceCountdownGate.shouldShow(mode: .auto, daysBefore: 42, daysLeft: 100))
        // User edits target to a nearer date (now 30 days out) → recomputed daysLeft shows it.
        XCTAssertTrue(RaceCountdownGate.shouldShow(mode: .auto, daysBefore: 42, daysLeft: 30))
    }

    // MARK: - mode parsing

    func test_modeRawValueParsing_fallsBackToDefault() {
        XCTAssertEqual(RaceCountdownDisplayMode(rawValueOrDefault: "always"), .always)
        XCTAssertEqual(RaceCountdownDisplayMode(rawValueOrDefault: "off"), .off)
        XCTAssertEqual(RaceCountdownDisplayMode(rawValueOrDefault: "auto"), .auto)
        XCTAssertEqual(RaceCountdownDisplayMode(rawValueOrDefault: "garbage"), .auto)
        XCTAssertEqual(RaceCountdownDisplayMode.default, .auto)
    }
}
