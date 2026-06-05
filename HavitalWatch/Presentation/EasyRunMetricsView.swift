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
            Text("\(WatchFormatting.pace(WatchFormatting.paceSecondsPerKm(speedMps: vm.recentSpeedMps))) 配速")
                .font(.body)
                .foregroundStyle(.cyan)
            Text(WatchFormatting.distance(vm.meters))
                .font(.body)
            Label("\(Int(vm.heartRate))", systemImage: "heart.fill")
                .foregroundStyle(.red)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .background(Color.black)
        .foregroundStyle(.white)
    }

    private var targetText: String {
        if let meters = vm.snapshot.totalDistanceMeters {
            return WatchFormatting.distance(meters)
        }
        return ""
    }
}
