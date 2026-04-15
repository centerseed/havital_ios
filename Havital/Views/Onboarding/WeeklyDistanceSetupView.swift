//
//  WeeklyDistanceSetupView.swift
//  Havital
//
//  Weekly Distance onboarding step
//  Refactored to use OnboardingFeatureViewModel (Clean Architecture)
//

import SwiftUI

struct WeeklyDistanceSetupView: View {
    @StateObject private var viewModel: OnboardingFeatureViewModel
    @ObservedObject private var coordinator = OnboardingCoordinator.shared

    let targetDistance: Double?

    // Constants
    private let defaultMaxWeeklyDistanceCap = 30.0
    private let minimumWeeklyDistance = 0.0
    private let maxWeeklyDistance = 180.0

    init(targetDistance: Double? = nil) {
        self.targetDistance = targetDistance
        _viewModel = StateObject(wrappedValue: DependencyContainer.shared.makeOnboardingFeatureViewModel())
    }

    // Quick-select preset distances
    private let presetDistances: [Double] = [10, 20, 30, 40, 50, 60]

    var body: some View {
        Form {
            Section {
                Text(NSLocalizedString("onboarding.adjust_weekly_volume", comment: "Adjust Weekly Volume"))
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)

                // Large current value display
                Text(String(format: "%.0f km", viewModel.weeklyDistance))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("WeeklyDistance_Display")
            }

            // Quick-select preset buttons
            Section(header: Text(NSLocalizedString("onboarding.quick_select_label", comment: "Quick Select"))) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(presetDistances, id: \.self) { distance in
                        Button(action: {
                            viewModel.weeklyDistance = distance
                        }) {
                            Text(String(format: "%.0f km", distance))
                                .font(AppFont.bodySmall())
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    viewModel.weeklyDistance == distance
                                        ? Color.accentColor
                                        : Color(.systemGray5)
                                )
                                .foregroundColor(
                                    viewModel.weeklyDistance == distance
                                        ? .white
                                        : .primary
                                )
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("WeeklyDistance_Preset_\(Int(distance))")
                    }
                }
                .padding(.vertical, 4)
            }

            // Fine-tune with stepper
            Section(footer: Text(NSLocalizedString("onboarding.weekly_distance_description", comment: "Weekly Distance Description"))) {
                HStack {
                    Text(NSLocalizedString("onboarding.fine_tune_label", comment: "Fine Tune"))
                        .font(AppFont.bodySmall())
                    Spacer()
                    Stepper("", value: $viewModel.weeklyDistance, in: minimumWeeklyDistance...maxWeeklyDistance, step: 1)
                        .labelsHidden()
                        .accessibilityIdentifier("WeeklyDistance_Stepper")
                }
            }

            if let error = viewModel.error {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(NSLocalizedString("onboarding.weekly_distance_title", comment: "Weekly Distance Title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Skip button
                Button(NSLocalizedString("onboarding.skip", comment: "Skip")) {
                    Task {
                        viewModel.weeklyDistance = 0
                        let success = await viewModel.saveWeeklyDistance()
                        if success {
                            navigateToNextStep()
                        }
                    }
                }
                .disabled(viewModel.isLoading)

                // Next button or loading indicator
                if viewModel.isLoading || viewModel.isLoadingWeeklyHistory {
                    ProgressView()
                        .padding(.leading, 5)
                } else {
                    Button(action: {
                        Task {
                            let success = await viewModel.saveWeeklyDistance()
                            if success {
                                navigateToNextStep()
                            }
                        }
                    }) {
                        Text(NSLocalizedString("onboarding.next_step", comment: "Next Step"))
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityIdentifier("WeeklyDistance_ContinueButton")
                }
            }
        }
        .background(EmptyView())
        .onAppear {
            // Always reset to default 10km on appear
            viewModel.weeklyDistance = 10.0

            // Set target distance if available (for future use)
            if let targetDistance = targetDistance {
                viewModel.targetDistance = targetDistance
            }

            // Load historical weekly distance (for logging only, doesn't override default)
            Task {
                await viewModel.loadHistoricalWeeklyDistance()
            }
        }
    }

    // MARK: - Navigation

    private func navigateToNextStep() {
        // V2 Flow: Always go to Goal Type first (both onboarding and re-onboarding)
        // User can choose race_run, beginner, or maintenance target types
        let nextStep = viewModel.determineNextStepAfterWeeklyDistance()
        coordinator.navigate(to: nextStep)
    }
}

struct WeeklyDistanceSetupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WeeklyDistanceSetupView(targetDistance: 21.0975)
        }
        NavigationView {
            WeeklyDistanceSetupView(targetDistance: 5)
        }
        NavigationView {
            WeeklyDistanceSetupView(targetDistance: nil)
        }
    }
}
