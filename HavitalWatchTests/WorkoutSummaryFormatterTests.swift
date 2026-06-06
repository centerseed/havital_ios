import XCTest
@testable import HavitalWatch

final class WorkoutSummaryFormatterTests: XCTestCase {
    func test_intervalDetails_includeWorkPaceAndRecovery() {
        let snapshot = WatchPlanSnapshot(
            date: "2026-06-01",
            flowType: .warmupMainCooldown,
            totalDistanceMeters: nil,
            totalSeconds: nil,
            planId: "interval",
            segments: [
                WatchSegment(
                    kind: .work,
                    measure: .distance,
                    targetMeters: 400,
                    targetSeconds: nil,
                    paceLowSecPerKm: 245,
                    paceHighSecPerKm: 255,
                    label: "400m",
                    repIndex: 1,
                    repTotal: 4
                ),
                WatchSegment(
                    kind: .rest,
                    measure: .time,
                    targetMeters: nil,
                    targetSeconds: 90,
                    paceLowSecPerKm: nil,
                    paceHighSecPerKm: nil,
                    label: "慢跑恢復",
                    repIndex: 1,
                    repTotal: 4
                )
            ]
        )

        XCTAssertEqual(
            WorkoutSummaryFormatter.detailLines(for: snapshot),
            [
                "400m × 4",
                "目標配速 4:05-4:15/km",
                "每趟後恢復跑 1 分 30 秒"
            ]
        )
    }

    func test_warmupAndCooldownDetails_includeDuration() {
        let snapshot = WatchPlanSnapshot(
            date: "2026-06-01",
            flowType: .warmupMainCooldown,
            totalDistanceMeters: nil,
            totalSeconds: nil,
            planId: "interval",
            segments: [
                WatchSegment(
                    kind: .warmup,
                    measure: .time,
                    targetMeters: nil,
                    targetSeconds: 600,
                    paceLowSecPerKm: nil,
                    paceHighSecPerKm: nil,
                    label: "Warmup",
                    repIndex: nil,
                    repTotal: nil
                ),
                WatchSegment(
                    kind: .cooldown,
                    measure: .time,
                    targetMeters: nil,
                    targetSeconds: 480,
                    paceLowSecPerKm: nil,
                    paceHighSecPerKm: nil,
                    label: "Cooldown",
                    repIndex: nil,
                    repTotal: nil
                )
            ]
        )

        XCTAssertEqual(
            WorkoutSummaryFormatter.detailLines(for: snapshot),
            [
                "暖身 10 分鐘",
                "緩和 8 分鐘"
            ]
        )
    }

    func test_intervalDetails_collapseEqualPaceAndNormalizeStaticRecovery() {
        let snapshot = WatchPlanSnapshot(
            date: "2026-06-01",
            flowType: .warmupMainCooldown,
            totalDistanceMeters: nil,
            totalSeconds: nil,
            planId: "interval",
            segments: [
                WatchSegment(
                    kind: .work,
                    measure: .distance,
                    targetMeters: 400,
                    targetSeconds: nil,
                    paceLowSecPerKm: 305,
                    paceHighSecPerKm: 305,
                    label: "400m",
                    repIndex: 1,
                    repTotal: 4
                ),
                WatchSegment(
                    kind: .rest,
                    measure: .time,
                    targetMeters: nil,
                    targetSeconds: 245,
                    paceLowSecPerKm: nil,
                    paceHighSecPerKm: nil,
                    label: "245s static recovery",
                    repIndex: 1,
                    repTotal: 4
                )
            ]
        )

        XCTAssertEqual(
            WorkoutSummaryFormatter.detailLines(for: snapshot),
            [
                "400m × 4",
                "目標配速 5:05/km",
                "每趟後原地休息 4 分 05 秒"
            ]
        )
    }

    func test_intervalDetails_deduplicateExpandedRepeats() {
        let work = WatchSegment(
            kind: .work,
            measure: .distance,
            targetMeters: 400,
            targetSeconds: nil,
            paceLowSecPerKm: 305,
            paceHighSecPerKm: 305,
            label: "400m",
            repIndex: 1,
            repTotal: 4
        )
        let rest = WatchSegment(
            kind: .rest,
            measure: .time,
            targetMeters: nil,
            targetSeconds: 245,
            paceLowSecPerKm: nil,
            paceHighSecPerKm: nil,
            label: "245s static recovery",
            repIndex: 1,
            repTotal: 4
        )
        let snapshot = WatchPlanSnapshot(
            date: "2026-06-01",
            flowType: .warmupMainCooldown,
            totalDistanceMeters: nil,
            totalSeconds: nil,
            planId: "interval",
            segments: [work, rest, work, rest]
        )

        XCTAssertEqual(
            WorkoutSummaryFormatter.detailLines(for: snapshot),
            [
                "400m × 4",
                "目標配速 5:05/km",
                "每趟後原地休息 4 分 05 秒"
            ]
        )
    }
}
