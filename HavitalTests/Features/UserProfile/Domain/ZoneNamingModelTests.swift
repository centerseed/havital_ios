import XCTest
@testable import paceriz_dev

/// Zone naming / mapping alignment with the (authoritative) backend model.
///
/// Backend ground truth:
/// - `tempo` (節奏跑) ≡ `threshold` (閾值): tempo is anchored at the lactate-threshold
///   (LT2 ~87% HRR) band, so 節奏跑 belongs to the THRESHOLD zone.
/// - `marathon` (~76%) / `half_marathon` (~82%) → the ~0.75–0.84 HRR band is the
///   MARATHON / Zone-3 band.
///
/// Correct 6-zone model:
///   recovery / easy / marathon (Z3, ~0.75–0.84) / threshold (Z4, ~0.83–0.88) /
///   anaerobic / interval.
final class ZoneNamingModelTests: XCTestCase {

    // MARK: - HR Zones (HeartRateZone)

    func test_hrZone3_isMarathon_not_tempo() {
        let zones = HeartRateZone.calculateZones(maxHR: 180, restingHR: 60)
        let z3 = zones.first { $0.zone == 3 }
        XCTAssertNotNil(z3)
        // Zone 3 resolves to the Marathon name, NOT 節奏/Tempo.
        XCTAssertEqual(z3?.name, NSLocalizedString("hr_zone.marathon", comment: ""))
        XCTAssertNotEqual(z3?.name, NSLocalizedString("hr_zone.tempo", comment: ""),
                          "Zone 3 (~0.75–0.84) is the marathon band, not tempo")
    }

    func test_hrZone3_marathonName_localizesToMarathonText() {
        let zones = HeartRateZone.calculateZones(maxHR: 180, restingHR: 60)
        let z3 = zones.first { $0.zone == 3 }
        // Key must resolve to a real localized value, not fall back to the key name.
        XCTAssertEqual(z3?.name, NSLocalizedString("hr_zone.marathon", comment: ""))
        XCTAssertNotEqual(z3?.name, "hr_zone.marathon",
                          "hr_zone.marathon must be defined in the active locale")
    }

    func test_hrZone4_isThreshold() {
        let zones = HeartRateZone.calculateZones(maxHR: 180, restingHR: 60)
        let z4 = zones.first { $0.zone == 4 }
        XCTAssertNotNil(z4)
        XCTAssertEqual(z4?.name, NSLocalizedString("hr_zone.threshold", comment: ""))
    }

    func test_hrZone3_marathonBand_below_zone4_thresholdBand() {
        let zones = HeartRateZone.calculateZones(maxHR: 180, restingHR: 60)
        let z3 = zones.first { $0.zone == 3 }!
        let z4 = zones.first { $0.zone == 4 }!
        // Marathon band (Z3) sits below the threshold band (Z4).
        XCTAssertLessThan(z3.range.lowerBound, z4.range.lowerBound,
                          "Marathon (Z3) lower bound must be below threshold (Z4)")
    }

    // MARK: - Pace Zones (PaceCalculator)

    func test_paceZone_tempo_isThresholdBand() {
        // 節奏跑 / tempo paces correspond to the threshold band (~0.83–0.88).
        let (low, high) = PaceCalculator.PaceZone.tempo.percentageRange
        XCTAssertEqual(low, 0.83, accuracy: 0.001, "tempo low must align to threshold band")
        XCTAssertEqual(high, 0.88, accuracy: 0.001, "tempo high must align to threshold band")
    }

    func test_paceZone_marathon_isModerateBand() {
        // The ~0.75–0.84 band is marathon.
        let (low, high) = PaceCalculator.PaceZone.marathon.percentageRange
        XCTAssertEqual(low, 0.75, accuracy: 0.001, "marathon low must be the M band")
        XCTAssertEqual(high, 0.84, accuracy: 0.001, "marathon high must be the M band")
    }

    func test_paceZone_tempo_fasterThan_marathon() {
        // Tempo (threshold effort) must be a faster pace than marathon effort.
        let vdot = 45.0
        let tempo = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot)!
        let marathon = PaceCalculator.getSuggestedPace(for: "marathon", vdot: vdot)!
        let tempoSec = PaceFormatterHelper.paceToSeconds(tempo) ?? 0
        let marathonSec = PaceFormatterHelper.paceToSeconds(marathon) ?? 0
        XCTAssertLessThan(tempoSec, marathonSec,
                          "Tempo (threshold band) must be faster than marathon band")
    }
}
