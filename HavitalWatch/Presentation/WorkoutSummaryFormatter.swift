enum WorkoutSummaryFormatter {
    static func detailLines(for snapshot: WatchPlanSnapshot) -> [String] {
        var seen = Set<String>()
        var lines = [String]()
        for segment in snapshot.segments {
            for line in formatSegment(segment) where !seen.contains(line) {
                seen.insert(line)
                lines.append(line)
            }
        }
        return Array(lines.prefix(4))
    }

    private static func formatSegment(_ segment: WatchSegment) -> [String] {
        switch segment.kind {
        case .work, .run:
            return formatWork(segment)
        case .rest:
            return formatRest(segment)
        case .warmup:
            return [String(format: String(localized: "watch.summary.segmentTarget"), String(localized: "watch.phase.warmup"), targetText(segment))]
        case .cooldown:
            return [String(format: String(localized: "watch.summary.segmentTarget"), String(localized: "watch.phase.cooldown"), targetText(segment))]
        }
    }

    private static func formatWork(_ segment: WatchSegment) -> [String] {
        var parts = [targetWithRepetition(segment)]
        if let pace = paceRange(segment) {
            parts.append(String(format: String(localized: "watch.summary.targetPace"), pace))
        }
        return parts
    }

    private static func formatRest(_ segment: WatchSegment) -> [String] {
        [String(format: String(localized: "watch.summary.perRep"), recoveryVerb(segment.label), targetText(segment))]
    }

    private static func targetWithRepetition(_ segment: WatchSegment) -> String {
        let target = targetText(segment)
        guard let total = segment.repTotal, total > 1 else { return target }
        return "\(target) × \(total)"
    }

    private static func targetText(_ segment: WatchSegment) -> String {
        switch segment.measure {
        case .distance:
            if let meters = segment.targetMeters {
                if meters >= 1000 {
                    return WatchFormatting.distance(meters)
                }
                return "\(Int(meters.rounded()))m"
            }
        case .time:
            if let seconds = segment.targetSeconds {
                return durationText(seconds)
            }
        }
        return segment.label.isEmpty ? "--" : segment.label
    }

    private static func paceRange(_ segment: WatchSegment) -> String? {
        guard let low = segment.paceLowSecPerKm, let high = segment.paceHighSecPerKm else {
            return nil
        }
        if low == high {
            return WatchFormatting.pace(high)
        }
        return "\(paceWithoutUnit(low))-\(WatchFormatting.pace(high))"
    }

    private static func paceWithoutUnit(_ secondsPerKm: Int) -> String {
        String(format: "%d:%02d", secondsPerKm / 60, secondsPerKm % 60)
    }

    private static func recoveryVerb(_ label: String) -> String {
        let lowercased = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowercased.contains("static recovery") {
            return String(localized: "watch.summary.recoveryRest")
        }
        if lowercased.contains("jog")
            || lowercased.contains("easy")
            || lowercased.contains("慢跑")
            || lowercased.contains("恢復跑") {
            return String(localized: "watch.summary.recoveryJog")
        }
        return String(localized: "watch.flow.rest")
    }

    private static func durationText(_ seconds: Int) -> String {
        let value = max(0, seconds)
        let minutes = value / 60
        let remainingSeconds = value % 60
        if minutes > 0, remainingSeconds > 0 {
            return String(format: String(localized: "watch.dur.minSec"), minutes, remainingSeconds)
        }
        if minutes > 0 {
            return String(format: String(localized: "watch.dur.min"), minutes)
        }
        return String(format: String(localized: "watch.dur.sec"), remainingSeconds)
    }
}
