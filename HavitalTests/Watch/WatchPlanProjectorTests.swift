import XCTest
@testable import paceriz_dev

final class WatchPlanProjectorTests: XCTestCase {
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
