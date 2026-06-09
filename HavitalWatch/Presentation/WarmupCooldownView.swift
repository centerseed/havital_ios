import SwiftUI

struct WarmupCooldownView: View {
    enum Mode {
        case warmup
        case cooldown
    }

    @ObservedObject var vm: ActiveWorkoutViewModel
    let mode: Mode
    let primaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mode == .warmup ? "watch.phase.warmup" : "watch.phase.cooldown")
                .font(WatchTheme.metricLabel)
                .foregroundStyle(WatchTheme.tooFast)
            Text(WatchFormatting.time(vm.seconds))
                .font(WatchTheme.metricValue(44))
                .foregroundStyle(.white)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            HStack(alignment: .bottom, spacing: 10) {
                WatchMetric(label: String(localized: "watch.summary.distance"),
                            value: WatchFormatting.distance(vm.meters),
                            valueColor: .white, valueSize: 20)
                WatchMetric(label: String(localized: "watch.summary.hr"),
                            value: "\(Int(vm.heartRate))",
                            valueColor: WatchTheme.heartRate, valueSize: 20)
            }
            Button(action: primaryAction) {
                Label(mode == .warmup ? "watch.warmup.startPlan" : "watch.control.end", systemImage: mode == .warmup ? "forward.fill" : "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(mode == .warmup ? WatchTheme.brand : WatchTheme.tooSlow)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal)
        .background(WatchTheme.activeBackground)
        .foregroundStyle(.white)
    }
}
