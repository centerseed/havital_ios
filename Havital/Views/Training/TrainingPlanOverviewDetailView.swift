import SwiftUI

struct TrainingPlanOverviewDetailView: View {
    let overview: TrainingPlanOverview
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with Plan Name
                VStack(alignment: .leading, spacing: 4) {
                    Text(overview.trainingPlanName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("總週數: \(overview.totalWeeks)週")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 4)
                
                // Goal Evaluation Section
                SectionCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "目標評估", systemImage: "target")
                        
                        Text(overview.targetEvaluate)
                            .font(.body)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                // Training Highlight Section
                SectionCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "計劃亮點", systemImage: "sparkles")
                        
                        Text(overview.trainingHighlight)
                            .font(.body)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                // Training Stages
                SectionCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "訓練階段", systemImage: "chart.bar.fill")
                        
                        ForEach(overview.trainingStageDescription.indices, id: \.self) { index in
                            let stage = overview.trainingStageDescription[index]
                            TrainingStageCard(stage: stage, index: index)
                        }
                    }
                }
            }
            .padding(.vertical)
            .background(colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
        }
        .overlay(alignment: .topTrailing) {
            Button("完成") {
                dismiss()
            }
            .foregroundColor(.blue)
            .padding(.trailing, 16)
            .padding(.top, 16)
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
        .presentationDetents([.large])
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let systemImage: String
    
    var body: some View {
        Label {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
        } icon: {
            Image(systemName: systemImage)
                .foregroundColor(.blue)
                .imageScale(.large)
        }
    }
}

struct SectionCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading) // 確保佔據最大寬度
        .padding(.horizontal)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(UIColor.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
}

struct TrainingStageCard: View {
    let stage: TrainingStage
    let index: Int
    @Environment(\.colorScheme) private var colorScheme
    
    private var stageColors: (Color, Color) {
        let colors: [(Color, Color)] = [
            (Color.blue, Color.blue.opacity(0.15)),
            (Color.green, Color.green.opacity(0.15)),
            (Color.orange, Color.orange.opacity(0.15)),
            (Color.purple, Color.purple.opacity(0.15))
        ]
        
        return colors[index % colors.count]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 階段標題和週數
            HStack {
                Circle()
                    .fill(stageColors.0)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text("\(index + 1)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading) {
                    Text(stage.stageName)
                        .font(.headline)
                        .foregroundColor(stageColors.0)
                    
                    if let weekEnd = stage.weekEnd {
                        Text("第\(stage.weekStart)-\(weekEnd)週")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("第\(stage.weekStart)週開始")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // 階段描述，確保文字可以根據內容動態調整高度
            Text(stage.stageDescription)
                .font(.body)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true) // 確保文字可以根據內容動態調整高度
            
            // 重點訓練部分
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(stageColors.0)
                    Text("重點訓練:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Text(stage.trainingFocus)
                    .font(.subheadline)
                    .foregroundColor(stageColors.0)
                    .fontWeight(.semibold)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(stageColors.1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading) // 確保佔據最大寬度
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(UIColor.systemGray5) : Color(UIColor.systemGray6).opacity(0.5))
        )
        .padding(.vertical, 4)
    }
}


// MARK: - Preview

struct TrainingPlanOverviewDetailView_Previews: PreviewProvider {
    static var previews: some View {
        TrainingPlanOverviewDetailView(overview: TrainingPlanOverview(
            targetEvaluate: "根據您的目標和現況，這個計劃將幫助您安全且有效地達成目標。本計劃充分考慮了您的當前健康狀況和跑步經驗，精心設計了漸進式的訓練課程。",
            totalWeeks: 16,
            trainingHighlight: "本計劃的亮點在於其結合了長跑、間歇跑和恢復跑等多樣化訓練方式，並根據您的進展逐步調整強度。特別注重恢復和節奏控制，幫助您在提升成績的同時降低受傷風險。",
            trainingPlanName: "半馬訓練計劃",
            trainingStageDescription: [
                TrainingStage(
                    stageName: "基礎建立期",
                    stageId: "1",
                    stageDescription: "本階段的訓練重點在於提升耐力基礎和適應性，以及建立穩定的訓練習慣。以較低強度的有氧訓練為主，逐步增加每週里程。",
                    trainingFocus: "耐力訓練",
                    weekStart: 1,
                    weekEnd: 4
                ),
                TrainingStage(
                    stageName: "強度發展期",
                    stageId: "2",
                    stageDescription: "本階段的訓練重點在於提升速度與節奏感，通過各種間歇訓練，提升心肺功能和乳酸閾值。",
                    trainingFocus: "速度和節奏訓練",
                    weekStart: 5,
                    weekEnd: 8
                ),
                TrainingStage(
                    stageName: "比賽準備期",
                    stageId: "3",
                    stageDescription: "本階段的訓練重點在於模擬比賽條件，熟悉比賽配速，以及精神和身體狀態的調整優化。",
                    trainingFocus: "配速穩定性與耐力",
                    weekStart: 9,
                    weekEnd: 14
                ),
                TrainingStage(
                    stageName: "賽前調整期",
                    stageId: "4",
                    stageDescription: "本階段的訓練重點在於保持狀態，同時降低訓練量，讓身體充分恢復以應對比賽。",
                    trainingFocus: "保持狀態與恢復",
                    weekStart: 15,
                    weekEnd: 16
                )
            ]
        ))
    }
}
