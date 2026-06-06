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
    }

    func test_waitingForPace_keepsPointerCenteredByView() {
        let guidance = PaceGuidance.make(
            currentPaceSecPerKm: nil,
            targetLowSecPerKm: 305,
            targetHighSecPerKm: 315
        )

        XCTAssertEqual(guidance.state, .waitingForPace)
        XCTAssertNil(guidance.pointerFraction)
    }

    func test_fasterThanTarget_isTooFast() {
        let guidance = PaceGuidance.make(
            currentPaceSecPerKm: 290,
            targetLowSecPerKm: 305,
            targetHighSecPerKm: 315
        )

        XCTAssertEqual(guidance.state, .tooFast)
        XCTAssertLessThan(guidance.pointerFraction ?? 1, 0.5)
    }

    func test_insideTargetRange_isOnTarget() {
        let guidance = PaceGuidance.make(
            currentPaceSecPerKm: 310,
            targetLowSecPerKm: 305,
            targetHighSecPerKm: 315
        )

        XCTAssertEqual(guidance.state, .onTarget)
    }

    func test_slowerThanExactTarget_isTooSlowAndPinsRight() {
        let guidance = PaceGuidance.make(
            currentPaceSecPerKm: 330,
            targetLowSecPerKm: 305,
            targetHighSecPerKm: 305
        )

        XCTAssertEqual(guidance.state, .tooSlow)
        XCTAssertEqual(guidance.pointerFraction, 1)
    }
}
