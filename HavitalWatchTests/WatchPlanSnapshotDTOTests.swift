import XCTest
@testable import HavitalWatch

final class WatchPlanSnapshotDTOTests: XCTestCase {
    private let json = """
    {
      "date": "2026-06-05",
      "run_type": "interval",
      "total_distance_meters": 6400,
      "total_seconds": null,
      "plan_id": "plan_abc",
      "segments": [
        {"kind":"run","measure":"distance","target_meters":800,"target_seconds":null,
         "pace_low_sec_per_km":270,"pace_high_sec_per_km":290,"label":"800m","rep_index":1,"rep_total":5},
        {"kind":"rest","measure":"time","target_meters":null,"target_seconds":120,
         "pace_low_sec_per_km":null,"pace_high_sec_per_km":null,"label":"休息","rep_index":1,"rep_total":5}
      ]
    }
    """.data(using: .utf8)!

    func test_decodesDTOAndMapsToEntity() throws {
        let dto = try JSONDecoder().decode(WatchPlanSnapshotDTO.self, from: json)
        let entity = dto.toEntity()
        XCTAssertEqual(entity.date, "2026-06-05")
        XCTAssertEqual(entity.flowType, .warmupMainCooldown)
        XCTAssertEqual(entity.totalDistanceMeters, 6400)
        XCTAssertEqual(entity.segments.count, 2)
        XCTAssertEqual(entity.segments[0].kind, .run)
        XCTAssertEqual(entity.segments[0].measure, .distance)
        XCTAssertEqual(entity.segments[0].targetMeters, 800)
        XCTAssertEqual(entity.segments[0].paceLowSecPerKm, 270)
        XCTAssertEqual(entity.segments[0].repIndex, 1)
        XCTAssertEqual(entity.segments[1].kind, .rest)
        XCTAssertEqual(entity.segments[1].targetSeconds, 120)
    }

    func test_unknownSegmentKind_fallsBackToRun() throws {
        let bad = #"{"date":"2026-06-05","run_type":"interval","plan_id":"p","segments":[{"kind":"weird","measure":"distance","target_meters":400,"label":"x"}]}"#.data(using: .utf8)!
        let dto = try JSONDecoder().decode(WatchPlanSnapshotDTO.self, from: bad)
        XCTAssertEqual(dto.toEntity().segments[0].kind, .run)
    }

    func test_backendRunTypesDecodeToDisplayableWatchDetails() throws {
        let cases: [(runType: String, flow: WorkoutFlowType)] = [
            ("easy", .directStart),
            ("easy_run", .directStart),
            ("recovery_run", .directStart),
            ("long_run", .directStart),
            ("lsd", .directStart),
            ("tempo", .warmupMainCooldown),
            ("threshold", .warmupMainCooldown),
            ("fartlek", .warmupMainCooldown),
            ("progression", .warmupMainCooldown),
            ("interval", .warmupMainCooldown),
            ("short_interval", .warmupMainCooldown),
            ("long_interval", .warmupMainCooldown),
            ("short_intervals", .warmupMainCooldown),
            ("long_intervals", .warmupMainCooldown),
            ("tempo_run", .warmupMainCooldown),
            ("threshold_run", .warmupMainCooldown),
            ("combination", .warmupMainCooldown),
            ("benchmark", .warmupMainCooldown),
            ("race", .warmupMainCooldown),
            ("race_pace", .warmupMainCooldown),
            ("strides", .warmupMainCooldown),
            ("strides_session", .warmupMainCooldown),
            ("hill_repeats", .warmupMainCooldown),
            ("hill_sprints", .warmupMainCooldown),
            ("cruise_intervals", .warmupMainCooldown),
            ("norwegian_4x4", .warmupMainCooldown),
            ("norwegian_singles", .warmupMainCooldown),
            ("norwegian_doubles", .warmupMainCooldown),
            ("norwegian_threshold", .warmupMainCooldown),
            ("yasso_800", .warmupMainCooldown),
            ("mile_repeats", .warmupMainCooldown),
            ("fast_finish", .warmupMainCooldown),
        ]

        for testCase in cases {
            let data = """
            {
              "date": "2026-06-05",
              "run_type": "\(testCase.runType)",
              "total_distance_meters": 8000,
              "total_seconds": 2880,
              "plan_id": "plan-\(testCase.runType)",
              "segments": [
                {
                  "kind": "run",
                  "measure": "distance",
                  "target_meters": 8000,
                  "target_seconds": 2880,
                  "pace_low_sec_per_km": 360,
                  "pace_high_sec_per_km": 360,
                  "label": "\(testCase.runType)",
                  "rep_index": null,
                  "rep_total": null
                }
              ]
            }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(WatchPlanSnapshotDTO.self, from: data)
            let entity = dto.toEntity()

            XCTAssertEqual(entity.flowType, testCase.flow, testCase.runType)
            XCTAssertEqual(entity.segments.count, 1, testCase.runType)
            XCTAssertEqual(
                WorkoutSummaryFormatter.detailLines(for: entity),
                ["8.00 km", "目標配速 6:00/km"],
                testCase.runType
            )
        }
    }
}
