import SwiftUI

struct WeekOverviewCard: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.colorScheme) var colorScheme
    let plan: WeeklyPlan
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var showWeekSelector = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("本週概覽")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 16) {
                // 使用GeometryReader动态计算和分配空间
                GeometryReader { geometry in
                    HStack(alignment: .center, spacing: 0) {
                        // 训练周期进度
                        VStack(spacing: 6) {
                            CircularProgressView(
                                progress: Double(plan.weekOfPlan) / Double(plan.totalWeeks),
                                currentWeek: plan.weekOfPlan,
                                totalWeeks: plan.totalWeeks
                            )
                            .frame(width: 80, height: 80)
                            .onTapGesture {
                                // 點擊進度圓圈彈出週數選擇
                                showWeekSelector = true
                            }

                            Text("訓練進度")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: geometry.size.width / 2)

                        // 如果有周跑量目标，显示第二个圆形进度条
                        VStack(spacing: 6) {
                            if viewModel.isLoadingDistance {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(1.0)
                                    .frame(width: 80, height: 80)
                            } else {
                                // 周跑量圆形进度条
                                ZStack {
                                    // 背景圓環
                                    Circle()
                                        .stroke(lineWidth: 8)
                                        .opacity(0.3)
                                        .foregroundColor(.blue)

                                    // 進度圓環
                                    Circle()
                                        .trim(from: 0.0, to: min(CGFloat(viewModel.currentWeekDistance / max(plan.totalDistance, 1.0)), 1.0))
                                        .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                                        .foregroundColor(.blue)
                                        .rotationEffect(Angle(degrees: 270.0))
                                        .animation(.linear, value: viewModel.currentWeekDistance)

                                    // 中间的文字
                                    VStack(spacing: 2) {
                                        Text("\(String(format: "%.1f", viewModel.currentWeekDistance))")
                                            .font(.system(size: 16, weight: .bold))

                                        Text("\(viewModel.formatDistance(plan.totalDistance))")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(width: 80, height: 80)
                            }

                            Text("本週跑量")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: geometry.size.width / 2)
                    }
                    .frame(width: geometry.size.width)
                }
                .frame(height: 100) // 設置一個固定高度以容納進度條和標籤

                // 訓練目的
                VStack(alignment: .leading, spacing: 2) {
                    Text("週目標")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Text(plan.purpose)
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 顯示「產生下週課表」按鈕 (根據新的條件)
                // 在 TrainingPlanView 中的適當位置添加以下代碼

                // 判斷是否顯示產生課表按鈕
                /*
                if let plan = viewModel.weeklyPlan, let currentTrainingWeek = viewModel.calculateCurrentTrainingWeek() {
                    let (shouldShow, nextWeek) = viewModel.shouldShowNextWeekButton(plan: plan)

                    if shouldShow {
                        // 顯示產生課表按鈕
                        VStack(spacing: 8) {
                            Text("當前訓練週數：第 \(currentTrainingWeek) 週")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Button(action: {
                                Task {
                                    await viewModel.generateNextWeekPlan()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "calendar.badge.plus")
                                    Text("產生第 \(nextWeek) 週課表")
                                }
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                        .disabled(viewModel.isLoading)
                    }
                }*/
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showWeekSelector) {
            NavigationView {
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
                                        showWeekSelector = false
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
                                        Task { await viewModel.fetchWeekPlan(week: item.weekIndex, healthKitManager: healthKitManager) }
                                        showWeekSelector = false
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
            .navigationViewStyle(StackNavigationViewStyle())
            .navigationTitle("訓練進度")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { showWeekSelector = false }
                }
            }
            .task { await viewModel.fetchWeeklySummaries() }
        }
        .sheet(isPresented: $viewModel.showWeeklySummary) {
            if let summary = viewModel.weeklySummary {
                WeeklySummaryView(
                    summary: summary,
                    weekNumber: viewModel.lastFetchedWeekNumber,
                    isVisible: $viewModel.showWeeklySummary
                )
            }
        }
    }
}

struct CircularProgressView: View {
    let progress: Double
    let currentWeek: Int
    let totalWeeks: Int
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // 背景圓環
            Circle()
                .stroke(lineWidth: 10)
                .opacity(0.3)
                .foregroundColor(.gray)

            // 進度圓環
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                .foregroundColor(.blue)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: progress)

            // 中心文字
            VStack(spacing: 2) {
                Text("\(currentWeek)")
                    .font(.system(size: 22, weight: .bold))

                Text("/ \(totalWeeks)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Text("週")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// EditTargetView(targetId: viewModel.trainingOverview?.mainRaceId ?? target.id)
