import SwiftUI

struct WorkoutV2RowView: View {
    let workout: WorkoutV2
    let isUploaded: Bool
    let uploadTime: Date?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            // 左側彩色邊條（4pt）
            Rectangle()
                .fill(getActivityTypeColor(workout.activityType))
                .frame(width: 4)

            // 主內容區域
            VStack(alignment: .leading, spacing: 14) {
                // 頂部：運動類型 · 訓練類型（左） + VDOT（右）
                HStack(alignment: .top) {
                    HStack(spacing: 6) {
                        Image(systemName: getActivityTypeIcon(workout.activityType))
                            .font(.subheadline)
                            .foregroundColor(getActivityTypeColor(workout.activityType))

                        Text(workout.activityType.workoutTypeDisplayName())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        if let trainingType = workout.trainingType {
                            Text("·")
                                .foregroundColor(.secondary)
                            Text(formatTrainingType(trainingType))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // VDOT 右上角
                    if let dynamicVdot = workout.dynamicVdot {
                        HStack(spacing: 4) {
                            Image(systemName: "speedometer")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text(String(format: "VDOT %.1f", dynamicVdot))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                    }
                }

                // 數據網格（標籤在下、數字在上）
                HStack(spacing: 0) {
                    // 距離
                    VStack(alignment: .leading, spacing: 4) {
                        if let distanceMeters = workout.distanceMeters {
                            Text(formatDistance(distanceMeters))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                        } else {
                            Text("-")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        Text(L10n.WorkoutMetrics.distance.localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // 時間
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDuration(workout.duration))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        Text(L10n.WorkoutMetrics.time.localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // 卡路里
                    VStack(alignment: .leading, spacing: 4) {
                        if let calories = workout.calories {
                            Text(String(format: "%.0f kcal", calories))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                        } else {
                            Text("-")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        Text(L10n.WorkoutMetrics.calories.localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 細分隔線
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 1)

                // 底部：日期時間（左） + Badge（右）
                HStack {
                    Text(formattedDate(workout.startDate))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Provider/Device Attribution - 顯示數據來源和設備 logo
                    attributionLogos
                }
            }
            .padding(.vertical, 16)
            .padding(.leading, 16)
            .padding(.trailing, 16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }

    // MARK: - Attribution Logos
    @ViewBuilder
    private var attributionLogos: some View {
        let isStravaProvider = workout.provider.lowercased() == "strava"
        let isGarminProvider = workout.provider.lowercased() == "garmin"
        let isGarminDevice = workout.deviceName?.lowercased().contains("garmin") ?? false ||
                             workout.deviceName?.lowercased().contains("forerunner") ?? false

        if isStravaProvider || isGarminProvider || isGarminDevice {
            HStack(spacing: 6) {
                Spacer()

                // Strava logo
                if isStravaProvider {
                    ConditionalStravaAttributionView(
                        dataProvider: workout.provider,
                        displayStyle: .compact
                    )
                }

                // Garmin logo (if provider is Garmin OR device is Garmin)
                if isGarminProvider || isGarminDevice {
                    GarminAttributionView(
                        deviceModel: nil,  // 列表中不顯示型號，節省空間
                        displayStyle: .compact
                    )
                }
            }
        }
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
        case "easy_run", "easy":
            return L10n.Training.TrainingType.easy.localized
        case "recovery_run":
            return L10n.Training.TrainingType.recovery.localized
        case "long_run":
            return L10n.Training.TrainingType.long.localized
        case "tempo":
            return L10n.Training.TrainingType.tempo.localized
        case "threshold":
            return L10n.Training.TrainingType.threshold.localized
        case "interval":
            return L10n.Training.TrainingType.interval.localized
        case "fartlek":
            return L10n.Training.TrainingType.fartlek.localized
        case "combination":
            return L10n.Training.TrainingType.combination.localized
        case "hill_training":
            return L10n.Training.TrainingType.hill.localized
        case "race":
            return L10n.Training.TrainingType.race.localized
        case "rest":
            return L10n.Training.TrainingType.rest.localized
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

    private func getActivityTypeColor(_ activityType: String) -> Color {
        let type = activityType.lowercased()

        // 跑步類型：根據訓練類型分組配色（與 DailyTrainingCard 一致）
        if type.contains("running") || type.contains("run") {
            if let trainingType = workout.trainingType {
                let trainingTypeLower = trainingType.lowercased()

                // 綠色：輕鬆跑、恢復跑、LSD
                if trainingTypeLower.contains("easy") ||
                   trainingTypeLower.contains("recovery") ||
                   trainingTypeLower.contains("lsd") {
                    return .mint
                }
                // 橘色：間歇、節奏跑、閾值跑、漸進跑、組合跑
                else if trainingTypeLower.contains("interval") ||
                        trainingTypeLower.contains("tempo") ||
                        trainingTypeLower.contains("threshold") ||
                        trainingTypeLower.contains("progression") ||
                        trainingTypeLower.contains("combination") ||
                        trainingTypeLower.contains("fartlek") {
                    return .orange
                }
                // 藍色：長距離跑
                else if trainingTypeLower.contains("long") {
                    return .blue
                }
                // 紅色：比賽
                else if trainingTypeLower.contains("race") {
                    return .red
                }
                // 灰色：休息
                else if trainingTypeLower.contains("rest") {
                    return .gray
                }
                // 默認綠色
                else {
                    return .mint
                }
            } else {
                return .mint  // 沒有訓練類型時默認綠色
            }
        }
        // 其他運動類型
        else if type.contains("cycling") || type.contains("bike") || type.contains("ride") {
            return .blue
        } else if type.contains("hiking") || type.contains("hike") {
            return .blue
        } else if type.contains("strength") || type.contains("weight") || type.contains("gym") || type.contains("cross") {
            return .purple
        } else if type.contains("swimming") || type.contains("swim") {
            return .cyan
        } else if type.contains("yoga") {
            return .mint
        } else if type.contains("walking") || type.contains("walk") {
            return .mint
        } else {
            return .mint
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
        storagePath: Optional<String>.none,
        dailyPlanSummary: Optional<DailyPlanSummary>.none,
        aiSummary: Optional<AISummary>.none,
        shareCardContent: Optional<ShareCardContent>.none
    )
    
    WorkoutV2RowView(
        workout: workout,
        isUploaded: true,
        uploadTime: Date()
    )
    .previewLayout(.sizeThatFits)
    .padding()
} 
