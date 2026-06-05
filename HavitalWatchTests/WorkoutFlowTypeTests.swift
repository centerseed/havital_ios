import XCTest
@testable import HavitalWatch

final class WorkoutFlowTypeTests: XCTestCase {
    func test_easyTypes_areDirectStart() {
        for type in ["easy_run", "easy", "long_run", "lsd", "recovery_run"] {
            XCTAssertEqual(WorkoutFlowType(runType: type), .directStart, type)
        }
    }

    func test_structuredTypes_areWarmupMainCooldown() {
        for type in ["interval", "combination", "tempo", "threshold", "progression", "benchmark", "race"] {
            XCTAssertEqual(WorkoutFlowType(runType: type), .warmupMainCooldown, type)
        }
    }

    func test_rest_isRest() {
        XCTAssertEqual(WorkoutFlowType(runType: "rest"), .rest)
    }

    func test_nonRunning_isUnsupported() {
        for type in ["strength", "yoga", "cycling", "hiking", "cross_training"] {
            XCTAssertEqual(WorkoutFlowType(runType: type), .unsupported, type)
        }
    }

    func test_unknownType_defaultsToRest() {
        XCTAssertEqual(WorkoutFlowType(runType: "wat_is_this"), .rest)
    }
}
