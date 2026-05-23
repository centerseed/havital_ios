import XCTest
@testable import paceriz_dev

final class WorkoutReflectionGateTests: XCTestCase {

    // MARK: - shouldAutoPrompt

    func test_shouldAutoPrompt_noRPE_detailLoaded_notYetPrompted_returnsTrue() {
        let result = WorkoutReflectionGate.shouldAutoPrompt(
            hasRPE: false,
            detailLoaded: true,
            alreadyPrompted: false
        )
        XCTAssertTrue(result, "Should prompt when no RPE, detail loaded, and not yet prompted")
    }

    func test_shouldAutoPrompt_hasRPE_returnsFalse() {
        let result = WorkoutReflectionGate.shouldAutoPrompt(
            hasRPE: true,
            detailLoaded: true,
            alreadyPrompted: false
        )
        XCTAssertFalse(result, "Should not prompt when RPE already set")
    }

    func test_shouldAutoPrompt_detailNotLoaded_returnsFalse() {
        let result = WorkoutReflectionGate.shouldAutoPrompt(
            hasRPE: false,
            detailLoaded: false,
            alreadyPrompted: false
        )
        XCTAssertFalse(result, "Should not prompt before detail is loaded")
    }

    func test_shouldAutoPrompt_alreadyPrompted_returnsFalse() {
        let result = WorkoutReflectionGate.shouldAutoPrompt(
            hasRPE: false,
            detailLoaded: true,
            alreadyPrompted: true
        )
        XCTAssertFalse(result, "Should not prompt if already prompted this session")
    }
}
