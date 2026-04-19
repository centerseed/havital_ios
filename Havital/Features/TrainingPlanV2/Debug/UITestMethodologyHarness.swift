#if DEBUG
import Combine
import Foundation
import SwiftUI

enum UITestMethodologyHarness {
    private static var sharedState = State()

    fileprivate static var state: State {
        sharedState
    }

    static func registerDependencies() {
        do {
            let context = try UITestMethodologyContext.loadFromEnvironment()
            let repository = UITestMethodologyTrainingPlanRepository(context: context)

            sharedState = State(context: context, bootError: nil)

            DependencyContainer.shared.replace(
                repository as TrainingPlanV2Repository,
                for: TrainingPlanV2Repository.self
            )
            DependencyContainer.shared.replace(
                UITestMethodologyTargetRepository(targets: context.targets) as TargetRepository,
                for: TargetRepository.self
            )
            DependencyContainer.shared.replace(
                UITestMethodologyWorkoutRepository() as WorkoutRepository,
                for: WorkoutRepository.self
            )
        } catch {
            let message = "Methodology harness bootstrap failed: \(error.localizedDescription)"
            sharedState = State(context: nil, bootError: message)

            DependencyContainer.shared.replace(
                UITestMethodologyTrainingPlanRepository(context: nil) as TrainingPlanV2Repository,
                for: TrainingPlanV2Repository.self
            )
            DependencyContainer.shared.replace(
                UITestMethodologyTargetRepository(targets: []) as TargetRepository,
                for: TargetRepository.self
            )
            DependencyContainer.shared.replace(
                UITestMethodologyWorkoutRepository() as WorkoutRepository,
                for: WorkoutRepository.self
            )
        }
    }

    fileprivate struct State {
        fileprivate let context: UITestMethodologyContext?
        fileprivate let bootError: String?

        fileprivate init(context: UITestMethodologyContext? = nil, bootError: String? = nil) {
            self.context = context
            self.bootError = bootError
        }
    }
}

struct UITestMethodologyHostView: View {
    @State private var selectedScreen: UITestMethodologyScreen
    @State private var viewModel = DependencyContainer.shared.makeTrainingPlanV2ViewModel()

    init() {
        _selectedScreen = State(initialValue: UITestMethodologyHarness.state.context?.initialScreen ?? .weekly)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let bootError = UITestMethodologyHarness.state.bootError {
                    errorView(message: bootError)
                } else if let context = UITestMethodologyHarness.state.context {
                    VStack(spacing: 12) {
                        header(context: context)

                        Picker("Methodology Screen", selection: $selectedScreen) {
                            ForEach(context.availableScreens, id: \.self) { screen in
                                Text(screen.title).tag(screen)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .accessibilityIdentifier("v2.harness.screen_picker")

                        screenView(context: context)
                    }
                    .padding(.vertical, 12)
                    .background(Color(UIColor.systemGroupedBackground))
                } else {
                    errorView(message: "Methodology harness has no fixture context.")
                }
            }
            .navigationTitle("Methodology Harness")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await viewModel.loader.initialize()
        }
    }

    @ViewBuilder
    private func header(context: UITestMethodologyContext) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(context.displayName)
                .font(AppFont.headline())
                .foregroundColor(.primary)
                .accessibilityIdentifier("v2.harness.fixture_name")

            Text(context.availableScreens.map(\.title).joined(separator: " / "))
                .font(AppFont.caption())
                .foregroundColor(.secondary)
                .accessibilityIdentifier("v2.harness.available_screens")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func screenView(context: UITestMethodologyContext) -> some View {
        switch selectedScreen {
        case .overview:
            if context.overview != nil {
                PlanOverviewSheetV2(
                    viewModel: viewModel,
                    initialTab: context.overviewInitialTab
                )
                    .accessibilityIdentifier("v2.harness.overview")
            } else {
                unavailableView(for: .overview)
            }

        case .weekly:
            if let weekly = context.weekly {
                ScrollView {
                    VStack(spacing: 24) {
                        TrainingProgressCardV2(viewModel: viewModel, plan: weekly)
                        WeekOverviewCardV2(viewModel: viewModel, plan: weekly)
                        WeekTimelineViewV2(viewModel: viewModel, plan: weekly)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .navigationTitle(viewModel.loader.trainingPlanName)
                .accessibilityIdentifier("v2.weekly.screen")
            } else {
                unavailableView(for: .weekly)
            }

        case .summary:
            if let summary = context.summary {
                WeeklySummaryV2View(viewModel: viewModel, weekOfPlan: summary.weekOfTraining)
                    .accessibilityIdentifier("v2.summary.screen")
            } else {
                unavailableView(for: .summary)
            }
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            Text(message)
                .font(AppFont.bodySmall())
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityIdentifier("v2.harness.error")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func unavailableView(for screen: UITestMethodologyScreen) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("\(screen.title) fixture unavailable")
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("v2.harness.unavailable")
    }
}

private enum UITestMethodologyScreen: String, CaseIterable {
    case overview
    case weekly
    case summary

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .weekly: return "Weekly"
        case .summary: return "Summary"
        }
    }
}

fileprivate struct UITestMethodologyContext {
    let overview: PlanOverviewV2?
    let weekly: WeeklyPlanV2?
    let summary: WeeklySummaryV2?
    let preview: WeeklyPreviewV2?
    let planStatus: PlanStatusV2Response
    let targetTypes: [TargetTypeV2]
    let methodologies: [MethodologyV2]
    let targets: [Target]
    let displayName: String
    let initialScreen: UITestMethodologyScreen
    let overviewInitialTab: Int

    var availableScreens: [UITestMethodologyScreen] {
        var screens: [UITestMethodologyScreen] = []
        if overview != nil { screens.append(.overview) }
        if weekly != nil { screens.append(.weekly) }
        if summary != nil { screens.append(.summary) }
        return screens
    }

    static func loadFromEnvironment() throws -> UITestMethodologyContext {
        let env = ProcessInfo.processInfo.environment

        let overviewRecord = try loadRecord(explicitPath: env["UITEST_METHODOLOGY_OVERVIEW_FIXTURE_PATH"])
        let weeklyRecord = try loadRecord(explicitPath: env["UITEST_METHODOLOGY_WEEKLY_FIXTURE_PATH"])
        let summaryRecord = try loadRecord(explicitPath: env["UITEST_METHODOLOGY_SUMMARY_FIXTURE_PATH"])

        let primaryRecord: FixtureRecord?
        if let path = env["UITEST_METHODOLOGY_FIXTURE_PATH"] {
            primaryRecord = try loadRecord(explicitPath: path)
        } else {
            primaryRecord = nil
        }

        let resolvedOverview = overviewRecord?.overview
            ?? primaryRecord?.overview
            ?? weeklyRecord?.makeSyntheticOverview(targetTypeHint: env["UITEST_METHODOLOGY_TARGET_TYPE"])
            ?? primaryRecord?.makeSyntheticOverview(targetTypeHint: env["UITEST_METHODOLOGY_TARGET_TYPE"])

        let resolvedWeekly = weeklyRecord?.weekly ?? primaryRecord?.weekly
        let resolvedSummary = summaryRecord?.summary ?? primaryRecord?.summary

        guard resolvedOverview != nil || resolvedWeekly != nil || resolvedSummary != nil else {
            throw HarnessError.missingFixture
        }

        let availableScreens: [UITestMethodologyScreen] = [
            resolvedOverview != nil ? .overview : nil,
            resolvedWeekly != nil ? .weekly : nil,
            resolvedSummary != nil ? .summary : nil,
        ].compactMap { $0 }

        let initialScreen = env["UITEST_METHODOLOGY_SCREEN"]
            .flatMap(UITestMethodologyScreen.init(rawValue:))
            .flatMap { availableScreens.contains($0) ? $0 : nil }
            ?? primaryRecord?.defaultScreen
            ?? overviewRecord?.defaultScreen
            ?? weeklyRecord?.defaultScreen
            ?? summaryRecord?.defaultScreen
            ?? availableScreens.first
            ?? .weekly

        let overviewInitialTab = min(
            max(Int(env["UITEST_METHODOLOGY_OVERVIEW_TAB"] ?? "0") ?? 0, 0),
            1
        )

        let overview = resolvedOverview
        let weekly = resolvedWeekly
        let summary = resolvedSummary

        let targetType = overview?.targetType
            ?? summary?.planContext?.targetType
            ?? inferTargetType(
                methodologyId: overview?.methodologyId ?? summary?.planContext?.methodologyId,
                fallback: env["UITEST_METHODOLOGY_TARGET_TYPE"]
            )

        let methodologyId = overview?.methodologyId
            ?? summary?.planContext?.methodologyId
            ?? weeklyRecord?.weeklyDTO?.methodologyId
            ?? primaryRecord?.weeklyDTO?.methodologyId
            ?? "paceriz"

        let totalWeeks = overview?.totalWeeks
            ?? summary?.planContext?.totalWeeks
            ?? weeklyRecord?.weeklyDTO?.totalWeeks
            ?? primaryRecord?.weeklyDTO?.totalWeeks
            ?? 12

        let currentWeek = weekly?.effectiveWeek
            ?? summary?.weekOfTraining
            ?? 1

        let planStatus = PlanStatusV2Response(
            currentWeek: currentWeek,
            totalWeeks: totalWeeks,
            nextAction: weekly != nil ? "view_plan" : "create_plan",
            canGenerateNextWeek: false,
            currentWeekPlanId: weekly?.effectivePlanId,
            previousWeekSummaryId: summary?.id,
            targetType: targetType,
            methodologyId: methodologyId,
            nextWeekInfo: nil,
            metadata: nil
        )

        let preview = makePreview(from: overview, currentWeek: currentWeek, methodologyId: methodologyId)
        let targetTypes = makeTargetTypes()
        let methodologies = makeMethodologies()
        let targets = makeTargets(from: overview)

        let displayName = [
            primaryRecord?.displayName,
            overviewRecord?.displayName,
            weeklyRecord?.displayName,
            summaryRecord?.displayName,
        ]
        .compactMap { $0 }
        .first
        ?? methodologyId

        return UITestMethodologyContext(
            overview: overview,
            weekly: weekly,
            summary: summary,
            preview: preview,
            planStatus: planStatus,
            targetTypes: targetTypes,
            methodologies: methodologies,
            targets: targets,
            displayName: displayName,
            initialScreen: initialScreen,
            overviewInitialTab: overviewInitialTab
        )
    }

    fileprivate static func inferTargetType(methodologyId: String?, fallback: String?) -> String {
        if let fallback, !fallback.isEmpty {
            return fallback
        }
        switch methodologyId {
        case "complete_10k":
            return "beginner"
        case "balanced_fitness", "aerobic_endurance":
            return "maintenance"
        default:
            return "race_run"
        }
    }

    private static func loadRecord(explicitPath: String?) throws -> FixtureRecord? {
        guard let explicitPath, !explicitPath.isEmpty else { return nil }
        return try FixtureRecord.load(from: URL(fileURLWithPath: explicitPath))
    }

    private static func makePreview(from overview: PlanOverviewV2?, currentWeek: Int, methodologyId: String) -> WeeklyPreviewV2? {
        guard let overview else { return nil }

        let weeks = (1...overview.totalWeeks).map { week -> WeekPreview in
            let stage = overview.trainingStages.first(where: { $0.contains(week: week) }) ?? overview.trainingStages.last
            return WeekPreview(
                week: week,
                stageId: stage?.stageId ?? overview.startFromStage ?? "base",
                targetKm: stage?.targetWeeklyKmRange.average ?? 40,
                targetKmDisplay: stage?.targetWeeklyKmRangeDisplay?.lowDisplay,
                distanceUnit: stage?.targetWeeklyKmRangeDisplay?.distanceUnit,
                isRecovery: week != currentWeek && (week % 4 == 0),
                milestoneRef: overview.milestones.first(where: { $0.week == week })?.title,
                intensityRatio: stage?.intensityRatio,
                qualityOptions: stage?.keyWorkouts ?? [],
                longRun: stage?.keyWorkouts?.first(where: { $0.contains("long") })
            )
        }

        return WeeklyPreviewV2(
            id: overview.id,
            methodologyId: methodologyId,
            weeks: weeks,
            createdAt: overview.createdAt,
            updatedAt: overview.createdAt
        )
    }

    private static func makeTargetTypes() -> [TargetTypeV2] {
        [
            TargetTypeV2(
                id: "race_run",
                name: "Specific Race",
                description: "Train toward a target race.",
                defaultMethodology: "paceriz",
                availableMethodologies: ["paceriz", "hansons", "norwegian", "polarized"]
            ),
            TargetTypeV2(
                id: "beginner",
                name: "Build Habit",
                description: "Progress gradually from low volume.",
                defaultMethodology: "complete_10k",
                availableMethodologies: ["complete_10k", "balanced_fitness"]
            ),
            TargetTypeV2(
                id: "maintenance",
                name: "Maintain Fitness",
                description: "Keep a sustainable running rhythm.",
                defaultMethodology: "aerobic_endurance",
                availableMethodologies: ["aerobic_endurance", "balanced_fitness", "paceriz"]
            ),
        ]
    }

    private static func makeMethodologies() -> [MethodologyV2] {
        [
            MethodologyV2(
                id: "paceriz",
                name: "Paceriz",
                description: "Balanced progression with structured phases.",
                targetTypes: ["race_run", "maintenance"],
                phases: ["base", "build", "peak", "taper"],
                crossTrainingEnabled: true
            ),
            MethodologyV2(
                id: "hansons",
                name: "Hansons",
                description: "Cumulative fatigue marathon method.",
                targetTypes: ["race_run"],
                phases: ["base", "build", "peak", "taper"],
                crossTrainingEnabled: false
            ),
            MethodologyV2(
                id: "norwegian",
                name: "Norwegian",
                description: "Threshold-focused progression.",
                targetTypes: ["race_run"],
                phases: ["base", "build", "peak", "taper"],
                crossTrainingEnabled: false
            ),
            MethodologyV2(
                id: "polarized",
                name: "Polarized",
                description: "Mostly easy running with focused hard work.",
                targetTypes: ["race_run", "maintenance"],
                phases: ["base", "build", "peak"],
                crossTrainingEnabled: true
            ),
            MethodologyV2(
                id: "complete_10k",
                name: "Complete 10K",
                description: "Conservative beginner progression.",
                targetTypes: ["beginner"],
                phases: ["conversion", "base"],
                crossTrainingEnabled: true
            ),
            MethodologyV2(
                id: "balanced_fitness",
                name: "Balanced Fitness",
                description: "General fitness maintenance.",
                targetTypes: ["beginner", "maintenance"],
                phases: ["base", "build"],
                crossTrainingEnabled: true
            ),
            MethodologyV2(
                id: "aerobic_endurance",
                name: "Aerobic Endurance",
                description: "Steady aerobic development.",
                targetTypes: ["maintenance"],
                phases: ["base", "build"],
                crossTrainingEnabled: true
            ),
        ]
    }

    private static func makeTargets(from overview: PlanOverviewV2?) -> [Target] {
        guard let overview else { return [] }
        guard overview.isRaceRunTarget else { return [] }

        return [
            Target(
                id: overview.targetId ?? "ui_test_target",
                type: overview.targetType,
                name: overview.targetName ?? "UI Test Target",
                distanceKm: Int(overview.distanceKm ?? 42.195),
                targetTime: overview.targetTime ?? 14_400,
                targetPace: overview.targetPace ?? "5:30",
                raceDate: overview.raceDate ?? Int(Date().addingTimeInterval(60 * 60 * 24 * 90).timeIntervalSince1970),
                isMainRace: overview.isMainRace ?? true,
                trainingWeeks: overview.totalWeeks,
                timezone: "Asia/Taipei"
            )
        ]
    }
}

private struct FixtureRecord {
    let url: URL
    let kind: UITestMethodologyScreen
    let overview: PlanOverviewV2?
    let weekly: WeeklyPlanV2?
    let summary: WeeklySummaryV2?
    let weeklyDTO: WeeklyPlanV2DTO?

    var displayName: String {
        url.deletingPathExtension().lastPathComponent
    }

    var defaultScreen: UITestMethodologyScreen {
        kind
    }

    static func load(from url: URL) throws -> FixtureRecord {
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data)
        guard let object = json as? [String: Any] else {
            throw HarnessError.invalidFixture("Fixture root must be a JSON object: \(url.lastPathComponent)")
        }

        let decoder = JSONDecoder()

        if object["training_stages"] != nil {
            let dto = try decoder.decode(PlanOverviewV2DTO.self, from: data)
            return FixtureRecord(
                url: url,
                kind: .overview,
                overview: PlanOverviewV2Mapper.toEntity(from: dto),
                weekly: nil,
                summary: nil,
                weeklyDTO: nil
            )
        }

        if object["days"] != nil {
            let dto = try decoder.decode(WeeklyPlanV2DTO.self, from: data)
            return FixtureRecord(
                url: url,
                kind: .weekly,
                overview: nil,
                weekly: WeeklyPlanV2Mapper.toEntity(from: dto),
                summary: nil,
                weeklyDTO: dto
            )
        }

        if object["training_completion"] != nil {
            let dto = try decoder.decode(WeeklySummaryV2DTO.self, from: data)
            return FixtureRecord(
                url: url,
                kind: .summary,
                overview: nil,
                weekly: nil,
                summary: WeeklySummaryV2Mapper.toEntity(from: dto),
                weeklyDTO: nil
            )
        }

        throw HarnessError.invalidFixture("Cannot infer fixture kind from \(url.lastPathComponent)")
    }

    func makeSyntheticOverview(targetTypeHint: String?) -> PlanOverviewV2? {
        guard let dto = weeklyDTO else { return nil }

        let methodologyId = dto.methodologyId ?? "paceriz"
        let stageId = dto.stageId ?? "base"
        let totalWeeks = dto.totalWeeks ?? max(dto.weekOfTraining ?? 1, dto.weekOfPlan ?? 1)
        let stageName = stageId.replacingOccurrences(of: "_", with: " ").capitalized

        return PlanOverviewV2(
            id: dto.overviewId ?? "ui_test_overview",
            targetId: nil,
            targetType: UITestMethodologyContext.inferTargetType(methodologyId: methodologyId, fallback: targetTypeHint),
            targetDescription: "UI test fixture overview",
            methodologyId: methodologyId,
            totalWeeks: totalWeeks,
            startFromStage: stageId,
            raceDate: nil,
            distanceKm: dto.totalDistance,
            distanceKmDisplay: dto.totalDistanceDisplay,
            distanceUnit: dto.totalDistanceUnit,
            targetPace: nil,
            targetTime: nil,
            isMainRace: nil,
            targetName: "\(methodologyId.capitalized) Fixture",
            methodologyOverview: methodologyOverview(for: methodologyId),
            targetEvaluate: "Synthetic overview generated for UI test harness.",
            approachSummary: dto.purpose,
            trainingStages: [
                TrainingStageV2(
                    stageId: stageId,
                    stageName: stageName,
                    stageDescription: dto.totalDistanceReason ?? dto.purpose,
                    weekStart: 1,
                    weekEnd: totalWeeks,
                    trainingFocus: dto.purpose,
                    targetWeeklyKmRange: TargetWeeklyKmRangeV2(
                        low: max(dto.totalDistance - 5, 1),
                        high: dto.totalDistance + 5
                    ),
                    targetWeeklyKmRangeDisplay: nil,
                    intensityRatio: nil,
                    keyWorkouts: dto.days.compactMap { day -> String? in
                        guard let primary = day.primary,
                              case .run(let run) = primary else { return nil }
                        return run.runType
                    }
                ),
            ],
            milestones: [],
            createdAt: nil,
            methodologyVersion: "ui-test",
            milestoneBasis: nil
        )
    }

    private func methodologyOverview(for methodologyId: String) -> MethodologyOverviewV2 {
        switch methodologyId {
        case "hansons":
            return MethodologyOverviewV2(
                name: "Hansons",
                philosophy: "Cumulative fatigue with controlled long runs.",
                intensityStyle: "threshold",
                intensityDescription: "High density quality sessions"
            )
        case "norwegian":
            return MethodologyOverviewV2(
                name: "Norwegian",
                philosophy: "Threshold progression with repeatable intensity.",
                intensityStyle: "threshold",
                intensityDescription: "Threshold-biased intensity"
            )
        case "polarized":
            return MethodologyOverviewV2(
                name: "Polarized",
                philosophy: "Mostly easy, some very hard.",
                intensityStyle: "polarized",
                intensityDescription: "80/0/20 style split"
            )
        case "complete_10k":
            return MethodologyOverviewV2(
                name: "Complete 10K",
                philosophy: "Build habit safely before quality work.",
                intensityStyle: "easy",
                intensityDescription: "Mostly easy aerobic minutes"
            )
        default:
            return MethodologyOverviewV2(
                name: "Paceriz",
                philosophy: "Balanced progression with structured phases.",
                intensityStyle: "balanced",
                intensityDescription: "Balanced intensity distribution"
            )
        }
    }
}

private final class UITestMethodologyTrainingPlanRepository: TrainingPlanV2Repository {
    private let context: UITestMethodologyContext?

    init(context: UITestMethodologyContext?) {
        self.context = context
    }

    func getPlanStatus(forceRefresh: Bool) async throws -> PlanStatusV2Response {
        guard let context else { throw TrainingPlanV2Error.noActivePlan }
        return context.planStatus
    }

    func getTargetTypes() async throws -> [TargetTypeV2] {
        context?.targetTypes ?? []
    }

    func getMethodologies(targetType: String?) async throws -> [MethodologyV2] {
        guard let methodologies = context?.methodologies else { return [] }
        guard let targetType else { return methodologies }
        return methodologies.filter { $0.targetTypes.contains(targetType) }
    }

    func createOverviewForRace(targetId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2 {
        try await getOverview()
    }

    func createOverviewForNonRace(
        targetType: String,
        trainingWeeks: Int,
        availableDays: Int?,
        methodologyId: String?,
        startFromStage: String?,
        intendedRaceDistanceKm: Int?
    ) async throws -> PlanOverviewV2 {
        try await getOverview()
    }

    func getOverview() async throws -> PlanOverviewV2 {
        guard let overview = context?.overview else {
            throw TrainingPlanV2Error.noActivePlan
        }
        return overview
    }

    func refreshOverview() async throws -> PlanOverviewV2 {
        try await getOverview()
    }

    func updateOverview(overviewId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2 {
        try await getOverview()
    }

    func generateWeeklyPlan(
        weekOfTraining: Int,
        forceGenerate: Bool?,
        promptVersion: String?,
        methodology: String?
    ) async throws -> WeeklyPlanV2 {
        try await resolveWeeklyPlan()
    }

    func getWeeklyPlan(weekOfTraining: Int, overviewId: String) async throws -> WeeklyPlanV2 {
        try await resolveWeeklyPlan()
    }

    func fetchWeeklyPlan(planId: String) async throws -> WeeklyPlanV2 {
        try await resolveWeeklyPlan()
    }

    func updateWeeklyPlan(planId: String, updates: UpdateWeeklyPlanRequest) async throws -> WeeklyPlanV2 {
        try await resolveWeeklyPlan()
    }

    func refreshWeeklyPlan(weekOfTraining: Int, overviewId: String) async throws -> WeeklyPlanV2 {
        try await resolveWeeklyPlan()
    }

    func deleteWeeklyPlan(planId: String) async throws {}

    func getWeeklyPreview(overviewId: String) async throws -> WeeklyPreviewV2 {
        guard let preview = context?.preview else {
            throw TrainingPlanV2Error.parsingError("No weekly preview fixture available")
        }
        return preview
    }

    func generateWeeklySummary(weekOfPlan: Int, forceUpdate: Bool?) async throws -> WeeklySummaryV2 {
        try await resolveWeeklySummary()
    }

    func getWeeklySummaries() async throws -> [WeeklySummaryItem] {
        guard let summary = context?.summary else { return [] }
        return [
            WeeklySummaryItem(
                weekIndex: summary.weekOfTraining,
                weekStart: "",
                weekStartTimestamp: summary.createdAt?.timeIntervalSince1970,
                distanceKm: summary.trainingCompletion.completedKm,
                weekPlan: summary.weeklyPlanId,
                weekSummary: summary.id,
                completionPercentage: summary.trainingCompletion.percentage
            )
        ]
    }

    func getWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2 {
        try await resolveWeeklySummary()
    }

    func refreshWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2 {
        try await resolveWeeklySummary()
    }

    func applyAdjustmentItems(weekOfPlan: Int, appliedIndices: [Int]) async throws {
        // Debug harness - no-op
    }

    func deleteWeeklySummary(summaryId: String) async throws {}

    func getCachedPlanStatus() -> PlanStatusV2Response? {
        context?.planStatus
    }

    func getCachedOverview() -> PlanOverviewV2? {
        context?.overview
    }

    func getCachedWeeklyPlan(week: Int) -> WeeklyPlanV2? {
        context?.weekly
    }

    func clearCache() async {}
    func clearOverviewCache() async {}
    func clearWeeklyPlanCache(weekOfTraining: Int?) async {}
    func clearWeeklySummaryCache(weekOfPlan: Int?) async {}
    func preloadData() async {}

    private func resolveWeeklyPlan() async throws -> WeeklyPlanV2 {
        guard let weekly = context?.weekly else {
            throw TrainingPlanV2Error.weeklyPlanNotFound(week: context?.planStatus.currentWeek ?? 1)
        }
        return weekly
    }

    private func resolveWeeklySummary() async throws -> WeeklySummaryV2 {
        guard let summary = context?.summary else {
            throw TrainingPlanV2Error.weeklySummaryNotFound(week: context?.planStatus.currentWeek ?? 1)
        }
        return summary
    }
}

private final class UITestMethodologyTargetRepository: TargetRepository {
    private var targets: [Target]

    init(targets: [Target]) {
        self.targets = targets
    }

    func getTargets() async throws -> [Target] {
        targets
    }

    func getTarget(id: String) async throws -> Target {
        guard let target = targets.first(where: { $0.id == id }) else {
            throw NSError(domain: "UITestMethodologyTargetRepository", code: 404)
        }
        return target
    }

    func getMainTarget() async -> Target? {
        targets.first(where: \.isMainRace)
    }

    func getSupportingTargets() async -> [Target] {
        targets.filter { !$0.isMainRace }
    }

    func createTarget(_ target: Target) async throws -> Target {
        targets.append(target)
        return target
    }

    func updateTarget(id: String, target: Target) async throws -> Target {
        targets.removeAll(where: { $0.id == id })
        targets.append(target)
        return target
    }

    func deleteTarget(id: String) async throws {
        targets.removeAll(where: { $0.id == id })
    }

    func forceRefresh() async throws -> [Target] {
        targets
    }

    func clearCache() {
        targets.removeAll()
    }

    func hasCache() -> Bool {
        !targets.isEmpty
    }
}

private final class UITestMethodologyWorkoutRepository: WorkoutRepository {
    var workoutsDidRefresh: AnyPublisher<Void, Never> {
        Empty().eraseToAnyPublisher()
    }

    var workoutsDidUpdateNotification: Notification.Name {
        .workoutsDidUpdate
    }

    func getWorkoutsInDateRange(startDate: Date, endDate: Date) -> [WorkoutV2] { [] }
    func getAllWorkouts() -> [WorkoutV2] { [] }
    func getWorkoutsInDateRangeAsync(startDate: Date, endDate: Date) async -> [WorkoutV2] { [] }
    func getAllWorkoutsAsync() async -> [WorkoutV2] { [] }
    func getWorkouts(limit: Int?, offset: Int?) async throws -> [WorkoutV2] { [] }
    func refreshWorkouts() async throws -> [WorkoutV2] { [] }

    func loadInitialWorkouts(pageSize: Int) async throws -> WorkoutListResponse {
        WorkoutListResponse(
            workouts: [],
            pagination: PaginationInfo(
                nextCursor: nil,
                prevCursor: nil,
                hasMore: false,
                hasNewer: false,
                oldestId: nil,
                newestId: nil,
                totalItems: 0,
                pageSize: pageSize
            )
        )
    }

    func loadMoreWorkouts(afterCursor: String, pageSize: Int) async throws -> WorkoutListResponse {
        try await loadInitialWorkouts(pageSize: pageSize)
    }

    func refreshLatestWorkouts(beforeCursor: String?, pageSize: Int) async throws -> WorkoutListResponse {
        try await loadInitialWorkouts(pageSize: pageSize)
    }

    func getWorkout(id: String) async throws -> WorkoutV2 {
        throw DomainError.notFound("No workout fixtures available")
    }

    func getWorkoutDetail(id: String) async throws -> WorkoutV2Detail {
        throw DomainError.notFound("No workout detail fixtures available")
    }

    func refreshWorkoutDetail(id: String) async throws -> WorkoutV2Detail {
        try await getWorkoutDetail(id: id)
    }

    func clearWorkoutDetailCache(id: String) async {}
    func syncWorkout(_ workout: WorkoutV2) async throws -> WorkoutV2 { workout }
    func updateTrainingNotes(id: String, notes: String) async throws {}
    func deleteWorkout(id: String) async throws {}
    func invalidateRefreshCooldown() {}
    func clearCache() async {}
    func preloadData() async {}
}

private enum HarnessError: LocalizedError {
    case missingFixture
    case invalidFixture(String)

    var errorDescription: String? {
        switch self {
        case .missingFixture:
            return "No methodology fixture path provided."
        case .invalidFixture(let message):
            return message
        }
    }
}
#endif
