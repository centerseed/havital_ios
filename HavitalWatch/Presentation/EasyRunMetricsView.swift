import SwiftUI

struct EasyRunMetricsView: View {
    @ObservedObject var vm: ActiveWorkoutViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: String(localized: "watch.easy.title"), targetText))
                .font(WatchTheme.metricLabel)
                .foregroundStyle(WatchTheme.brand)
            Text(WatchFormatting.time(vm.seconds))
                .font(WatchTheme.metricValue(46))
                .foregroundStyle(.white)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            PaceGuidanceView(
                currentPaceSecPerKm: WatchFormatting.paceSecondsPerKm(speedMps: vm.recentSpeedMps),
                targetLowSecPerKm: targetPaceLow,
                targetHighSecPerKm: targetPaceHigh
            )
            HStack(alignment: .bottom, spacing: 10) {
                WatchMetric(label: String(localized: "watch.summary.distance"),
                            value: WatchFormatting.distance(vm.meters),
                            valueColor: .white, valueSize: 20)
                WatchMetric(label: String(localized: "watch.summary.hr"),
                            value: "\(Int(vm.heartRate))",
                            valueColor: WatchTheme.heartRate, valueSize: 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal)
        .background(WatchTheme.activeBackground)
        .foregroundStyle(.white)
    }

    private var targetText: String {
        if let meters = vm.snapshot.totalDistanceMeters {
            return WatchFormatting.distance(meters)
        }
        return ""
    }

    private var targetPaceLow: Int? {
        vm.currentSegment?.paceLowSecPerKm ?? vm.snapshot.segments.first?.paceLowSecPerKm
    }

    private var targetPaceHigh: Int? {
        vm.currentSegment?.paceHighSecPerKm ?? vm.snapshot.segments.first?.paceHighSecPerKm
    }
}
