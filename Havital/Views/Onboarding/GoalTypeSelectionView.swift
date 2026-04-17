//
//  GoalTypeSelectionView.swift
//  Havital
//
//  Goal Type selection onboarding step
//  Refactored to use shared OnboardingFeatureViewModel via @EnvironmentObject
//

import SwiftUI

// MARK: - Goal Type Enum
enum GoalType: Equatable {
    case v2(TargetTypeV2)
    case specificRace
    case beginner5k

    static func == (lhs: GoalType, rhs: GoalType) -> Bool {
        switch (lhs, rhs) {
        case (.v2(let lhsType), .v2(let rhsType)):
            return lhsType.id == rhsType.id
        case (.specificRace, .specificRace):
            return true
        case (.beginner5k, .beginner5k):
            return true
        default:
            return false
        }
    }
}

// MARK: - View
struct GoalTypeSelectionView: View {
    @EnvironmentObject private var viewModel: OnboardingFeatureViewModel
    @ObservedObject private var coordinator = OnboardingCoordinator.shared

    var body: some View {
        let _ = Logger.debug("🎯 [GoalTypeSelectionView] body rendered - isLoading: \(viewModel.isLoadingTargetTypes), targetTypes: \(viewModel.availableTargetTypes.count), error: \(viewModel.error ?? "none")")

        OnboardingPageTemplate(
            ctaTitle: NSLocalizedString("onboarding.next_step", comment: "Next Step"),
            ctaEnabled: viewModel.selectedGoalType != nil && !viewModel.isLoading,
            isLoading: viewModel.isLoading,
            skipTitle: nil,
            ctaAccessibilityId: "GoalType_NextButton",
            ctaAction: {
                handleNextStep()
            },
            skipAction: nil
        ) {
            VStack(spacing: 24) {
                // Title and description
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("onboarding.goal_type_title", comment: "Choose your training goal"))
                        .font(AppFont.title2())
                        .fontWeight(.bold)

                    Text(NSLocalizedString("onboarding.goal_type_description", comment: "We'll create a suitable training plan based on your experience and goals"))
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // Loading indicator
                if viewModel.isLoadingTargetTypes {
                    ProgressView()
                        .padding()
                } else if !viewModel.availableTargetTypes.isEmpty {
                    // V2 Dynamic Goal Type Cards
                    ForEach(viewModel.availableTargetTypes) { targetType in
                        GoalTypeCard(
                            icon: iconForTargetType(targetType),
                            title: targetType.name,
                            description: targetType.description,
                            isSelected: viewModel.selectedGoalType == .v2(targetType)
                        ) {
                            viewModel.selectedGoalType = .v2(targetType)
                        }
                        .accessibilityIdentifier("GoalType_\(targetType.id)")
                    }
                } else {
                    // Fallback: V1 Legacy Options
                    GoalTypeCard(
                        icon: "flag.checkered",
                        title: NSLocalizedString("onboarding.goal_type_specific_race", comment: "I have a specific race goal"),
                        description: NSLocalizedString("onboarding.goal_type_specific_race_desc", comment: "Set race date, distance and target time"),
                        isSelected: viewModel.selectedGoalType == .specificRace
                    ) {
                        viewModel.selectedGoalType = .specificRace
                    }
                    .accessibilityIdentifier("GoalType_race_run")

                    GoalTypeCard(
                        icon: "figure.run",
                        title: NSLocalizedString("onboarding.goal_type_beginner_5k", comment: "Complete my first 5km, enjoy running"),
                        description: NSLocalizedString("onboarding.goal_type_beginner_5k_desc", comment: "Training plan to help you achieve 5km goal"),
                        isSelected: viewModel.selectedGoalType == .beginner5k
                    ) {
                        viewModel.selectedGoalType = .beginner5k
                    }
                    .accessibilityIdentifier("GoalType_beginner")
                }

                // Error message
                if let error = viewModel.error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(AppFont.caption())
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("GoalType_Screen")
        .navigationTitle(NSLocalizedString("onboarding.goal_type_nav_title", comment: "Training Goal"))
        .onAppear {
            Logger.info("🎯 [GoalTypeSelectionView] onAppear triggered - loading V2 target types")
            Task {
                await viewModel.loadTargetTypes()
            }
        }
    }

    // MARK: - Private Methods

    private func iconForTargetType(_ targetType: TargetTypeV2) -> String {
        switch targetType.id {
        case "race_run":
            return "flag.checkered"
        case "beginner":
            return "figure.run"
        case "maintenance":
            return "heart.circle"
        default:
            return "target"
        }
    }

    private func handleNextStep() {
        guard let goalType = viewModel.selectedGoalType else { return }

        switch goalType {
        case .v2(let targetType):
            coordinator.selectedTargetTypeId = targetType.id

            if targetType.isRaceRunTarget {
                coordinator.isBeginner = false
                viewModel.isBeginner = false
                viewModel.selectedTargetTypeV2 = targetType
                coordinator.navigate(to: .raceSetup)
            } else {
                coordinator.isBeginner = targetType.isBeginnerTarget
                viewModel.isBeginner = targetType.isBeginnerTarget
                viewModel.selectedTargetTypeV2 = targetType
                viewModel.trackTargetSetForNonRace(targetType: targetType)

                Task {
                    await viewModel.loadMethodologiesForTargetType(targetType.id)

                    await MainActor.run {
                        if viewModel.availableMethodologies.count > 1 {
                            Logger.debug("[GoalTypeSelectionView] Multiple methodologies available (\(viewModel.availableMethodologies.count)), navigating to methodology selection")
                            coordinator.navigate(to: .methodologySelection)
                        } else {
                            Logger.debug("[GoalTypeSelectionView] Single or no methodology, navigating to training weeks setup")
                            coordinator.navigate(to: .trainingWeeksSetup)
                        }
                    }
                }
            }

        case .specificRace:
            coordinator.isBeginner = false
            viewModel.isBeginner = false
            coordinator.navigate(to: .raceSetup)

        case .beginner5k:
            Task {
                let success = await viewModel.createBeginner5kGoal()
                if success {
                    coordinator.isBeginner = true
                    coordinator.navigate(to: .trainingDays)
                }
            }
        }
    }
}

// MARK: - Goal Type Card Component
struct GoalTypeCard: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(AppFont.systemScaled(size: 32))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(AppFont.headline())
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    Text(description)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(AppFont.title2())
                    .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.3))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color(.systemGray3), lineWidth: isSelected ? 2.5 : 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct GoalTypeSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GoalTypeSelectionView()
        }
    }
}
