import Foundation

enum InterruptRoutePolicy {
    static func shouldRouteThroughInterruptQueue(
        requiresForceUpdate: Bool,
        isAuthenticated: Bool,
        hasCompletedOnboarding: Bool
    ) -> Bool {
        !requiresForceUpdate && isAuthenticated && hasCompletedOnboarding
    }
}

