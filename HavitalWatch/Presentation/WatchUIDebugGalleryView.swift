#if DEBUG
import SwiftUI

enum WatchUIDebugScreen: String {
    case welcome
    case permission
    case todayEasy = "today_easy"
    case warmup
    case cooldown
    case easy
    case interval
    case controls
    case rpe
    case summary

    static var current: WatchUIDebugScreen? {
        let arguments = ProcessInfo.processInfo.arguments
        guard
            let index = arguments.firstIndex(of: "-watchUITestScreen"),
            arguments.indices.contains(index + 1)
        else {
            return nil
        }

        return WatchUIDebugScreen(rawValue: arguments[index + 1])
    }
}

struct WatchUIDebugGalleryView: View {
    let screen: WatchUIDebugScreen

    var body: some View {
        switch screen {
        case .welcome:
            WelcomeView(title: "等待 iPhone 同步", message: "請在 iPhone 上傳送 Paceriz 課表。")
        case .permission:
            PermissionView {}
        case .todayEasy:
            debugTodayStartView
        case .warmup:
            WarmupCooldownView(vm: configuredIntervalViewModel(phase: .warmup), mode: .warmup) {}
        case .cooldown:
            WarmupCooldownView(vm: configuredIntervalViewModel(phase: .cooldown), mode: .cooldown) {}
        case .easy:
            EasyRunMetricsView(vm: configuredEasyViewModel())
        case .interval:
            IntervalMetricsView(vm: configuredIntervalViewModel(phase: .main))
        case .controls:
            WorkoutControlView(isPaused: false, togglePause: {}, end: {})
        case .rpe:
            RPEView(complete: { _ in }, skip: {})
        case .summary:
            WorkoutSummaryView(meters: 5200, seconds: 1815, averageHeartRate: 154, recentSpeedMps: 2.86)
        }
    }

    private var debugTodayStartView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("已同步 · \(Self.easySnapshot.date) · 輕鬆跑")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text(WatchFormatting.distance(5000))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.72)
                    .lineLimit(2)
                Text("直接開始")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {} label: {
                    Label("開始訓練", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Color.black)
        .foregroundStyle(.white)
    }

    @MainActor
    private func configuredEasyViewModel() -> ActiveWorkoutViewModel {
        let viewModel = ActiveWorkoutViewModel(snapshot: Self.easySnapshot)
        viewModel.phase = .main
        viewModel.meters = 3200
        viewModel.seconds = 1120
        viewModel.heartRate = 148
        viewModel.recentSpeedMps = 2.85
        return viewModel
    }

    @MainActor
    private func configuredIntervalViewModel(phase: ActiveWorkoutSession.Phase) -> ActiveWorkoutViewModel {
        let viewModel = ActiveWorkoutViewModel(snapshot: Self.intervalSnapshot)
        viewModel.phase = phase
        viewModel.meters = 2400
        viewModel.seconds = 820
        viewModel.heartRate = 123
        viewModel.recentSpeedMps = 3.03
        viewModel.currentSegment = Self.intervalSnapshot.segments[1]
        viewModel.segmentMeters = 31
        viewModel.segmentSeconds = 108
        return viewModel
    }

    private static let easySnapshot = WatchPlanSnapshot(
        date: WatchFormatting.localDayString(),
        flowType: .directStart,
        totalDistanceMeters: 5000,
        totalSeconds: nil,
        planId: "debug-easy",
        segments: [
            WatchSegment(
                kind: .run,
                measure: .distance,
                targetMeters: 5000,
                targetSeconds: nil,
                paceLowSecPerKm: 330,
                paceHighSecPerKm: 375,
                label: "5K Easy",
                repIndex: nil,
                repTotal: nil
            )
        ]
    )

    private static let intervalSnapshot = WatchPlanSnapshot(
        date: WatchFormatting.localDayString(),
        flowType: .warmupMainCooldown,
        totalDistanceMeters: nil,
        totalSeconds: nil,
        planId: "debug-interval",
        segments: [
            WatchSegment(
                kind: .warmup,
                measure: .time,
                targetMeters: nil,
                targetSeconds: 600,
                paceLowSecPerKm: nil,
                paceHighSecPerKm: nil,
                label: "Warmup",
                repIndex: nil,
                repTotal: nil
            ),
            WatchSegment(
                kind: .work,
                measure: .distance,
                targetMeters: 400,
                targetSeconds: nil,
                paceLowSecPerKm: 305,
                paceHighSecPerKm: 305,
                label: "400m",
                repIndex: 1,
                repTotal: 4
            ),
            WatchSegment(
                kind: .rest,
                measure: .time,
                targetMeters: nil,
                targetSeconds: 90,
                paceLowSecPerKm: nil,
                paceHighSecPerKm: nil,
                label: "Rest",
                repIndex: 3,
                repTotal: 5
            ),
            WatchSegment(
                kind: .cooldown,
                measure: .time,
                targetMeters: nil,
                targetSeconds: 600,
                paceLowSecPerKm: nil,
                paceHighSecPerKm: nil,
                label: "Cooldown",
                repIndex: nil,
                repTotal: nil
            )
        ]
    )
}
#endif
