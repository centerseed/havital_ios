import Foundation

enum WatchPlanProjector {
    static func project(activity: RunActivity, date: String, planId: String) -> WatchPlanSnapshotDTO {
        let segments = activity.interval.map(expandInterval) ?? projectSegments(activity.segments ?? [])

        return WatchPlanSnapshotDTO(
            date: date,
            runType: activity.runType,
            totalDistanceMeters: activity.distanceKm.map { $0 * 1_000 },
            totalSeconds: activity.durationSeconds ?? activity.durationMinutes.map { $0 * 60 },
            planId: planId,
            segments: segments
        )
    }

    static func projectSegments(_ segments: [RunSegment]) -> [WatchSegmentDTO] {
        segments
            .filter { !isWarmupOrCooldown($0) }
            .map { segment in
                let paceSec = paceToSec(segment.pace)
                return WatchSegmentDTO(
                    kind: "run",
                    measure: segmentDistanceMeters(segment) != nil ? "distance" : "time",
                    targetMeters: segmentDistanceMeters(segment),
                    targetSeconds: segment.durationSeconds ?? segment.durationMinutes.map { $0 * 60 },
                    paceLowSecPerKm: paceSec,
                    paceHighSecPerKm: paceSec,
                    label: segment.description ?? segment.intensity ?? "",
                    repIndex: nil,
                    repTotal: nil
                )
            }
    }

    static func paceToSec(_ pace: String?) -> Int? {
        guard let pace,
              let colonIndex = pace.firstIndex(of: ":") else {
            return nil
        }

        let minutePart = String(pace[..<colonIndex])
        let secondsStart = pace.index(after: colonIndex)
        let secondPart = String(pace[secondsStart...].prefix { $0.isNumber })

        guard let minutes = Int(minutePart),
              let seconds = Int(secondPart),
              (0..<60).contains(seconds) else {
            return nil
        }
        return minutes * 60 + seconds
    }

    private static func expandInterval(_ block: IntervalBlock) -> [WatchSegmentDTO] {
        let repeatCount = max(block.repeats, 1)
        var projected: [WatchSegmentDTO] = []

        for rep in 1...repeatCount {
            let workPaceSec = paceToSec(block.workPace)
            projected.append(
                WatchSegmentDTO(
                    kind: "run",
                    measure: intervalWorkMeters(block) != nil ? "distance" : "time",
                    targetMeters: intervalWorkMeters(block),
                    targetSeconds: block.workDurationMinutes.map { $0 * 60 },
                    paceLowSecPerKm: workPaceSec,
                    paceHighSecPerKm: workPaceSec,
                    label: block.workDescription ?? intervalWorkLabel(block),
                    repIndex: rep,
                    repTotal: repeatCount
                )
            )

            guard hasRecovery(block) else { continue }
            let recoveryPaceSec = paceToSec(block.recoveryPace)
            projected.append(
                WatchSegmentDTO(
                    kind: "rest",
                    measure: intervalRecoveryMeters(block) != nil ? "distance" : "time",
                    targetMeters: intervalRecoveryMeters(block),
                    targetSeconds: block.recoveryDurationSeconds ?? block.recoveryDurationMinutes.map { $0 * 60 },
                    paceLowSecPerKm: recoveryPaceSec,
                    paceHighSecPerKm: recoveryPaceSec,
                    label: block.recoveryDescription ?? NSLocalizedString("watch.segment.rest", value: "Rest", comment: "Apple Watch rest segment label"),
                    repIndex: rep,
                    repTotal: repeatCount
                )
            )
        }

        return projected
    }

    private static func isWarmupOrCooldown(_ segment: RunSegment) -> Bool {
        let intensity = (segment.intensity ?? "").lowercased()
        return intensity.contains("warm") || intensity.contains("cool")
    }

    private static func segmentDistanceMeters(_ segment: RunSegment) -> Double? {
        if let distanceM = segment.distanceM { return Double(distanceM) }
        if let distanceKm = segment.distanceKm { return distanceKm * 1_000 }
        return nil
    }

    private static func intervalWorkMeters(_ block: IntervalBlock) -> Double? {
        if let distanceM = block.workDistanceM { return Double(distanceM) }
        if let distanceKm = block.workDistanceKm { return distanceKm * 1_000 }
        return nil
    }

    private static func intervalRecoveryMeters(_ block: IntervalBlock) -> Double? {
        if let distanceM = block.recoveryDistanceM { return Double(distanceM) }
        if let distanceKm = block.recoveryDistanceKm { return distanceKm * 1_000 }
        return nil
    }

    private static func hasRecovery(_ block: IntervalBlock) -> Bool {
        block.recoveryDistanceM != nil ||
        block.recoveryDistanceKm != nil ||
        block.recoveryDurationSeconds != nil ||
        block.recoveryDurationMinutes != nil
    }

    private static func intervalWorkLabel(_ block: IntervalBlock) -> String {
        if let meters = intervalWorkMeters(block) {
            return "\(Int(meters))m"
        }
        if let minutes = block.workDurationMinutes {
            return "\(minutes)min"
        }
        return ""
    }
}
