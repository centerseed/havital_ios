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
        VStack(alignment: .leading, spacing: 4) {
            Text(mode == .warmup ? "watch.phase.warmup" : "watch.phase.cooldown")
                .font(.caption2)
                .foregroundStyle(.orange)
            Text(WatchFormatting.time(vm.seconds))
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .foregroundStyle(.green)
                .monospacedDigit()
            PaceGuidanceView(
                currentPaceSecPerKm: WatchFormatting.paceSecondsPerKm(speedMps: vm.recentSpeedMps),
                targetLowSecPerKm: nil,
                targetHighSecPerKm: nil
            )
            Text(WatchFormatting.distance(vm.meters))
                .font(.body)
            Label("\(Int(vm.heartRate))", systemImage: "heart.fill")
                .font(.body)
                .foregroundStyle(.red)
            Button(action: primaryAction) {
                Label(mode == .warmup ? "watch.warmup.startPlan" : "watch.control.end", systemImage: mode == .warmup ? "forward.fill" : "stop.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(mode == .warmup ? .green : .red)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .padding(.top, 22)
        .background(Color.black)
        .foregroundStyle(.white)
    }
}
