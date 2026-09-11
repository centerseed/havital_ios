import XCTest
@testable import paceriz_dev

/// Zone naming / mapping alignment with the (authoritative) backend model.
///
/// Backend ground truth — `prompts/sections/training_type_section.py:272`:
///     "tempo": get_pace_range(vdot, 0.75, 0.84)
/// and `intensity_calculator.py:665`: medium_intensity_types = {'tempo', 'race_pace', ...}.
///
/// So `tempo` is the MEDIUM / marathon band, NOT the lactate-threshold band. It was renamed
/// to 「馬拉松配速」 on the client (hr_zone.tempo now localizes to 馬拉松), and the threshold
/// effort lives in its own `threshold` zone. An earlier version of this file asserted the
/// opposite (`tempo ≡ threshold`); that premise contradicted both the backend table above and
/// PaceCalculator, which is why it went red.
///
/// 6-zone model, as shipped:
///   recovery (0.52–0.59) / easy (0.59–0.74) / marathon (Z3, 0.75–0.84) /
///   threshold (Z4, 0.83–0.88) / anaerobic (0.88–0.95) / interval (0.95–1.0)
///
/// 2026-09-11：`PaceZone.tempo` 已刪除。它與 `marathon` 的百分比範圍一字不差，配速表
/// 因此同時列出「馬拉松配速[M]」與「全程馬拉松配速[M]」、數字一樣（使用者回報）。
/// zone 的 SSOT 是後端 `core/calculations/speed_zones.py:12` 的六格，沒有 tempo，
/// 所以留 marathon；節奏跑（`tempo` run type）對映到 M 區。
final class ZoneNamingModelTests: XCTestCase {

    // MARK: - HR Zones (HeartRateZone)

    func test_hrZone3_isMarathon_not_threshold() {
        let zones = HeartRateZone.calculateZones(maxHR: 180, restingHR: 60)
        let z3 = zones.first { $0.zone == 3 }
        XCTAssertNotNil(z3)
        // Zone 3 is the marathon band. Comparing against hr_zone.tempo would be vacuous —
        // that key is an alias whose value is now 「馬拉松」 too. The band it must NOT be
        // confused with is threshold (Z4).
        XCTAssertEqual(z3?.name, NSLocalizedString("hr_zone.marathon", comment: ""))
        XCTAssertNotEqual(z3?.name, NSLocalizedString("hr_zone.threshold", comment: ""),
                          "Zone 3 (~0.75–0.84) is the marathon band, not threshold")
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

    /// 配速表**不得出現兩格同樣範圍**（2026-09-11 使用者回報）。這一條鎖的是
    /// 「zone 集合沒有重複的百分比範圍」，不是某一格的值——加回任何一格別名都會紅。
    func test_paceZones_haveNoDuplicateRanges() {
        let ranges = PaceCalculator.PaceZone.allCases.map { $0.percentageRange }
        let unique = Set(ranges.map { "\($0.0)-\($0.1)" })
        XCTAssertEqual(
            unique.count, ranges.count,
            "有兩格以上的配速區間範圍完全相同：\(PaceCalculator.PaceZone.allCases.map { "\($0)=\($0.percentageRange)" })"
        )
    }

    func test_paceZones_matchBackendZoneSet() {
        // 後端 `core/calculations/speed_zones.py:12` 的 zone_order 加上 client 自己多的
        // 一格 `anaerobic`（落在 I 與 R 之間，見 `PaceZone.danielsCode` 的註解）。
        XCTAssertEqual(
            PaceCalculator.PaceZone.allCases.map { String(describing: $0) },
            ["recovery", "easy", "marathon", "threshold", "anaerobic", "interval"]
        )
    }

    func test_paceZone_threshold_isThresholdBand() {
        // The lactate-threshold effort has its own zone; it is NOT what `tempo` means here.
        let (low, high) = PaceCalculator.PaceZone.threshold.percentageRange
        XCTAssertEqual(low, 0.83, accuracy: 0.001, "threshold low must be the LT2 band")
        XCTAssertEqual(high, 0.88, accuracy: 0.001, "threshold high must be the LT2 band")
    }

    func test_paceZone_marathon_isModerateBand() {
        // The ~0.75–0.84 band is marathon.
        let (low, high) = PaceCalculator.PaceZone.marathon.percentageRange
        XCTAssertEqual(low, 0.75, accuracy: 0.001, "marathon low must be the M band")
        XCTAssertEqual(high, 0.84, accuracy: 0.001, "marathon high must be the M band")
    }

    func test_paceZone_threshold_fasterThan_marathon() {
        // The invariant that actually matters: threshold effort is faster than marathon effort.
        let vdot = 45.0
        let threshold = PaceCalculator.getSuggestedPace(for: "threshold", vdot: vdot)!
        let marathon = PaceCalculator.getSuggestedPace(for: "marathon", vdot: vdot)!
        let thresholdSec = PaceFormatterHelper.paceToSeconds(threshold) ?? 0
        let marathonSec = PaceFormatterHelper.paceToSeconds(marathon) ?? 0
        XCTAssertLessThan(thresholdSec, marathonSec,
                          "Threshold (LT2 band) must be faster than the marathon band")
    }
}
