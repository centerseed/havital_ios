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
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("onboarding.training_timeline", comment: "Training Timeline"))
                .font(.headline)

            // Training Highlight 卡片（移到最上方）
            if !overview.trainingHighlight.isEmpty {
                highlightCard(overview.trainingHighlight)
            }

            // 階段卡片
            ForEach(Array(overview.trainingStageDescription.enumerated()), id: \.offset) { index, stage in
                VStack(spacing: 0) {
                    // 階段卡片
                    stageCard(stage, targetPace: viewModel.targetPace, stageIndex: index)

                    // 時間軸連接線（除了最後一個階段）
                    if index < overview.trainingStageDescription.count - 1 {
                        timelineConnector(color: stageColor(for: index))
                    }
                }
            }
        }
    }

    // MARK: - Stage Card
    @ViewBuilder
    private func stageCard(_ stage: TrainingStage, targetPace: String, stageIndex: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 左側時間軸圓點
            VStack(spacing: 0) {
                Circle()
                    .fill(stageColor(for: stageIndex))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(color: stageColor(for: stageIndex).opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .frame(width: 20)

            // 右側內容卡片
            VStack(alignment: .leading, spacing: 8) {
                // 階段名稱 + 週數範圍（同一行）
                HStack {
                    Text(stage.stageName)
                        .font(.headline)
                    Spacer()
                    Text(weekRangeText(stage))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Target Pace
                HStack {
                    Image(systemName: "speedometer")
                        .foregroundColor(stageColor(for: stageIndex))
                        .font(.caption)
                    Text(NSLocalizedString("onboarding.target_pace", comment: "Target Pace"))
                        .font(.subheadline)
                    Spacer()
                    Text("\(targetPace) /km")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Training Focus
                if !stage.trainingFocus.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "target")
                                .foregroundColor(stageColor(for: stageIndex))
                                .font(.caption)
                            Text(NSLocalizedString("onboarding.training_focus", comment: "Training Focus"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Text(stage.trainingFocus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
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

    // MARK: - Timeline Connector
    @ViewBuilder
    private func timelineConnector(color: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // 左側連接線（對齊圓點中心）
            VStack(spacing: 2) {
                ForEach(0..<5) { _ in
                    Rectangle()
                        .fill(color.opacity(0.6))
                        .frame(width: 3, height: 6)
                }
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 10))
                    .foregroundColor(color.opacity(0.6))
            }
            .frame(width: 20)

            Spacer()
        }
        .frame(height: 40)
        .padding(.leading, 0)
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
            TrainingOverviewView()
        }
    }
}
