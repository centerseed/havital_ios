//
//  TrainingDaysSetupView.swift
//  Havital
//
//  Training Days selection onboarding step
//  Refactored to use shared OnboardingFeatureViewModel via @EnvironmentObject
//

import SwiftUI

struct TrainingDaysSetupView: View {
    @EnvironmentObject private var viewModel: OnboardingFeatureViewModel
    @ObservedObject private var coordinator = OnboardingCoordinator.shared

    let isBeginner: Bool
    private let recommendedMinTrainingDays = 2
    private let longRunGridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private let previewLoadingMessages = [
        NSLocalizedString("onboarding.evaluating_goal", comment: "Evaluating Goal"),
        NSLocalizedString("onboarding.calculating_training_intensity", comment: "Calculating Training Intensity"),
        NSLocalizedString("onboarding.generating_overview", comment: "Generating Overview")
    ]
    private let previewLoadingDuration: Double = 15

    private var canSavePreferences: Bool {
        let hasEnoughDays = viewModel.selectedWeekdays.count >= recommendedMinTrainingDays
        let isLongRunDayValid = viewModel.selectedWeekdays.contains(viewModel.selectedLongRunDay) || viewModel.selectedWeekdays.isEmpty
        return hasEnoughDays && isLongRunDayValid
    }

    private var longRunOptions: [Int] {
        Array(viewModel.selectedWeekdays).sorted()
    }

    private var recommendedLongRunDay: Int? {
        if longRunOptions.contains(6) { return 6 }
        if longRunOptions.contains(7) { return 7 }
        return longRunOptions.first
    }

    private var hasWeekendOption: Bool {
        longRunOptions.contains(6) || longRunOptions.contains(7)
    }

    var body: some View {
        OnboardingPageTemplate(
            ctaTitle: NSLocalizedString("onboarding.save_preferences_preview", comment: "Save Preferences Preview"),
            ctaEnabled: !viewModel.isLoading && canSavePreferences,
            isLoading: viewModel.isLoading,
            skipTitle: nil,
            ctaAccessibilityId: "TrainingDays_SaveButton",
            ctaAction: {
                saveAndNavigate()
            },
            skipAction: nil
        ) {
            VStack(alignment: .leading, spacing: OnboardingLayout.sectionSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("onboarding.select_training_days", comment: "Select Training Days"))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    VStack(spacing: 0) {
                        ForEach(1..<8, id: \.self) { weekday in
                            Button(action: {
                                if viewModel.selectedWeekdays.contains(weekday) {
                                    viewModel.selectedWeekdays.remove(weekday)
                                } else {
                                    viewModel.selectedWeekdays.insert(weekday)
                                }
                            }) {
                                HStack {
                                    Text(getWeekdayName(weekday))
                                    Spacer()
                                    if viewModel.selectedWeekdays.contains(weekday) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 4)
                            }
                            .foregroundColor(.primary)
                            .accessibilityIdentifier("TrainingDay_\(weekday)")

                            if weekday < 7 {
                                Divider()
                            }
                        }
                    }

                    Text(String(format: NSLocalizedString("onboarding.training_days_description", comment: "Training Days Description"), recommendedMinTrainingDays))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(isBeginner
                        ? NSLocalizedString("onboarding.setup_long_run_day_beginner", comment: "Select a day for slightly longer run")
                        : NSLocalizedString("onboarding.setup_long_run_day", comment: "Select long run day"))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    if longRunOptions.isEmpty {
                        longRunEmptyState
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.shared.accentColor)

                            Text(currentLongRunSummary)
                                .font(AppFont.bodySmall())
                                .foregroundColor(.primary)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )

                        LazyVGrid(columns: longRunGridColumns, alignment: .leading, spacing: 10) {
                            ForEach(longRunOptions, id: \.self) { weekday in
                                longRunChip(for: weekday)
                            }
                        }
                    }

                    if !viewModel.selectedWeekdays.contains(viewModel.selectedLongRunDay) {
                        statusText(
                            NSLocalizedString("onboarding.long_run_day_must_be_training_day", comment: "Long run day must be training day"),
                            color: .red
                        )
                    } else if !hasWeekendOption {
                        statusText(
                            NSLocalizedString("onboarding.suggest_saturday_long_run", comment: "Suggest weekend long run"),
                            color: AppTheme.shared.accentColor
                        )
                    }

                    Text(isBeginner
                        ? NSLocalizedString("onboarding.long_run_day_description_beginner", comment: "This day will have slightly longer distance")
                        : NSLocalizedString("onboarding.long_run_day_description", comment: "Weekly long distance training day"))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }

                if let error = viewModel.error {
                    Text(error).foregroundColor(.red)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("TrainingDays_Screen")
        .navigationTitle(NSLocalizedString("onboarding.training_days_title", comment: "Training Days Title"))
        .fullScreenCover(isPresented: $viewModel.isLoading) {
            LoadingAnimationView(messages: previewLoadingMessages, totalDuration: previewLoadingDuration)
        }
        .task {
            viewModel.isBeginner = isBeginner
            await viewModel.loadTrainingDayPreferences()
            syncLongRunDaySelection()
        }
        .onAppear {
            syncLongRunDaySelection()
        }
        .onChange(of: viewModel.selectedWeekdays) { _ in
            syncLongRunDaySelection()
        }
    }

    private var currentLongRunSummary: String {
        let day = getWeekdayName(viewModel.selectedLongRunDay)
        return isBeginner
            ? "\(day) · \(NSLocalizedString("onboarding.long_run_day_description_beginner", comment: "This day will have slightly longer distance"))"
            : "\(day) · \(NSLocalizedString("onboarding.long_run_day_description", comment: "Weekly long distance training day"))"
    }

    private var longRunEmptyState: some View {
        Text(NSLocalizedString("onboarding.long_run_day_must_be_training_day", comment: "Long run day must be training day"))
            .font(AppFont.bodySmall())
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
    }

    private func longRunChip(for weekday: Int) -> some View {
        let isSelected = viewModel.selectedLongRunDay == weekday
        let isRecommended = weekday == recommendedLongRunDay && hasWeekendOption

        return Button {
            viewModel.selectedLongRunDay = weekday
        } label: {
            HStack(spacing: 6) {
                Text(getWeekdayName(weekday))
                    .font(AppFont.bodySmall())
                    .lineLimit(1)

                if isRecommended {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .foregroundColor(isSelected ? .white : (isRecommended ? AppTheme.shared.accentColor : .primary))
            .frame(maxWidth: .infinity, minHeight: 42)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(isSelected ? (isRecommended ? AppTheme.shared.accentColor : AppTheme.shared.primaryColor) : Color(.secondarySystemBackground))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? .clear : (isRecommended ? AppTheme.shared.accentColor.opacity(0.35) : Color.primary.opacity(0.08)), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("LongRunDay_\(weekday)")
    }

    private func statusText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(AppFont.caption())
            .foregroundColor(color)
    }

    private func saveAndNavigate() {
        Task {
            let targetTypeId = coordinator.selectedTargetTypeId
            let selectedStage: String?
            if targetTypeId == "race_run" {
                selectedStage = UserDefaults.standard.string(forKey: OnboardingCoordinator.startStageUserDefaultsKey)
            } else if targetTypeId == nil {
                selectedStage = coordinator.selectedStartStage
            } else {
                selectedStage = nil
            }

            coordinator.availableDays = viewModel.selectedWeekdays.count

            let isV2Flow = coordinator.selectedTargetTypeId != nil
            Logger.debug("[TrainingDaysSetupView] isV2Flow: \(isV2Flow), availableDays: \(viewModel.selectedWeekdays.count)")

            if isV2Flow {
                let saveSuccess = await viewModel.saveTrainingDaysPreferencesOnly()
                guard saveSuccess else {
                    Logger.error("[TrainingDaysSetupView] V2: Failed to save training days")
                    return
                }

                Logger.debug("[TrainingDaysSetupView] V2: Training days saved, creating V2 overview...")

                guard let targetType = viewModel.selectedTargetTypeV2 else {
                    Logger.warn("[TrainingDaysSetupView] V2: selectedTargetTypeV2 is nil, loading target types...")
                    await viewModel.loadTargetTypes()

                    guard let targetTypeId = coordinator.selectedTargetTypeId,
                          let loadedType = viewModel.availableTargetTypes.first(where: { $0.id == targetTypeId }) else {
                        Logger.error("[TrainingDaysSetupView] V2: Failed to find targetType for id: \(coordinator.selectedTargetTypeId ?? "nil")")
                        return
                    }

                    viewModel.selectedTargetTypeV2 = loadedType
                    await createAndNavigateWithOverview(targetType: loadedType, startFromStage: selectedStage)
                    return
                }

                await createAndNavigateWithOverview(targetType: targetType, startFromStage: selectedStage)
            } else {
                let success = await viewModel.saveTrainingDaysAndGenerateOverview(startFromStage: selectedStage)
                if success {
                    coordinator.trainingPlanOverview = viewModel.trainingOverview
                    coordinator.navigate(to: .trainingOverview)
                }
            }
        }
    }

    private func createAndNavigateWithOverview(targetType: TargetTypeV2, startFromStage: String?) async {
        let overview = await viewModel.createPlanOverviewV2(
            targetType: targetType,
            trainingWeeks: coordinator.trainingWeeks,
            targetId: coordinator.selectedTargetId,
            startFromStage: startFromStage,
            methodologyId: coordinator.selectedMethodologyId,
            intendedRaceDistanceKm: coordinator.intendedRaceDistanceKm
        )

        if let overview = overview {
            coordinator.trainingPlanOverviewV2 = overview
            Logger.info("[TrainingDaysSetupView] V2 Overview created: \(overview.id), navigating to trainingOverview")
            coordinator.navigate(to: .trainingOverview)
        } else {
            Logger.error("[TrainingDaysSetupView] V2: Failed to create overview")
        }
    }

    private func syncLongRunDaySelection() {
        if let recommendedLongRunDay, !longRunOptions.contains(viewModel.selectedLongRunDay) {
            viewModel.selectedLongRunDay = recommendedLongRunDay
        }
    }

    private func getWeekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return NSLocalizedString("onboarding.monday", comment: "Monday")
        case 2: return NSLocalizedString("onboarding.tuesday", comment: "Tuesday")
        case 3: return NSLocalizedString("onboarding.wednesday", comment: "Wednesday")
        case 4: return NSLocalizedString("onboarding.thursday", comment: "Thursday")
        case 5: return NSLocalizedString("onboarding.friday", comment: "Friday")
        case 6: return NSLocalizedString("onboarding.saturday", comment: "Saturday")
        case 7: return NSLocalizedString("onboarding.sunday", comment: "Sunday")
        default: return ""
        }
    }
}

struct TrainingDaysSetupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TrainingDaysSetupView(isBeginner: false)
        }
    }
}
