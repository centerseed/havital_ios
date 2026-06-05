import SwiftUI

@MainActor
final class TodayWorkoutViewModel: ObservableObject {
    @Published var snapshot: WatchPlanSnapshot?
    @Published var decision: LaunchDecision = .blockedNeedSyncFromPhone

    private let store = WorkoutSnapshotStore()
    private let permission = PermissionGate()

    func refresh(today: String = WatchFormatting.localDayString()) {
        snapshot = store.currentSnapshot()
        decision = WorkoutLauncher.evaluate(
            snapshot: snapshot,
            today: today,
            permissionsGranted: permission.allGranted()
        )
    }

    func requestPermissions(today: String = WatchFormatting.localDayString()) {
        permission.requestAll { [weak self] _ in
            Task { @MainActor in
                self?.refresh(today: today)
            }
        }
    }
}
