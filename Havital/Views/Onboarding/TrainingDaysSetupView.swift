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
                        .accessibilityIdentifier("TrainingDay_\(weekday)")
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
                    .accessibilityIdentifier("LongRunDay_Picker")
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
                    .accessibilityIdentifier("TrainingDays_SaveButton")
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
            let targetTypeId = coordinator.selectedTargetTypeId
            let selectedStage: String?
            if targetTypeId == "race_run" {
                // race_run V2：起始階段由 StartStageSelectionView 寫入 UserDefaults
                selectedStage = UserDefaults.standard.string(forKey: OnboardingCoordinator.startStageUserDefaultsKey)
            } else if targetTypeId == nil {
                // V1 legacy：從 coordinator 取，不讀 UserDefaults（避免 race_run 殘留值污染）
                selectedStage = coordinator.selectedStartStage
            } else {
                // maintenance / beginner V2：不傳 stage
                selectedStage = nil
            }

            // 保存 availableDays 到 coordinator（供 V2 流程使用）
            coordinator.availableDays = viewModel.selectedWeekdays.count

            // 判斷是否為 V2 流程
            let isV2Flow = coordinator.selectedTargetTypeId != nil
            Logger.debug("[TrainingDaysSetupView] isV2Flow: \(isV2Flow), availableDays: \(viewModel.selectedWeekdays.count)")

            if isV2Flow {
                // V2 流程：只保存訓練日偏好，overview 建立延遲到用戶最終確認時
                // （避免在這一步就設定 training_version: "v2"，讓用戶有機會返回）
                let saveSuccess = await viewModel.saveTrainingDaysPreferencesOnly()
                guard saveSuccess else {
                    Logger.error("[TrainingDaysSetupView] V2: Failed to save training days")
                    return
                }

                Logger.debug("[TrainingDaysSetupView] V2: Training days saved, creating V2 overview...")
                Logger.debug("[TrainingDaysSetupView] V2: targetTypeId=\(coordinator.selectedTargetTypeId ?? "nil"), targetId=\(coordinator.selectedTargetId ?? "nil"), trainingWeeks=\(coordinator.trainingWeeks ?? 0)")

                // 獲取 targetType - 優先使用 viewModel 中的
                guard let targetType = viewModel.selectedTargetTypeV2 else {
                    // 如果 viewModel 沒有，從 API 重新載入
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
                // V1 流程：保存訓練日偏好並生成 Overview
                let success = await viewModel.saveTrainingDaysAndGenerateOverview(startFromStage: selectedStage)
                if success {
                    // Update coordinator with overview
                    coordinator.trainingPlanOverview = viewModel.trainingOverview
                    coordinator.navigate(to: .trainingOverview)
                }
            }
        }
    }

    /// V2 流程：創建 Overview 並導航
    private func createAndNavigateWithOverview(targetType: TargetTypeV2, startFromStage: String?) async {
        // 呼叫 POST /v2/plan/overview
        let overview = await viewModel.createPlanOverviewV2(
            targetType: targetType,
            trainingWeeks: coordinator.trainingWeeks,
            targetId: coordinator.selectedTargetId,
            startFromStage: startFromStage,
            methodologyId: coordinator.selectedMethodologyId,
            intendedRaceDistanceKm: coordinator.intendedRaceDistanceKm
        )

        if let overview = overview {
            // 存儲到 coordinator
            coordinator.trainingPlanOverviewV2 = overview
            Logger.info("[TrainingDaysSetupView] ✅ V2 Overview created: \(overview.id), navigating to trainingOverview")
            coordinator.navigate(to: .trainingOverview)
        } else {
            Logger.error("[TrainingDaysSetupView] ❌ V2: Failed to create overview")
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
