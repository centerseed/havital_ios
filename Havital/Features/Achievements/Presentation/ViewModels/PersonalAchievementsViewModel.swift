import Foundation
import Combine

@MainActor
final class PersonalAchievementsViewModel: ObservableObject, TaskManageable {
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case error(String)
    }

    @Published private(set) var summary: AchievementSummary?
    @Published private(set) var state: ViewState = .idle
    @Published private(set) var isAcknowledgingBackfill = false
    @Published var selectedBadge: AchievementBadge?
    @Published var selectedShareable: AchievementShareable?
    @Published private(set) var pinnedBadgeId: String?

    nonisolated let taskRegistry = TaskRegistry()

    private let repository: AchievementRepository
    private let analyticsService: AnalyticsService
    private var cancellables = Set<AnyCancellable>()
    private var hasTrackedTabOpen = false

    init(
        repository: AchievementRepository? = nil,
        analyticsService: AnalyticsService? = nil
    ) {
        let container = DependencyContainer.shared
        if let repository {
            self.repository = repository
        } else {
            if !container.isRegistered(AchievementRepository.self) {
                container.registerAchievementModule()
            }
            self.repository = container.resolve() as AchievementRepository
        }
        self.analyticsService = analyticsService ?? (container.resolve() as AnalyticsService)
        observePinnedBadge()
        subscribeToEvents()
    }

    /// 訓練同步 / 課表變更後成就可能解鎖 → 自動強制刷新（使用者無感）。
    private func subscribeToEvents() {
        CacheEventBus.shared.subscribe(for: "dataChanged.workouts") { [weak self] in
            Self.diagnostic("event dataChanged.workouts → forceRefresh")
            await self?.performLoad(forceRefresh: true)
        }
        CacheEventBus.shared.subscribe(for: "dataChanged.trainingPlanV2") { [weak self] in
            Self.diagnostic("event dataChanged.trainingPlanV2 → forceRefresh")
            await self?.performLoad(forceRefresh: true)
        }
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Pin

    private func observePinnedBadge() {
        pinnedBadgeId = repository.getPinnedBadgeId()
        repository.pinnedBadgeIdDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] id in self?.pinnedBadgeId = id }
            .store(in: &cancellables)
    }

    func togglePin(badgeId: String) {
        let current = repository.getPinnedBadgeId()
        let newValue: String? = (current == badgeId) ? nil : badgeId
        repository.setPinnedBadgeId(newValue)
    }

    var showBackfillBanner: Bool {
        summary?.backfill.showBanner == true
    }

    var visibleInsights: [AchievementInsight] {
        summary?.visibleInsights ?? []
    }

    func load(forceRefresh: Bool = false) {
        Self.diagnostic(
            "load start forceRefresh=\(forceRefresh) appVersion=\(Self.appVersion) build=\(Self.buildNumber)"
        )
        Task { [weak self] in
            await self?.performLoad(forceRefresh: forceRefresh)
        }
    }

    /// 下拉刷新用：await 直到抓取完成，刷新指示器才會收起。
    func refresh() async {
        Self.diagnostic("refresh start (pull-to-refresh)")
        await performLoad(forceRefresh: true)
    }

    private func performLoad(forceRefresh: Bool) async {
        await executeTask(id: TaskID("achievements_load"), cooldownSeconds: forceRefresh ? 0 : 1) { [weak self] in
            guard let self else { return }
            await MainActor.run {
                if self.summary == nil {
                    self.state = .loading
                }
            }

            do {
                let summary = try await self.repository.fetchSummary(forceRefresh: forceRefresh)
                await MainActor.run {
                    self.summary = summary
                    self.state = summary.hasVisibleContent ? .loaded : .empty
                    Self.diagnostic(
                        "load success state=\(summary.hasVisibleContent ? "loaded" : "empty") catalog=\(summary.catalogVersion) groups=\(summary.badgeGroups.count) unlocked=\(summary.storySummary.unlockedCount)/\(summary.storySummary.totalCount)"
                    )
                }
            } catch let urlError as URLError where urlError.code == .cancelled {
                Self.diagnostic("load cancelled via URLError.cancelled", level: .debug)
                return
            } catch HTTPError.cancelled {
                Self.diagnostic("load cancelled via HTTPError.cancelled", level: .debug)
                return
            } catch {
                await MainActor.run {
                    Self.diagnostic("load failed state=error error=\(type(of: error)): \(error.localizedDescription)", level: .error)
                    Self.cloudFailure(error)
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }

    func trackTabOpenIfNeeded() {
        guard !hasTrackedTabOpen else { return }
        hasTrackedTabOpen = true
        analyticsService.track(.achievementTabOpen(entry: "main_tab"))
    }

    func openBadge(_ badge: AchievementBadge, entry: String = "badge_collection") {
        selectedBadge = badge
        analyticsService.track(.achievementBadgeOpen(
            entry: entry,
            badgeId: badge.badgeId,
            chapter: badge.chapter.analyticsValue,
            status: badge.status.rawValue
        ))
    }

    func selectShareable(_ shareable: AchievementShareable, entry: String = "share_center") {
        selectedShareable = shareable
        analyticsService.track(.achievementShareTap(
            entry: entry,
            materialType: shareable.materialType.analyticsValue,
            badgeId: shareable.badgeId,
            chapter: shareable.chapter?.analyticsValue
        ))
    }

    func closeShare(entry: String = "share_preview") {
        if let shareable = selectedShareable {
            analyticsService.track(.achievementShareClose(
                entry: entry,
                materialType: shareable.materialType.analyticsValue,
                badgeId: shareable.badgeId,
                chapter: shareable.chapter?.analyticsValue
            ))
        }
        selectedShareable = nil
    }

    func completeShare(entry: String = "share_preview") {
        guard let shareable = selectedShareable else { return }
        analyticsService.track(.achievementShareComplete(
            entry: entry,
            materialType: shareable.materialType.analyticsValue,
            badgeId: shareable.badgeId,
            chapter: shareable.chapter?.analyticsValue
        ))
    }

    func acknowledgeBackfill() {
        Task { [weak self] in
            guard let self else { return }
            await self.executeTask(id: TaskID("achievements_backfill_ack")) { [weak self] in
                guard let self else { return }
                await MainActor.run { self.isAcknowledgingBackfill = true }
                defer {
                    Task { @MainActor [weak self] in
                        self?.isAcknowledgingBackfill = false
                    }
                }

                do {
                    try await self.repository.ackBackfill()
                    await MainActor.run {
                        guard let current = self.summary else { return }
                        self.summary = AchievementSummary(
                            generatedAt: current.generatedAt,
                            catalogVersion: current.catalogVersion,
                            backfill: AchievementBackfill(
                                status: current.backfill.status,
                                showBanner: false,
                                bannerKey: current.backfill.bannerKey,
                                historicalUnlockCount: current.backfill.historicalUnlockCount,
                                acknowledgedAt: current.generatedAt
                            ),
                            storySummary: current.storySummary,
                            badgeGroups: current.badgeGroups,
                            achievementTracks: current.achievementTracks,
                            pbOverview: current.pbOverview,
                            lifetimeStats: current.lifetimeStats,
                            insights: current.insights,
                            recentShareables: current.recentShareables,
                            unlockFeedbackQueue: current.unlockFeedbackQueue,
                            privacyPolicy: current.privacyPolicy
                        )
                    }
                } catch {
                    Logger.error("[AchievementsVM] backfill ack failed: \(error.localizedDescription)")
                }
            }
        }
    }

    nonisolated private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    nonisolated private static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    }

    nonisolated private static func diagnostic(_ message: String, level: LogLevel = .info) {
        let output = "[AchievementsVM] \(message)"
        print(output)
        Logger.log(output, level: level)
    }

    private static func cloudFailure(_ error: Error) {
        Logger.firebase(
            "Achievements screen entered error state",
            level: .error,
            labels: [
                "cloud_logging": "true",
                "component": "Achievements",
                "operation": "load_summary",
                "stage": "view_model"
            ],
            jsonPayload: [
                "error_type": String(describing: type(of: error)),
                "error": error.localizedDescription,
                "app_version": appVersion,
                "build_number": buildNumber
            ]
        )
    }
}
