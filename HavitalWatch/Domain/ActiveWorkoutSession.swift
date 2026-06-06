import Foundation

final class ActiveWorkoutSession {
    enum Phase: Equatable {
        case warmup
        case main
        case cooldown
        case finished
    }

    let snapshot: WatchPlanSnapshot
    private(set) var phase: Phase
    private(set) var isPaused = false
    private(set) var activeDistanceMeters: Double = 0
    private(set) var activeElapsedSeconds: Int = 0

    private let engine: SegmentTransitionEngine?
    private let mainSegments: [WatchSegment]
    private var lastRawMeters: Double?
    private var lastRawSeconds: Int?
    private var needsResumeBaseline = false

    init(snapshot: WatchPlanSnapshot) {
        self.snapshot = snapshot

        switch snapshot.flowType {
        case .directStart:
            mainSegments = snapshot.segments
            phase = .main
            engine = nil
            lastRawMeters = 0
            lastRawSeconds = 0
        case .warmupMainCooldown:
            mainSegments = snapshot.segments.filter { segment in
                segment.kind != .warmup && segment.kind != .cooldown
            }
            phase = .warmup
            engine = mainSegments.isEmpty ? nil : SegmentTransitionEngine(segments: mainSegments)
        case .rest, .unsupported:
            mainSegments = []
            phase = .finished
            engine = nil
        }
    }

    var currentSegmentIndex: Int {
        engine?.currentIndex ?? 0
    }

    var currentSegment: WatchSegment? {
        guard
            let engine,
            engine.currentIndex < mainSegments.count
        else {
            return nil
        }
        return mainSegments[engine.currentIndex]
    }

    func beginPlan() {
        guard phase == .warmup else { return }
        phase = .main
        resetActiveTracking()
    }

    func setPaused(_ paused: Bool) {
        guard isPaused != paused else { return }
        isPaused = paused
        if paused {
            needsResumeBaseline = true
        }
    }

    func finish() {
        phase = .finished
    }

    @discardableResult
    func ingest(totalMeters: Double, totalSeconds: Int, recentSpeedMps: Double) -> [ActiveSegmentEvent] {
        guard phase == .main else { return [] }

        guard !isPaused else {
            lastRawMeters = totalMeters
            lastRawSeconds = totalSeconds
            needsResumeBaseline = false
            return []
        }

        guard
            let previousMeters = lastRawMeters,
            let previousSeconds = lastRawSeconds,
            !needsResumeBaseline
        else {
            lastRawMeters = totalMeters
            lastRawSeconds = totalSeconds
            needsResumeBaseline = false
            return []
        }

        activeDistanceMeters += max(0, totalMeters - previousMeters)
        activeElapsedSeconds += max(0, totalSeconds - previousSeconds)
        lastRawMeters = totalMeters
        lastRawSeconds = totalSeconds

        guard let engine else { return [] }
        let events = engine.update(
            totalMeters: activeDistanceMeters,
            totalSeconds: activeElapsedSeconds,
            recentSpeedMps: recentSpeedMps,
            isPaused: false
        )
        events.forEach(handleSegmentEvent)
        return events
    }

    func handleSegmentEvent(_ event: ActiveSegmentEvent) {
        guard case .finished = event else { return }
        phase = snapshot.flowType == .warmupMainCooldown ? .cooldown : .finished
    }

    private func resetActiveTracking() {
        activeDistanceMeters = 0
        activeElapsedSeconds = 0
        lastRawMeters = nil
        lastRawSeconds = nil
        needsResumeBaseline = false
    }
}
