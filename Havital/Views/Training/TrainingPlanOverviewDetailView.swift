import SwiftUI

struct TrainingPlanOverviewDetailView: View {
    let overview: TrainingPlanOverview
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Overview Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("計劃概覽")
                            .font(.title2)
                            .bold()
                        
                        Text(overview.trainingPlanName)
                            .font(.body)
                    }
                    .padding(.horizontal)
                    
                    // Goal Evaluation
                    VStack(alignment: .leading, spacing: 16) {
                        Label("目標評估", systemImage: "target")
                            .font(.title3)
                            .bold()
                        
                        Text(overview.targetEvaluate)
                            .font(.body)
                    }
                    .padding(.horizontal)
                    
                    // Training Highlight
                    VStack(alignment: .leading, spacing: 16) {
                        Label("計劃亮點", systemImage: "sparkles")
                            .font(.title3)
                            .bold()
                        
                        Text(overview.trainingHighlight)
                            .font(.body)
                    }
                    .padding(.horizontal)
                    
                    // Training Stages
                    VStack(alignment: .leading, spacing: 16) {
                        Label("訓練階段", systemImage: "chart.bar.fill")
                            .font(.title3)
                            .bold()
                        
                        ForEach(overview.trainingStageDescription.indices, id: \.self) { index in
                            let stage = overview.trainingStageDescription[index]
                            VStack(alignment: .leading, spacing: 8) {
                                Text(stage.stageName)
                                    .font(.headline)
                                
                                if let weekEnd = stage.weekEnd {
                                    Text("第\(stage.weekStart)-\(weekEnd)週")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(stage.stageDescription)
                                    .font(.body)
                                
                                Text("重點訓練：\(stage.trainingFocus)")
                                    .font(.body)
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle(overview.trainingPlanName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    TrainingPlanOverviewDetailView(overview: TrainingPlanOverview(
        targetEvaluate: "根據您的目標和現況，這個計劃將幫助您安全且有效地達成目標。",
        totalWeeks: 16,
        trainingHighlight: "本計劃的亮點在於其結合了長跑、間歇跑和恢復跑等多樣化訓練方式。",
        trainingPlanName: "半馬訓練計劃",
        trainingStageDescription: [
            TrainingStage(
                stageName: "第一階段",
                stageId: "1",
                stageDescription: "本階段的訓練重點在於提升耐力。",
                trainingFocus: "耐力訓練",
                weekStart: 1,
                weekEnd: 4
            ),
            TrainingStage(
                stageName: "第二階段",
                stageId: "2",
                stageDescription: "本階段的訓練重點在於提升速度。",
                trainingFocus: "速度訓練",
                weekStart: 5,
                weekEnd: 8
            )
        ]
    ))
}
