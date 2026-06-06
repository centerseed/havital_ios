import XCTest
@testable import paceriz_dev

final class WatchPlanProjectorTests: XCTestCase {
    func test_backendDirectRunDTOs_projectDisplayableTopLevelSegment() throws {
        let cases: [(runType: String, distanceKm: Double, durationMinutes: Int?, pace: String, expectedPace: Int)] = [
            ("easy", 8, 48, "6:00", 360),
            ("easy_run", 7, 42, "6:00/km", 360),
            ("recovery_run", 5, 35, "7:00", 420),
            ("long_run", 18, 117, "6:30", 390),
            ("lsd", 25, 156, "6:15", 375),
        ]

        for testCase in cases {
            let dto = try projectRunActivityJSON(
                """
                {
                  "run_type": "\(testCase.runType)",
                  "distance_km": \(testCase.distanceKm),
                  "duration_minutes": \(testCase.durationMinutes ?? 0),
                  "pace": "\(testCase.pace)"
                }
                """
            )

            XCTAssertEqual(dto.runType, testCase.runType)
            XCTAssertEqual(dto.segments.count, 1, testCase.runType)
            XCTAssertEqual(dto.segments[0].kind, "run", testCase.runType)
            XCTAssertEqual(dto.segments[0].measure, "distance", testCase.runType)
            XCTAssertEqual(dto.segments[0].targetMeters, testCase.distanceKm * 1_000, testCase.runType)
            XCTAssertEqual(dto.segments[0].targetSeconds, testCase.durationMinutes.map { $0 * 60 }, testCase.runType)
            XCTAssertEqual(dto.segments[0].paceLowSecPerKm, testCase.expectedPace, testCase.runType)
            XCTAssertEqual(dto.segments[0].paceHighSecPerKm, testCase.expectedPace, testCase.runType)
        }
    }

    func test_backendQualityRunDTOsWithoutSegments_projectDisplayableTopLevelSegment() throws {
        for runType in [
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
            let dto = try projectRunActivityJSON(
                """
                {
                  "run_type": "\(runType)",
                  "distance_km": 10,
                  "duration_minutes": 50,
                  "pace": "5:00",
                  "description": "\(runType) main set"
                }
                """
            )

            XCTAssertEqual(dto.runType, runType)
            XCTAssertEqual(dto.segments.count, 1, runType)
            XCTAssertEqual(dto.segments[0].kind, "run", runType)
            XCTAssertEqual(dto.segments[0].measure, "distance", runType)
            XCTAssertEqual(dto.segments[0].targetMeters, 10_000, runType)
            XCTAssertEqual(dto.segments[0].targetSeconds, 3_000, runType)
            XCTAssertEqual(dto.segments[0].paceLowSecPerKm, 300, runType)
            XCTAssertEqual(dto.segments[0].label, "\(runType) main set", runType)
        }
    }

    func test_backendDurationOnlyRunDTO_projectsTimeSegment() throws {
        let dto = try projectRunActivityJSON(
            """
            {
              "run_type": "easy",
              "duration_seconds": 2700,
              "pace": "6:20"
            }
            """
        )

        XCTAssertEqual(dto.totalSeconds, 2_700)
        XCTAssertEqual(dto.segments.count, 1)
        XCTAssertEqual(dto.segments[0].measure, "time")
        XCTAssertNil(dto.segments[0].targetMeters)
        XCTAssertEqual(dto.segments[0].targetSeconds, 2_700)
        XCTAssertEqual(dto.segments[0].paceLowSecPerKm, 380)
    }

    func test_directRunWithTopLevelDistanceAndPace_projectsDisplayableSegment() {
        let activity = RunActivity.watchTestStub(
            runType: "easy",
            distanceKm: 8,
            durationMinutes: 48,
            pace: "6:00",
            interval: nil,
            segments: nil
        )

        let dto = WatchPlanProjector.project(activity: activity, date: "2026-06-05", planId: "easy-1")

        XCTAssertEqual(dto.runType, "easy")
        XCTAssertEqual(dto.totalDistanceMeters, 8_000)
        XCTAssertEqual(dto.totalSeconds, 2_880)
        XCTAssertEqual(dto.segments.count, 1)
        XCTAssertEqual(dto.segments[0].kind, "run")
        XCTAssertEqual(dto.segments[0].measure, "distance")
        XCTAssertEqual(dto.segments[0].targetMeters, 8_000)
        XCTAssertEqual(dto.segments[0].targetSeconds, 2_880)
        XCTAssertEqual(dto.segments[0].paceLowSecPerKm, 360)
        XCTAssertEqual(dto.segments[0].paceHighSecPerKm, 360)
    }

    func test_backendIntervalDTO_projectsDistanceWorkAndStaticTimeRecovery() throws {
        let dto = try projectRunActivityJSON(
            """
            {
              "run_type": "interval",
              "distance_km": 6.4,
              "interval": {
                "repeats": 4,
                "work_distance_m": 400,
                "work_pace": "5:05",
                "work_description": "400m",
                "recovery_duration_seconds": 245,
                "recovery_description": "245s static recovery"
              }
            }
            """
        )

        XCTAssertEqual(dto.totalDistanceMeters, 6_400)
        XCTAssertEqual(dto.segments.count, 8)
        XCTAssertEqual(dto.segments[0].kind, "run")
        XCTAssertEqual(dto.segments[0].measure, "distance")
        XCTAssertEqual(dto.segments[0].targetMeters, 400)
        XCTAssertEqual(dto.segments[0].paceLowSecPerKm, 305)
        XCTAssertEqual(dto.segments[0].label, "400m")
        XCTAssertEqual(dto.segments[1].kind, "rest")
        XCTAssertEqual(dto.segments[1].measure, "time")
        XCTAssertEqual(dto.segments[1].targetSeconds, 245)
        XCTAssertEqual(dto.segments[1].label, "245s static recovery")
        XCTAssertEqual(dto.segments[7].repIndex, 4)
        XCTAssertEqual(dto.segments[7].repTotal, 4)
    }

    func test_backendIntervalDTO_projectsTimeWorkAndDistanceRecovery() throws {
        let dto = try projectRunActivityJSON(
            """
            {
              "run_type": "norwegian_4x4",
              "interval": {
                "repeats": 4,
                "work_duration_minutes": 4,
                "work_pace": "4:10",
                "recovery_distance_km": 0.4,
                "recovery_pace": "7:00",
                "recovery_description": "jog recovery"
              }
            }
            """
        )

        XCTAssertEqual(dto.segments.count, 8)
        XCTAssertEqual(dto.segments[0].kind, "run")
        XCTAssertEqual(dto.segments[0].measure, "time")
        XCTAssertNil(dto.segments[0].targetMeters)
        XCTAssertEqual(dto.segments[0].targetSeconds, 240)
        XCTAssertEqual(dto.segments[0].paceLowSecPerKm, 250)
        XCTAssertEqual(dto.segments[1].kind, "rest")
        XCTAssertEqual(dto.segments[1].measure, "distance")
        XCTAssertEqual(dto.segments[1].targetMeters, 400)
        XCTAssertEqual(dto.segments[1].paceLowSecPerKm, 420)
        XCTAssertEqual(dto.segments[1].label, "jog recovery")
    }

    func test_backendIntervalDTOWithoutRecovery_projectsOnlyWorkRepeats() throws {
        let dto = try projectRunActivityJSON(
            """
            {
              "run_type": "strides",
              "interval": {
                "repeats": 6,
                "work_distance_m": 100,
                "work_pace": "3:30",
                "variant": "strides"
              }
            }
            """
        )

        XCTAssertEqual(dto.segments.count, 6)
        XCTAssertTrue(dto.segments.allSatisfy { $0.kind == "run" })
        XCTAssertTrue(dto.segments.allSatisfy { $0.targetMeters == 100 })
        XCTAssertTrue(dto.segments.allSatisfy { $0.paceLowSecPerKm == 210 })
        XCTAssertEqual(dto.segments[5].repIndex, 6)
        XCTAssertEqual(dto.segments[5].repTotal, 6)
    }

    func test_backendSegmentDTOs_projectMainSegmentsAndFilterWarmupCooldown() throws {
        let dto = try projectRunActivityJSON(
            """
            {
              "run_type": "progression",
              "distance_km": 12,
              "segments": [
                {"distance_km": 2, "pace": "6:30", "intensity": "warmup", "description": "Warmup"},
                {"distance_km": 4, "pace": "6:00", "intensity": "easy", "description": "Easy"},
                {"duration_seconds": 1200, "pace": "5:20", "intensity": "steady", "description": "Steady"},
                {"distance_m": 3000, "pace": "5:00", "intensity": "tempo", "description": "Tempo"},
                {"distance_km": 1, "pace": "6:40", "intensity": "cooldown", "description": "Cooldown"}
              ]
            }
            """
        )

        XCTAssertEqual(dto.segments.count, 3)
        XCTAssertEqual(dto.segments[0].measure, "distance")
        XCTAssertEqual(dto.segments[0].targetMeters, 4_000)
        XCTAssertEqual(dto.segments[0].paceLowSecPerKm, 360)
        XCTAssertEqual(dto.segments[1].measure, "time")
        XCTAssertEqual(dto.segments[1].targetSeconds, 1_200)
        XCTAssertEqual(dto.segments[1].paceLowSecPerKm, 320)
        XCTAssertEqual(dto.segments[2].targetMeters, 3_000)
        XCTAssertEqual(dto.segments[2].paceLowSecPerKm, 300)
    }

    func test_intervalBlock_expandsToWorkRestPairs() {
        let block = IntervalBlock(
            repeats: 3,
            workDistanceKm: nil,
            workDistanceM: 800,
            workDistanceDisplay: nil,
            workDistanceUnit: nil,
            workPaceUnit: nil,
            workDurationMinutes: nil,
            workPace: "4:30",
            workDescription: nil,
            recoveryDistanceKm: nil,
            recoveryDistanceM: nil,
            recoveryDurationMinutes: nil,
            recoveryPace: nil,
            recoveryDescription: nil,
            recoveryDurationSeconds: 120,
            variant: nil
        )
        let activity = RunActivity.watchTestStub(runType: "interval", interval: block)

        let dto = WatchPlanProjector.project(activity: activity, date: "2026-06-05", planId: "plan-1")

        XCTAssertEqual(dto.date, "2026-06-05")
        XCTAssertEqual(dto.runType, "interval")
        XCTAssertEqual(dto.planId, "plan-1")
        XCTAssertEqual(dto.segments.count, 6)
        XCTAssertEqual(dto.segments[0].kind, "run")
        XCTAssertEqual(dto.segments[0].measure, "distance")
        XCTAssertEqual(dto.segments[0].targetMeters, 800)
        XCTAssertEqual(dto.segments[0].repIndex, 1)
        XCTAssertEqual(dto.segments[0].repTotal, 3)
        XCTAssertEqual(dto.segments[0].paceLowSecPerKm, 270)
        XCTAssertEqual(dto.segments[1].kind, "rest")
        XCTAssertEqual(dto.segments[1].measure, "time")
        XCTAssertEqual(dto.segments[1].targetSeconds, 120)
        XCTAssertEqual(dto.segments[5].repIndex, 3)
    }

    func test_paceToSec_parsesMinutesSecondsWithOptionalUnitSuffix() {
        XCTAssertEqual(WatchPlanProjector.paceToSec("4:30"), 270)
        XCTAssertEqual(WatchPlanProjector.paceToSec("4:30/km"), 270)
        XCTAssertEqual(WatchPlanProjector.paceToSec("5:00"), 300)
        XCTAssertNil(WatchPlanProjector.paceToSec(nil))
        XCTAssertNil(WatchPlanProjector.paceToSec("--"))
    }

    func test_segments_filterOutWarmupCooldown() {
        let warmup = RunSegment.watchTestStub(intensity: "warmup", distanceM: 1_000, pace: "6:00")
        let main = RunSegment.watchTestStub(intensity: "tempo", distanceM: 3_000, pace: "4:00")
        let cooldown = RunSegment.watchTestStub(intensity: "cooldown", distanceM: 1_000, pace: "6:10")

        let result = WatchPlanProjector.projectSegments([warmup, main, cooldown])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].kind, "run")
        XCTAssertEqual(result[0].measure, "distance")
        XCTAssertEqual(result[0].targetMeters, 3_000)
        XCTAssertEqual(result[0].paceLowSecPerKm, 240)
    }
}

private func projectRunActivityJSON(_ json: String) throws -> WatchPlanSnapshotDTO {
    let dto = try JSONDecoder().decode(RunActivityDTO.self, from: Data(json.utf8))
    let entity = TrainingSessionMapper.toEntity(from: dto)
    return WatchPlanProjector.project(activity: entity, date: "2026-06-05", planId: "plan-json")
}

private extension RunActivity {
    static func watchTestStub(
        runType: String = "easy",
        distanceKm: Double? = nil,
        durationMinutes: Int? = nil,
        pace: String? = nil,
        interval: IntervalBlock? = nil,
        segments: [RunSegment]? = nil
    ) -> RunActivity {
        RunActivity(
            runType: runType,
            distanceKm: distanceKm,
            distanceDisplay: nil,
            distanceUnit: nil,
            paceUnit: nil,
            durationMinutes: durationMinutes,
            durationSeconds: nil,
            pace: pace,
            basePace: nil,
            climateAdjustedPace: nil,
            heartRateRange: nil,
            interval: interval,
            segments: segments,
            description: nil,
            targetIntensity: nil,
            climateMeta: nil
        )
    }
}

private extension RunSegment {
    static func watchTestStub(
        intensity: String?,
        distanceM: Int?,
        pace: String?,
        durationSeconds: Int? = nil
    ) -> RunSegment {
        RunSegment(
            distanceKm: nil,
            distanceM: distanceM,
            distanceDisplay: nil,
            distanceUnit: nil,
            durationMinutes: nil,
            durationSeconds: durationSeconds,
            pace: pace,
            basePace: nil,
            climateAdjustedPace: nil,
            climateMeta: nil,
            heartRateRange: nil,
            intensity: intensity,
            description: nil
        )
    }
}
