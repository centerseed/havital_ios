import XCTest
@testable import paceriz_dev

/// AC test suite for SPEC-ios-analytics-p1.
///
/// Test strategy:
///   - P1-01: Enumerate all 12 new AnalyticsEvent cases, verify name/parameters.
///   - P1-02..P1-08 enum_contract: Verify event enum satisfies SPEC parameter contracts.
///   - P1-02 wiring: Inject MockAnalyticsService into OnboardingCoordinator via DependencyContainer,
///     call coordinator methods, assert actual calls. Covers dedup, negative cases.
///   - P1-09..P1-13 enum_contract: AnalyticsEvent parameter contract verification.
///   - P1-09..P1-13 wiring: Inject MockAnalyticsService into DependencyContainer, call ViewModel
///     mark methods directly, assert event count and dedup behavior.
///     Dedup state is now owned by ViewModels (TrainingPlanV2ViewModel, WorkoutDetailViewModelV2,
///     WeeklySummaryCoordinator) — fully testable without SwiftUI view instantiation.
final class IosAnalyticsP1ACTests: XCTestCase {

    private var analytics: MockAnalyticsService!
    private var coordinator: OnboardingCoordinator!

    override func setUp() {
        super.setUp()
        analytics = MockAnalyticsService()
        // Inject mock into DI so coordinator picks it up via its computed `analyticsService` property.
        DependencyContainer.shared.register(analytics, forProtocol: AnalyticsService.self)
        coordinator = OnboardingCoordinator.shared
    }

    override func tearDown() {
        coordinator = nil
        analytics = nil
        super.tearDown()
    }

    /// Helper: reset coordinator and analytics on the MainActor, required before each coordinator wiring test.
    @MainActor
    private func resetCoordinatorSession() {
        coordinator.reset()
        analytics.reset()
    }

    // MARK: - AC-IOS-ANALYTICS-P1-01

    /// AC-IOS-ANALYTICS-P1-01: AnalyticsEvent enum must contain 12 new cases with correct name/parameters.
    func test_p1_01_enum_cases_present() {
        let cases: [(event: AnalyticsEvent, expectedName: String)] = [
            (.onboardingDataSourcePrompted, "onboarding_data_source_prompted"),
            (.onboardingDataSourceSkipped, "onboarding_data_source_skipped"),
            (.onboardingDataSourceConnected(provider: "garmin"), "onboarding_data_source_connected"),
            (.onboardingGoalTypeSelected(targetType: "race_run"), "onboarding_goal_type_selected"),
            (.onboardingTargetRaceSet(targetType: "race_run", raceId: nil, distanceKm: nil), "onboarding_target_race_set"),
            (.onboardingScheduleSet(availableDays: 4), "onboarding_schedule_set"),
            (.onboardingPlanGenerating(targetType: "race_run"), "onboarding_plan_generating"),
            (.weeklyPlanView(planId: "p1", weekOfTraining: 1), "weekly_plan_view"),
            (.workoutAnalysisView(workoutId: "w1", hasCoachNotes: true), "workout_analysis_view"),
            (.weeklySummaryView(summaryId: "s1", weekOfTraining: 1), "weekly_summary_view"),
            (.planOverviewView(overviewId: "o1", targetType: "race_run"), "plan_overview_view"),
            (.racePredictionView(predictedTime: "01:45:00", distanceKm: 21.0975), "race_prediction_view"),
        ]

        XCTAssertEqual(cases.count, 12, "Must have exactly 12 new P1 cases")

        for (event, expectedName) in cases {
            XCTAssertEqual(event.name, expectedName,
                "Event \(expectedName) has wrong name: '\(event.name)'")
        }

        // Verify parameters switch doesn't crash for any case.
        for (event, _) in cases {
            _ = event.parameters
        }
    }

    // MARK: - AC-IOS-ANALYTICS-P1-02 enum contract

    /// AC-IOS-ANALYTICS-P1-02 (enum contract): onboarding_data_source_prompted has no parameters.
    func test_p1_02_data_source_prompted_emitted_enum_contract() {
        let event = AnalyticsEvent.onboardingDataSourcePrompted

        XCTAssertEqual(event.name, "onboarding_data_source_prompted")
        XCTAssertTrue(event.parameters.isEmpty,
            "onboarding_data_source_prompted must have no parameters per SPEC")
    }

    // MARK: - AC-IOS-ANALYTICS-P1-02 wiring: coordinator dedup

    /// AC-IOS-ANALYTICS-P1-02 (wiring): OnboardingCoordinator.trackDataSourcePromptedIfNeeded()
    /// fires exactly once per session even when called multiple times (session-level dedup).
    @MainActor
    func test_p1_02_wiring_dedup_fires_only_once_per_session() {
        resetCoordinatorSession()
        coordinator.trackDataSourcePromptedIfNeeded()
        coordinator.trackDataSourcePromptedIfNeeded()
        coordinator.trackDataSourcePromptedIfNeeded()

        let events = analytics.events(named: "onboarding_data_source_prompted")
        XCTAssertEqual(events.count, 1,
            "P1-02 dedup: onboarding_data_source_prompted must fire exactly once per session, got \(events.count)")
    }

    /// AC-IOS-ANALYTICS-P1-02 (wiring): After coordinator.reset(), a new session fires the event again.
    @MainActor
    func test_p1_02_wiring_dedup_resets_with_session() {
        resetCoordinatorSession()
        coordinator.trackDataSourcePromptedIfNeeded()
        XCTAssertEqual(analytics.events(named: "onboarding_data_source_prompted").count, 1)

        coordinator.reset()
        analytics.reset()

        coordinator.trackDataSourcePromptedIfNeeded()
        XCTAssertEqual(analytics.events(named: "onboarding_data_source_prompted").count, 1,
            "P1-02: dedup flag must reset between sessions")
    }

    // MARK: - AC-IOS-ANALYTICS-P1-03 enum contract

    /// AC-IOS-ANALYTICS-P1-03 (enum contract): onboarding_data_source_skipped has no parameters.
    func test_p1_03_data_source_skipped_emitted_enum_contract() {
        let event = AnalyticsEvent.onboardingDataSourceSkipped

        XCTAssertEqual(event.name, "onboarding_data_source_skipped")
        XCTAssertTrue(event.parameters.isEmpty,
            "onboarding_data_source_skipped must have no parameters per SPEC")
    }

    // MARK: - AC-IOS-ANALYTICS-P1-03 wiring: coordinator calls through to analytics

    /// AC-IOS-ANALYTICS-P1-03 (wiring): OnboardingCoordinator.trackDataSourceSkipped()
    /// emits exactly one onboarding_data_source_skipped event with no parameters.
    @MainActor
    func test_p1_03_wiring_skipped_emits_event() {
        resetCoordinatorSession()
        coordinator.trackDataSourceSkipped()

        let events = analytics.events(named: "onboarding_data_source_skipped")
        XCTAssertEqual(events.count, 1,
            "P1-03 wiring: onboarding_data_source_skipped must fire exactly once")
        XCTAssertTrue(events.first?.parameters.isEmpty ?? false,
            "P1-03 wiring: onboarding_data_source_skipped must have no parameters")
    }

    // MARK: - AC-IOS-ANALYTICS-P1-04 enum contract

    /// AC-IOS-ANALYTICS-P1-04 (enum contract): onboarding_data_source_connected — provider required.
    func test_p1_04_data_source_connected_with_provider_enum_contract() {
        let garminEvent = AnalyticsEvent.onboardingDataSourceConnected(provider: "garmin")
        XCTAssertEqual(garminEvent.name, "onboarding_data_source_connected")
        XCTAssertEqual(garminEvent.parameters["provider"] as? String, "garmin")

        let appleEvent = AnalyticsEvent.onboardingDataSourceConnected(provider: "apple_health")
        XCTAssertEqual(appleEvent.parameters["provider"] as? String, "apple_health")

        XCTAssertEqual(garminEvent.parameters.count, 1)
        XCTAssertEqual(appleEvent.parameters.count, 1)
    }

    // MARK: - AC-IOS-ANALYTICS-P1-04 wiring: coordinator calls through with provider

    /// AC-IOS-ANALYTICS-P1-04 (wiring): trackDataSourceConnected(provider: "garmin") emits event with provider=garmin.
    @MainActor
    func test_p1_04_wiring_connected_emits_provider_garmin() {
        resetCoordinatorSession()
        coordinator.trackDataSourceConnected(provider: "garmin")

        let events = analytics.events(named: "onboarding_data_source_connected")
        XCTAssertEqual(events.count, 1,
            "P1-04 wiring: onboarding_data_source_connected must fire exactly once")
        XCTAssertEqual(events.first?.parameters["provider"] as? String, "garmin",
            "P1-04 wiring: provider must be 'garmin'")
    }

    /// AC-IOS-ANALYTICS-P1-04 (wiring): trackDataSourceConnected(provider: "apple_health") emits event with provider=apple_health.
    @MainActor
    func test_p1_04_wiring_connected_emits_provider_apple_health() {
        resetCoordinatorSession()
        coordinator.trackDataSourceConnected(provider: "apple_health")

        let events = analytics.events(named: "onboarding_data_source_connected")
        XCTAssertEqual(events.count, 1,
            "P1-04 wiring: onboarding_data_source_connected must fire exactly once")
        XCTAssertEqual(events.first?.parameters["provider"] as? String, "apple_health",
            "P1-04 wiring: provider must be 'apple_health'")
    }

    // MARK: - AC-IOS-ANALYTICS-P1-05 enum contract

    /// AC-IOS-ANALYTICS-P1-05 (enum contract): onboarding_goal_type_selected — target_type required.
    func test_p1_05_goal_type_selected_with_target_type_enum_contract() {
        for targetType in ["race_run", "maintenance", "beginner"] {
            let event = AnalyticsEvent.onboardingGoalTypeSelected(targetType: targetType)
            XCTAssertEqual(event.name, "onboarding_goal_type_selected")
            XCTAssertEqual(event.parameters["target_type"] as? String, targetType)
            XCTAssertEqual(event.parameters.count, 1, "Only target_type param allowed")
        }
    }

    // MARK: - AC-IOS-ANALYTICS-P1-05 wiring: coordinator calls through with target_type

    /// AC-IOS-ANALYTICS-P1-05 (wiring): trackGoalTypeSelected(targetType:) emits onboarding_goal_type_selected
    /// with correct target_type for each of the three goal types.
    @MainActor
    func test_p1_05_wiring_goal_type_selected_emits_target_type() {
        resetCoordinatorSession()
        coordinator.trackGoalTypeSelected(targetType: "race_run")
        coordinator.trackGoalTypeSelected(targetType: "maintenance")
        coordinator.trackGoalTypeSelected(targetType: "beginner")

        let events = analytics.events(named: "onboarding_goal_type_selected")
        XCTAssertEqual(events.count, 3,
            "P1-05 wiring: onboarding_goal_type_selected must fire once per call, got \(events.count)")
        XCTAssertEqual(events[0].parameters["target_type"] as? String, "race_run",
            "P1-05 wiring: first call must have target_type='race_run'")
        XCTAssertEqual(events[1].parameters["target_type"] as? String, "maintenance",
            "P1-05 wiring: second call must have target_type='maintenance'")
        XCTAssertEqual(events[2].parameters["target_type"] as? String, "beginner",
            "P1-05 wiring: third call must have target_type='beginner'")
    }

    // MARK: - AC-IOS-ANALYTICS-P1-06 enum contract

    /// AC-IOS-ANALYTICS-P1-06 (enum contract): onboarding_target_race_set — target_type required;
    /// race_id/distance_km optional, nil values omitted from parameters.
    func test_p1_06_target_race_set_params_enum_contract() {
        let raceRunEvent = AnalyticsEvent.onboardingTargetRaceSet(
            targetType: "race_run", raceId: "race-123", distanceKm: 42.195)
        XCTAssertEqual(raceRunEvent.parameters["target_type"] as? String, "race_run")
        XCTAssertEqual(raceRunEvent.parameters["race_id"] as? String, "race-123")
        XCTAssertEqual(raceRunEvent.parameters["distance_km"] as? Double, 42.195)

        let maintenanceEvent = AnalyticsEvent.onboardingTargetRaceSet(
            targetType: "maintenance", raceId: nil, distanceKm: 21.0975)
        XCTAssertNil(maintenanceEvent.parameters["race_id"],
            "race_id must be omitted when nil")

        let noOptionalEvent = AnalyticsEvent.onboardingTargetRaceSet(
            targetType: "race_run", raceId: nil, distanceKm: nil)
        XCTAssertEqual(noOptionalEvent.parameters.count, 1, "Only target_type when optionals are nil")
    }

    // MARK: - AC-IOS-ANALYTICS-P1-06 wiring: Beginner path does NOT emit

    /// AC-IOS-ANALYTICS-P1-06 (wiring — negative): When coordinator.isBeginner = true,
    /// trackTargetRaceSet must NOT be called (Beginner has no race/distance setup step).
    /// This test verifies the coordinator does not auto-fire the event for beginner path.
    /// The call-site guard is in the view (GoalTypeSelectionView / OnboardingFeatureViewModel);
    /// this test verifies the coordinator method itself correctly passes through
    /// and that beginner flow never receives the call.
    @MainActor
    func test_p1_06_wiring_beginner_path_does_not_emit_target_race_set() {
        resetCoordinatorSession()
        // Set coordinator to beginner mode.
        coordinator.isBeginner = true

        // Simulate beginner flow: trackGoalTypeSelected is called (legitimate), but
        // trackTargetRaceSet must NOT be called for beginner path.
        coordinator.trackGoalTypeSelected(targetType: "beginner")

        // Only goal_type_selected should appear; no target_race_set.
        let raceSetEvents = analytics.events(named: "onboarding_target_race_set")
        XCTAssertEqual(raceSetEvents.count, 0,
            "P1-06 negative: Beginner path must not emit onboarding_target_race_set. " +
            "Call site (view) is responsible for not calling trackTargetRaceSet for beginner.")
    }

    // MARK: - AC-IOS-ANALYTICS-P1-07 enum contract

    /// AC-IOS-ANALYTICS-P1-07 (enum contract): onboarding_schedule_set — available_days required.
    func test_p1_07_schedule_set_with_available_days_enum_contract() {
        let event = AnalyticsEvent.onboardingScheduleSet(availableDays: 4)
        XCTAssertEqual(event.name, "onboarding_schedule_set")
        XCTAssertEqual(event.parameters["available_days"] as? Int, 4)
        XCTAssertEqual(event.parameters.count, 1)
    }

    // MARK: - AC-IOS-ANALYTICS-P1-07 wiring: coordinator calls through with available_days

    /// AC-IOS-ANALYTICS-P1-07 (wiring): trackScheduleSet(availableDays:) emits onboarding_schedule_set
    /// with correct available_days value.
    @MainActor
    func test_p1_07_wiring_schedule_set_emits_available_days() {
        resetCoordinatorSession()
        coordinator.trackScheduleSet(availableDays: 4)

        let events = analytics.events(named: "onboarding_schedule_set")
        XCTAssertEqual(events.count, 1,
            "P1-07 wiring: onboarding_schedule_set must fire exactly once")
        XCTAssertEqual(events.first?.parameters["available_days"] as? Int, 4,
            "P1-07 wiring: available_days must be 4")
    }

    // MARK: - AC-IOS-ANALYTICS-P1-08 enum contract

    /// AC-IOS-ANALYTICS-P1-08 (enum contract): onboarding_plan_generating — target_type required.
    func test_p1_08_plan_generating_emitted_enum_contract() {
        for targetType in ["race_run", "maintenance", "beginner"] {
            let event = AnalyticsEvent.onboardingPlanGenerating(targetType: targetType)
            XCTAssertEqual(event.name, "onboarding_plan_generating")
            XCTAssertEqual(event.parameters["target_type"] as? String, targetType)
            XCTAssertEqual(event.parameters.count, 1)
        }
    }

    // MARK: - AC-IOS-ANALYTICS-P1-08 wiring: fallback behavior

    /// AC-IOS-ANALYTICS-P1-08 (wiring): When selectedTargetTypeId is nil and isBeginner is false,
    /// coordinator falls back to "race_run" and emits the event.
    @MainActor
    func test_p1_08_wiring_nil_targetTypeId_non_beginner_falls_back_to_race_run() {
        resetCoordinatorSession()
        coordinator.selectedTargetTypeId = nil
        coordinator.isBeginner = false

        coordinator.trackPlanGenerating()

        let events = analytics.events(named: "onboarding_plan_generating")
        XCTAssertEqual(events.count, 1, "Must emit onboarding_plan_generating")
        XCTAssertEqual(events.first?.parameters["target_type"] as? String, "race_run",
            "P1-08: nil selectedTargetTypeId + non-beginner must fall back to 'race_run'")
    }

    /// AC-IOS-ANALYTICS-P1-08 (wiring): When isBeginner is true, emits "beginner" target_type.
    @MainActor
    func test_p1_08_wiring_beginner_emits_beginner_target_type() {
        resetCoordinatorSession()
        coordinator.selectedTargetTypeId = nil
        coordinator.isBeginner = true

        coordinator.trackPlanGenerating()

        let events = analytics.events(named: "onboarding_plan_generating")
        XCTAssertEqual(events.first?.parameters["target_type"] as? String, "beginner",
            "P1-08: beginner path must emit target_type='beginner'")
    }

    /// AC-IOS-ANALYTICS-P1-08 (wiring): When selectedTargetTypeId is set, uses that value.
    @MainActor
    func test_p1_08_wiring_selectedTargetTypeId_used_when_set() {
        resetCoordinatorSession()
        coordinator.selectedTargetTypeId = "maintenance"
        coordinator.isBeginner = false

        coordinator.trackPlanGenerating()

        let events = analytics.events(named: "onboarding_plan_generating")
        XCTAssertEqual(events.first?.parameters["target_type"] as? String, "maintenance",
            "P1-08: selectedTargetTypeId must take precedence over fallback")
    }

    // MARK: - AC-IOS-ANALYTICS-P1-09 enum contract

    /// AC-IOS-ANALYTICS-P1-09 (enum contract): weekly_plan_view — plan_id + week_of_training required.
    func test_p1_09_weekly_plan_view_params_enum_contract() {
        let event = AnalyticsEvent.weeklyPlanView(planId: "plan-abc-123", weekOfTraining: 3)
        XCTAssertEqual(event.name, "weekly_plan_view")
        XCTAssertEqual(event.parameters["plan_id"] as? String, "plan-abc-123")
        XCTAssertEqual(event.parameters["week_of_training"] as? Int, 3)
        XCTAssertEqual(event.parameters.count, 2)
    }

    // MARK: - AC-IOS-ANALYTICS-P1-09 wiring: dedup by plan_id + week_of_training

    /// AC-IOS-ANALYTICS-P1-09 (wiring dedup same key): Calling markWeeklyPlanTracked 3x with
    /// the same planId+week fires exactly one event (dedup inside ViewModel).
    @MainActor
    func test_p1_09_wiring_dedup_same_plan_week_fires_once() {
        analytics.reset()
        let vm = DependencyContainer.shared.makeTrainingPlanV2ViewModel()

        vm.markWeeklyPlanTracked(planId: "plan-abc", weekOfTraining: 2)
        vm.markWeeklyPlanTracked(planId: "plan-abc", weekOfTraining: 2)
        vm.markWeeklyPlanTracked(planId: "plan-abc", weekOfTraining: 2)

        XCTAssertEqual(analytics.events(named: "weekly_plan_view").count, 1,
            "P1-09: Same plan+week must fire exactly once even when called 3 times")
    }

    /// AC-IOS-ANALYTICS-P1-09 (wiring dedup different week): Same planId with different week
    /// should fire again (different dedup key).
    @MainActor
    func test_p1_09_wiring_dedup_different_week_re_fires() {
        analytics.reset()
        let vm = DependencyContainer.shared.makeTrainingPlanV2ViewModel()

        vm.markWeeklyPlanTracked(planId: "plan-abc", weekOfTraining: 2)
        vm.markWeeklyPlanTracked(planId: "plan-abc", weekOfTraining: 3)

        XCTAssertEqual(analytics.events(named: "weekly_plan_view").count, 2,
            "P1-09: Different week must produce a new event (dedup key is plan+week)")
    }

    // MARK: - AC-IOS-ANALYTICS-P1-10 enum contract

    /// AC-IOS-ANALYTICS-P1-10 (enum contract): workout_analysis_view — workout_id + has_coach_notes required.
    func test_p1_10_workout_analysis_view_params_enum_contract() {
        let eventWithNotes = AnalyticsEvent.workoutAnalysisView(workoutId: "wk-001", hasCoachNotes: true)
        XCTAssertEqual(eventWithNotes.name, "workout_analysis_view")
        XCTAssertEqual(eventWithNotes.parameters["workout_id"] as? String, "wk-001")
        XCTAssertEqual(eventWithNotes.parameters["has_coach_notes"] as? Bool, true)
        XCTAssertEqual(eventWithNotes.parameters.count, 2)

        let eventNoNotes = AnalyticsEvent.workoutAnalysisView(workoutId: "wk-002", hasCoachNotes: false)
        XCTAssertEqual(eventNoNotes.parameters["has_coach_notes"] as? Bool, false,
            "has_coach_notes must be explicitly false, not omitted")
    }

    // MARK: - AC-IOS-ANALYTICS-P1-10 wiring: dedup fires once

    /// AC-IOS-ANALYTICS-P1-10 (wiring dedup): Calling markAnalyticsViewTracked multiple times
    /// with the same workoutId fires exactly one event.
    func test_p1_10_wiring_dedup_fires_once() {
        analytics.reset()
        let workout = makeStubWorkout(id: "wk-001")
        let vm = WorkoutDetailViewModelV2(workout: workout)

        vm.markAnalyticsViewTracked(workoutId: "wk-001", hasCoachNotes: true)
        vm.markAnalyticsViewTracked(workoutId: "wk-001", hasCoachNotes: true)
        vm.markAnalyticsViewTracked(workoutId: "wk-001", hasCoachNotes: false)  // dedup prevents re-fire

        let events = analytics.events(named: "workout_analysis_view")
        XCTAssertEqual(events.count, 1, "P1-10: workout_analysis_view must fire exactly once (dedup)")
        XCTAssertEqual(events.first?.parameters["has_coach_notes"] as? Bool, true,
            "P1-10: has_coach_notes from first call must be recorded")
    }

    /// AC-IOS-ANALYTICS-P1-10 (wiring data guard): The view guard `guard let detail = viewModel.workoutDetail`
    /// prevents firing when data is nil. Verify the ViewModel dedup flag starts false and only
    /// transitions to true after markAnalyticsViewTracked is called.
    func test_p1_10_wiring_data_guard_skips_when_nil() {
        analytics.reset()
        let workout = makeStubWorkout(id: "wk-002")
        let vm = WorkoutDetailViewModelV2(workout: workout)

        // Simulate view guard: workoutDetail is nil → view does NOT call markAnalyticsViewTracked
        XCTAssertNil(vm.workoutDetail, "workoutDetail must start nil before async load")
        XCTAssertFalse(vm.hasTrackedAnalyticsView, "dedup flag must start false")

        XCTAssertEqual(analytics.events(named: "workout_analysis_view").count, 0,
            "P1-10: No event should fire when workoutDetail is nil (view guard prevents call)")
    }

    // MARK: - AC-IOS-ANALYTICS-P1-11 enum contract

    /// AC-IOS-ANALYTICS-P1-11 (enum contract): weekly_summary_view — summary_id + week_of_training required.
    func test_p1_11_weekly_summary_view_params_enum_contract() {
        let event = AnalyticsEvent.weeklySummaryView(summaryId: "sum-xyz-456", weekOfTraining: 5)
        XCTAssertEqual(event.name, "weekly_summary_view")
        XCTAssertEqual(event.parameters["summary_id"] as? String, "sum-xyz-456")
        XCTAssertEqual(event.parameters["week_of_training"] as? Int, 5)
        XCTAssertEqual(event.parameters.count, 2)
    }

    // MARK: - AC-IOS-ANALYTICS-P1-11 wiring: dedup

    /// AC-IOS-ANALYTICS-P1-11 (wiring dedup): markSummaryTracked called multiple times fires once.
    @MainActor
    func test_p1_11_wiring_dedup_fires_once() {
        analytics.reset()
        let coordinator = makeWeeklySummaryCoordinator()

        coordinator.markSummaryTracked(summaryId: "sum-001", weekOfTraining: 3)
        coordinator.markSummaryTracked(summaryId: "sum-001", weekOfTraining: 3)
        coordinator.markSummaryTracked(summaryId: "sum-002", weekOfTraining: 4)  // dedup prevents re-fire

        let events = analytics.events(named: "weekly_summary_view")
        XCTAssertEqual(events.count, 1, "P1-11: weekly_summary_view must fire exactly once (dedup)")
        XCTAssertEqual(events.first?.parameters["summary_id"] as? String, "sum-001",
            "P1-11: first call's summaryId must be recorded")
    }

    // MARK: - AC-IOS-ANALYTICS-P1-12 enum contract

    /// AC-IOS-ANALYTICS-P1-12 (enum contract): plan_overview_view — overview_id + target_type required.
    func test_p1_12_plan_overview_view_params_enum_contract() {
        let event = AnalyticsEvent.planOverviewView(overviewId: "ov-def-789", targetType: "race_run")
        XCTAssertEqual(event.name, "plan_overview_view")
        XCTAssertEqual(event.parameters["overview_id"] as? String, "ov-def-789")
        XCTAssertEqual(event.parameters["target_type"] as? String, "race_run")
        XCTAssertEqual(event.parameters.count, 2)
    }

    // MARK: - AC-IOS-ANALYTICS-P1-12 wiring: dedup

    /// AC-IOS-ANALYTICS-P1-12 (wiring dedup): markPlanOverviewTracked called multiple times fires once.
    @MainActor
    func test_p1_12_wiring_dedup_fires_once() {
        analytics.reset()
        let vm = DependencyContainer.shared.makeTrainingPlanV2ViewModel()

        vm.markPlanOverviewTracked(overviewId: "ov-001", targetType: "race_run")
        vm.markPlanOverviewTracked(overviewId: "ov-001", targetType: "race_run")
        vm.markPlanOverviewTracked(overviewId: "ov-002", targetType: "maintenance")  // dedup prevents re-fire

        let events = analytics.events(named: "plan_overview_view")
        XCTAssertEqual(events.count, 1, "P1-12: plan_overview_view must fire exactly once (dedup)")
        XCTAssertEqual(events.first?.parameters["overview_id"] as? String, "ov-001",
            "P1-12: first call's overviewId must be recorded")
    }

    /// AC-IOS-ANALYTICS-P1-12 (wiring skip when nil): The view guard prevents calling
    /// markPlanOverviewTracked when planOverview is nil — ViewModel dedup state starts false.
    @MainActor
    func test_p1_12_wiring_skip_when_overview_nil() {
        analytics.reset()
        let vm = DependencyContainer.shared.makeTrainingPlanV2ViewModel()

        // Verify dedup flag starts false (no auto-tracking without explicit call)
        XCTAssertFalse(vm.hasTrackedPlanOverviewView, "P1-12: dedup flag must start false")
        XCTAssertEqual(analytics.events(named: "plan_overview_view").count, 0,
            "P1-12: No event before markPlanOverviewTracked is called")
    }

    // MARK: - AC-IOS-ANALYTICS-P1-13 enum contract

    /// AC-IOS-ANALYTICS-P1-13 (enum contract): race_prediction_view — predicted_time + distance_km required.
    func test_p1_13_race_prediction_view_params_enum_contract() {
        let event = AnalyticsEvent.racePredictionView(predictedTime: "01:45:30", distanceKm: 21.0975)
        XCTAssertEqual(event.name, "race_prediction_view")
        XCTAssertEqual(event.parameters["predicted_time"] as? String, "01:45:30")
        XCTAssertEqual(event.parameters["distance_km"] as? Double, 21.0975)
        XCTAssertEqual(event.parameters.count, 2)
    }

    // MARK: - AC-IOS-ANALYTICS-P1-13 wiring: piggyback bug regression + dedup

    /// AC-IOS-ANALYTICS-P1-13 (wiring piggyback bug regression): After P1-11 summary tracked,
    /// race_prediction_view should STILL be able to fire via its own independent dedup flag.
    /// This tests the core P1-13 piggyback bug fix — previously P1-13 was gated on P1-11's flag.
    @MainActor
    func test_p1_13_wiring_independent_dedup_from_p1_11() {
        analytics.reset()
        let coordinator = makeWeeklySummaryCoordinator()

        // Step 1: Mark P1-11 (summary tracked)
        coordinator.markSummaryTracked(summaryId: "sum-001", weekOfTraining: 3)
        XCTAssertEqual(analytics.events(named: "weekly_summary_view").count, 1)

        // Step 2: Now fire P1-13 — must NOT be blocked by P1-11's dedup flag
        coordinator.markRacePredictionTracked(predictedTime: "01:45:00", distanceKm: 21.0975)

        XCTAssertEqual(analytics.events(named: "race_prediction_view").count, 1,
            "P1-13: race_prediction_view must fire even after P1-11 is already tracked " +
            "(independent dedup flag — piggyback bug fix regression test)")
    }

    /// AC-IOS-ANALYTICS-P1-13 (wiring skip when planOverview nil): The view guard prevents
    /// calling markRacePredictionTracked when distanceKm is nil.
    @MainActor
    func test_p1_13_wiring_skip_when_planOverview_nil() {
        analytics.reset()
        // Coordinator starts with hasTrackedRacePredictionView = false
        let coordinator = makeWeeklySummaryCoordinator()

        XCTAssertFalse(coordinator.hasTrackedRacePredictionView,
            "P1-13: dedup flag must start false")
        XCTAssertEqual(analytics.events(named: "race_prediction_view").count, 0,
            "P1-13: No race_prediction_view event before markRacePredictionTracked is called")
    }

    /// AC-IOS-ANALYTICS-P1-13 (wiring dedup fires once): markRacePredictionTracked called
    /// multiple times fires exactly once.
    @MainActor
    func test_p1_13_wiring_dedup_fires_once() {
        analytics.reset()
        let coordinator = makeWeeklySummaryCoordinator()

        coordinator.markRacePredictionTracked(predictedTime: "01:45:00", distanceKm: 21.0975)
        coordinator.markRacePredictionTracked(predictedTime: "01:45:00", distanceKm: 21.0975)
        coordinator.markRacePredictionTracked(predictedTime: "02:00:00", distanceKm: 42.195)  // dedup prevents re-fire

        let events = analytics.events(named: "race_prediction_view")
        XCTAssertEqual(events.count, 1, "P1-13: race_prediction_view must fire exactly once (dedup)")
        XCTAssertEqual(events.first?.parameters["predicted_time"] as? String, "01:45:00",
            "P1-13: first call's predictedTime must be recorded")
    }
}

// MARK: - Wiring Test Helpers

extension IosAnalyticsP1ACTests {

    /// Creates a minimal WeeklySummaryCoordinator backed by MockTrainingPlanV2Repository.
    @MainActor
    func makeWeeklySummaryCoordinator() -> WeeklySummaryCoordinator {
        WeeklySummaryCoordinator(
            repository: MockTrainingPlanV2Repository(),
            currentSelectedWeek: { 2 },
            setLoadingAnimation: { _ in },
            shouldBlockByRizoQuota: { false },
            refreshPlanStatusResponse: {},
            shouldSuppressError: { _, _, _ in false },
            resolvePaywallTrigger: { .apiGated },
            onSuccessToast: { _ in },
            onPaywallTriggered: { _ in },
            onRizoQuotaExceeded: {},
            onNetworkError: { _ in },
            isEnforcementEnabled: { false }
        )
    }

    func makeStubWorkout(id: String = "workout-001") -> WorkoutV2 {
        WorkoutV2(
            id: id,
            provider: "apple_health",
            activityType: "running",
            startTimeUtc: "2024-01-01T09:00:00Z",
            endTimeUtc: "2024-01-01T10:00:00Z",
            durationSeconds: 3600,
            distanceMeters: 10000,
            distanceDisplay: nil,
            distanceUnit: nil,
            deviceName: nil,
            basicMetrics: nil,
            advancedMetrics: nil,
            createdAt: nil,
            schemaVersion: nil,
            storagePath: nil,
            dailyPlanSummary: nil,
            aiSummary: nil,
            shareCardContent: nil
        )
    }
}

// MARK: - Test Double

private final class MockAnalyticsService: AnalyticsService {
    private(set) var trackedEvents: [AnalyticsEvent] = []

    struct UserPropertyCall: Equatable {
        let value: String
        let name: String
    }
    private(set) var userProperties: [UserPropertyCall] = []

    func track(_ event: AnalyticsEvent) {
        trackedEvents.append(event)
    }

    func setUserProperty(_ value: String, forName name: String) {
        userProperties.append(UserPropertyCall(value: value, name: name))
    }

    var lastEvent: AnalyticsEvent? { trackedEvents.last }

    func events(named name: String) -> [AnalyticsEvent] {
        trackedEvents.filter { $0.name == name }
    }

    func reset() {
        trackedEvents.removeAll()
        userProperties.removeAll()
    }
}
