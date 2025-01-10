import SwiftUI
import Combine
import GoogleGenerativeAI

struct CombinedFeedback: Codable {
    let user_feedback: String
    let weekly_summary: String
}

struct WeeklyAnalysisView: View {
    @StateObject var viewModel: TrainingPlanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingNextWeekPlanning = false
    @State private var isGeneratingPlan = false
    
    private func formatJSON(_ jsonString: String) -> String {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return jsonString
        }
        return prettyString
    }
    
    private func generateCombinedJSON(userFeedback: UserFeedback, weeklySummary: String) async -> [String: Any]? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let userFeedbackData = try encoder.encode(userFeedback)
            let userFeedbackString = String(data: userFeedbackData, encoding: .utf8) ?? "{}"
            
            // 格式化 weekly summary
            let formattedWeeklySummary = formatJSON(weeklySummary)
            
            let combinedFeedback = [
                "user_feedback": try JSONSerialization.jsonObject(with: userFeedbackData),
                "weekly_summary": try JSONSerialization.jsonObject(with: formattedWeeklySummary.data(using: .utf8) ?? Data())
            ]
            
            return combinedFeedback
        } catch {
            print("Error generating JSON: \(error)")
            return nil
        }
    }
    
    private func getTomorrowDate() -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        if viewModel.isGeneratingAnalysis {
                            ProgressView("正在生成分析...")
                                .progressViewStyle(.circular)
                        } else if let analysis = viewModel.weeklyAnalysis {
                            VStack(alignment: .leading, spacing: 24) {
                                // 總結部分
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("總結")
                                        .font(.headline)
                                    Text(analysis.summary)
                                        .font(.body)
                                }
                                
                                // 訓練分析部分
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("訓練分析")
                                        .font(.headline)
                                    Text(analysis.training_analysis)
                                        .font(.body)
                                }
                                
                                // 進一步建議部分
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("進一步建議")
                                        .font(.headline)
                                    Text(analysis.further_suggestion)
                                        .font(.body)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(radius: 2)
                            
                            Button(action: {
                                Task {
                                    isGeneratingPlan = true
                                    let weekOfPlan = (UserPreferenceManager.shared.currentPreference?.weekOfPlan ?? 1) + 1
                                    guard let planOverView = TrainingPlanStorage.shared.loadTrainingPlanOverview() else {
                                        print("無法載入訓練計劃概覽")
                                        isGeneratingPlan = false
                                        return
                                    }
                                    let selectedGoal = UserPreferenceManager.shared.currentPreference?.goalType ?? "defaultGoal"
                                    print("weekOfPlan: \(weekOfPlan), goal: \(selectedGoal)")
                                    
                                    do {
                                        // 產生下週訓練計劃
                                        let result = try await GeminiService.shared.generateContent(
                                            withPromptFiles: [selectedGoal == "beginner" ? "prompt_plan_base_habit" : "prompt_plan_runing"],
                                            input: planOverView.merging(["action": "產生第\(weekOfPlan)週訓練計劃"]) { (_, new) in new },
                                            schema: trainingPlanSchema
                                        )
                                        
                                        print("成功生成計劃：\(result)")
                                        
                                        // 更新並保存 weekOfPlan
                                        if var preference = UserPreferenceManager.shared.currentPreference {
                                            preference.weekOfPlan = weekOfPlan
                                            UserPreferenceManager.shared.savePreference(preference)
                                        }
                                        
                                        // 保存新的計劃
                                        if let plan = try? TrainingPlanStorage.shared.generateAndSaveNewPlan(from: result) {
                                            print("已保存的weekOfPlan: \(UserPreferenceManager.shared.currentPreference?.weekOfPlan ?? 1)")
                                            
                                            await MainActor.run {
                                                // 刷新 TrainingPlanView
                                                viewModel.loadTrainingPlan()
                                                isGeneratingPlan = false
                                                dismiss()
                                            }
                                        }
                                    } catch {
                                        print("生成計劃時出錯：\(error.localizedDescription)")
                                        isGeneratingPlan = false
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "calendar.badge.plus")
                                    Text("產生下週訓練計劃")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .disabled(isGeneratingPlan)
                        } else if let error = viewModel.analysisError {
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.red)
                                Text("生成分析時出錯")
                                    .font(.headline)
                                Text(error.localizedDescription)
                                    .font(.body)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                                Button("重試") {
                                    Task {
                                        await viewModel.generateAnalysis()
                                    }
                                }
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .padding()
                        } else {
                            // 如果沒有分析結果，才自動生成
                            Text("正在準備分析...")
                                .onAppear {
                                    Task {
                                        await viewModel.generateAnalysis()
                                    }
                                }
                        }
                    }
                    .padding()
                }
                
                // Loading View
                if isGeneratingPlan {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("Vita正在產生下週訓練計劃")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationTitle("本週訓練總結")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
