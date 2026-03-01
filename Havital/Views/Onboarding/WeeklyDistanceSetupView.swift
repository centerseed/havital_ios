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

    // Slider max value - always use maxWeeklyDistance (180km)
    private var sliderMaxDistance: Double {
        return maxWeeklyDistance
    }

    var body: some View {
        Form {
            Section(
                footer: Text(NSLocalizedString("onboarding.weekly_distance_description", comment: "Weekly Distance Description"))
            ) {
                Text(NSLocalizedString("onboarding.adjust_weekly_volume", comment: "Adjust Weekly Volume"))
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)

                VStack(alignment: .leading, spacing: 10) {
                    // Weekly distance label with stepper
                    HStack {
                        Text(String(format: NSLocalizedString("onboarding.weekly_volume_label", comment: "Weekly Volume Label"), viewModel.weeklyDistance))
                            .fontWeight(.medium)
                        Spacer()
                        Stepper("", value: $viewModel.weeklyDistance, in: minimumWeeklyDistance...sliderMaxDistance, step: 1)
                            .labelsHidden()
                    }

                    Slider(
                        value: $viewModel.weeklyDistance,
                        in: minimumWeeklyDistance...sliderMaxDistance,
                        step: 1
                    )

                    HStack {
                        Text(String(format: NSLocalizedString("onboarding.km_label", comment: "KM Label"), minimumWeeklyDistance))
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: NSLocalizedString("onboarding.km_label", comment: "KM Label"), sliderMaxDistance))
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 5)
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
