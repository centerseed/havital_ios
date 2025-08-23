import SwiftUI

struct TrainingPlanInfoCard: View {
    let workout: WorkoutV2
    @State private var isAnalysisExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("課表資訊")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let dailyPlan = workout.dailyPlanSummary {
                VStack(alignment: .leading, spacing: 12) {
                    // Day target
                    if let dayTarget = dailyPlan.dayTarget {
                        Text(dayTarget)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Training details grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        if let distance = dailyPlan.distanceKm {
                            TrainingInfoItem(
                                title: "距離",
                                value: String(format: "%.1f km", distance),
                                icon: "location"
                            )
                        }
                        
                        if let pace = dailyPlan.pace {
                            TrainingInfoItem(
                                title: "配速",
                                value: pace,
                                icon: "speedometer"
                            )
                        }
                        
                        if let hrRange = dailyPlan.heartRateRange {
                            TrainingInfoItem(
                                title: "心率區間",
                                value: "\(hrRange.min)-\(hrRange.max)",
                                icon: "heart"
                            )
                        }
                        
                        if let trainingType = dailyPlan.trainingType {
                            TrainingInfoItem(
                                title: "訓練類型",
                                value: formatTrainingType(trainingType),
                                icon: "figure.run"
                            )
                        }
                    }
                }
            }
            
            // AI Summary section
            if let aiSummary = workout.aiSummary {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("AI 分析")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isAnalysisExpanded.toggle()
                            }
                        }) {
                            Text(isAnalysisExpanded ? "收起" : "展開")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Text(aiSummary.analysis)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(isAnalysisExpanded ? nil : 3)
                        .animation(.easeInOut(duration: 0.2), value: isAnalysisExpanded)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatTrainingType(_ type: String) -> String {
        switch type.lowercased() {
        case "easy_run", "easy":
            return "輕鬆跑"
        case "interval":
            return "間歇跑"
        case "tempo":
            return "節奏跑"
        case "threshold":
            return "閾值跑"
        case "long_run":
            return "長跑"
        case "recovery_run":
            return "恢復跑"
        case "lsd":
            return "長距離慢跑"
        case "progression":
            return "漸進跑"
        default:
            return type
        }
    }
}

struct TrainingInfoItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    TrainingPlanInfoCard(workout: WorkoutV2(
        id: "preview-1",
        provider: "Garmin",
        activityType: "running",
        startTimeUtc: ISO8601DateFormatter().string(from: Date()),
        endTimeUtc: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
        durationSeconds: 3600,
        distanceMeters: 15000,
        deviceName: "Garmin",
        basicMetrics: nil,
        advancedMetrics: nil,
        createdAt: nil,
        schemaVersion: nil,
        storagePath: nil,
        dailyPlanSummary: DailyPlanSummary(
            dayTarget: "長距離輕鬆跑，建立耐力基礎。",
            distanceKm: 15,
            pace: "6:40",
            trainingType: "lsd",
            heartRateRange: DailySummaryHeartRateRange(min: 140, max: 160)
        ),
        aiSummary: AISummary(
            analysis: "這次長距離輕鬆跑訓練，您實際完成了約14.7公里，時間約101分鐘，配速約為6分43秒，與課表目標相當接近，建立耐力基礎的目標達成度很高。從心率分佈來看，大部分時間落在輕鬆和馬拉松配速區間，平均心率159 bpm，顯示訓練品質良好，有效地刺激了耐力系統。建議下次可以稍微增加距離，並注意到最大心率略高於預期，未來訓練中可嘗試更穩定的配速控制，確保心率維持在輕鬆跑的範圍內，以最大化訓練效果。"
        )
    ))
    .padding()
}