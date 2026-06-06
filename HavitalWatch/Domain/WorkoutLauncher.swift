enum LaunchDecision: Equatable {
    case canStart
    case requiresPermission
    case blockedRestDay
    case blockedUnsupportedType
    case blockedNeedSyncFromPhone
}

enum WorkoutLauncher {
    static func evaluate(
        snapshot: WatchPlanSnapshot?,
        today: String,
        permissionsGranted: Bool
    ) -> LaunchDecision {
        guard let snapshot else { return .blockedNeedSyncFromPhone }

        switch snapshot.flowType {
        case .rest:
            return .blockedRestDay
        case .unsupported:
            return .blockedUnsupportedType
        case .directStart, .warmupMainCooldown:
            return permissionsGranted ? .canStart : .requiresPermission
        }
    }
}
