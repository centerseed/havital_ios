final class SegmentTransitionEngine {
    let segments: [WatchSegment]
    private(set) var currentIndex: Int = 0
    private var segmentStartMeters: Double = 0
    private var segmentStartSeconds: Int = 0
    private var countdownLatched = false

    init(segments: [WatchSegment]) {
        self.segments = segments
    }

    func update(
        totalMeters: Double,
        totalSeconds: Int,
        recentSpeedMps: Double,
        isPaused: Bool
    ) -> [ActiveSegmentEvent] {
        guard !isPaused, currentIndex < segments.count else { return [] }

        let segment = segments[currentIndex]
        let metersInSegment = totalMeters - segmentStartMeters
        let secondsInSegment = totalSeconds - segmentStartSeconds

        let reached: Bool
        switch segment.measure {
        case .distance:
            reached = metersInSegment >= (segment.targetMeters ?? .infinity)
        case .time:
            reached = secondsInSegment >= (segment.targetSeconds ?? .max)
        }

        if !countdownLatched {
            let remainingSeconds: Double
            switch segment.measure {
            case .time:
                remainingSeconds = Double((segment.targetSeconds ?? .max) - secondsInSegment)
            case .distance:
                let remainingMeters = (segment.targetMeters ?? .infinity) - metersInSegment
                remainingSeconds = recentSpeedMps > 0.1 ? remainingMeters / recentSpeedMps : .infinity
            }

            if remainingSeconds <= 5, remainingSeconds >= 0, !reached {
                countdownLatched = true
                return [.countdownCue]
            }
        }

        guard reached else { return [] }

        if currentIndex == segments.count - 1 {
            currentIndex += 1
            return [.finished]
        }

        currentIndex += 1
        segmentStartMeters = totalMeters
        segmentStartSeconds = totalSeconds
        countdownLatched = false
        return [.advanced(toIndex: currentIndex)]
    }
}
