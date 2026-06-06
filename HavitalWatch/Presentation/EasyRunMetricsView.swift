import SwiftUI

struct EasyRunMetricsView: View {
    @ObservedObject var vm: ActiveWorkoutViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("輕鬆跑 \(targetText)")
                .font(.caption2)
                .foregroundStyle(.green)
            Text(WatchFormatting.time(vm.seconds))
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .foregroundStyle(.green)
                .monospacedDigit()
            PaceGuidanceView(
                currentPaceSecPerKm: WatchFormatting.paceSecondsPerKm(speedMps: vm.recentSpeedMps),
                targetLowSecPerKm: targetPaceLow,
                targetHighSecPerKm: targetPaceHigh
            )
            Text(WatchFormatting.distance(vm.meters))
                .font(.body)
            Label("\(Int(vm.heartRate))", systemImage: "heart.fill")
                .foregroundStyle(.red)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .padding(.top, 22)
        .background(Color.black)
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
