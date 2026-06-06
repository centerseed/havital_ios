import SwiftUI

@MainActor
final class ActiveWorkoutViewModel: ObservableObject {
    let snapshot: WatchPlanSnapshot

    @Published var meters: Double = 0
    @Published var seconds: Int = 0
    @Published var heartRate: Double = 0
    @Published var recentSpeedMps: Double = 0
    @Published var phase: ActiveWorkoutSession.Phase
    @Published var currentSegment: WatchSegment?
    @Published var segmentMeters: Double = 0
    @Published var segmentSeconds: Int = 0
    @Published var isPaused = false

    private let session: ActiveWorkoutSession
    private let hk: WorkoutBuilding
    private let now: () -> Date
    private var segmentStartMeters: Double = 0
    private var segmentStartSeconds: Int = 0
    private var lastSegmentBoundary = Date()
    private var lastSegmentBoundaryMeters: Double = 0

    init(
        snapshot: WatchPlanSnapshot,
        workoutBuilder: WorkoutBuilding = HKLiveWorkoutBuilderWrapper(),
        now: @escaping () -> Date = Date.init
    ) {
        self.snapshot = snapshot
        self.hk = workoutBuilder
        self.now = now
        session = ActiveWorkoutSession(snapshot: snapshot)
        phase = session.phase
        currentSegment = snapshot.segments.first
        hk.onMetrics = { [weak self] meters, seconds, heartRate, speed in
            Task { @MainActor in
                self?.onMetrics(meters, seconds, heartRate, speed)
            }
        }
    }

    func start(indoor: Bool) {
        lastSegmentBoundary = now()
        lastSegmentBoundaryMeters = meters
        try? hk.start(indoor: indoor)
        HapticPlayer.start()
    }

    func beginPlan() {
        let previousPhase = phase
        session.beginPlan()
        phase = session.phase
        if previousPhase == .warmup, phase == .main {
            markSegmentBoundary()
        }
        currentSegment = session.currentSegment
        segmentStartMeters = session.activeDistanceMeters
        segmentStartSeconds = session.activeElapsedSeconds
    }

    func setPaused(_ paused: Bool) {
        session.setPaused(paused)
        isPaused = session.isPaused
        paused ? hk.pause() : hk.resume()
    }

    func finish(rpe: Int?, completion: @escaping (Bool) -> Void) {
        markOpenSegmentIfNeeded()
        session.finish()
        phase = .finished
        HapticPlayer.stop()
        hk.finish(rpe: rpe, completion: completion)
    }

    private func onMetrics(_ meters: Double, _ seconds: Int, _ heartRate: Double, _ speed: Double) {
        self.meters = meters
        self.seconds = seconds
        self.heartRate = heartRate
        recentSpeedMps = speed

        let events = session.ingest(totalMeters: meters, totalSeconds: seconds, recentSpeedMps: speed)
        updateSegmentProgress()

        for event in events {
            switch event {
            case .countdownCue:
                HapticPlayer.segmentCue()
            case .advanced:
                HapticPlayer.start()
                currentSegment = session.currentSegment
                markSegmentBoundary()
                segmentStartMeters = session.activeDistanceMeters
                segmentStartSeconds = session.activeElapsedSeconds
                updateSegmentProgress()
            case .finished:
                markSegmentBoundary()
                phase = session.phase
                currentSegment = nil
            }
        }
    }

    private func updateSegmentProgress() {
        segmentMeters = max(0, session.activeDistanceMeters - segmentStartMeters)
        segmentSeconds = max(0, session.activeElapsedSeconds - segmentStartSeconds)
    }

    private func markOpenSegmentIfNeeded() {
        guard snapshot.flowType == .warmupMainCooldown else { return }
        switch phase {
        case .warmup, .main, .cooldown:
            markSegmentBoundary()
        case .finished:
            break
        }
    }

    private func markSegmentBoundary() {
        let end = now()
        let distanceMeters = max(0, meters - lastSegmentBoundaryMeters)
        hk.markSegment(
            start: lastSegmentBoundary,
            end: end,
            distanceMeters: distanceMeters > 0 ? distanceMeters : nil
        )
        lastSegmentBoundary = end
        lastSegmentBoundaryMeters = meters
    }
}
