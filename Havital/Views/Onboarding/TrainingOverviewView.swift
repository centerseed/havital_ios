import SwiftUI

// MARK: - ViewModel
@MainActor
class TrainingOverviewViewModel: ObservableObject {
    @Published var trainingOverview: TrainingPlanOverview?
    @Published var targetPace: String = "6:00"
    @Published var raceDate: Date = Date()
    @Published var isLoading = false
    @Published var error: String?
    @Published var isTargetEvaluateExpanded = false
    @Published var isGeneratingPlan = false
    @Published var navigateToMainApp = false

    func loadTrainingOverview() async {
        isLoading = true
        error = nil

        do {
            // 獲取訓練總覽
            let overview = try await TrainingPlanService.shared.getTrainingOverview()

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
            // 調用生成第一週計劃的 API
            // TODO: 實現 API 調用
            try await Task.sleep(nanoseconds: 1_000_000_000) // 模擬延遲

            await MainActor.run {
                self.isGeneratingPlan = false
                self.navigateToMainApp = true
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
    @StateObject private var viewModel = TrainingOverviewViewModel()
    @Environment(\.dismiss) private var dismiss

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

            // 階段卡片
            ForEach(Array(overview.trainingStageDescription.enumerated()), id: \.offset) { index, stage in
                VStack(spacing: 0) {
                    // 階段卡片
                    stageCard(stage, targetPace: viewModel.targetPace)

                    // 虛線箭頭連接（除了最後一個階段）
                    if index < overview.trainingStageDescription.count - 1 {
                        dashedArrow
                    }
                }
            }

            // Training Highlight 卡片
            if !overview.trainingHighlight.isEmpty {
                VStack(spacing: 0) {
                    dashedArrow
                    highlightCard(overview.trainingHighlight)
                }
            }
        }
    }

    // MARK: - Stage Card
    @ViewBuilder
    private func stageCard(_ stage: TrainingStage, targetPace: String) -> some View {
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
                    .foregroundColor(.accentColor)
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
                            .foregroundColor(.accentColor)
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

    // MARK: - Highlight Card
    @ViewBuilder
    private func highlightCard(_ highlight: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text(NSLocalizedString("onboarding.training_highlight", comment: "Training Highlight"))
                    .font(.headline)
            }

            Text(highlight)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Dashed Arrow
    @ViewBuilder
    private var dashedArrow: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                ForEach(0..<3) { _ in
                    Rectangle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 2, height: 8)
                }
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
            }
            Spacer()
        }
        .frame(height: 30)
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
                    Text(NSLocalizedString("onboarding.generate_first_week", comment: "Generate First Week Plan"))
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
}

// MARK: - Preview
struct TrainingOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TrainingOverviewView()
        }
    }
}
