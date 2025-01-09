import SwiftUI

struct TrainingPlanOverviewView: View {
    let planOverview: [String: Any]
    let selectedGoalType: String
    @Environment(\.dismiss) private var dismiss
    @State private var isGeneratingPlan = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Binding var hasCompletedOnboarding: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 訓練計劃總覽
                if let overview = planOverview["training_plan_overview"] as? String {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("訓練計劃總覽")
                            .font(.headline)
                            .font(.system(size: 16))
                        Text(overview)
                            .font(.body)
                            .font(.system(size: 14))       
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 2)
                }
                
                // 目標評估
                if let evaluation = planOverview["target_evaluate"] as? String {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("目標評估")
                            .font(.headline)
                            .font(.system(size: 16))
                        Text(evaluation)
                            .font(.body)
                            .font(.system(size: 14))       
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 2)
                }
                
                // 訓練方法
                if let trainingHighlight = planOverview["training_highlight"] as? String {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("訓練方法")
                            .font(.headline)
                            .font(.system(size: 16))
                        Text(trainingHighlight)
                            .font(.body)
                            .font(.system(size: 14))       
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 2)
                }
                
                // 訓練階段
                if let stages = planOverview["training_stages"] as? [[String: Any]] {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("訓練階段")
                            .font(.headline)
                            .font(.system(size: 16))
                        
                        ForEach(stages.indices, id: \.self) { index in
                            let stage = stages[index]
                            if let stageName = stage["stage_name"] as? String,
                               let description = stage["stage_description"] as? String,
                               let weekStart = stage["week_start"] as? Int,
                               let weekEnd = stage["week_end"] as? Int {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("\(stageName) (第\(weekStart)-\(weekEnd)週)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(description)
                                        .font(.body)
                                        .font(.system(size: 14))
                                }
                                .padding(.bottom, 10)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 2)
                }
                
                // 產生一週計劃按鈕
                Button(action: {
                    Task {
                        isGeneratingPlan = true
                        do {
                            var result = try await GeminiService.shared.generateContent(
                                withPromptFiles: [selectedGoalType == "beginner" ? "prompt_plan_base_habit" : "prompt_plan_runing"],
                                input: planOverview.merging(["action": "產生第\(UserPreferenceManager.shared.currentPreference?.weekOfPlan ?? 1)週訓練計劃"]) { (_, new) in new },
                                schema: trainingPlanSchema
                            )
                            
                            print("成功生成計劃：\(result)")
                            
                            // 處理生成的計劃
                            if let plan = try? TrainingPlanStorage.shared.generateAndSaveNewPlan(from: result) {
                                
                                await MainActor.run {
                                    isGeneratingPlan = false
                                    dismiss()
                                    hasCompletedOnboarding = true
                                }
                            }
                        } catch {
                            await MainActor.run {
                                isGeneratingPlan = false
                                showError = true
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                }) {
                    HStack {
                        Text("產生第\(UserPreferenceManager.shared.currentPreference?.weekOfPlan ?? 1)週計劃")
                            .fontWeight(.semibold)
                        if isGeneratingPlan {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isGeneratingPlan)
                .padding(.top, 20)
            }
            .padding()
        }
        .alert("錯誤", isPresented: $showError) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
}

#Preview {
    TrainingPlanOverviewView(planOverview: [
        "plan_name": "半馬訓練計劃",
        "training_plan_overview": "這是一個為期16週的半馬訓練計劃，專注於漸進式提升耐力和速度。計劃包含每週3-4次的訓練，結合長跑、間歇跑和恢復跑等多樣化訓練方式。",
        "goal_evaluation": "根據您的目標和現況，這個計劃將幫助您安全且有效地達成目標。",
        "training_method": "採用科學化的訓練方法，結合不同強度的訓練，確保訓練效果最大化。",
        "training_highlight": "本計劃的亮點在於其結合了長跑、間歇跑和恢復跑等多樣化訓練方式，能夠有效提升耐力和速度。",
        "training_stages": [
            [
                "stage_name": "第一階段",
                "stage_description": "本階段的訓練重點在於提升耐力，包含每週3次的長跑和間歇跑訓練。",
                "week_start": 1,
                "week_end": 4
            ],
            [
                "stage_name": "第二階段",
                "stage_description": "本階段的訓練重點在於提升速度，包含每週3次的間歇跑和恢復跑訓練。",
                "week_start": 5,
                "week_end": 8
            ]
        ]
    ], selectedGoalType: "beginner", hasCompletedOnboarding: .constant(false))
}
