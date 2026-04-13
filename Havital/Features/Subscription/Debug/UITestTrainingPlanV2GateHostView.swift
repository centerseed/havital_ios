#if DEBUG
import SwiftUI
import Foundation

enum UITestTrainingPlanV2GateHarness {
    static func registerDependencies() {
        DependencyContainer.shared.replace(
            UITestTrainingPlanV2GateRepository() as TrainingPlanV2Repository,
            for: TrainingPlanV2Repository.self
        )
        DependencyContainer.shared.replace(
            UITestTrainingPlanV2GateSubscriptionRepository() as SubscriptionRepository,
            for: SubscriptionRepository.self
        )
    }
}

private enum UITestGateErrorKind {
    case none
    case subscriptionRequired
    case trialExpired
    case forbidden
    case serverError

    static func fromEnvironment(_ key: String) -> UITestGateErrorKind {
        let raw = ProcessInfo.processInfo.environment[key]?.lowercased() ?? "none"
        switch raw {
        case "subscription_required":
            return .subscriptionRequired
        case "trial_expired":
            return .trialExpired
        case "forbidden":
            return .forbidden
        case "server_error":
            return .serverError
        default:
            return .none
        }
    }

    func toDomainError(message: String) -> DomainError {
        switch self {
        case .none:
            return .unknown("UITest error kind should not map when .none")
        case .subscriptionRequired:
            return .subscriptionRequired
        case .trialExpired:
            return .trialExpired
        case .forbidden:
            return .forbidden
        case .serverError:
            return .serverError(500, message)
        }
    }
}

private final class UITestTrainingPlanV2GateRepository: TrainingPlanV2Repository {
    private let generatePlanError = UITestGateErrorKind.fromEnvironment("UITEST_TPV2_GENERATE_PLAN_ERROR")
    private let generateSummaryError = UITestGateErrorKind.fromEnvironment("UITEST_TPV2_GENERATE_SUMMARY_ERROR")
    private let updateOverviewError = UITestGateErrorKind.fromEnvironment("UITEST_TPV2_UPDATE_OVERVIEW_ERROR")

    func getPlanStatus() async throws -> PlanStatusV2Response {
        PlanStatusV2Response(
            currentWeek: 1,
            totalWeeks: 12,
            nextAction: "create_plan",
            canGenerateNextWeek: true,
            currentWeekPlanId: nil,
            previousWeekSummaryId: nil,
            targetType: "maintenance",
            methodologyId: "paceriz",
            nextWeekInfo: nil,
            metadata: nil
        )
    }

    func getTargetTypes() async throws -> [TargetTypeV2] { [] }

    func getMethodologies(targetType: String?) async throws -> [MethodologyV2] { [] }

    func createOverviewForRace(targetId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2 {
        stubOverview()
    }

    func createOverviewForNonRace(
        targetType: String,
        trainingWeeks: Int,
        availableDays: Int?,
        methodologyId: String?,
        startFromStage: String?,
        intendedRaceDistanceKm: Int?
    ) async throws -> PlanOverviewV2 {
        stubOverview()
    }

    func getOverview() async throws -> PlanOverviewV2 {
        stubOverview()
    }

    func refreshOverview() async throws -> PlanOverviewV2 {
        stubOverview()
    }

    func updateOverview(overviewId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2 {
        if updateOverviewError != .none {
            throw updateOverviewError.toDomainError(message: "UITest updateOverview forced error")
        }
        return stubOverview()
    }

    func generateWeeklyPlan(
        weekOfTraining: Int,
        forceGenerate: Bool?,
        promptVersion: String?,
        methodology: String?
    ) async throws -> WeeklyPlanV2 {
        if generatePlanError != .none {
            throw generatePlanError.toDomainError(message: "UITest generateWeeklyPlan forced error")
        }
        return stubWeeklyPlan(week: weekOfTraining)
    }

    func getWeeklyPlan(weekOfTraining: Int, overviewId: String) async throws -> WeeklyPlanV2 {
        stubWeeklyPlan(week: weekOfTraining)
    }

    func fetchWeeklyPlan(planId: String) async throws -> WeeklyPlanV2 {
        stubWeeklyPlan(week: 1)
    }

    func updateWeeklyPlan(planId: String, updates: UpdateWeeklyPlanRequest) async throws -> WeeklyPlanV2 {
        stubWeeklyPlan(week: 1)
    }

    func refreshWeeklyPlan(weekOfTraining: Int, overviewId: String) async throws -> WeeklyPlanV2 {
        stubWeeklyPlan(week: weekOfTraining)
    }

    func deleteWeeklyPlan(planId: String) async throws {}

    func getWeeklyPreview(overviewId: String) async throws -> WeeklyPreviewV2 {
        WeeklyPreviewV2(id: overviewId, methodologyId: "paceriz", weeks: [], createdAt: nil, updatedAt: nil)
    }

    func generateWeeklySummary(weekOfPlan: Int, forceUpdate: Bool?) async throws -> WeeklySummaryV2 {
        if generateSummaryError != .none {
            throw generateSummaryError.toDomainError(message: "UITest generateWeeklySummary forced error")
        }
        return stubWeeklySummary(week: weekOfPlan)
    }

    func getWeeklySummaries() async throws -> [WeeklySummaryItem] { [] }

    func getWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2 {
        stubWeeklySummary(week: weekOfPlan)
    }

    func refreshWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2 {
        stubWeeklySummary(week: weekOfPlan)
    }

    func deleteWeeklySummary(summaryId: String) async throws {}

    func getCachedPlanStatus() -> PlanStatusV2Response? { nil }

    func getCachedOverview() -> PlanOverviewV2? { nil }

    func getCachedWeeklyPlan(week: Int) -> WeeklyPlanV2? { nil }

    func clearCache() async {}

    func clearOverviewCache() async {}

    func clearWeeklyPlanCache(weekOfTraining: Int?) async {}

    func clearWeeklySummaryCache(weekOfPlan: Int?) async {}

    func preloadData() async {}

    private func stubOverview() -> PlanOverviewV2 {
        PlanOverviewV2(
            id: "ui_test_overview",
            targetId: nil,
            targetType: "maintenance",
            targetDescription: "UITest overview",
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
            targetName: "UITest Plan",
            methodologyOverview: nil,
            targetEvaluate: nil,
            approachSummary: nil,
            trainingStages: [
                TrainingStageV2(
                    stageId: "base",
                    stageName: "Base",
                    stageDescription: "Base training",
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

    private func stubWeeklyPlan(week: Int) -> WeeklyPlanV2 {
        WeeklyPlanV2(
            planId: "ui_test_overview_\(week)",
            weekOfTraining: week,
            id: "ui_test_overview_\(week)",
            purpose: "UITest plan",
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

    private func stubWeeklySummary(week: Int) -> WeeklySummaryV2 {
        WeeklySummaryV2(
            id: "summary_\(week)",
            uid: "ui-test-user",
            weeklyPlanId: "ui_test_overview_\(week)",
            trainingOverviewId: "ui_test_overview",
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
                highlights: ["UITest"],
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

private final class UITestTrainingPlanV2GateSubscriptionRepository: SubscriptionRepository {
    private var status = SubscriptionStatusEntity(status: .active)

    func getStatus() async throws -> SubscriptionStatusEntity {
        status
    }

    func refreshStatus() async throws -> SubscriptionStatusEntity {
        status
    }

    func getCachedStatus() -> SubscriptionStatusEntity? {
        status
    }

    func clearCache() {}

    func fetchOfferings() async throws -> [SubscriptionOfferingEntity] { [] }

    func purchase(offeringId: String, packageId: String) async throws -> PurchaseResultEntity {
        .cancelled
    }

    func restorePurchases() async throws {}
}

struct UITestTrainingPlanV2GateHostView: View {
    @State private var viewModel = TrainingPlanV2ViewModel()
    @State private var lastAction = "idle"

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        VStack(spacing: 16) {
            Text("UITest TrainingPlanV2 Gate Host")
                .font(.headline)
                .accessibilityIdentifier("UITest_TPV2_HostTitle")

            Text("trigger:\(String(describing: viewModel.paywallTrigger))")
                .font(.subheadline)
                .accessibilityIdentifier("UITest_TPV2_PaywallTriggerLabel")

            Text("last_action:\(lastAction)")
                .font(.subheadline)
                .accessibilityIdentifier("UITest_TPV2_LastActionLabel")

            Button("Generate Weekly Plan") {
                lastAction = "running_generate_plan"
                Task {
                    await viewModel.generateCurrentWeekPlan()
                    lastAction = "done_generate_plan"
                }
            }
            .accessibilityIdentifier("UITest_TPV2_GeneratePlanButton")

            Button("Generate Weekly Summary") {
                lastAction = "running_generate_summary"
                Task {
                    await viewModel.generateWeeklySummary()
                    lastAction = "done_generate_summary"
                }
            }
            .accessibilityIdentifier("UITest_TPV2_GenerateSummaryButton")

            Button("Regenerate Overview") {
                lastAction = "running_regenerate_overview"
                Task {
                    await viewModel.updateOverview(startFromStage: "base")
                    lastAction = "done_regenerate_overview"
                }
            }
            .accessibilityIdentifier("UITest_TPV2_RegenerateOverviewButton")
        }
        .padding(24)
        .onAppear {
            if viewModel.planOverview == nil {
                viewModel.planOverview = UITestTrainingPlanV2GateRepository().getCachedOverview()
                    ?? PlanOverviewV2(
                        id: "ui_test_overview",
                        targetId: nil,
                        targetType: "maintenance",
                        targetDescription: "UITest overview",
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
                        targetName: "UITest Plan",
                        methodologyOverview: nil,
                        targetEvaluate: nil,
                        approachSummary: nil,
                        trainingStages: [],
                        milestones: [],
                        createdAt: Date(),
                        methodologyVersion: nil,
                        milestoneBasis: nil
                    )
            }
        }
        .sheet(item: $bindableViewModel.paywallTrigger) { trigger in
            PaywallView(trigger: trigger)
        }
    }
}
#endif
