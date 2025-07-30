import SwiftUI

struct WorkoutV2RowView: View {
    let workout: WorkoutV2
    let isUploaded: Bool
    let uploadTime: Date?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // 運動類型和訓練類型資訊
            HStack {
                // 運動類型
                HStack(spacing: 4) {
                    Image(systemName: getActivityTypeIcon(workout.activityType))
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(workout.activityType.workoutTypeDisplayName())
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
                
                // 訓練類型
                if let trainingType = workout.trainingType {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.run")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(formatTrainingType(trainingType))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
                if isToday(date: workout.startDate) {
                    Text("今天")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(4)
                }
                Spacer()
                
                // 動態 VDOT
                if let dynamicVdot = workout.dynamicVdot {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(String(format: "VDOT %.1f", dynamicVdot))
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            // 訓練詳情
            HStack {
                // 距離
                VStack(alignment: .leading) {
                    Text("距離")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let distanceMeters = workout.distanceMeters {
                        Text(formatDistance(distanceMeters))
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
                    Text("時間")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDuration(workout.duration))
                        .font(.subheadline)
                }
                
                Spacer()
                
                // 卡路里
                VStack(alignment: .leading) {
                    Text("卡路里")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let calories = workout.calories {
                        Text(String(format: "%.0f kcal", calories))
                            .font(.subheadline)
                    } else {
                        Text("-")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 數據來源和訓練資訊
            HStack {
                Text(formattedDate(workout.startDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Garmin Attribution and data source
                ConditionalGarminAttributionView(
                    dataProvider: workout.provider,
                    deviceModel: workout.deviceName,
                    displayStyle: .secondary
                )
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
    
    // MARK: - Helper Methods
    
    private func formatDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            return String(format: "%.2f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formatTrainingType(_ trainingType: String) -> String {
        switch trainingType.lowercased() {
        case "easy_run":
            return "輕鬆跑"
        case "recovery_run":
            return "恢復跑"
        case "long_run":
            return "長跑"
        case "tempo":
            return "節奏跑"
        case "threshold":
            return "閾值跑"
        case "interval":
            return "間歇跑"
        case "fartlek":
            return "法特萊克"
        case "hill_training":
            return "坡道訓練"
        case "race":
            return "比賽"
        case "rest":
            return "休息"
        default:
            return trainingType
        }
    }
    
    private func getActivityTypeIcon(_ activityType: String) -> String {
        let type = activityType.lowercased()
        
        if type.contains("cycling") || type.contains("bike") || type.contains("ride") {
            return "bicycle"
        } else if type.contains("running") || type.contains("run") {
            return "figure.run"
        } else if type.contains("swimming") || type.contains("swim") {
            return "figure.pool.swim"
        } else if type.contains("walking") || type.contains("walk") {
            return "figure.walk"
        } else if type.contains("hiking") || type.contains("hike") {
            return "figure.hiking"
        } else if type.contains("strength") || type.contains("weight") {
            return "dumbbell"
        } else if type.contains("yoga") {
            return "figure.yoga"
        } else {
            return "figure.strengthtraining.traditional"
        }
    }
}

#Preview {
    // 使用預設的 WorkoutV2 實例進行預覽
    let workout = WorkoutV2(
        id: "preview-1",
        provider: "Apple Health",
        activityType: "running",
        startTimeUtc: ISO8601DateFormatter().string(from: Date()),
        endTimeUtc: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
        durationSeconds: 3600,
        distanceMeters: 5000, deviceName: "garmin",
        basicMetrics: BasicMetrics(
            avgHeartRateBpm: 150,
            maxHeartRateBpm: 180,
            minHeartRateBpm: 120.0,
            caloriesKcal: 300.0,
            totalDistanceM: 5000.0,
            totalDurationS: 3600,
            movingDurationS: 3600
        ),
        advancedMetrics: AdvancedMetrics(
            dynamicVdot: 45.2,
            tss: 65.0,
            trainingType: "tempo",
            intensityMinutes: Optional<APIIntensityMinutes>.none,
            intervalCount: Optional<Int>.none,
            avgHrTop20Percent: Optional<Double>.none,
            hrZoneDistribution: Optional<ZoneDistribution>.none,
            paceZoneDistribution: Optional<ZoneDistribution>.none,
            rpe: Optional<Double>.none
        ),
        createdAt: Optional<String>.none,
        schemaVersion: "1.0",
        storagePath: Optional<String>.none
    )
    
    WorkoutV2RowView(
        workout: workout,
        isUploaded: true,
        uploadTime: Date()
    )
    .previewLayout(.sizeThatFits)
    .padding()
} 
