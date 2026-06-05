import XCTest
@testable import HavitalWatch

final class WorkoutUUIDValidatorTests: XCTestCase {
    func test_validV4_passes() {
        XCTAssertTrue(WorkoutUUIDValidator.isValid("9b2e4f1a-3c4d-4e5f-8a9b-0c1d2e3f4a5b"))
    }

    func test_empty_fails() {
        XCTAssertFalse(WorkoutUUIDValidator.isValid(""))
    }

    func test_wrongVersion_fails() {
        XCTAssertFalse(WorkoutUUIDValidator.isValid("9b2e4f1a-3c4d-1e5f-8a9b-0c1d2e3f4a5b"))
    }

    func test_uppercase_fails() {
        XCTAssertFalse(WorkoutUUIDValidator.isValid("9B2E4F1A-3C4D-4E5F-8A9B-0C1D2E3F4A5B"))
    }

    func test_generatedUUID_isValid() {
        XCTAssertTrue(WorkoutUUIDValidator.isValid(WorkoutUUIDValidator.generate()))
    }
}
