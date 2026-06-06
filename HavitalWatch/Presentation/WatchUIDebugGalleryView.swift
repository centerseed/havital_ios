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
    case intervalSlow = "interval_slow"
    case simulatedIntervalFlow = "sim_interval_flow"
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
        case .intervalSlow:
            IntervalMetricsView(vm: configuredIntervalViewModel(phase: .main, recentSpeedMps: 3.03))
        case .simulatedIntervalFlow:
            SimulatedIntervalFlowView(snapshot: Self.intervalSnapshot)
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
        viewModel.recentSpeedMps = 0
        return viewModel
    }

    @MainActor
    private func configuredIntervalViewModel(
        phase: ActiveWorkoutSession.Phase,
        recentSpeedMps: Double = 0
    ) -> ActiveWorkoutViewModel {
        let viewModel = ActiveWorkoutViewModel(snapshot: Self.intervalSnapshot)
        viewModel.phase = phase
        viewModel.meters = 2400
        viewModel.seconds = 820
        viewModel.heartRate = 123
        viewModel.recentSpeedMps = recentSpeedMps
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
                repIndex: 1,
                repTotal: 4
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

@MainActor
private struct SimulatedIntervalFlowView: View {
    @StateObject private var viewModel: ActiveWorkoutViewModel
    @State private var started = false

    init(snapshot: WatchPlanSnapshot) {
        let builder = DebugSimulatedWorkoutBuilder(
            samples: [
                .init(meters: 0, seconds: 0, heartRate: 118, recentSpeedMps: 0),
                .init(meters: 80, seconds: 24, heartRate: 124, recentSpeedMps: 3.27),
                .init(meters: 160, seconds: 49, heartRate: 132, recentSpeedMps: 3.27),
                .init(meters: 240, seconds: 73, heartRate: 138, recentSpeedMps: 3.27),
                .init(meters: 320, seconds: 98, heartRate: 143, recentSpeedMps: 3.27),
                .init(meters: 360, seconds: 110, heartRate: 146, recentSpeedMps: 3.27),
                .init(meters: 399, seconds: 121, heartRate: 147, recentSpeedMps: 3.27),
                .init(meters: 400, seconds: 122, heartRate: 148, recentSpeedMps: 3.27),
                .init(meters: 400, seconds: 123, heartRate: 142, recentSpeedMps: 0),
                .init(meters: 400, seconds: 150, heartRate: 128, recentSpeedMps: 0)
            ],
            intervalNanoseconds: 1_000_000_000
        )
        _viewModel = StateObject(
            wrappedValue: ActiveWorkoutViewModel(snapshot: snapshot, workoutBuilder: builder)
        )
    }

    var body: some View {
        IntervalMetricsView(vm: viewModel)
            .onAppear {
                guard !started else { return }
                started = true
                viewModel.start(indoor: false)
                viewModel.beginPlan()
            }
    }
}
#endif
