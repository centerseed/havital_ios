import XCTest
@testable import paceriz_dev

/// Tests methodology-specific constraints on API responses.
/// Validates that training plans respect methodology rules after decoding.
final class MethodologyConstraintTests: XCTestCase {

    // MARK: - Helpers

    private func loadWeeklyPlanFixture(_ name: String) throws -> Data {
        let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let fixtureURL = testDir.appendingPathComponent("Fixtures/WeeklyPlan/\(name).json")
        return try Data(contentsOf: fixtureURL)
    }

    private func decodeAndMapWeeklyPlan(from fixtureName: String) throws -> WeeklyPlanV2 {
        let data = try loadWeeklyPlanFixture(fixtureName)
        let dto = try JSONDecoder().decode(WeeklyPlanV2DTO.self, from: data)
        return WeeklyPlanV2Mapper.toEntity(from: dto)
    }

    private func loadPreviewFixture(_ name: String) throws -> Data {
        let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let fixtureURL = testDir.appendingPathComponent("Fixtures/WeeklyPreview/\(name).json")
        return try Data(contentsOf: fixtureURL)
    }

    // MARK: - Complete 10K Conversion Phase Constraints

    func test_complete10k_conversionPhase_noQualitySessions() throws {
        let entity = try decodeAndMapWeeklyPlan(from: "complete_10k_conversion_week")

        // In conversion phase, complete_10k should have NO interval/threshold/tempo workouts
        let qualityRunTypes = ["interval", "threshold", "tempo", "progression", "race_pace"]

        for day in entity.days {
            guard let session = day.session,
                  case .run(let runActivity) = session.primary else {
                continue
            }
            XCTAssertFalse(
                qualityRunTypes.contains(runActivity.runType),
                "Complete 10K conversion phase should not have \(runActivity.runType) on day \(day.dayIndex)"
            )
        }
    }

    func test_complete10k_conversionPhase_allRunsAreEasy() throws {
        let entity = try decodeAndMapWeeklyPlan(from: "complete_10k_conversion_week")

        for day in entity.days {
            guard let session = day.session,
                  case .run(let runActivity) = session.primary else {
                continue
            }
            XCTAssertEqual(
                runActivity.runType, "easy",
                "Complete 10K conversion phase: all runs should be easy, got \(runActivity.runType) on day \(day.dayIndex)"
            )
        }
    }

    // MARK: - Polarized Methodology Constraints

    func test_polarized_noModerateIntensity() throws {
        let entity = try decodeAndMapWeeklyPlan(from: "polarized_42k_build_week")

        // Polarized methodology: medium intensity should be 0
        XCTAssertNotNil(entity.intensityTotalMinutes)
        XCTAssertEqual(entity.intensityTotalMinutes?.medium, 0,
                       "Polarized methodology should have 0 moderate intensity minutes")

        // No threshold or tempo run types
        let moderateRunTypes = ["threshold", "tempo"]

        for day in entity.days {
            guard let session = day.session,
                  case .run(let runActivity) = session.primary else {
                continue
            }
            XCTAssertFalse(
                moderateRunTypes.contains(runActivity.runType),
                "Polarized methodology should not have \(runActivity.runType) on day \(day.dayIndex)"
            )
        }
    }

    // MARK: - Paceriz Methodology Constraints

    func test_paceriz_basePhase_hasTempoButNoHighIntensity() throws {
        let entity = try decodeAndMapWeeklyPlan(from: "paceriz_42k_base_week")

        // Base phase: should have tempo but no interval/VO2max work
        var hasModerate = false
        var hasHigh = false

        for day in entity.days {
            guard let session = day.session,
                  case .run(let runActivity) = session.primary else {
                continue
            }
            if runActivity.runType == "tempo" || runActivity.runType == "threshold" {
                hasModerate = true
            }
            if runActivity.runType == "interval" {
                hasHigh = true
            }
        }

        XCTAssertTrue(hasModerate, "Paceriz base phase should include moderate intensity (tempo)")
        XCTAssertFalse(hasHigh, "Paceriz base phase should not include high intensity (interval)")
    }

    func test_paceriz_peakPhase_hasIntervalsAndThreshold() throws {
        let entity = try decodeAndMapWeeklyPlan(from: "paceriz_42k_peak_week")

        var hasInterval = false
        var hasThreshold = false

        for day in entity.days {
            guard let session = day.session,
                  case .run(let runActivity) = session.primary else {
                continue
            }
            if runActivity.runType == "interval" {
                hasInterval = true
            }
            if runActivity.runType == "threshold" {
                hasThreshold = true
            }
        }

        XCTAssertTrue(hasInterval, "Paceriz peak phase should include intervals")
        XCTAssertTrue(hasThreshold, "Paceriz peak phase should include threshold")
    }
}
