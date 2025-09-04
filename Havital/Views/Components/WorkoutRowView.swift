import SwiftUI
import HealthKit

struct WorkoutRowView: View {
    let workout: HKWorkout
    let isUploaded: Bool
    let uploadTime: Date?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Text(workout.workoutActivityType.name)
                        .font(.headline)
                    
                    if isToday(date: workout.startDate) {
                        Text(NSLocalizedString("workout_row.today", comment: "Today"))
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // 同步狀態
                HStack(spacing: 4) {
                    if isUploaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(NSLocalizedString("workout_row.synced", comment: "Synced"))
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "arrow.up.circle")
                            .foregroundColor(.orange)
                        Text(NSLocalizedString("workout_row.not_synced", comment: "Not Synced"))
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // 訓練詳情
            HStack {
                // 距離
                VStack(alignment: .leading) {
                    Text(NSLocalizedString("workout_row.distance", comment: "Distance"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                        Text(distance >= 1000 ?
                             String(format: "%.2f km", distance / 1000) :
                             String(format: "%.0f m", distance))
                            .font(.subheadline)
                    } else {
                        Text("-")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 時間
                VStack(alignment: .leading) {
                    Text(NSLocalizedString("workout_row.time", comment: "Time"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(WorkoutUtils.formatDuration(workout.duration))
                        .font(.subheadline)
                }
                
                Spacer()
                
                // 卡路里
                VStack(alignment: .leading) {
                    Text(NSLocalizedString("workout_row.calories", comment: "Calories"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                        Text(String(format: "%.0f kcal", calories))
                            .font(.subheadline)
                    } else {
                        Text("-")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 日期
            HStack {
                Text(formattedDate(workout.startDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func isToday(date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}


#Preview {
    // 使用預設的 HKWorkout 實例進行預覽
    let workout = try! HKWorkout(
        activityType: .running,
        start: Date(),
        end: Date().addingTimeInterval(3600),
        duration: 3600,
        totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 300),
        totalDistance: HKQuantity(unit: .meter(), doubleValue: 5000),
        metadata: nil
    )
    
    return WorkoutRowView(
        workout: workout,
        isUploaded: true,
        uploadTime: Date()
    )
    .previewLayout(.sizeThatFits)
    .padding()
}
