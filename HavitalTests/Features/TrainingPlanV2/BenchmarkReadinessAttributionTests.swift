import XCTest
@testable import paceriz_dev

final class BenchmarkReadinessAttributionTests: XCTestCase {

    // MARK: - RaceFitnessMetric decoding

    func test_raceFitnessMetric_decodes_benchmark_attribution() throws {
        let json = """
        {
            "score": 72.5,
            "vdot_source": "benchmark",
            "benchmark_date": "2026-06-18"
        }
        """
        let dto = try JSONDecoder().decode(RaceFitnessMetric.self, from: Data(json.utf8))
        XCTAssertEqual(dto.score, 72.5)
        XCTAssertEqual(dto.vdotSource, "benchmark")
        XCTAssertEqual(dto.benchmarkDate, "2026-06-18")
    }

    func test_raceFitnessMetric_missing_attribution_decodes_nil_no_crash() throws {
        let json = """
        {
            "score": 65.0
        }
        """
        let dto = try JSONDecoder().decode(RaceFitnessMetric.self, from: Data(json.utf8))
        XCTAssertEqual(dto.score, 65.0)
        XCTAssertNil(dto.vdotSource)
        XCTAssertNil(dto.benchmarkDate)
    }

    func test_raceFitnessMetric_training_source_benchmark_date_nil() throws {
        let json = """
        {
            "score": 60.0,
            "vdot_source": "training",
            "benchmark_date": null
        }
        """
        let dto = try JSONDecoder().decode(RaceFitnessMetric.self, from: Data(json.utf8))
        XCTAssertEqual(dto.vdotSource, "training")
        XCTAssertNil(dto.benchmarkDate)
    }

    // MARK: - RaceFitnessSummaryDTO decoding (weekly summary race_fitness)

    func test_raceFitnessSummaryDTO_decodes_benchmark_attribution() throws {
        let json = """
        {
            "score": 78.0,
            "current_vdot": 45.2,
            "progress_percentage": 82.5,
            "trend": "up",
            "trend_data": [],
            "evaluation": "on_track",
            "vdot_source": "benchmark",
            "benchmark_date": "2026-06-18"
        }
        """
        let dto = try JSONDecoder().decode(RaceFitnessSummaryDTO.self, from: Data(json.utf8))
        XCTAssertEqual(dto.currentVdot, 45.2)
        XCTAssertEqual(dto.vdotSource, "benchmark")
        XCTAssertEqual(dto.benchmarkDate, "2026-06-18")
    }

    func test_raceFitnessSummaryDTO_missing_attribution_decodes_nil_no_crash() throws {
        let json = """
        {
            "score": 70.0,
            "current_vdot": 42.0,
            "progress_percentage": 75.0,
            "trend": "stable",
            "trend_data": [],
            "evaluation": "on_track"
        }
        """
        let dto = try JSONDecoder().decode(RaceFitnessSummaryDTO.self, from: Data(json.utf8))
        XCTAssertEqual(dto.currentVdot, 42.0)
        XCTAssertNil(dto.vdotSource)
        XCTAssertNil(dto.benchmarkDate)
    }
}
