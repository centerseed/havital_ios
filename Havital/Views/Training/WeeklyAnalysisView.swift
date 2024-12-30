import SwiftUI
import Combine


struct WeeklyAnalysisView: View {
    @StateObject var viewModel: TrainingPlanViewModel
    @Environment(\.dismiss) private var dismiss
    
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
        }
    }
}
