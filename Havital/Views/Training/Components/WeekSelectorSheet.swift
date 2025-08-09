import SwiftUI

struct WeekSelectorSheet: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingWeeklySummaries {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.weeklySummaries, id: \.weekIndex) { item in
                        HStack {
                            // 左側：週次與完成率
                            Text("第 \(item.weekIndex) 週")
                                .font(.headline)
                                .foregroundColor(.primary)
                            // 顯示完成率（若有）
                            if let percent = item.completionPercentage {
                                HStack(spacing: 8) {
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color(.systemGray5))
                                            .frame(width: 40, height: 6)
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(LinearGradient(
                                                gradient: Gradient(colors: [.blue, .teal]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ))
                                            .frame(width: 40 * min(percent, 100) / 100, height: 6)
                                    }
                                    Text("\(Int(percent))%")
                                        .fixedSize()
                                        .font(.footnote.bold())
                                        .foregroundColor(.blue)
                                }
                            }
                            Spacer()
                            // 右側：功能按鈕
                            HStack(spacing: 8) {
                                if item.weekSummary != nil {
                                    Button {
                                        Task { await viewModel.fetchWeeklySummary(weekNumber: item.weekIndex) }
                                        isPresented = false
                                    } label: {
                                        HStack(alignment: .center, spacing: 4) {
                                            Image(systemName: "doc.text.magnifyingglass")
                                                .font(.system(size: 12, weight: .medium))
                                            Text("回顧")
                                                .font(.footnote)
                                                .fontWeight(.medium)
                                        }
                                        .fixedSize() 
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                if item.weekPlan != nil {
                                    Button {
                                        Task {
                                            viewModel.selectedWeek = item.weekIndex
                                            await viewModel.fetchWeekPlan(week: item.weekIndex)
                                            isPresented = false
                                        }
                                    } label: {
                                        HStack(alignment: .center, spacing: 4) {
                                            Image(systemName: "calendar")
                                                .font(.system(size: 12, weight: .medium))
                                            Text("課表")
                                                .font(.footnote)
                                                .fontWeight(.medium)
                                        }
                                        .fixedSize() 
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(Color.green.opacity(0.1))
                                        .foregroundColor(.green)
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.systemBackground))
                                .strokeBorder(Color(.systemGray4), lineWidth: 0.5)
                                .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
                        )
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(PlainListStyle())
                    .padding(.horizontal, 6)
                }
            }
            .navigationTitle("訓練進度")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        HStack {
                            Image(systemName: "xmark")
                            Text("關閉")
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .task {
            await viewModel.fetchWeeklySummaries()
        }
    }
}

#Preview {
    WeekSelectorSheet(
        viewModel: TrainingPlanViewModel(),
        isPresented: .constant(true)
    )
}
