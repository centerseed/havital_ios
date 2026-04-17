import Foundation

// MARK: - V2Clock Protocol
/// Time source abstraction for TrainingPlanV2 cooldown logic.
/// Enables time injection in unit tests without depending on real Date().
protocol V2Clock {
    func now() -> Date
}

// MARK: - SystemV2Clock
/// Production implementation using real system time.
final class SystemV2Clock: V2Clock {
    func now() -> Date {
        Date()
    }
}
