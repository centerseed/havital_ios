import SwiftUI
import HealthKit

struct WorkoutRowView: View {
    let workout: HKWorkout
    var isUploaded: Bool = false
    var uploadTime: Date? = nil
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(WorkoutUtils.workoutTypeString(for: workout.workoutActivityType))
                    .font(.headline)
                
                HStack(spacing: 16) {
                    if let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                        Label(String(format: "%.0f kcal", calories), systemImage: "flame.fill")
                    }
                    
                    if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                        Label(
                            distance >= 1000 ? String(format: "%.2f km", distance / 1000) : String(format: "%.0f m", distance),
                            systemImage: "figure.walk"
                        )
                    }
                    
                    Label(WorkoutUtils.formatDuration(workout.duration), systemImage: "clock")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(formattedTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle()) // 使整個區域可點擊
        .padding(.vertical, 4)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: workout.startDate)
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: workout.startDate)
    }
}

extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running:
            return "跑步"
        case .walking:
            return "步行"
        case .cycling:
            return "騎行"
        case .swimming:
            return "游泳"
        case .hiking:
            return "徒步"
        case .yoga:
            return "瑜伽"
        case .functionalStrengthTraining:
            return "力量訓練"
        default:
            return "其他運動"
        }
    }
}
