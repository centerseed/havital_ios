import SwiftUI

struct IntervalMetricsView: View {
    @ObservedObject var vm: ActiveWorkoutViewModel

    var body: some View {
        let segment = vm.currentSegment

        VStack(alignment: .leading, spacing: 6) {
            Text(stepTitle(segment))
                .font(WatchTheme.metricLabel)
                .foregroundStyle(segment?.kind == .rest ? WatchTheme.neutral : WatchTheme.brand)
            Text(primaryMetric(segment))
                .font(WatchTheme.metricValue(44))
                .foregroundStyle(segment?.kind == .rest ? WatchTheme.tooFast : .white)
                .monospacedDigit()
                .minimumScaleFactor(0.72)
                .lineLimit(1)
            if segment?.kind == .rest {
                Text(nextSegmentText())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            PaceGuidanceView(
                currentPaceSecPerKm: currentPaceSecPerKm,
                targetLowSecPerKm: segment?.paceLowSecPerKm,
                targetHighSecPerKm: segment?.paceHighSecPerKm
            )
            Label("\(Int(vm.heartRate))", systemImage: "heart.fill")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(WatchTheme.heartRate)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal)
        .background(WatchTheme.activeBackground)
        .foregroundStyle(.white)
    }

    private var currentPaceSecPerKm: Int? {
        WatchFormatting.paceSecondsPerKm(speedMps: vm.recentSpeedMps)
    }

    private func stepTitle(_ segment: WatchSegment?) -> String {
        guard let segment else { return String(localized: "watch.phase.main") }
        let title: String
        switch segment.kind {
        case .rest:
            title = String(localized: "watch.flow.rest")
        case .work, .run:
            title = String(localized: "watch.flow.interval")
        case .warmup:
            title = String(localized: "watch.phase.warmup")
        case .cooldown:
            title = String(localized: "watch.phase.cooldown")
        }

        if let index = segment.repIndex, let total = segment.repTotal {
            return "\(title) \(index)/\(total)"
        }
        return title
    }

    private func primaryMetric(_ segment: WatchSegment?) -> String {
        guard let segment else { return "--" }
        switch segment.measure {
        case .distance:
            let remaining = (segment.targetMeters ?? 0) - vm.segmentMeters
            return WatchFormatting.distance(max(0, remaining))
        case .time:
            let remaining = (segment.targetSeconds ?? 0) - vm.segmentSeconds
            return WatchFormatting.time(max(0, remaining))
        }
    }

    private func nextSegmentText() -> String {
        guard
            let current = vm.currentSegment,
            let currentIndex = vm.snapshot.segments.firstIndex(of: current)
        else {
            return String(format: String(localized: "watch.interval.next"), String(localized: "watch.interval.next.none"))
        }

        let nextIndex = currentIndex + 1
        guard nextIndex < vm.snapshot.segments.count else {
            return String(format: String(localized: "watch.interval.next"), String(localized: "watch.phase.cooldown"))
        }
        let next = vm.snapshot.segments[nextIndex]
        if let meters = next.targetMeters {
            return String(format: String(localized: "watch.interval.next"), String(format: String(localized: "watch.interval.next.meters"), Int(meters)))
        }
        if let seconds = next.targetSeconds {
            return String(format: String(localized: "watch.interval.next"), WatchFormatting.time(seconds))
        }
        return String(format: String(localized: "watch.interval.next"), "").trimmingCharacters(in: .whitespaces)
    }
}
