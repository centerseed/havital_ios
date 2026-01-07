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
                    // Summary Section
                    summarySection

                    // Target Evaluate (collapsible)
                    if let overview = viewModel.trainingOverview,
                       !overview.targetEvaluate.isEmpty {
                        targetEvaluateSection(overview.targetEvaluate)
                    }

                    // Training Timeline
                    if let overview = viewModel.trainingOverview {
                        timelineSection(overview)
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

            // Use initial overview if provided, otherwise load from repository
            if let overview = initialOverview {
                viewModel.trainingOverview = overview
                await loadTargetPace()
            } else {
                await viewModel.loadTrainingOverview()
                await loadTargetPace()
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

    // MARK: - Summary Section
    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    .font(.headline)
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
                .font(.subheadline)
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
                .font(.headline)
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
            VStack(spacing: 0) {
                Circle()
                    .fill(stageColor(for: stageIndex))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(color: stageColor(for: stageIndex).opacity(0.3), radius: 4, x: 0, y: 2)

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

            // Right content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(stage.stageName)
                        .font(.headline)
                    Spacer()
                    Text(weekRangeText(stage))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text(targetPace)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(stageColor(for: stageIndex))

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
                        isHighlightExpanded.toggle()
                    }
                }) {
                    Image(systemName: isHighlightExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }

            Text(highlight)
                .font(.subheadline)
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
            .disabled(coordinator.isCompleting || viewModel.trainingOverview == nil)
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
