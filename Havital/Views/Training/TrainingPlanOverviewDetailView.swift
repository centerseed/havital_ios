import SwiftUI

struct TrainingPlanOverviewDetailView: View {
    let overview: [String: Any]
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
                        
                        if let overview = overview["training_plan_overview"] as? String {
                            Text(overview)
                                .font(.body)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Goal Evaluation
                    if let evaluation = overview["target_evaluate"] as? String {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("目標評估", systemImage: "target")
                                .font(.title3)
                                .bold()
                            
                            Text(evaluation)
                                .font(.body)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Training Highlight
                    if let highlight = overview["training_hightlight"] as? String {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("計劃亮點", systemImage: "sparkles")
                                .font(.title3)
                                .bold()
                            
                            Text(highlight)
                                .font(.body)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Training Stages
                    if let stages = overview["training_stage_discription"] as? [[String: Any]] {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("訓練階段", systemImage: "chart.bar.fill")
                                .font(.title3)
                                .bold()
                            
                            ForEach(stages.indices, id: \.self) { index in
                                let stage = stages[index]
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(stage["stage_name"] as? String ?? "")
                                        .font(.headline)
                                    
                                    if let weekStart = stage["week_start"] as? Int,
                                       let weekEnd = stage["week_end"] as? Int {
                                        Text("第\(weekStart)-\(weekEnd)週")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Text(stage["stage_description"] as? String ?? "")
                                        .font(.body)
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .onAppear {
                    print("TrainingPlanOverviewDetailView appeared with overview: \(overview)")
                }
            }
            .navigationTitle(overview["plan_name"] as? String ?? "訓練計劃")
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
    TrainingPlanOverviewDetailView(overview: [
        "plan_name": "半馬訓練計劃",
        "training_plan_overview": "這是一個為期16週的半馬訓練計劃，專注於漸進式提升耐力和速度。",
        "goal_evaluation": "根據您的目標和現況，這個計劃將幫助您安全且有效地達成目標。",
        "training_method": "採用科學化的訓練方法，結合不同強度的訓練，確保訓練效果最大化。",
        "training_highlight": "本計劃的亮點在於其結合了長跑、間歇跑和恢復跑等多樣化訓練方式。",
        "training_stages": [
            [
                "stage_name": "第一階段",
                "stage_description": "本階段的訓練重點在於提升耐力。",
                "week_start": 1,
                "week_end": 4
            ],
            [
                "stage_name": "第二階段",
                "stage_description": "本階段的訓練重點在於提升速度。",
                "week_start": 5,
                "week_end": 8
            ]
        ]
    ])
}
