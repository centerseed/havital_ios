import SwiftUI

/// V2 訓練計畫主頁面
/// 設計原則：與 V1 保持一致的 UI/UX，使用 V2 的資料模型
struct TrainingPlanV2View: View {
    @StateObject private var viewModel: TrainingPlanV2ViewModel
    @State private var showPlanOverview = false
    @State private var showUserProfile = false
    @State private var showWeeklySummary = false

    // MARK: - Initialization

    init(viewModel: TrainingPlanV2ViewModel? = nil) {
        if let viewModel = viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: DependencyContainer.shared.makeTrainingPlanV2ViewModel())
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    switch viewModel.planStatus {
                    case .ready(let weeklyPlan):
                        // 1️⃣ 訓練進度卡片（與 V1 相同）
                        TrainingProgressCardV2(viewModel: viewModel, plan: weeklyPlan)

                        // 2️⃣ 週總覽卡片（與 V1 相同）
                        WeekOverviewCardV2(viewModel: viewModel, plan: weeklyPlan)

                        // 3️⃣ 週時間軸
                        WeekTimelineViewV2(viewModel: viewModel, plan: weeklyPlan)

                    case .noWeeklyPlan:
                        GenerateWeeklyPlanPromptView {
                            Task {
                                await viewModel.generateCurrentWeekPlan()
                            }
                        }

                    case .generating:
                        GeneratingWeeklyPlanView()

                    case .noPlan:
                        NoPlanPromptView()

                    case .completed:
                        TrainingCompletedView()

                    case .loading:
                        ProgressView()
                            .padding(.top, 100)

                    case .error(let error):
                        ErrorView(error: error, retryAction: {
                            Task {
                                await viewModel.refreshWeeklyPlan()
                            }
                        })
                    }
                }
                .padding(.horizontal)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .refreshable {
                await viewModel.refreshWeeklyPlan()
            }
            .navigationTitle(viewModel.trainingPlanName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左側按鈕 - 快速進入計畫概覽
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showPlanOverview = true
                    }) {
                        Image(systemName: "doc.text.below.ecg")
                            .foregroundColor(.primary)
                    }
                }

                // 右側選單
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showUserProfile = true }) {
                            Label("個人資料", systemImage: "person.circle")
                        }

                        Button(action: { showPlanOverview = true }) {
                            Label("訓練計畫概覽", systemImage: "doc.text.below.ecg")
                        }

                        Button(action: { showWeeklySummary = true }) {
                            Label(NSLocalizedString("training.weekly_summary", comment: "週摘要"), systemImage: "chart.bar.doc.horizontal")
                        }

                        Divider()

                        Button(action: {
                            // TODO: 實作聯絡功能
                        }) {
                            Label("聯絡 Paceriz", systemImage: "envelope.circle")
                        }

                        // Debug 選單
                        #if DEBUG
                        Divider()

                        Menu {
                            Button(action: {
                                Task {
                                    await viewModel.debugGenerateWeeklySummary()
                                }
                            }) {
                                Label("🐛 產生週回顧", systemImage: "note.text.badge.plus")
                            }

                            Button(role: .destructive, action: {
                                Task {
                                    await viewModel.debugDeleteCurrentWeekPlan()
                                }
                            }) {
                                Label("🗑️ 刪除當前週課表", systemImage: "trash")
                            }

                            Button(role: .destructive, action: {
                                Task {
                                    await viewModel.debugDeleteCurrentWeeklySummary()
                                }
                            }) {
                                Label("🗑️ 刪除當前週回顧", systemImage: "trash")
                            }
                        } label: {
                            Label("🐛 Debug 工具", systemImage: "hammer.circle")
                        }
                        #endif
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.primary)
                    }
                }
            }
            // TODO: 實作 PlanOverviewSheet
            // .sheet(isPresented: $showPlanOverview) {
            //     PlanOverviewSheet(viewModel: viewModel)
            // }
            .sheet(isPresented: $showUserProfile) {
                NavigationView {
                    UserProfileView()
                }
            }
            .sheet(isPresented: $showWeeklySummary) {
                NavigationStack {
                    WeeklySummaryV2View(viewModel: viewModel, weekOfPlan: viewModel.selectedWeek)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(NSLocalizedString("common.close", comment: "Close")) {
                                    showWeeklySummary = false
                                }
                            }
                        }
                }
            }
        }
        .task {
            await viewModel.initialize()
        }
        // 成功訊息 Toast
        .overlay(alignment: .top) {
            if let successMessage = viewModel.successToast {
                VStack {
                    Text(successMessage)
                        .font(AppFont.bodySmall())
                        .padding()
                        .background(Color.green.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top, 60)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                viewModel.clearSuccessToast()
                            }
                        }
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: viewModel.successToast)
            }
        }
        // 錯誤訊息 Toast
        .overlay(alignment: .top) {
            if let error = viewModel.networkError {
                VStack {
                    Text("❌ \(error.localizedDescription)")
                        .font(AppFont.bodySmall())
                        .padding()
                        .background(Color.red.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top, 60)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                viewModel.clearError()
                            }
                        }
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: viewModel.networkError as? NSError)
            }
        }
    }
}

// MARK: - Placeholder Views

/// 佔位用的週時間軸視圖（待實作）
private struct PlaceholderWeekTimelineView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                    .font(.headline)
                Text(NSLocalizedString("training.daily_training", comment: "Daily Training"))
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 4)

            Text("週課表功能開發中...")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(10)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

/// 產生週課表提示視圖
private struct GenerateWeeklyPlanPromptView: View {
    let generateAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.top, 40)

            Text(NSLocalizedString("training.no_weekly_plan_title", comment: "週課表尚未產生"))
                .font(.headline)
                .foregroundColor(.primary)

            Text(NSLocalizedString("training.no_weekly_plan_description", comment: "點擊下方按鈕產生本週課表"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: generateAction) {
                Text(NSLocalizedString("training.generate_weekly_plan", comment: "產生週課表"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 32)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

/// 正在生成週課表視圖
private struct GeneratingWeeklyPlanView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .padding(.top, 40)

            Text(NSLocalizedString("training.generating_weekly_plan", comment: "正在產生週課表..."))
                .font(.headline)
                .foregroundColor(.primary)

            Text(NSLocalizedString("training.generating_weekly_plan_description", comment: "AI 正在為您規劃本週訓練，請稍候"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

/// 無計畫提示視圖
private struct NoPlanPromptView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .padding(.top, 40)

            Text("尚未建立訓練計畫")
                .font(.headline)
                .foregroundColor(.primary)

            Text("請前往 Onboarding 建立您的訓練計畫")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

/// 訓練完成提示視圖
private struct TrainingCompletedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .padding(.top, 40)

            Text("恭喜!訓練計畫已完成")
                .font(.headline)
                .foregroundColor(.primary)

            Text("準備開始新的訓練計畫嗎?")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

/// 錯誤視圖
private struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .padding(.top, 40)

            Text("載入失敗")
                .font(.headline)
                .foregroundColor(.primary)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: retryAction) {
                Text("重試")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 32)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    TrainingPlanV2View()
}
