import XCTest
@testable import HavitalWatch

@MainActor
final class ActiveWorkoutViewModelTests: XCTestCase {
    private final class SpyWorkoutBuilder: WorkoutBuilding {
        var onMetrics: ((_ meters: Double, _ seconds: Int, _ hr: Double, _ recentSpeedMps: Double) -> Void)?
        private(set) var markedSegments: [(start: Date, end: Date, distanceMeters: Double?)] = []
        private(set) var finishedRPE: Int?

        func start(indoor: Bool) throws {}
        func pause() {}
        func resume() {}
        func markSegment(start: Date, end: Date, distanceMeters: Double?) {
            markedSegments.append((start, end, distanceMeters))
        }
        func finish(rpe: Int?, completion: @escaping (Bool) -> Void) {
            finishedRPE = rpe
            completion(true)
        }
    }

    private func snapshot(segments: [WatchSegment]) -> WatchPlanSnapshot {
        WatchPlanSnapshot(
            date: "2026-06-05",
            flowType: .warmupMainCooldown,
            totalDistanceMeters: nil,
            totalSeconds: nil,
            planId: "p",
            segments: segments
        )
    }

    private func runSegment(_ seconds: Int) -> WatchSegment {
        WatchSegment(
            kind: .run,
            measure: .time,
            targetMeters: nil,
            targetSeconds: seconds,
            paceLowSecPerKm: nil,
            paceHighSecPerKm: nil,
            label: "run",
            repIndex: nil,
            repTotal: nil
        )
    }

    func test_beginPlan_marksWarmupSegment() async {
        let builder = SpyWorkoutBuilder()
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = ActiveWorkoutViewModel(
            snapshot: snapshot(segments: [runSegment(60)]),
            workoutBuilder: builder,
            now: { now }
        )

        viewModel.start(indoor: true)
        builder.onMetrics?(100, 20, 0, 0)
        await Task.yield()
        now = now.addingTimeInterval(120)
        viewModel.beginPlan()

        XCTAssertEqual(builder.markedSegments.count, 1)
        XCTAssertEqual(builder.markedSegments[0].start, Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertEqual(builder.markedSegments[0].end, Date(timeIntervalSince1970: 1_800_000_120))
        XCTAssertEqual(builder.markedSegments[0].distanceMeters, 100)
    }

    func test_finishedMainSegment_marksFinalSegmentBeforeCooldown() async {
        let builder = SpyWorkoutBuilder()
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = ActiveWorkoutViewModel(
            snapshot: snapshot(segments: [runSegment(60)]),
            workoutBuilder: builder,
            now: { now }
        )

        viewModel.start(indoor: true)
        builder.onMetrics?(100, 20, 0, 0)
        await Task.yield()
        now = now.addingTimeInterval(30)
        viewModel.beginPlan()
        builder.onMetrics?(100, 0, 0, 0)
        await Task.yield()

        now = now.addingTimeInterval(60)
        builder.onMetrics?(500, 60, 0, 0)
        await Task.yield()

        XCTAssertEqual(viewModel.phase, .cooldown)
        XCTAssertEqual(builder.markedSegments.count, 2)
        XCTAssertEqual(builder.markedSegments[1].start, Date(timeIntervalSince1970: 1_800_000_030))
        XCTAssertEqual(builder.markedSegments[1].end, Date(timeIntervalSince1970: 1_800_000_090))
        XCTAssertEqual(builder.markedSegments[1].distanceMeters, 400)
    }

    func test_finishFromCooldown_marksCooldownSegmentBeforeFinishing() async {
        let builder = SpyWorkoutBuilder()
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = ActiveWorkoutViewModel(
            snapshot: snapshot(segments: [runSegment(1)]),
            workoutBuilder: builder,
            now: { now }
        )

        viewModel.start(indoor: true)
        now = now.addingTimeInterval(10)
        viewModel.beginPlan()
        builder.onMetrics?(10, 0, 0, 0)
        await Task.yield()
        now = now.addingTimeInterval(1)
        builder.onMetrics?(20, 1, 0, 0)
        await Task.yield()

        now = now.addingTimeInterval(90)
        builder.onMetrics?(320, 91, 0, 0)
        await Task.yield()
        let finished = expectation(description: "finish")
        viewModel.finish(rpe: 7) { ok in
            XCTAssertTrue(ok)
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 1)

        XCTAssertEqual(builder.finishedRPE, 7)
        XCTAssertEqual(builder.markedSegments.count, 3)
        XCTAssertEqual(builder.markedSegments[2].start, Date(timeIntervalSince1970: 1_800_000_011))
        XCTAssertEqual(builder.markedSegments[2].end, Date(timeIntervalSince1970: 1_800_000_101))
        XCTAssertEqual(builder.markedSegments[2].distanceMeters, 300)
    }
}
