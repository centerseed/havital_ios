import SwiftUI

// MARK: - Mode Enum
enum TrainingOverviewMode {
    case preview   // 從 TrainingDaysSetupView 預覽，需要生成第一週計劃
    case final     // 從 TrainingDaysSetupView 生成計劃後最終展示
}

// MARK: - ViewModel
@MainActor
class TrainingOverviewViewModel: ObservableObject {
    @Published var trainingOverview: TrainingPlanOverview?
    @Published var targetPace: String = "6:00"
    @Published var raceDate: Date = Date()
    @Published var isLoading = false
    @Published var error: String?
    @Published var isTargetEvaluateExpanded = false
    @Published var isHighlightExpanded = false  // 計劃亮點收折狀態
    @Published var isGeneratingPlan = false
    @Published var navigateToMainApp = false

    let mode: TrainingOverviewMode

    init(mode: TrainingOverviewMode = .final, trainingOverview: TrainingPlanOverview? = nil) {
        self.mode = mode
        self.trainingOverview = trainingOverview
    }

    func loadTrainingOverview() async {
        // 如果是 preview 模式且已經有 overview，則不需要載入
        if mode == .preview && trainingOverview != nil {
            print("[TrainingOverviewViewModel] Preview 模式，使用傳入的 overview")
            return
        }

        isLoading = true
        error = nil

        do {
            // 獲取訓練總覽
            let overview = try await TrainingPlanService.shared.getTrainingPlanOverview()

            // TODO: 獲取目標配速和賽事日期（從 Target 或其他來源）
            // 暫時使用模擬數據

            await MainActor.run {
                self.trainingOverview = overview
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func generateFirstWeekPlan() async {
        isGeneratingPlan = true
        error = nil

        do {
            // 如果是 preview 模式，需要調用 createWeeklyPlan API
            if mode == .preview {
                print("[TrainingOverviewViewModel] Preview 模式，調用 createWeeklyPlan")
                let _ = try await TrainingPlanService.shared.createWeeklyPlan(startFromStage: nil)
                print("[TrainingOverviewViewModel] 第一週計劃生成成功")
            }

            // 標記 onboarding 完成
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            print("[TrainingOverviewViewModel] 已設置 hasCompletedOnboarding = true")

            await MainActor.run {
                self.isGeneratingPlan = false
                // 設置完成標誌，讓 AuthenticationService 觸發導航
                AuthenticationService.shared.hasCompletedOnboarding = true
                print("[TrainingOverviewViewModel] Onboarding 完成，導航到主應用")
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isGeneratingPlan = false
            }
        }
    }
}

// MARK: - View
struct TrainingOverviewView: View {
    @StateObject private var viewModel: TrainingOverviewViewModel
    @Environment(\.dismiss) private var dismiss

    init(mode: TrainingOverviewMode = .final, trainingOverview: TrainingPlanOverview? = nil) {
        _viewModel = StateObject(wrappedValue: TrainingOverviewViewModel(mode: mode, trainingOverview: trainingOverview))
    }

    var body: some View {
        ZStack {
            // 主要內容區域
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary Section
                    summarySection

                    // Target Evaluate (折疊)
                    if let overview = viewModel.trainingOverview,
                       !overview.targetEvaluate.isEmpty {
                        targetEvaluateSection(overview.targetEvaluate)
                    }

                    // Training Timeline
                    if let overview = viewModel.trainingOverview {
                        timelineSection(overview)
                    }

                    // 底部留白，避免被按鈕遮蔽
                    Color.clear.frame(height: 100)
                }
                .padding()
            }

            // 底部固定按鈕
            VStack {
                Spacer()
                generateButton
            }
        }
        .navigationTitle(NSLocalizedString("onboarding.training_overview_title", comment: "Training Overview"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Text(NSLocalizedString("common.back", comment: "Back"))
                }
            }
        }
        .task {
            await viewModel.loadTrainingOverview()
        }
        .alert(NSLocalizedString("common.error", comment: "Error"), isPresented: .constant(viewModel.error != nil)) {
            Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }

    // MARK: - Summary Section
    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("onboarding.training_summary", comment: "Training Summary"))
                .font(.headline)

            if let overview = viewModel.trainingOverview {
                HStack {
                    Label(NSLocalizedString("onboarding.total_weeks", comment: "Total Weeks"), systemImage: "calendar")
                    Spacer()
                    Text("\(overview.totalWeeks) \(NSLocalizedString("common.weeks", comment: "weeks"))")
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Label(NSLocalizedString("onboarding.race_date", comment: "Race Date"), systemImage: "flag.checkered")
                Spacer()
                Text(viewModel.raceDate, style: .date)
                    .foregroundColor(.secondary)
            }

            HStack {
                Label(NSLocalizedString("onboarding.target_pace", comment: "Target Pace"), systemImage: "speedometer")
                Spacer()
                Text("\(viewModel.targetPace) /km")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Target Evaluate Section (Collapsible)
    @ViewBuilder
    private func targetEvaluateSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("onboarding.target_evaluate", comment: "Target Evaluation"))
                    .font(.headline)
                Spacer()
                Button(action: {
                    withAnimation {
                        viewModel.isTargetEvaluateExpanded.toggle()
                    }
                }) {
                    Image(systemName: viewModel.isTargetEvaluateExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(viewModel.isTargetEvaluateExpanded ? nil : 2)
                .animation(.easeInOut, value: viewModel.isTargetEvaluateExpanded)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Timeline Section
    @ViewBuilder
    private func timelineSection(_ overview: TrainingPlanOverview) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("onboarding.training_timeline", comment: "Training Timeline"))
                .font(.headline)
                .padding(.bottom, 16)

            // Training Highlight 卡片（移到最上方）
            if !overview.trainingHighlight.isEmpty {
                highlightCard(overview.trainingHighlight)
                    .padding(.bottom, 16)
            }

            // 階段卡片
            ForEach(Array(overview.trainingStageDescription.enumerated()), id: \.offset) { index, stage in
                stageCard(
                    stage,
                    targetPace: viewModel.targetPace,
                    stageIndex: index,
                    isLast: index == overview.trainingStageDescription.count - 1,
                    nextStageColor: index < overview.trainingStageDescription.count - 1 ? stageColor(for: index) : nil
                )
            }
        }
    }

    // MARK: - Stage Card
    @ViewBuilder
    private func stageCard(_ stage: TrainingStage, targetPace: String, stageIndex: Int, isLast: Bool, nextStageColor: Color?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 左側時間軸（圓點 + 連接線）
            VStack(spacing: 0) {
                // 圓點
                Circle()
                    .fill(stageColor(for: stageIndex))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(color: stageColor(for: stageIndex).opacity(0.3), radius: 4, x: 0, y: 2)

                // 連接線（如果不是最後一個階段）
                if !isLast, let nextColor = nextStageColor {
                    VStack(spacing: 2) {
                        ForEach(0..<8) { _ in
                            Rectangle()
                                .fill(nextColor.opacity(0.6))
                                .frame(width: 3, height: 6)
                        }
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 10))
                            .foregroundColor(nextColor.opacity(0.6))
                    }
                    .padding(.top, 4)
                }
            }
            .frame(width: 20)

            // 右側內容（無背景卡片）
            VStack(alignment: .leading, spacing: 4) {
                // 階段名稱 + 週數範圍（同一行）
                HStack {
                    Text(stage.stageName)
                        .font(.headline)
                    Spacer()
                    Text(weekRangeText(stage))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Target Pace（彩色加粗）
                Text("\(targetPace) /km")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(stageColor(for: stageIndex))

                // Training Focus（小字灰色）
                if !stage.trainingFocus.isEmpty {
                    Text(stage.trainingFocus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.bottom, isLast ? 0 : 8)
    }

    // MARK: - Highlight Card
    @ViewBuilder
    private func highlightCard(_ highlight: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text(NSLocalizedString("onboarding.training_highlight", comment: "Training Highlight"))
                    .font(.headline)
                Spacer()
                Button(action: {
                    withAnimation {
                        viewModel.isHighlightExpanded.toggle()
                    }
                }) {
                    Image(systemName: viewModel.isHighlightExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }

            Text(highlight)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(viewModel.isHighlightExpanded ? nil : 2)
                .animation(.easeInOut, value: viewModel.isHighlightExpanded)
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    // MARK: - Generate Button
    @ViewBuilder
    private var generateButton: some View {
        VStack(spacing: 0) {
            // 漸變遮罩效果
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            Button(action: {
                Task {
                    await viewModel.generateFirstWeekPlan()
                }
            }) {
                HStack {
                    if viewModel.isGeneratingPlan {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(viewModel.mode == .preview ?
                         NSLocalizedString("onboarding.confirm_generate_first_week", comment: "確認並生成第一週計劃") :
                         NSLocalizedString("onboarding.generate_first_week", comment: "生成第一週計劃"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isGeneratingPlan || viewModel.trainingOverview == nil)
            .padding(.horizontal)
            .padding(.bottom, 20)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Helper Methods
    private func weekRangeText(_ stage: TrainingStage) -> String {
        if let weekEnd = stage.weekEnd {
            return String(format: NSLocalizedString("onboarding.week_range", comment: "Week %d-%d"), stage.weekStart, weekEnd)
        } else {
            return String(format: NSLocalizedString("onboarding.week_single", comment: "Week %d"), stage.weekStart)
        }
    }

    /// 根據階段索引返回對應的顏色
    private func stageColor(for index: Int) -> Color {
        let colors: [Color] = [
            Color(red: 0.2, green: 0.7, blue: 0.9),   // 淺藍色 - 第一階段
            Color(red: 0.4, green: 0.8, blue: 0.4),   // 綠色 - 第二階段
            Color(red: 1.0, green: 0.6, blue: 0.2),   // 橘色 - 第三階段
            Color(red: 0.9, green: 0.3, blue: 0.5),   // 粉紅色 - 第四階段
            Color(red: 0.6, green: 0.4, blue: 0.9)    // 紫色 - 第五階段
        ]
        return colors[index % colors.count]
    }
}

// MARK: - Preview
struct TrainingOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TrainingOverviewView(mode: .preview, trainingOverview: mockTrainingOverview)
        }
    }

    /// 模擬訓練總覽數據
    static var mockTrainingOverview: TrainingPlanOverview {
        TrainingPlanOverview(
            id: "mock_overview_123",
            mainRaceId: "mock_race_456",
            targetEvaluate: "根據您目前的跑步經驗和設定的目標，這是一個具有挑戰性但可達成的目標。建議在訓練過程中注意身體狀況，適度調整訓練強度。如果感到過度疲勞，請適當休息，避免受傷。保持規律的訓練和充足的恢復時間，將有助於您逐步提升跑步能力，最終達成目標。",
            totalWeeks: 12,
            trainingHighlight: "本計畫將直接進入強化期，著重於提升您的速度耐力與比賽配速適應能力。透過間歇跑、節奏跑、速度耐力提升等多元化的訓練方式，循序漸進地增強您的心肺功能與肌肉耐力。在訓練後期，我們會安排充分的減量與恢復期，讓您的身體在比賽日達到最佳狀態。",
            trainingPlanName: "半程馬拉松訓練計劃",
            trainingStageDescription: [
                TrainingStage(
                    stageName: "速度與耐力強化",
                    stageId: "stage_1",
                    stageDescription: "建立跑步基礎，提升心肺功能",
                    trainingFocus: "間歇跑、節奏跑、速度耐力提升",
                    weekStart: 1,
                    weekEnd: 4
                ),
                TrainingStage(
                    stageName: "比賽配速適應",
                    stageId: "stage_2",
                    stageDescription: "熟悉目標配速，建立比賽節奏感",
                    trainingFocus: "目標配速跑、長間歇、比賽策略模擬",
                    weekStart: 5,
                    weekEnd: 8
                ),
                TrainingStage(
                    stageName: "賽前減量與恢復",
                    stageId: "stage_3",
                    stageDescription: "降低訓練量，讓身體充分恢復",
                    trainingFocus: "輕量跑、短距離配速刺激、充分休息",
                    weekStart: 9,
                    weekEnd: 12
                )
            ],
            createdAt: "2025-01-15T10:30:00Z"
        )
    }
}
