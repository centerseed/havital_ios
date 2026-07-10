import XCTest
@testable import paceriz_dev

/// Golden test against the canonical contract fixture (docs/contracts/steady-intervals-v1.json).
/// The same fixture is decoded by Android and round-tripped by api_service.
/// If this test and the Android one disagree, the contract has drifted.
final class SteadyIntervalsContractTests: XCTestCase {

    /// Fixture lives at HavitalTests/Fixtures/, this file at HavitalTests/TrainingPlanV2/.
    /// Read via #filePath so no Xcode bundle-resource wiring is needed.
    private func loadRunActivityDTO() throws -> RunActivityDTO {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // TrainingPlanV2/
            .deletingLastPathComponent()   // HavitalTests/
            .appendingPathComponent("Fixtures/steady-intervals-v1.json")
        let data = try Data(contentsOf: url)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let primary = try XCTUnwrap(root["primary"] as? [String: Any])
        let primaryData = try JSONSerialization.data(withJSONObject: primary)
        return try JSONDecoder().decode(RunActivityDTO.self, from: primaryData)
    }

    func test_runType_isSteadyIntervals() throws {
        let run = try loadRunActivityDTO()
        XCTAssertEqual(run.runType, "steady_intervals")
    }

    func test_decodesFourSegments() throws {
        let run = try loadRunActivityDTO()
        XCTAssertEqual(run.segments?.count, 4)
    }

    func test_firstSegment_hasNoKind_soItIsLegacySteady() throws {
        let segs = try XCTUnwrap(loadRunActivityDTO().segments)
        XCTAssertNil(segs[0].kind, "missing kind means a legacy document; Domain layer must degrade it to steady")
        XCTAssertEqual(segs[0].distanceKm, 5.0)
    }

    func test_intervalSegment_withJogRecovery() throws {
        let segs = try XCTUnwrap(loadRunActivityDTO().segments)
        let s = segs[1]
        XCTAssertEqual(s.kind, "interval")
        XCTAssertEqual(s.repeats, 6)
        XCTAssertEqual(s.work?.distanceM, 400)
        XCTAssertEqual(s.work?.pace, "4:05")
        XCTAssertEqual(s.work?.paceZone, "interval")
        XCTAssertEqual(s.work?.targetHrr, [0.88, 0.92])
        XCTAssertEqual(s.recovery?.durationSeconds, 90)
        XCTAssertEqual(s.recovery?.recoveryType, "jog")
        // degraded summary: legacy apps can only read these fields
        XCTAssertEqual(s.distanceKm, 3.8)
        XCTAssertEqual(s.pace, "4:05")
    }

    func test_intervalSegment_withStaticRecovery() throws {
        let segs = try XCTUnwrap(loadRunActivityDTO().segments)
        let s = segs[2]
        XCTAssertEqual(s.repeats, 4)
        XCTAssertEqual(s.work?.distanceM, 200)
        XCTAssertEqual(s.recovery?.recoveryType, "static")
        XCTAssertNil(s.recovery?.pace, "static recovery has no pace")
        XCTAssertEqual(s.distanceKm, 0.8, "static recovery contributes 0 distance, so summary = 4 x 200m")
    }

    func test_explicitSteadySegment() throws {
        let segs = try XCTUnwrap(loadRunActivityDTO().segments)
        XCTAssertEqual(segs[3].kind, "steady")
        XCTAssertNil(segs[3].repeats)
        XCTAssertNil(segs[3].work)
    }

    // MARK: - Domain mapping

    private func loadRunActivityEntity() throws -> RunActivity {
        TrainingSessionMapper.toEntity(from: try loadRunActivityDTO())
    }

    func test_missingKind_mapsToSteady() throws {
        let segs = try XCTUnwrap(loadRunActivityEntity().segments)
        XCTAssertEqual(segs[0].segmentKind, .steady)
        XCTAssertNil(segs[0].kind, "raw value is preserved as-is")
    }

    func test_unknownKind_degradesToSteady() {
        XCTAssertEqual(SegmentKind.from("pyramid"), .steady,
                       "unknown kind must degrade, otherwise a new backend type blanks the whole page")
        XCTAssertEqual(SegmentKind.from(nil), .steady)
        XCTAssertEqual(SegmentKind.from("interval"), .interval)
    }

    // MARK: - Cache compatibility (RunSegment is Codable and goes through the local cache)

    func test_entityDecodes_whenKindKeyMissing() throws {
        // Old cached documents have no "kind" key. Decoding must not throw.
        let json = #"{"distance_km":5.0,"pace":"5:30"}"#.data(using: .utf8)!
        let seg = try JSONDecoder().decode(RunSegment.self, from: json)
        XCTAssertNil(seg.kind)
        XCTAssertEqual(seg.segmentKind, .steady)
    }

    func test_entityDecodes_whenKindIsUnknown_andRoundTripsVerbatim() throws {
        // A future backend kind such as "pyramid" must not throw, and the raw value must survive.
        let json = #"{"distance_km":5.0,"pace":"5:30","kind":"pyramid"}"#.data(using: .utf8)!
        let seg = try JSONDecoder().decode(RunSegment.self, from: json)
        XCTAssertEqual(seg.kind, "pyramid", "raw value must round-trip verbatim")
        XCTAssertEqual(seg.segmentKind, .steady, "display degrades to steady")

        let reencoded = try JSONEncoder().encode(seg)
        let again = try JSONDecoder().decode(RunSegment.self, from: reencoded)
        XCTAssertEqual(again.kind, "pyramid", "raw value survives a cache round-trip")
    }

    func test_intervalSegment_mapsToEntity() throws {
        let segs = try XCTUnwrap(loadRunActivityEntity().segments)
        let s = segs[1]
        XCTAssertEqual(s.segmentKind, .interval)
        XCTAssertEqual(s.repeats, 6)
        XCTAssertEqual(s.work?.distanceM, 400)
        XCTAssertEqual(s.recovery?.recoveryType, "jog")
    }

    func test_mapperRoundTrip_preservesSequence() throws {
        let dto = try loadRunActivityDTO()
        let roundTripped = TrainingSessionMapper.toDTO(from: TrainingSessionMapper.toEntity(from: dto))
        XCTAssertEqual(roundTripped.segments?[1].kind, "interval")
        XCTAssertEqual(roundTripped.segments?[1].repeats, 6)
        XCTAssertEqual(roundTripped.segments?[1].work?.distanceM, 400)
        XCTAssertEqual(roundTripped.segments?[2].recovery?.recoveryType, "static")
    }

    // MARK: - DayType

    func test_steadyIntervals_inferredAsOwnType() throws {
        let run = try loadRunActivityEntity()
        XCTAssertEqual(DayType(rawValue: "steady_intervals"), .steadyIntervals)
        XCTAssertEqual(run.runType, "steady_intervals")
    }
}
