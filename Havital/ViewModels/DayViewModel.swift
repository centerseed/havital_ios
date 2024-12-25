import SwiftUI
import HealthKit

class DayViewModel: ObservableObject {
    let day: TrainingDay
    let isToday: Bool
    private let trainingPlanViewModel: TrainingPlanViewModel
    private let healthKitManager: HealthKitManager
    
    init(day: TrainingDay, isToday: Bool, trainingPlanViewModel: TrainingPlanViewModel, healthKitManager: HealthKitManager) {
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
    
    func getWorkouts() async -> [HKWorkout] {
        let dayStart = Date(timeIntervalSince1970: TimeInterval(day.startTimestamp))
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        return await healthKitManager.fetchWorkoutsForDateRange(start: dayStart, end: dayEnd)
    }
    
    func updateTrainingDay(_ updatedDay: TrainingDay) async throws {
        try await trainingPlanViewModel.updateTrainingDay(updatedDay)
    }
}
