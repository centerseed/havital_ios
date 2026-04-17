import Foundation

// MARK: - CooldownResource
/// Identifies a resource that is subject to background-refresh cooldown.
/// Extend this enum to add cooldown for additional V2 resources (overview, weeklyPlan, etc.).
enum CooldownResource {
    case planStatus

    /// Cooldown duration in seconds.
    var duration: TimeInterval {
        switch self {
        case .planStatus:
            return 1800  // 30 minutes
        }
    }
}

// MARK: - Hashable
extension CooldownResource: Hashable {}
