import SwiftUI

struct WeekSelectorSheet: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle(NSLocalizedString("training.progress", comment: "Training Progress"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            isPresented = false
                        } label: {
                            HStack {
                                Image(systemName: "xmark")
                                Text(L10n.WeekSelector.close.localized)
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

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoadingWeeklySummaries {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            listView
        }
    }

    private var listView: some View {
        List(viewModel.weeklySummaries, id: \.weekIndex) { item in
                        HStack {
                            // 左側：週次與完成率
                            Text(L10n.WeekSelector.weekNumber.localized(with: item.weekIndex))
                                .font(AppFont.headline())
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
                                        Task {
                                            await viewModel.fetchWeeklySummary(weekNumber: item.weekIndex)
                                            // ✅ 延遲關閉 sheet，確保週回顧 sheet 可以正常顯示
                                            // SwiftUI 限制：同一時間只能顯示一個 sheet
                                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                                            isPresented = false
                                        }.tracked(from: "WeekSelectorSheet: fetchWeeklySummary")
                                    } label: {
                                        HStack(alignment: .center, spacing: 4) {
                                            Image(systemName: "doc.text.magnifyingglass")
                                                .font(.system(size: 12, weight: .medium))
                                            Text(L10n.WeekSelector.review.localized)
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
                                            // ✅ 直接調用 fetchWeekPlan,它內部會處理 selectedWeek 和 currentWeek 的更新
                                            await viewModel.fetchWeekPlan(week: item.weekIndex)
                                            // ✅ 等待課表載入完成後再關閉 sheet
                                            isPresented = false
                                        }.tracked(from: "WeekSelectorSheet: fetchWeekPlan")
                                    } label: {
                                        HStack(alignment: .center, spacing: 4) {
                                            Image(systemName: "calendar")
                                                .font(.system(size: 12, weight: .medium))
                                            Text(L10n.WeekSelector.schedule.localized)
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

#Preview {
    WeekSelectorSheet(
        viewModel: TrainingPlanViewModel(),
        isPresented: .constant(true)
    )
}
