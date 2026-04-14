//
//  GoalTypeSelectionView.swift
//  Havital
//
//  Goal Type selection onboarding step
//  Refactored to use OnboardingFeatureViewModel (Clean Architecture)
//

import SwiftUI

// MARK: - Goal Type Enum
enum GoalType: Equatable {
    case v2(TargetTypeV2)  // V2 dynamic target types from API
    case specificRace      // V1 legacy: Has specific race goal
    case beginner5k        // V1 legacy: Beginner, wants to run 5km first

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
    @StateObject private var viewModel: OnboardingFeatureViewModel
    @ObservedObject private var coordinator = OnboardingCoordinator.shared

    init() {
        _viewModel = StateObject(wrappedValue: DependencyContainer.shared.makeOnboardingFeatureViewModel())
        Logger.info("🎯 [GoalTypeSelectionView] Initialized")
    }

    var body: some View {
        let _ = Logger.debug("🎯 [GoalTypeSelectionView] body rendered - isLoading: \(viewModel.isLoadingTargetTypes), targetTypes: \(viewModel.availableTargetTypes.count), error: \(viewModel.error ?? "none")")

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
                            .padding(.horizontal)
                        }
                    } else {
                        // Fallback: V1 Legacy Options (如果 API 載入失敗或返回空)
                        GoalTypeCard(
                            icon: "flag.checkered",
                            title: NSLocalizedString("onboarding.goal_type_specific_race", comment: "I have a specific race goal"),
                            description: NSLocalizedString("onboarding.goal_type_specific_race_desc", comment: "Set race date, distance and target time"),
                            isSelected: viewModel.selectedGoalType == .specificRace
                        ) {
                            viewModel.selectedGoalType = .specificRace
                        }
                        .accessibilityIdentifier("GoalType_race_run")
                        .padding(.horizontal)

                        GoalTypeCard(
                            icon: "figure.run",
                            title: NSLocalizedString("onboarding.goal_type_beginner_5k", comment: "Complete my first 5km, enjoy running"),
                            description: NSLocalizedString("onboarding.goal_type_beginner_5k_desc", comment: "Training plan to help you achieve 5km goal"),
                            isSelected: viewModel.selectedGoalType == .beginner5k
                        ) {
                            viewModel.selectedGoalType = .beginner5k
                        }
                        .accessibilityIdentifier("GoalType_beginner")
                        .padding(.horizontal)
                    }

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
                .accessibilityIdentifier("GoalType_NextButton")
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
        .onAppear {
            Logger.info("🎯 [GoalTypeSelectionView] onAppear triggered - loading V2 target types")
            // Load V2 target types on view appear
            Task {
                await viewModel.loadTargetTypes()
            }
        }
    }

    // MARK: - Private Methods

    /// Get icon for target type
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
            // V2 flow: handle different target types
            // ⭐ 統一設定 coordinator 的 selectedTargetTypeId（供 MethodologySelectionView 使用）
            coordinator.selectedTargetTypeId = targetType.id

            if targetType.isRaceRunTarget {
                // Race run: navigate to race setup
                coordinator.isBeginner = false
                viewModel.isBeginner = false
                viewModel.selectedTargetTypeV2 = targetType
                coordinator.navigate(to: .raceSetup)
            } else {
                // Non-race (beginner/maintenance)
                coordinator.isBeginner = targetType.isBeginnerTarget
                viewModel.isBeginner = targetType.isBeginnerTarget
                viewModel.selectedTargetTypeV2 = targetType

                // ⭐ V2 流程：先檢查方法論數量，再決定流程
                // 如果有多個方法論 → 先選方法論 → 選週數 → 訓練日
                // 如果單一/無方法論 → 直接選週數 → 訓練日
                Task {
                    await viewModel.loadMethodologiesForTargetType(targetType.id)

                    await MainActor.run {
                        if viewModel.availableMethodologies.count > 1 {
                            // 多個方法論：先讓用戶選擇方法論
                            Logger.debug("[GoalTypeSelectionView] Multiple methodologies available (\(viewModel.availableMethodologies.count)), navigating to methodology selection")
                            coordinator.navigate(to: .methodologySelection)
                        } else {
                            // 單一或無方法論：直接到訓練週數選擇
                            Logger.debug("[GoalTypeSelectionView] Single or no methodology, navigating to training weeks setup")
                            coordinator.navigate(to: .trainingWeeksSetup)
                        }
                    }
                }
            }

        case .specificRace:
            // V1 legacy: Navigate to detailed race setup
            coordinator.isBeginner = false
            viewModel.isBeginner = false
            coordinator.navigate(to: .raceSetup)

        case .beginner5k:
            // V1 legacy: Create beginner 5K goal, then navigate to training days
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
