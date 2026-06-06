import XCTest
@testable import HavitalWatch

final class WorkoutFlowTypeTests: XCTestCase {
    func test_easyTypes_areDirectStart() {
        for type in ["easy_run", "easy", "long_run", "lsd", "recovery_run"] {
            XCTAssertEqual(WorkoutFlowType(runType: type), .directStart, type)
        }
    }

    func test_structuredTypes_areWarmupMainCooldown() {
        for type in [
            "interval",
            "short_interval",
            "long_interval",
            "short_intervals",
            "long_intervals",
            "tempo",
            "tempo_run",
            "threshold",
            "threshold_run",
            "fartlek",
            "progression",
            "combination",
            "benchmark",
            "race",
            "race_pace",
            "strides",
            "strides_session",
            "hill_repeats",
            "hill_sprints",
            "cruise_intervals",
            "norwegian_4x4",
            "norwegian_singles",
            "norwegian_doubles",
            "norwegian_threshold",
            "yasso_800",
            "mile_repeats",
            "fast_finish",
        ] {
            XCTAssertEqual(WorkoutFlowType(runType: type), .warmupMainCooldown, type)
        }
    }

    func test_rest_isRest() {
        XCTAssertEqual(WorkoutFlowType(runType: "rest"), .rest)
    }

    func test_nonRunning_isUnsupported() {
        for type in ["strength", "yoga", "cycling", "hiking", "swimming", "elliptical", "rowing", "cross_training"] {
            XCTAssertEqual(WorkoutFlowType(runType: type), .unsupported, type)
        }
    }

    func test_unknownType_defaultsToRest() {
        XCTAssertEqual(WorkoutFlowType(runType: "wat_is_this"), .rest)
    }
}
