//
//  TrainingOverviewView.swift
//  Havital
//
//  Training Overview onboarding step
//  Refactored to use OnboardingFeatureViewModel (Clean Architecture)
//

import SwiftUI

// MARK: - Mode Enum
enum TrainingOverviewMode {
    case preview   // From TrainingDaysSetupView preview, needs to generate first week plan
    case final     // From TrainingDaysSetupView after plan generation
}

// MARK: - View
struct TrainingOverviewView: View {
    @StateObject private var viewModel: OnboardingFeatureViewModel
    @ObservedObject private var coordinator = OnboardingCoordinator.shared
    @Environment(\.dismiss) private var dismiss

    // UI State
    @State private var targetPace: String = "6:00"
    @State private var isTargetEvaluateExpanded = false
    @State private var isHighlightExpanded = false

    let mode: TrainingOverviewMode
    let initialOverview: TrainingPlanOverview?

    /// 判斷是否為 V2 流程
    private var isV2Flow: Bool {
        return coordinator.selectedTargetTypeId != nil
    }

    /// V2 Overview（優先從 coordinator 獲取）
    private var overviewV2: PlanOverviewV2? {
        return coordinator.trainingPlanOverviewV2 ?? viewModel.trainingOverviewV2
    }

    /// V1 Overview（優先從 coordinator 獲取）
    private var overviewV1: TrainingPlanOverview? {
        return viewModel.trainingOverview ?? coordinator.trainingPlanOverview
    }

    /// 是否有可顯示的 Overview
    private var hasOverview: Bool {
        return isV2Flow ? overviewV2 != nil : overviewV1 != nil
    }

    init(mode: TrainingOverviewMode = .final, trainingOverview: TrainingPlanOverview? = nil, isBeginner: Bool = false) {
        self.mode = mode
        self.initialOverview = trainingOverview
        _viewModel = StateObject(wrappedValue: DependencyContainer.shared.makeOnboardingFeatureViewModel())
    }

    var body: some View {
        ZStack {
            // Main content area
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isV2Flow {
                        // V2 Flow Content
                        v2ContentSection
                    } else {
                        // V1 Flow Content
                        v1ContentSection
                    }

                    // Bottom padding to avoid button overlay
                    Color.clear.frame(height: 100)
                }
                .padding()
            }

            // Bottom fixed button
            VStack {
                Spacer()
                generateButton
            }
        }
        .navigationTitle(NSLocalizedString("onboarding.training_overview_title", comment: "Training Overview"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Set isBeginner from coordinator
            viewModel.isBeginner = coordinator.isBeginner

            if isV2Flow {
                // V2 流程：Overview 已經在 TrainingDaysSetupView 中創建
                // 從 coordinator 獲取，更新 targetPace
                if let overview = overviewV2 {
                    targetPace = overview.targetPace ?? "6:00"
                    Logger.debug("[TrainingOverviewView] V2 flow: Using overview from coordinator: \(overview.id)")
                } else {
                    Logger.warn("[TrainingOverviewView] V2 flow: No overview found in coordinator")
                }
            } else {
                // V1 流程：使用原有邏輯
                if let overview = initialOverview {
                    viewModel.trainingOverview = overview
                    await loadTargetPace()
                } else {
                    await viewModel.loadTrainingOverview()
                    await loadTargetPace()
                }
            }
        }
        .fullScreenCover(isPresented: $coordinator.isCompleting) {
            LoadingAnimationView(messages: [
                NSLocalizedString("onboarding.analyzing_preferences", comment: "Analyzing your training preferences"),
                NSLocalizedString("onboarding.calculating_intensity", comment: "Calculating optimal training intensity"),
                NSLocalizedString("onboarding.almost_ready", comment: "Almost ready! Preparing your personalized schedule")
            ], totalDuration: 20)
        }
        .alert(NSLocalizedString("common.error", comment: "Error"), isPresented: .constant(coordinator.error != nil)) {
            Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) {
                coordinator.error = nil
            }
        } message: {
            if let error = coordinator.error {
                Text(error)
            }
        }
    }

    // MARK: - Load Target Pace
    private func loadTargetPace() async {
        targetPace = await viewModel.loadTargetPace()
    }

    // MARK: - V1 Content Section
    @ViewBuilder
    private var v1ContentSection: some View {
        // Summary Section
        summarySection

        // Target Evaluate (collapsible)
        if let overview = overviewV1,
           !overview.targetEvaluate.isEmpty {
            targetEvaluateSection(overview.targetEvaluate)
        }

        // Training Timeline
        if let overview = overviewV1 {
            timelineSection(overview)
        }
    }

    // MARK: - V2 Content Section
    @ViewBuilder
    private var v2ContentSection: some View {
        if let overview = overviewV2 {
            // Summary Section - V2
            summarySectionV2(overview)

            // Target Evaluate (collapsible)
            if let evaluate = overview.targetEvaluate, !evaluate.isEmpty {
                targetEvaluateSection(evaluate)
            }

            // Approach Summary (類似 V1 的 Training Highlight)
            if let summary = overview.approachSummary, !summary.isEmpty {
                approachSummarySection(summary)
            }

            // Training Timeline - V2
            timelineSectionV2(overview)
        } else {
            // Loading state
            VStack(spacing: 16) {
                ProgressView()
                Text(NSLocalizedString("common.loading", comment: "Loading..."))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Summary Section V2
    @ViewBuilder
    private func summarySectionV2(_ overview: PlanOverviewV2) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Total Weeks
            HStack {
                Label(NSLocalizedString("onboarding.total_weeks", comment: "Total Weeks"), systemImage: "calendar")
                Spacer()
                Text("\(overview.totalWeeks) \(NSLocalizedString("common.weeks", comment: "weeks"))")
                    .foregroundColor(.secondary)
            }
            .accessibilityIdentifier("TrainingOverview_WeeksLabel")

            // Target Type / Race Date
            if overview.isRaceRunTarget, let raceDate = overview.raceDateValue {
                HStack {
                    Label(NSLocalizedString("onboarding.race_date", comment: "Race Date"), systemImage: "flag.checkered")
                    Spacer()
                    Text(raceDate, style: .date)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Label(NSLocalizedString("onboarding.target_type", comment: "Target Type"), systemImage: "target")
                    Spacer()
                    Text(overview.targetDescription ?? overview.targetType)
                        .foregroundColor(.secondary)
                }
            }

            // Target Pace (if available)
            if let pace = overview.targetPace {
                HStack {
                    Label(NSLocalizedString("onboarding.target_pace", comment: "Target Pace"), systemImage: "speedometer")
                    Spacer()
                    Text(UnitManager.shared.formatPaceString(pace))
                        .foregroundColor(.secondary)
                }
            }

            // Methodology (if available)
            if let methodology = overview.methodologyOverview {
                HStack {
                    Label(NSLocalizedString("onboarding.methodology", comment: "Methodology"), systemImage: "book.closed")
                    Spacer()
                    Text(methodology.name)
                        .foregroundColor(.secondary)
                }
                .accessibilityIdentifier("TrainingOverview_MethodologyLabel")
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Approach Summary Section (V2)
    @ViewBuilder
    private func approachSummarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                Text(NSLocalizedString("onboarding.approach_summary", comment: "Training Approach"))
                    .font(AppFont.headline())
                Spacer()
                Button(action: {
                    withAnimation {
                        isHighlightExpanded.toggle()
                    }
                }) {
                    Image(systemName: isHighlightExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }

            Text(summary)
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)
                .lineLimit(isHighlightExpanded ? nil : 3)
                .animation(.easeInOut, value: isHighlightExpanded)
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.orange.opacity(0.1), Color.yellow.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    // MARK: - Timeline Section V2
    @ViewBuilder
    private func timelineSectionV2(_ overview: PlanOverviewV2) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("onboarding.training_timeline", comment: "Training Timeline"))
                .font(AppFont.headline())
                .padding(.bottom, 16)

            // Stage cards - V2
            ForEach(Array(overview.trainingStages.enumerated()), id: \.offset) { index, stage in
                stageCardV2(
                    stage,
                    stageIndex: index,
                    isLast: index == overview.trainingStages.count - 1,
                    nextStageColor: index < overview.trainingStages.count - 1 ? stageColor(for: index + 1) : nil
                )
            }
        }
    }

    // MARK: - Stage Card V2
    @ViewBuilder
    private func stageCardV2(_ stage: TrainingStageV2, stageIndex: Int, isLast: Bool, nextStageColor: Color?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Left timeline (circle + connection line)
            ZStack(alignment: .top) {
                // Dashed connection line (behind the circle, fills full height)
                if !isLast, let nextColor = nextStageColor {
                    VStack(spacing: 0) {
                        // Offset to start below circle center
                        Color.clear.frame(height: 10)
                        DashedTimelineLine(color: nextColor)
                    }
                }

                // Circle on top
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

            // Right content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(stage.stageName)
                        .font(AppFont.headline())
                    Spacer()
                    Text(weekRangeTextV2(stage))
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)
                }

                // Weekly distance range
                Text({
                    if let display = stage.targetWeeklyKmRangeDisplay {
                        return "\(Int(display.lowDisplay))-\(Int(display.highDisplay)) \(display.distanceUnit)/\(NSLocalizedString("common.week_unit", comment: "week"))"
                    } else {
                        return "\(Int(stage.targetWeeklyKmRange.low))-\(Int(stage.targetWeeklyKmRange.high)) km/\(NSLocalizedString("common.week_unit", comment: "week"))"
                    }
                }())
                    .font(AppFont.bodySmall())
                    .fontWeight(.semibold)
                    .foregroundColor(stageColor(for: stageIndex))

                // Training Focus (brief)
                if !stage.trainingFocus.isEmpty {
                    Text(stage.trainingFocus)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }

                // Stage Description (detailed)
                if !stage.stageDescription.isEmpty {
                    Text(stage.stageDescription)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding(.bottom, isLast ? 0 : 0)
    }

    // MARK: - Helper for V2 Week Range
    private func weekRangeTextV2(_ stage: TrainingStageV2) -> String {
        if stage.weekStart == stage.weekEnd {
            return String(format: NSLocalizedString("onboarding.week_single", comment: "Week %d"), stage.weekStart)
        } else {
            return String(format: NSLocalizedString("onboarding.week_range", comment: "Week %d-%d"), stage.weekStart, stage.weekEnd)
        }
    }

    // MARK: - Summary Section (V1)
    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let overview = overviewV1 {
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
                Text(Date(), style: .date)
                    .foregroundColor(.secondary)
            }

            HStack {
                Label(NSLocalizedString("onboarding.target_pace", comment: "Target Pace"), systemImage: "speedometer")
                Spacer()
                Text("\(targetPace) /km")
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
                    .font(AppFont.headline())
                Spacer()
                Button(action: {
                    withAnimation {
                        isTargetEvaluateExpanded.toggle()
                    }
                }) {
                    Image(systemName: isTargetEvaluateExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }

            Text(text)
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)
                .lineLimit(isTargetEvaluateExpanded ? nil : 2)
                .animation(.easeInOut, value: isTargetEvaluateExpanded)
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
                .font(AppFont.headline())
                .padding(.bottom, 16)

            // Training Highlight card (at top)
            if !overview.trainingHighlight.isEmpty {
                highlightCard(overview.trainingHighlight)
                    .padding(.bottom, 16)
            }

            // Stage cards
            ForEach(Array(overview.trainingStageDescription.enumerated()), id: \.offset) { index, stage in
                stageCard(
                    stage,
                    targetPace: stage.targetPace ?? targetPace,
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
            // Left timeline (circle + connection line)
            ZStack(alignment: .top) {
                // Dashed connection line (behind the circle, fills full height)
                if !isLast, let nextColor = nextStageColor {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 10)
                        DashedTimelineLine(color: nextColor)
                    }
                }

                // Circle on top
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

            // Right content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(stage.stageName)
                        .font(AppFont.headline())
                    Spacer()
                    Text(weekRangeText(stage))
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)
                }

                Text(targetPace)
                    .font(AppFont.bodySmall())
                    .fontWeight(.semibold)
                    .foregroundColor(stageColor(for: stageIndex))

                if !stage.trainingFocus.isEmpty {
                    Text(stage.trainingFocus)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.bottom, isLast ? 0 : 0)
    }

    // MARK: - Highlight Card
    @ViewBuilder
    private func highlightCard(_ highlight: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text(NSLocalizedString("onboarding.training_highlight", comment: "Training Highlight"))
                    .font(AppFont.headline())
                Spacer()
                Button(action: {
                    withAnimation {
                        isHighlightExpanded.toggle()
                    }
                }) {
                    Image(systemName: isHighlightExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }

            Text(highlight)
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)
                .lineLimit(isHighlightExpanded ? nil : 2)
                .animation(.easeInOut, value: isHighlightExpanded)
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
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            Button(action: {
                Task {
                    await coordinator.completeOnboarding()
                }
            }) {
                Text(mode == .preview
                    ? NSLocalizedString("onboarding.confirm_generate_first_week", comment: "Confirm and generate first week plan")
                    : NSLocalizedString("onboarding.generate_first_week", comment: "Generate first week plan"))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(coordinator.isCompleting || !hasOverview)
            .accessibilityIdentifier("TrainingOverview_GenerateButton")
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

    private func stageColor(for index: Int) -> Color {
        let colors: [Color] = [
            Color(red: 0.2, green: 0.7, blue: 0.9),
            Color(red: 0.4, green: 0.8, blue: 0.4),
            Color(red: 1.0, green: 0.6, blue: 0.2),
            Color(red: 0.9, green: 0.3, blue: 0.5),
            Color(red: 0.6, green: 0.4, blue: 0.9)
        ]
        return colors[index % colors.count]
    }
}

// MARK: - Dashed Timeline Line
/// A dashed vertical line with an arrow at the bottom, fills available height
private struct DashedTimelineLine: View {
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            let arrowHeight: CGFloat = 10
            let lineHeight = max(0, totalHeight - arrowHeight)

            VStack(spacing: 0) {
                // Dashed line
                Path { path in
                    path.move(to: CGPoint(x: 1.5, y: 0))
                    path.addLine(to: CGPoint(x: 1.5, y: lineHeight))
                }
                .stroke(color.opacity(0.6), style: StrokeStyle(lineWidth: 3, dash: [6, 3]))
                .frame(width: 3, height: lineHeight)

                // Arrow
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 8))
                    .foregroundColor(color.opacity(0.6))
                    .frame(height: arrowHeight)
            }
        }
        .frame(width: 3)
    }
}

// MARK: - Preview
struct TrainingOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TrainingOverviewView(mode: .preview, trainingOverview: mockTrainingOverview)
        }
    }

    static var mockTrainingOverview: TrainingPlanOverview {
        TrainingPlanOverview(
            id: "mock_overview_123",
            mainRaceId: "mock_race_456",
            targetEvaluate: "Based on your running experience and set goals, this is a challenging but achievable target.",
            totalWeeks: 12,
            trainingHighlight: "This plan will focus on enhancing your speed endurance and race pace adaptation.",
            trainingPlanName: "Half Marathon Training Plan",
            trainingStageDescription: [
                TrainingStage(
                    stageName: "Speed & Endurance",
                    stageId: "stage_1",
                    stageDescription: "Build running base, improve cardio",
                    trainingFocus: "Interval runs, tempo runs, speed endurance",
                    weekStart: 1,
                    weekEnd: 4,
                    targetPace: "5:40-6:00/km"
                ),
                TrainingStage(
                    stageName: "Race Pace Adaptation",
                    stageId: "stage_2",
                    stageDescription: "Familiarize with target pace",
                    trainingFocus: "Target pace runs, long intervals",
                    weekStart: 5,
                    weekEnd: 8,
                    targetPace: "5:25-5:40/km"
                ),
                TrainingStage(
                    stageName: "Taper & Recovery",
                    stageId: "stage_3",
                    stageDescription: "Reduce training load for recovery",
                    trainingFocus: "Easy runs, short pace stimulation",
                    weekStart: 9,
                    weekEnd: 12,
                    targetPace: "6:00-6:30/km"
                )
            ],
            createdAt: "2025-01-15T10:30:00Z"
        )
    }
}
