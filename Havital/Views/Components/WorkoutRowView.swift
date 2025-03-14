import SwiftUI
import HealthKit

struct WorkoutRowView: View {
    let workout: HKWorkout
    let isUploaded: Bool
    let uploadTime: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Text(WorkoutUtils.workoutTypeString(for: workout.workoutActivityType))
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if isToday(date: workout.startDate) {
                        Text("今天")
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
                        Text("已同步")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "arrow.up.circle")
                            .foregroundColor(.orange)
                        Text("未同步")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // 訓練詳情
            HStack {
                // 距離
                VStack(alignment: .leading) {
                    Text("距離")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                        Text(distance >= 1000 ? 
                             String(format: "%.2f km", distance / 1000) : 
                             String(format: "%.0f m", distance))
                            .font(.subheadline)
                            .foregroundColor(.white)
                    } else {
                        Text("-")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // 時間
                VStack(alignment: .leading) {
                    Text("時間")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(WorkoutUtils.formatDuration(workout.duration))
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // 卡路里
                VStack(alignment: .leading) {
                    Text("卡路里")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                        Text(String(format: "%.0f kcal", calories))
                            .font(.subheadline)
                            .foregroundColor(.white)
                    } else {
                        Text("-")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // 日期
            HStack {
                Text(formattedDate(workout.startDate))
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
        }
        .padding()
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
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
    .background(Color.black)
    .previewLayout(.sizeThatFits)
}
