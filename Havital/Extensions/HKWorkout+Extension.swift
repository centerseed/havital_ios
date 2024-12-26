import HealthKit

extension HKWorkout: Identifiable {
    public var id: UUID {
        return uuid
    }
}
