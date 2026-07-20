//
//  WeeklyDistanceSetupView.swift
//  Havital
//
//  Weekly Distance onboarding step
//  Refactored to use shared OnboardingFeatureViewModel via @EnvironmentObject
//

import SwiftUI

struct WeeklyDistanceSetupView: View {
    @EnvironmentObject private var viewModel: OnboardingFeatureViewModel
    @ObservedObject private var coordinator = OnboardingCoordinator.shared

    let targetDistance: Double?

    private let minimumWeeklyDistance = 0.0
    private let maxWeeklyDistance = 180.0
    private let stepperStep = 5.0

    private let presetDistances: [Double] = [10, 20, 30, 50, 70, 100]

    var body: some View {
        OnboardingPageTemplate(
            ctaTitle: NSLocalizedString("onboarding.next_step", comment: "Next Step"),
            ctaEnabled: !viewModel.isLoading && !viewModel.isLoadingWeeklyHistory,
            isLoading: viewModel.isLoading || viewModel.isLoadingWeeklyHistory,
            skipTitle: nil,
            ctaAccessibilityId: "WeeklyDistance_ContinueButton",
            ctaAction: {
                Task {
                    let success = await viewModel.saveWeeklyDistance()
                    if success {
                        navigateToNextStep()
                    }
                }
            },
            skipAction: nil
        ) {
            VStack(alignment: .leading, spacing: OnboardingLayout.sectionSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("onboarding.adjust_weekly_volume", comment: "Adjust Weekly Volume"))
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)

                    Text(String(format: "%.0f km", viewModel.weeklyDistance))
                        .font(AppFont.systemScaled(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                        .accessibilityIdentifier("WeeklyDistance_Display")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("onboarding.quick_select_label", comment: "Quick Select"))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

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

                VStack(alignment: .leading, spacing: 12) {
                    Slider(
                        value: Binding(
                            get: { viewModel.weeklyDistance },
                            set: { viewModel.weeklyDistance = ($0 / stepperStep).rounded() * stepperStep }
                        ),
                        in: minimumWeeklyDistance...maxWeeklyDistance,
                        step: stepperStep
                    )
                    .accessibilityIdentifier("WeeklyDistance_Slider")

                    HStack {
                        Text(NSLocalizedString("onboarding.fine_tune_label", comment: "Fine Tune"))
                            .font(AppFont.bodySmall())
                        Spacer()
                        Stepper("", value: $viewModel.weeklyDistance, in: minimumWeeklyDistance...maxWeeklyDistance, step: stepperStep)
                            .labelsHidden()
                            .accessibilityIdentifier("WeeklyDistance_Stepper")
                    }

                    Text(NSLocalizedString("onboarding.weekly_distance_description", comment: "Weekly Distance Description"))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.accentColor)
                            .padding(.top, 1)
                        Text(NSLocalizedString("onboarding.weekly_distance_anchor_explain", comment: "Plan uses this as key reference"))
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if coordinator.selectedTargetTypeId == "maintenance" {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.accentColor)
                                .padding(.top, 1)
                            Text(NSLocalizedString("onboarding.weekly_distance_maintenance_note", comment: "Maintenance volume note"))
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.08))
                )
                .accessibilityIdentifier("WeeklyDistance_AnchorExplain")

                if let error = viewModel.error {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .accessibilityIdentifier("WeeklyDistance_Screen")
        .navigationTitle(NSLocalizedString("onboarding.weekly_distance_title", comment: "Weekly Distance Title"))
        .onAppear {
            viewModel.weeklyDistance = 10.0

            if let targetDistance = targetDistance {
                viewModel.targetDistance = targetDistance
            }

            Task {
                await viewModel.loadHistoricalWeeklyDistance()
            }
        }
    }

    // MARK: - Navigation

    private func navigateToNextStep() {
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
