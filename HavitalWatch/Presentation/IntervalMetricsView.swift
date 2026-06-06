import SwiftUI

struct IntervalMetricsView: View {
    @ObservedObject var vm: ActiveWorkoutViewModel

    var body: some View {
        let segment = vm.currentSegment

        VStack(alignment: .leading, spacing: 3) {
            Text(stepTitle(segment))
                .font(.caption2)
                .foregroundStyle(.blue)
            Text(primaryMetric(segment))
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .foregroundStyle(.green)
                .monospacedDigit()
                .minimumScaleFactor(0.72)
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
                .foregroundStyle(.red)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .padding(.top, 22)
        .background(Color.black)
        .foregroundStyle(.white)
    }

    private var currentPaceSecPerKm: Int? {
        WatchFormatting.paceSecondsPerKm(speedMps: vm.recentSpeedMps)
    }

    private func stepTitle(_ segment: WatchSegment?) -> String {
        guard let segment else { return "主段" }
        let title: String
        switch segment.kind {
        case .rest:
            title = "休息"
        case .work, .run:
            title = "間歇"
        case .warmup:
            title = "暖身"
        case .cooldown:
            title = "緩和"
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
            return "下一段 --"
        }

        let nextIndex = currentIndex + 1
        guard nextIndex < vm.snapshot.segments.count else { return "下一段 緩和" }
        let next = vm.snapshot.segments[nextIndex]
        if let meters = next.targetMeters {
            return "下一段 \(Int(meters))m"
        }
        if let seconds = next.targetSeconds {
            return "下一段 \(WatchFormatting.time(seconds))"
        }
        return "下一段"
    }
}
