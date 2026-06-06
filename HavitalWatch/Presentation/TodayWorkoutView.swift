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
                    WelcomeView(title: "沒有課表", message: "靠近 iPhone 後同步課表。")
                }
            case .requiresPermission:
                PermissionView {
                    vm.requestPermissions()
                }
            case .blockedRestDay:
                WelcomeView(title: "休息日", message: "這天沒有跑步課表。")
            case .blockedUnsupportedType:
                WelcomeView(title: "不支援的訓練", message: "Apple Watch MVP 目前只支援跑步課表。")
            case .blockedNeedSyncFromPhone:
                WelcomeView(title: "等待 iPhone 同步", message: "請在 iPhone 上傳送 Paceriz 課表。")
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
                Text("已同步 · \(snapshot.date) · \(flowTitle(snapshot.flowType))")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text(summary(snapshot))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.72)
                    .lineLimit(2)
                Text(routeLabel(snapshot.flowType))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(detailLines(snapshot), id: \.self) { line in
                        Text(line)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.64)
                    }
                }
                .foregroundStyle(.secondary)

                NavigationLink {
                    ActiveWorkoutRootView(snapshot: snapshot)
                } label: {
                    Label("開始訓練", systemImage: "play.fill")
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Color.black)
        .foregroundStyle(.white)
    }

    private func flowTitle(_ flow: WorkoutFlowType) -> String {
        switch flow {
        case .directStart: return "輕鬆跑"
        case .warmupMainCooldown: return "間歇"
        case .rest: return "休息"
        case .unsupported: return "不支援"
        }
    }

    private func routeLabel(_ flow: WorkoutFlowType) -> String {
        flow == .warmupMainCooldown ? "暖身→主段→緩和" : "直接開始"
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
