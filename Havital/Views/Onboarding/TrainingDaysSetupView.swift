//
//  TrainingDaysSetupView.swift
//  Havital
//
//  Training Days selection onboarding step
//  Refactored to use OnboardingFeatureViewModel (Clean Architecture)
//

import SwiftUI

struct TrainingDaysSetupView: View {
    @StateObject private var viewModel: OnboardingFeatureViewModel
    // Clean Architecture: Use AuthenticationViewModel from environment
    @EnvironmentObject private var authViewModel: AuthenticationViewModel
    @ObservedObject private var coordinator = OnboardingCoordinator.shared

    let isBeginner: Bool
    private let recommendedMinTrainingDays = 2

    // Loading animation settings
    private let previewLoadingMessages = [
        NSLocalizedString("onboarding.evaluating_goal", comment: "Evaluating Goal"),
        NSLocalizedString("onboarding.calculating_training_intensity", comment: "Calculating Training Intensity"),
        NSLocalizedString("onboarding.generating_overview", comment: "Generating Overview")
    ]
    private let previewLoadingDuration: Double = 15

    init(isBeginner: Bool = false) {
        self.isBeginner = isBeginner
        _viewModel = StateObject(wrappedValue: DependencyContainer.shared.makeOnboardingFeatureViewModel())
    }

    // Check if can save preferences
    private var canSavePreferences: Bool {
        let hasEnoughDays = viewModel.selectedWeekdays.count >= recommendedMinTrainingDays
        let isLongRunDayValid = viewModel.selectedWeekdays.contains(viewModel.selectedLongRunDay) || viewModel.selectedWeekdays.isEmpty
        return hasEnoughDays && isLongRunDayValid
    }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                Section(
                    header: Text(NSLocalizedString("onboarding.select_training_days", comment: "Select Training Days")),
                    footer: Text(String(format: NSLocalizedString("onboarding.training_days_description", comment: "Training Days Description"), recommendedMinTrainingDays))
                ) {
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
                        }
                        .foregroundColor(.primary)
                    }
                }

                Section(
                    header: Text(isBeginner
                        ? NSLocalizedString("onboarding.setup_long_run_day_beginner", comment: "Select a day for slightly longer run")
                        : NSLocalizedString("onboarding.setup_long_run_day", comment: "Select long run day")),
                    footer: Text(isBeginner
                        ? NSLocalizedString("onboarding.long_run_day_description_beginner", comment: "This day will have slightly longer distance")
                        : NSLocalizedString("onboarding.long_run_day_description", comment: "Weekly long distance training day"))
                ) {
                    let longRunOptions = viewModel.selectedWeekdays.isEmpty ? [6] : Array(viewModel.selectedWeekdays).sorted()
                    Picker(NSLocalizedString("onboarding.select_long_run_day", comment: "Select Long Run Day"), selection: $viewModel.selectedLongRunDay) {
                        ForEach(longRunOptions, id: \.self) { weekday in
                            Text(getWeekdayName(weekday)).tag(weekday)
                        }
                    }
                    .disabled(viewModel.selectedWeekdays.isEmpty)
                    .onAppear {
                        // Prefer Saturday, then Sunday for long run day
                        if viewModel.selectedWeekdays.contains(6) {
                            viewModel.selectedLongRunDay = 6
                        } else if viewModel.selectedWeekdays.contains(7) {
                            viewModel.selectedLongRunDay = 7
                        } else if let first = viewModel.selectedWeekdays.sorted().first {
                            viewModel.selectedLongRunDay = first
                        }
                    }
                    .onChange(of: viewModel.selectedWeekdays) { newWeekdays in
                        // Prefer Saturday, then Sunday for long run day
                        if newWeekdays.contains(6) {
                            viewModel.selectedLongRunDay = 6
                        } else if newWeekdays.contains(7) {
                            viewModel.selectedLongRunDay = 7
                        } else if !newWeekdays.contains(viewModel.selectedLongRunDay), let first = newWeekdays.sorted().first {
                            viewModel.selectedLongRunDay = first
                        }
                    }

                    if !viewModel.selectedWeekdays.contains(viewModel.selectedLongRunDay) {
                        Text(NSLocalizedString("onboarding.long_run_day_must_be_training_day", comment: "Long run day must be training day"))
                            .foregroundColor(.red)
                    } else if !viewModel.selectedWeekdays.contains(6) && !viewModel.selectedWeekdays.contains(7) {
                        Text(NSLocalizedString("onboarding.suggest_saturday_long_run", comment: "Suggest weekend long run"))
                            .foregroundColor(.orange)
                    }
                }

                if let error = viewModel.error {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }

                // Button section
                Section {
                    Button(action: {
                        saveAndNavigate()
                    }) {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(NSLocalizedString("onboarding.save_preferences_preview", comment: "Save Preferences Preview"))
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading || !canSavePreferences)
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle(NSLocalizedString("onboarding.training_days_title", comment: "Training Days Title"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(isPresented: $viewModel.isLoading) {
            LoadingAnimationView(messages: previewLoadingMessages, totalDuration: previewLoadingDuration)
        }
        .background(EmptyView())
        .task {
            // Set isBeginner and load user preferences
            viewModel.isBeginner = isBeginner
            await viewModel.loadTrainingDayPreferences()
        }
    }

    // MARK: - Private Methods

    private func saveAndNavigate() {
        Task {
            let selectedStage = UserDefaults.standard.string(forKey: "selectedStartStage")
            let success = await viewModel.saveTrainingDaysAndGenerateOverview(startFromStage: selectedStage)
            if success {
                // Update coordinator with overview
                coordinator.trainingPlanOverview = viewModel.trainingOverview
                coordinator.navigate(to: .trainingOverview)
            }
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
            TrainingDaysSetupView()
        }
    }
}
