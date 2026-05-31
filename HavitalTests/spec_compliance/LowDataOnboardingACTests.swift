import XCTest

final class LowDataOnboardingACTests: XCTestCase {
    private let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func read(_ relativePath: String) throws -> String {
        let url = projectRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    func test_ac_ld_01_02_dataSourceSkipPathUsesUnboundAndContinuesOnboarding() throws {
        let source = try read("Havital/Views/Onboarding/DataSourceSelectionView.swift")
        XCTAssertTrue(source.contains("skipForNow"))
        XCTAssertTrue(source.contains("updateAndSyncDataSource(.unbound)"))
        XCTAssertTrue(source.contains("navigate(to: .heartRateZone)"))
    }

    func test_ac_ld_04_05_06_heartRateOnboardingHasDefaultsAndSkip() throws {
        let source = try read("Havital/Views/Health/HeartRateZoneInfoView.swift")
        XCTAssertTrue(source.contains("220 - userAgeFromLocalStorage"))
        XCTAssertTrue(source.contains("restingHeartRate = 60"))
        XCTAssertTrue(source.contains("onboarding.skip"))
        XCTAssertTrue(source.contains("navigate(to: .personalBest)"))
    }

    func test_ac_ld_10_12_vdotNoDataAndLowDataCopyKeysExist() throws {
        let keys = try read("Havital/Utils/LocalizationKeys.swift")
        let zh = try read("Havital/Resources/zh-Hant.lproj/Localizable.strings")
        let en = try read("Havital/Resources/en.lproj/Localizable.strings")
        let ja = try read("Havital/Resources/ja.lproj/Localizable.strings")

        XCTAssertTrue(keys.contains("LowData"))
        XCTAssertTrue(zh.contains("low_data.vdot_hint"))
        XCTAssertTrue(en.contains("low_data.vdot_hint"))
        XCTAssertTrue(ja.contains("low_data.vdot_hint"))
    }

    func test_ac_ld_22_24_25_workoutDetailProvidesOptionalRPEEntry() throws {
        // RPEEditorView.swift was replaced by WorkoutReflectionView.swift (merged RPE + notes).
        // Path updated from Havital/Views/Training/RPEEditorView.swift
        //   to Havital/Features/Workout/Presentation/Recap/WorkoutReflectionView.swift
        let view = try read("Havital/Views/Training/WorkoutDetailViewV2.swift")
        let editor = try read("Havital/Features/Workout/Presentation/Recap/WorkoutReflectionView.swift")
        let viewModel = try read("Havital/Features/Workout/Presentation/ViewModels/WorkoutDetailViewModelV2.swift")
        let repository = try read("Havital/Features/Workout/Domain/Repositories/WorkoutRepository.swift")

        XCTAssertTrue(view.contains("WorkoutReflectionView"), "WorkoutDetailView must embed WorkoutReflectionView (replaces RPEEditorView)")
        XCTAssertTrue(view.contains("workout_detail_rpe_button"), "RPE entry button accessibility ID must remain")
        // WorkoutReflectionView contains the RPE scale section (rpeSection / rpePill)
        XCTAssertTrue(editor.contains("rpeSection"), "WorkoutReflectionView must contain rpeSection")
        XCTAssertTrue(editor.contains("rpePill"), "WorkoutReflectionView must render RPE pills")
        XCTAssertTrue(view.contains("currentRPE") || viewModel.contains("currentRPE") || viewModel.contains("initialRPE") || editor.contains("initialRPE"),
                      "RPE state must be tracked in view or viewmodel")
        XCTAssertTrue(viewModel.contains("updateRPE"))
        XCTAssertTrue(repository.contains("updateRPE"))
    }

    func test_ac_ld_23_noHrNoRPEDoesNotFabricateTSSOrAIInWorkoutDetail() throws {
        let view = try read("Havital/Views/Training/WorkoutDetailViewV2.swift")

        XCTAssertTrue(view.contains("if let tss = viewModel.workout.advancedMetrics?.tss"))
        XCTAssertTrue(view.contains("if viewModel.workoutDetail?.dailyPlanSummary != nil || viewModel.workoutDetail?.aiSummary != nil"))
        XCTAssertTrue(view.contains("L10n.WorkoutDetail.addRPE.localized"))
        XCTAssertTrue(view.contains("L10n.WorkoutDetail.noHeartRateData.localized"))
        XCTAssertFalse(view.contains("AI suggestion"))
        XCTAssertFalse(view.contains("estimatedTSS"))
    }

    func test_ac_ld_26_27_dataSourceReminderIsThrottled() throws {
        let source = try read("Havital/Features/UserProfile/Domain/Managers/DataSourceBindingReminderManager.swift")
        XCTAssertTrue(source.contains("reminderInterval"))
        XCTAssertTrue(source.contains("hasShownThisSession"))
        XCTAssertTrue(source.contains("dismissReminder"))
    }
}
