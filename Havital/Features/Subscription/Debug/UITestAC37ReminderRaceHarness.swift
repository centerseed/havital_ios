#if DEBUG
import Foundation
import SwiftUI
import Combine

// MARK: - Constants

/// 90-day offset in seconds for building "churned user" subscribedAt fixture values.
let AC37SubscribedAtChurnedFixture: TimeInterval = Date().addingTimeInterval(-7_776_000).timeIntervalSince1970

// MARK: - UITestAC37 Scenario

/// Selects which AC-PAYWALL-37 cohort to simulate.
/// Set via launch environment variable UITEST_AC37_SCENARIO.
enum UITestAC37Scenario: String {
    /// Churned user with existing Week 1 plan — original race condition test.
    /// subscribedAt != nil, planOverview returns success after delay.
    case expiredWithPlan = "expired_with_plan"
    /// True new user: subscribedAt = nil, plan API returns 404.
    /// Expected: no banner (no plan), no dialog (never subscribed).
    case newUserNoPlan = "new_user_no_plan"
    /// Churned user without plan: subscribedAt != nil, plan API returns 404.
    /// Expected: no banner (no plan), dialog shown (previously subscribed).
    case churnedUserNoPlan = "churned_user_no_plan"

    static func current() -> UITestAC37Scenario {
        let raw = ProcessInfo.processInfo.environment["UITEST_AC37_SCENARIO"] ?? ""
        return UITestAC37Scenario(rawValue: raw) ?? .expiredWithPlan
    }
}

// MARK: - UITestAC37ReminderRaceHarness
//
// Harness for reproducing AC-PAYWALL-37: the race between the expired-subscription
// dialog and FreeTierBanner appearing simultaneously on cold start.
//
// Setup:
//   subscription_status = expired  (enforcement enabled)
//   planOverview present in backend but getCachedOverview() returns nil on first call
//   → simulates the cache not yet populated when ContentView.onAppear fires
//
// Race steps reproduced:
//   1. ContentView.onAppear → checkAndShowReminder(hasGeneratedTrainingPlan: false) → dialog queued
//   2. WeeklyPlanLoader calls getOverview() → repo fetches, saves to cache, fires overviewDidUpdate
//   3. ContentView.onReceive(overviewUpdatePublisher) → re-evaluate → pendingReminder = nil
//   4. EXPECTED: only FreeTierBanner visible, no alert
//   5. BUG (pre-fix): step 3 either doesn't fire or fires too late, alert stays up

enum UITestAC37ReminderRaceHarness {
    static func registerDependencies() {
        let scenario = UITestAC37Scenario.current()
        DependencyContainer.shared.replace(
            UITestAC37MockSubscriptionRepository(scenario: scenario) as SubscriptionRepository,
            for: SubscriptionRepository.self
        )
        DependencyContainer.shared.replace(
            UITestAC37MockTrainingPlanV2Repository(scenario: scenario) as TrainingPlanV2Repository,
            for: TrainingPlanV2Repository.self
        )
    }
}

// MARK: - Mock Subscription Repository

/// Returns `expired` with enforcement enabled.
/// subscribedAt is nil for new users (never subscribed), non-nil for churned users.
private final class UITestAC37MockSubscriptionRepository: SubscriptionRepository {
    private let expiredStatus: SubscriptionStatusEntity

    init(scenario: UITestAC37Scenario) {
        // Churned user: has a past subscribedAt. New user: nil.
        let subscribedAt: TimeInterval? = scenario == .newUserNoPlan
            ? nil
            : AC37SubscribedAtChurnedFixture

        expiredStatus = SubscriptionStatusEntity(
            status: .expired,
            expiresAt: Date().addingTimeInterval(-3600).timeIntervalSince1970,
            billingIssue: false,
            enforcementEnabled: true,
            subscribedAt: subscribedAt
        )
    }

    func getStatus() async throws -> SubscriptionStatusEntity { expiredStatus }
    func refreshStatus() async throws -> SubscriptionStatusEntity { expiredStatus }
    func getCachedStatus() -> SubscriptionStatusEntity? { expiredStatus }
    func clearCache() {}
    func fetchOfferings() async throws -> [SubscriptionOfferingEntity] { [] }

    func purchase(request: SubscriptionPurchaseRequest) async throws -> PurchaseResultEntity {
        .cancelled
    }

    func redeemOfferCode() async throws -> PurchaseResultEntity {
        .pendingProcessing
    }

    func restorePurchases() async throws {}
}

// MARK: - Mock TrainingPlanV2 Repository

/// Simulates a repository where:
/// - getCachedOverview() returns nil initially (cache cold at cold start)
/// - getOverview() behaviour depends on scenario:
///     .expiredWithPlan → succeeds after delay (fires overviewDidUpdate)
///     .newUserNoPlan / .churnedUserNoPlan → throws .notFound (no overview at all)
final class UITestAC37MockTrainingPlanV2Repository: TrainingPlanV2Repository {

    // MARK: - overviewDidUpdate publisher (AC-PAYWALL-37 protocol requirement)
    // The subject fires once after getOverview() completes, simulating the plan loader
    // writing to local cache and notifying Presentation layer subscribers.
    private let overviewSubject = PassthroughSubject<PlanOverviewV2, Never>()

    var overviewDidUpdate: AnyPublisher<PlanOverviewV2, Never> {
        overviewSubject.eraseToAnyPublisher()
    }

    // MARK: - State

    private let scenario: UITestAC37Scenario

    // getCachedOverview() starts as nil to reproduce the cold-start race.
    // After getOverview() fires overviewDidUpdate, the cache is considered populated.
    private var cachedOverview: PlanOverviewV2? = nil

    // Delay (in seconds) before the overview is "loaded" — long enough to let
    // ContentView.onAppear fire first, short enough to be caught by the UITest.
    private let loadDelaySeconds: Double = 0.6

    init(scenario: UITestAC37Scenario = .expiredWithPlan) {
        self.scenario = scenario
    }

    // MARK: - Plan Status

    func getPlanStatus(forceRefresh: Bool) async throws -> PlanStatusV2Response {
        // No-plan scenarios: throw .notFound so WeeklyPlanLoader sets .noPlan
        if scenario == .newUserNoPlan || scenario == .churnedUserNoPlan {
            throw DomainError.notFound("no active plan")
        }
        return PlanStatusV2Response(
            currentWeek: 1,
            totalWeeks: 12,
            nextAction: "view_plan",
            canGenerateNextWeek: false,
            currentWeekPlanId: "ac37_test_week_1",
            previousWeekSummaryId: nil,
            targetType: "maintenance",
            methodologyId: "paceriz",
            nextWeekInfo: nil,
            metadata: nil
        )
    }

    // MARK: - Methodologies / Target Types

    func getTargetTypes() async throws -> [TargetTypeV2] { [] }
    func getMethodologies(targetType: String?) async throws -> [MethodologyV2] { [] }

    // MARK: - Plan Overview

    func createOverviewForRace(targetId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2 {
        makeStubOverview()
    }

    func createOverviewForNonRace(
        targetType: String,
        trainingWeeks: Int,
        availableDays: Int?,
        methodologyId: String?,
        startFromStage: String?,
        intendedRaceDistanceKm: Int?
    ) async throws -> PlanOverviewV2 {
        makeStubOverview()
    }

    /// Key method: simulates a fetch that happens AFTER onAppear.
    ///
    /// - .expiredWithPlan: succeeds after delay and fires overviewDidUpdate (plan exists).
    /// - .newUserNoPlan / .churnedUserNoPlan: throws .notFound after delay so
    ///   WeeklyPlanLoader calls PlanOverviewObserver.shared.confirmNoPlan().
    func getOverview() async throws -> PlanOverviewV2 {
        // Simulate realistic network/cache latency — must be > 0 so onAppear fires first
        try await Task.sleep(nanoseconds: UInt64(loadDelaySeconds * 1_000_000_000))

        if scenario == .newUserNoPlan || scenario == .churnedUserNoPlan {
            // No plan: WeeklyPlanLoader catches this and calls confirmNoPlan()
            throw DomainError.notFound("no overview for user")
        }

        let overview = makeStubOverview()
        await MainActor.run { [weak self] in
            guard let self else { return }
            self.cachedOverview = overview
            // This is the critical event: triggers ContentView.onReceive(overviewUpdatePublisher)
            self.overviewSubject.send(overview)
        }
        return overview
    }

    func refreshOverview() async throws -> PlanOverviewV2 {
        try await getOverview()
    }

    func updateOverview(overviewId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2 {
        makeStubOverview()
    }

    // MARK: - Weekly Plan

    func generateWeeklyPlan(
        weekOfTraining: Int,
        forceGenerate: Bool?,
        promptVersion: String?,
        methodology: String?
    ) async throws -> WeeklyPlanV2 {
        makeStubWeeklyPlan(week: weekOfTraining)
    }

    func getWeeklyPlan(weekOfTraining: Int, overviewId: String) async throws -> WeeklyPlanV2 {
        makeStubWeeklyPlan(week: weekOfTraining)
    }

    func fetchWeeklyPlan(planId: String) async throws -> WeeklyPlanV2 {
        makeStubWeeklyPlan(week: 1)
    }

    func updateWeeklyPlan(planId: String, updates: UpdateWeeklyPlanRequest) async throws -> WeeklyPlanV2 {
        makeStubWeeklyPlan(week: 1)
    }

    func refreshWeeklyPlan(weekOfTraining: Int, overviewId: String) async throws -> WeeklyPlanV2 {
        makeStubWeeklyPlan(week: weekOfTraining)
    }

    func deleteWeeklyPlan(planId: String) async throws {}

    // MARK: - Weekly Preview / Summary

    func getWeeklyPreview(overviewId: String) async throws -> WeeklyPreviewV2 {
        WeeklyPreviewV2(id: overviewId, methodologyId: "paceriz", weeks: [], createdAt: nil, updatedAt: nil)
    }

    func generateWeeklySummary(weekOfPlan: Int, forceUpdate: Bool?) async throws -> WeeklySummaryV2 {
        makeStubWeeklySummary(week: weekOfPlan)
    }

    func getWeeklySummaries() async throws -> [WeeklySummaryItem] { [] }

    func getWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2 {
        makeStubWeeklySummary(week: weekOfPlan)
    }

    func refreshWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2 {
        makeStubWeeklySummary(week: weekOfPlan)
    }

    func applyAdjustmentItems(weekOfPlan: Int, appliedIndices: [Int]) async throws {}

    func deleteWeeklySummary(summaryId: String) async throws {}

    // MARK: - Synchronous Cache (critical for race reproduction)

    /// Returns nil until getOverview() fires overviewDidUpdate.
    /// This is what causes the race: onAppear reads nil → dialog fires.
    func getCachedPlanStatus() -> PlanStatusV2Response? { nil }
    func getCachedOverview() -> PlanOverviewV2? { cachedOverview }
    func getCachedWeeklyPlan(week: Int) -> WeeklyPlanV2? { nil }

    // MARK: - Cache Management

    func clearCache() async {}
    func clearOverviewCache() async {}
    func clearWeeklyPlanCache(weekOfTraining: Int?) async {}
    func clearWeeklySummaryCache(weekOfPlan: Int?) async {}

    func preloadData() async {
        // Trigger the same path as the real repo: fetch overview in background
        Task.detached(priority: .background) { [weak self] in
            _ = try? await self?.getOverview()
        }
    }

    // MARK: - Stub Factories

    private func makeStubOverview() -> PlanOverviewV2 {
        PlanOverviewV2(
            id: "ac37_test_overview",
            targetId: nil,
            targetType: "maintenance",
            targetDescription: "AC37 UITest overview",
            methodologyId: "paceriz",
            totalWeeks: 12,
            startFromStage: "base",
            raceDate: nil,
            distanceKm: nil,
            distanceKmDisplay: nil,
            distanceUnit: nil,
            targetPace: nil,
            targetTime: nil,
            isMainRace: nil,
            targetName: "AC37 Test Plan",
            methodologyOverview: nil,
            targetEvaluate: nil,
            approachSummary: nil,
            trainingStages: [
                TrainingStageV2(
                    stageId: "base",
                    stageName: "Base",
                    stageDescription: "AC37 base training",
                    weekStart: 1,
                    weekEnd: 12,
                    trainingFocus: "Easy runs",
                    targetWeeklyKmRange: TargetWeeklyKmRangeV2(low: 20, high: 30),
                    targetWeeklyKmRangeDisplay: nil,
                    intensityRatio: nil,
                    keyWorkouts: nil
                )
            ],
            milestones: [],
            createdAt: Date(),
            methodologyVersion: nil,
            milestoneBasis: nil
        )
    }

    private func makeStubWeeklyPlan(week: Int) -> WeeklyPlanV2 {
        WeeklyPlanV2(
            planId: "ac37_test_overview_\(week)",
            weekOfTraining: week,
            id: "ac37_test_overview_\(week)",
            purpose: "AC37 UITest plan",
            weekOfPlan: week,
            totalWeeks: 12,
            totalDistance: 30,
            totalDistanceDisplay: nil,
            totalDistanceUnit: nil,
            totalDistanceReason: nil,
            designReason: nil,
            days: [],
            intensityTotalMinutes: nil,
            createdAt: Date(),
            updatedAt: Date(),
            trainingLoadAnalysis: nil,
            personalizedRecommendations: nil,
            realTimeAdjustments: nil,
            apiVersion: "2.0"
        )
    }

    private func makeStubWeeklySummary(week: Int) -> WeeklySummaryV2 {
        WeeklySummaryV2(
            id: "ac37_summary_\(week)",
            uid: "ac37-test-user",
            weeklyPlanId: "ac37_test_overview_\(week)",
            trainingOverviewId: "ac37_test_overview",
            weekOfTraining: week,
            createdAt: Date(),
            planContext: nil,
            trainingCompletion: TrainingCompletionV2(
                percentage: 0.8,
                plannedKm: 30,
                completedKm: 24,
                plannedSessions: 5,
                completedSessions: 4,
                evaluation: "Good"
            ),
            trainingAnalysis: TrainingAnalysisV2(
                heartRate: nil,
                pace: nil,
                distance: DistanceAnalysisV2(
                    total: 24,
                    comparisonToPlan: "On track",
                    longRunCompleted: true,
                    evaluation: "Good"
                ),
                intensityDistribution: IntensityDistributionAnalysisV2(
                    easyPercentage: 70,
                    moderatePercentage: 20,
                    hardPercentage: 10,
                    targetDistribution: "80/10/10",
                    evaluation: "Good"
                )
            ),
            readinessSummary: nil,
            capabilityProgression: nil,
            milestoneProgress: nil,
            historicalComparison: nil,
            weeklyHighlights: WeeklyHighlightsV2(
                highlights: ["AC37 UITest"],
                achievements: [],
                areasForImprovement: []
            ),
            upcomingRaceEvaluation: nil,
            nextWeekAdjustments: NextWeekAdjustmentsV2(
                items: [],
                summary: "No adjustments",
                methodologyConstraintsConsidered: true,
                basedOnFlags: []
            ),
            restWeekRecommendation: nil,
            finalTrainingReview: nil,
            promptAuditId: nil
        )
    }
}
#endif
