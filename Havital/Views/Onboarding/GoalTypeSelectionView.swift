//
//  GoalTypeSelectionView.swift
//  Havital
//
//  Goal Type selection onboarding step
//  Refactored to use OnboardingFeatureViewModel (Clean Architecture)
//

import SwiftUI

// MARK: - Goal Type Enum
enum GoalType {
    case specificRace  // Has specific race goal
    case beginner5k    // Beginner, wants to run 5km first
}

// MARK: - View
struct GoalTypeSelectionView: View {
    @StateObject private var viewModel: OnboardingFeatureViewModel
    @ObservedObject private var coordinator = OnboardingCoordinator.shared

    init() {
        _viewModel = StateObject(wrappedValue: DependencyContainer.shared.makeOnboardingFeatureViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            ScrollView {
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
                    .padding(.horizontal)
                    .padding(.top, 20)

                    // Option 1: Specific race goal
                    GoalTypeCard(
                        icon: "flag.checkered",
                        title: NSLocalizedString("onboarding.goal_type_specific_race", comment: "I have a specific race goal"),
                        description: NSLocalizedString("onboarding.goal_type_specific_race_desc", comment: "Set race date, distance and target time"),
                        isSelected: viewModel.selectedGoalType == .specificRace
                    ) {
                        viewModel.selectedGoalType = .specificRace
                    }
                    .padding(.horizontal)

                    // Option 2: Beginner 5K
                    GoalTypeCard(
                        icon: "figure.run",
                        title: NSLocalizedString("onboarding.goal_type_beginner_5k", comment: "Complete my first 5km, enjoy running"),
                        description: NSLocalizedString("onboarding.goal_type_beginner_5k_desc", comment: "Training plan to help you achieve 5km goal"),
                        isSelected: viewModel.selectedGoalType == .beginner5k
                    ) {
                        viewModel.selectedGoalType = .beginner5k
                    }
                    .padding(.horizontal)

                    // Error message
                    if let error = viewModel.error {
                        Text(error)
                            .foregroundColor(.red)
                            .font(AppFont.caption())
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 100) // Leave space for bottom button
            }

            // Bottom button
            VStack(spacing: 0) {
                Divider()

                Button(action: {
                    handleNextStep()
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(NSLocalizedString("onboarding.next_step", comment: "Next Step"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.selectedGoalType == nil || viewModel.isLoading)
                .padding()
                .background(viewModel.selectedGoalType == nil ? Color.gray : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))

            Spacer()
        }
        .navigationTitle(NSLocalizedString("onboarding.goal_type_nav_title", comment: "Training Goal"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Private Methods
    private func handleNextStep() {
        guard let goalType = viewModel.selectedGoalType else { return }

        switch goalType {
        case .specificRace:
            // Navigate to detailed race setup
            coordinator.isBeginner = false
            viewModel.isBeginner = false
            coordinator.navigate(to: .raceSetup)

        case .beginner5k:
            // Create beginner 5K goal, then navigate to training days
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
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 50)

                // Text content
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

                // Selection indicator
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
