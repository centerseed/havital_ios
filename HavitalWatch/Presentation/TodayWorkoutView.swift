import SwiftUI

struct TodayWorkoutView: View {
    @StateObject private var vm = TodayWorkoutViewModel()

    var body: some View {
        Group {
            switch vm.decision {
            case .canStart:
                if let snapshot = vm.snapshot {
                    startView(snapshot)
                } else {
                    WelcomeView(title: String(localized: "watch.welcome.noPlan.title"), message: String(localized: "watch.welcome.noPlan.body"), systemImage: "figure.run")
                }
            case .requiresPermission:
                PermissionView {
                    vm.requestPermissions()
                }
            case .blockedRestDay:
                WelcomeView(title: String(localized: "watch.welcome.rest.title"), message: String(localized: "watch.welcome.rest.body"), systemImage: "moon.zzz.fill")
            case .blockedUnsupportedType:
                WelcomeView(title: String(localized: "watch.welcome.unsupported.title"), message: String(localized: "watch.welcome.unsupported.body"), systemImage: "exclamationmark.triangle.fill")
            case .blockedNeedSyncFromPhone:
                WelcomeView(title: String(localized: "watch.welcome.waiting.title"), message: String(localized: "watch.welcome.waiting.body"), systemImage: "iphone.gen3")
            }
        }
        .onAppear {
            vm.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchPlanUpdated)) { _ in
            vm.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchAuthUpdated)) { _ in
            vm.refresh()
        }
    }

    private func startView(_ snapshot: WatchPlanSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Label {
                    Text(String(format: String(localized: "watch.today.synced"), snapshot.date, flowTitle(snapshot.flowType)))
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .font(WatchTheme.metricLabel)
                .foregroundStyle(WatchTheme.brand)
                Text(summary(snapshot))
                    .font(WatchTheme.metricValue(32))
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                Text(routeLabel(snapshot.flowType))
                    .font(.footnote)
                    .foregroundStyle(WatchTheme.neutral)
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(detailLines(snapshot), id: \.self) { line in
                        Text(line)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.64)
                    }
                }
                .foregroundStyle(WatchTheme.neutral)

                NavigationLink {
                    ActiveWorkoutRootView(snapshot: snapshot)
                } label: {
                    Label("watch.today.start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .buttonStyle(.borderedProminent)
                .tint(WatchTheme.brand)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(WatchTheme.ambientBackground)
        .foregroundStyle(.white)
    }

    private func flowTitle(_ flow: WorkoutFlowType) -> String {
        switch flow {
        case .directStart: return String(localized: "watch.flow.easy")
        case .warmupMainCooldown: return String(localized: "watch.flow.interval")
        case .rest: return String(localized: "watch.flow.rest")
        case .unsupported: return String(localized: "watch.flow.unsupported")
        }
    }

    private func routeLabel(_ flow: WorkoutFlowType) -> String {
        flow == .warmupMainCooldown ? String(localized: "watch.today.route.structured") : String(localized: "watch.today.directStart")
    }

    private func summary(_ snapshot: WatchPlanSnapshot) -> String {
        if let repeated = snapshot.segments.first(where: { ($0.repTotal ?? 0) > 1 }),
           let meters = repeated.targetMeters,
           let total = repeated.repTotal {
            return "\(Int(meters))m × \(total)"
        }
        if let meters = snapshot.totalDistanceMeters {
            return WatchFormatting.distance(meters)
        }
        if let seconds = snapshot.totalSeconds {
            return WatchFormatting.time(seconds)
        }
        return flowTitle(snapshot.flowType)
    }

    private func detailLines(_ snapshot: WatchPlanSnapshot) -> [String] {
        let title = summary(snapshot)
        return WorkoutSummaryFormatter.detailLines(for: snapshot).filter { $0 != title }
    }
}
