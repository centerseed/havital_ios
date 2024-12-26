import SwiftUI
import HealthKit

class DayViewModel: ObservableObject {
    let day: TrainingDay
    let isToday: Bool
    private let trainingPlanViewModel: TrainingPlanViewModel
    private let healthKitManager: HealthKitManager
    @Published var workouts: [HKWorkout] = []
    
    init(day: TrainingDay, isToday: Bool, trainingPlanViewModel: TrainingPlanViewModel, healthKitManager: HealthKitManager = HealthKitManager()) {
        self.day = day
        self.isToday = isToday
        self.trainingPlanViewModel = trainingPlanViewModel
        self.healthKitManager = healthKitManager
    }
    
    var formattedDate: String {
        let date = Date(timeIntervalSince1970: TimeInterval(day.startTimestamp))
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd"
        return dateFormatter.string(from: date)
    }
    
    var weekday: String {
        let date = Date(timeIntervalSince1970: TimeInterval(day.startTimestamp))
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_TW")
        dateFormatter.dateFormat = "EEEE"
        return dateFormatter.string(from: date)
    }
    
    func fetchWorkoutsForDay() {
        let date = Date(timeIntervalSince1970: TimeInterval(day.startTimestamp))
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        Task {
            do {
                let fetchedWorkouts = try await healthKitManager.fetchWorkoutsForDateRange(start: startOfDay, end: endOfDay)
                await MainActor.run {
                    self.workouts = fetchedWorkouts
                }
            } catch {
                print("Error fetching workouts: \(error)")
                await MainActor.run {
                    self.workouts = []
                }
            }
        }
    }
    
    func updateTrainingDay(_ updatedDay: TrainingDay) async throws {
        try await trainingPlanViewModel.updateTrainingDay(updatedDay)
    }
}
