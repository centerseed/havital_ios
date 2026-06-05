import SwiftUI

struct ActiveWorkoutRootView: View {
    @StateObject private var vm: ActiveWorkoutViewModel
    @State private var started = false
    @State private var showingRPE = false
    @State private var showingSummary = false

    init(snapshot: WatchPlanSnapshot) {
        _vm = StateObject(wrappedValue: ActiveWorkoutViewModel(snapshot: snapshot))
    }

    var body: some View {
        Group {
            if showingSummary {
                WorkoutSummaryView(
                    meters: vm.meters,
                    seconds: vm.seconds,
                    averageHeartRate: vm.heartRate,
                    recentSpeedMps: vm.recentSpeedMps
                )
            } else if showingRPE {
                RPEView(
                    complete: { rpe in finish(rpe: rpe) },
                    skip: { finish(rpe: nil) }
                )
            } else {
                TabView {
                    workoutPage
                    WorkoutControlView(
                        isPaused: vm.isPaused,
                        togglePause: { vm.setPaused(!vm.isPaused) },
                        end: { showingRPE = true }
                    )
                }
            }
        }
        .background(Color.black)
        .onAppear {
            guard !started else { return }
            started = true
            vm.start(indoor: false)
        }
    }

    @ViewBuilder
    private var workoutPage: some View {
        switch vm.phase {
        case .warmup:
            WarmupCooldownView(vm: vm, mode: .warmup) {
                vm.beginPlan()
            }
        case .main:
            if vm.snapshot.flowType == .directStart {
                EasyRunMetricsView(vm: vm)
            } else {
                IntervalMetricsView(vm: vm)
            }
        case .cooldown:
            WarmupCooldownView(vm: vm, mode: .cooldown) {
                showingRPE = true
            }
        case .finished:
            WorkoutSummaryView(
                meters: vm.meters,
                seconds: vm.seconds,
                averageHeartRate: vm.heartRate,
                recentSpeedMps: vm.recentSpeedMps
            )
        }
    }

    private func finish(rpe: Int?) {
        vm.finish(rpe: rpe) { _ in
            Task { @MainActor in
                showingRPE = false
                showingSummary = true
            }
        }
    }
}
