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
                            showingNextWeekPlanning = true
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
            .navigationTitle("本週訓練總結")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingNextWeekPlanning) {
                NextWeekPlanningView { feeling, difficulty, days, item, completion in
                    // 在背景執行計劃生成
                    Task {
                        let summary = await viewModel.generateWeeklySummary()
                        let userFeedback = UserFeedback(
                            feeling: feeling,
                            difficul_adjust: difficulty.jsonValue,
                            training_day_adjust: days.jsonValue,
                            training_item_adjust: item.jsonValue
                        )
                        if let combinedJSON = await generateCombinedJSON(userFeedback: userFeedback, weeklySummary: summary) {
                            do {
                                let result = try await GeminiService.shared.generateFollowingPlan(input: combinedJSON)
                                
                                // 打印完整的 AI 返回結果
                                print("=== AI Response ===")
                                if let jsonData = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
                                   let jsonString = String(data: jsonData, encoding: .utf8) {
                                    print(jsonString)
                                    
                                    // 設定明天為開始日期
                                    await MainActor.run {
                                        viewModel.selectedStartDate = getTomorrowDate()
                                        // 更新訓練計劃
                                        viewModel.generateNewPlan(plan: jsonString)
                                        // 完成後關閉視圖
                                        completion()
                                        dismiss()
                                    }
                                }
                            } catch {
                                print("Error generating new plan: \(error)")
                                completion()
                            }
                        }
                    }
                }
            }
        }
    }
}
