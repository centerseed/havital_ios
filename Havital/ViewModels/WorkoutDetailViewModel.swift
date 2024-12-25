import SwiftUI
import HealthKit

class WorkoutDetailViewModel: ObservableObject {
    @Published var heartRates: [HeartRatePoint] = []
    private let workout: HKWorkout
    private let healthKitManager: HealthKitManager
    
    init(workout: HKWorkout, healthKitManager: HealthKitManager) {
        self.workout = workout
        self.healthKitManager = healthKitManager
    }
    
    var workoutType: String {
        WorkoutUtils.workoutTypeString(for: workout)
    }
    
    var duration: String {
        WorkoutUtils.formatDuration(workout.duration)
    }
    
    var calories: String? {
        guard let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) else { return nil }
        return String(format: "%.0f kcal", calories)
    }
    
    var distance: String? {
        guard let distance = workout.totalDistance?.doubleValue(for: .meter()) else { return nil }
        return String(format: "%.2f km", distance / 1000)
    }
    
    var maxHeartRate: Int {
        Int(heartRates.max(by: { $0.value < $1.value })?.value ?? 0)
    }
    
    var minHeartRate: Int {
        Int(heartRates.min(by: { $0.value < $1.value })?.value ?? 0)
    }
    
    var yAxisRange: (min: Double, max: Double) {
        let maxHR = Double(maxHeartRate)
        let minHR = Double(minHeartRate)
        return (min: max(minHR * 0.9, 0), max: maxHR * 1.1)
    }
    
    func loadHeartRateData() {
        Task {
            let rawHeartRates = await healthKitManager.fetchHeartRateData(for: workout)
            let heartRatePoints = rawHeartRates.map { HeartRatePoint(time: $0.0, value: $0.1) }
            await MainActor.run {
                self.heartRates = heartRatePoints
            }
        }
    }
}
