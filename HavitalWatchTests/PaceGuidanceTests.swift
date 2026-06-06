import XCTest
@testable import HavitalWatch

final class PaceGuidanceTests: XCTestCase {
    func test_noTarget_returnsNoTargetState() {
        let guidance = PaceGuidance.make(
            currentPaceSecPerKm: 330,
            targetLowSecPerKm: nil,
            targetHighSecPerKm: nil
        )

        XCTAssertEqual(guidance.state, .noTarget)
        XCTAssertNil(guidance.pointerFraction)
        XCTAssertNil(guidance.deviationSeconds)
    }

    func test_waitingForPace_keepsPointerCenteredByView() {
        let guidance = PaceGuidance.make(
            currentPaceSecPerKm: nil,
            targetLowSecPerKm: 305,
            targetHighSecPerKm: 315
        )

        XCTAssertEqual(guidance.state, .waitingForPace)
        XCTAssertNil(guidance.pointerFraction)
        XCTAssertNil(guidance.deviationSeconds)
    }

    func test_stateDisplayText_usesReadableStatusNotCommands() {
        XCTAssertEqual(PaceGuidance.State.noTarget.displayText, "無配速目標")
        XCTAssertEqual(PaceGuidance.State.waitingForPace.displayText, "等 GPS")
        XCTAssertEqual(PaceGuidance.State.tooFast.displayText, "快")
        XCTAssertEqual(PaceGuidance.State.onTarget.displayText, "目標內")
        XCTAssertEqual(PaceGuidance.State.tooSlow.displayText, "慢")
    }

    func test_fasterThanTarget_isTooFast() {
        let guidance = PaceGuidance.make(
            currentPaceSecPerKm: 290,
            targetLowSecPerKm: 305,
            targetHighSecPerKm: 315
        )

        XCTAssertEqual(guidance.state, .tooFast)
        XCTAssertEqual(guidance.deviationSeconds, 15)
        XCTAssertLessThan(guidance.pointerFraction ?? 1, 0.5)
    }

    func test_insideTargetRange_isOnTarget() {
        let guidance = PaceGuidance.make(
            currentPaceSecPerKm: 310,
            targetLowSecPerKm: 305,
            targetHighSecPerKm: 315
        )

        XCTAssertEqual(guidance.state, .onTarget)
        XCTAssertNil(guidance.deviationSeconds)
    }

    func test_slowerThanExactTarget_isTooSlowAndPinsRight() {
        let guidance = PaceGuidance.make(
            currentPaceSecPerKm: 330,
            targetLowSecPerKm: 305,
            targetHighSecPerKm: 305
        )

        XCTAssertEqual(guidance.state, .tooSlow)
        XCTAssertEqual(guidance.deviationSeconds, 25)
        XCTAssertEqual(guidance.pointerFraction, 1)
    }
}
