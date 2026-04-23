import XCTest
@testable import paceriz_dev

@MainActor
final class GlobalInterruptQueueACTests: XCTestCase {
    private let dataSourceReminderKey = "data_source_unbound_last_shown_at"

    private var coordinator: InterruptCoordinator!
    private var appViewModel: AppViewModel!
    private var announcementViewModel: AnnouncementViewModel!
    private var appStateManager: MockAppStateManager!
    private var workoutRepository: MockWorkoutRepository!
    private var userProfileRepository: MockUserProfileRepository!
    private var announcementRepository: AnnouncementRepositorySpy!

    override func setUp() async throws {
        try await super.setUp()

        UserDefaults.standard.removeObject(forKey: dataSourceReminderKey)
        DataSourceBindingReminderManager.shared.resetSession()
        UserPreferencesManager.shared.dataSourcePreference = .appleHealth
        SubscriptionStateManager.shared.update(
            SubscriptionStatusEntity(status: .none, enforcementEnabled: false)
        )
        SubscriptionStateManager.shared.clearDowngrade()

        coordinator = InterruptCoordinator()
        appStateManager = MockAppStateManager()
        workoutRepository = MockWorkoutRepository()
        userProfileRepository = MockUserProfileRepository()
        announcementRepository = AnnouncementRepositorySpy()

        appViewModel = AppViewModel(
            appStateManager: appStateManager,
            workoutRepository: workoutRepository,
            userProfileRepository: userProfileRepository,
            interruptCoordinator: coordinator
        )

        announcementViewModel = AnnouncementViewModel(
            repository: announcementRepository,
            interruptCoordinator: coordinator
        )
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: dataSourceReminderKey)
        DataSourceBindingReminderManager.shared.resetSession()
        UserPreferencesManager.shared.dataSourcePreference = .appleHealth
        SubscriptionStateManager.shared.update(
            SubscriptionStatusEntity(status: .none, enforcementEnabled: false)
        )
        SubscriptionStateManager.shared.clearDowngrade()

        coordinator = nil
        appViewModel = nil
        announcementViewModel = nil
        appStateManager = nil
        workoutRepository = nil
        userProfileRepository = nil
        announcementRepository = nil

        try await super.tearDown()
    }

    func test_ac_int_01_and_10_root_features_share_single_global_queue() async throws {
        await announcementRepository.setAnnouncements([
            makeAnnouncement(id: "announcement-1", publishedAt: date(offset: -60), isSeen: false)
        ])

        _ = coordinator.enqueue(.paywall(.apiGated))
        appViewModel.handleDataSourceNotBoundNotification()
        announcementViewModel.loadAnnouncementsIfNeeded()

        await waitUntil {
            self.coordinator.currentItem?.type == .paywall
                && self.coordinator.pendingItems.count == 2
                && self.coordinator.pendingItems.map(\.type) == [.announcement, .dataSourceBindingReminder]
                && self.announcementViewModel.currentPopup == nil
                && self.appViewModel.showDataSourceNotBoundAlert == false
        }

        XCTAssertEqual(coordinator.currentItem?.type, .paywall)
        XCTAssertEqual(coordinator.pendingItems.map(\.type), [.announcement, .dataSourceBindingReminder])

        coordinator.dismissCurrent(reason: .dismissed)
        await waitUntil {
            self.coordinator.currentItem?.type == .announcement
                && self.announcementViewModel.currentPopup?.id == "announcement-1"
        }

        XCTAssertEqual(coordinator.currentItem?.type, .announcement)
        XCTAssertEqual(coordinator.pendingItems.map(\.type), [.dataSourceBindingReminder])

        coordinator.dismissCurrent(reason: .dismissed)
        await waitUntil {
            self.coordinator.currentItem?.type == .dataSourceBindingReminder
        }

        XCTAssertEqual(coordinator.currentItem?.type, .dataSourceBindingReminder)
        XCTAssertFalse(coordinator.hasPendingInterrupts)
    }

    func test_ac_int_03_and_05_priority_order_is_fixed_and_pending_items_drain_in_order() async throws {
        await announcementRepository.setAnnouncements([
            makeAnnouncement(id: "announcement-1", publishedAt: date(offset: -60), isSeen: false)
        ])

        _ = coordinator.enqueue(.paywall(.apiGated))
        appViewModel.handleDataSourceNotBoundNotification()
        announcementViewModel.loadAnnouncementsIfNeeded()

        await waitUntil {
            self.coordinator.currentItem?.type == .paywall
                && self.coordinator.pendingItems.map(\.type) == [.announcement, .dataSourceBindingReminder]
                && self.announcementViewModel.currentPopup == nil
                && self.appViewModel.showDataSourceNotBoundAlert == false
        }

        XCTAssertEqual(coordinator.currentItem?.type, .paywall)
        XCTAssertEqual(coordinator.pendingItems.map(\.type), [.announcement, .dataSourceBindingReminder])

        coordinator.dismissCurrent(reason: .dismissed)
        await waitUntil {
            self.coordinator.currentItem?.type == .announcement
                && self.announcementViewModel.currentPopup?.id == "announcement-1"
        }
        XCTAssertEqual(coordinator.currentItem?.type, .announcement)
        XCTAssertEqual(coordinator.pendingItems.map(\.type), [.dataSourceBindingReminder])

        coordinator.dismissCurrent(reason: .dismissed)
        await waitUntil {
            self.coordinator.currentItem?.type == .dataSourceBindingReminder
        }
        XCTAssertEqual(coordinator.currentItem?.type, .dataSourceBindingReminder)
        XCTAssertFalse(coordinator.hasPendingInterrupts)
    }

    func test_ac_int_07_data_source_reminder_enqueues_into_global_queue() async throws {
        _ = coordinator.enqueue(.paywall(.apiGated))

        appViewModel.handleDataSourceNotBoundNotification()

        await waitUntil {
            self.coordinator.currentItem?.type == .paywall
                && self.coordinator.pendingItems.contains(where: { $0.type == .dataSourceBindingReminder })
                && self.appViewModel.showDataSourceNotBoundAlert == false
        }

        XCTAssertEqual(coordinator.currentItem?.type, .paywall)
        XCTAssertTrue(coordinator.pendingItems.contains(where: { $0.type == .dataSourceBindingReminder }))
        XCTAssertFalse(appViewModel.showDataSourceNotBoundAlert)
    }

    func test_ac_int_08_announcement_popup_uses_shared_queue_and_waits_behind_active_interrupts() async throws {
        await announcementRepository.setAnnouncements([
            makeAnnouncement(id: "announcement-1", publishedAt: date(offset: -30), isSeen: false)
        ])

        _ = coordinator.enqueue(.paywall(.apiGated))
        announcementViewModel.loadAnnouncementsIfNeeded()

        await waitUntil {
            self.coordinator.currentItem?.type == .paywall
                && self.coordinator.pendingItems.contains(where: { $0.type == .announcement })
                && self.announcementViewModel.currentPopup == nil
        }

        let initialMarkSeenIDs = await announcementRepository.markSeenIDsSnapshot()
        XCTAssertEqual(initialMarkSeenIDs, [])

        coordinator.dismissCurrent(reason: .dismissed)
        await waitUntil {
            self.coordinator.currentItem?.type == .announcement
                && self.announcementViewModel.currentPopup?.id == "announcement-1"
        }

        await waitUntil {
            await self.announcementRepository.markSeenIDsSnapshot() == ["announcement-1"]
        }

        let markSeenIDs = await announcementRepository.markSeenIDsSnapshot()
        XCTAssertEqual(markSeenIDs, ["announcement-1"])
    }

    func test_ac_int_09_paywall_requests_use_global_interrupt_queue() async throws {
        await announcementRepository.setAnnouncements([
            makeAnnouncement(id: "announcement-1", publishedAt: date(offset: -30), isSeen: false)
        ])

        SubscriptionStateManager.shared.update(
            SubscriptionStatusEntity(status: .trial, enforcementEnabled: true)
        )

        let trigger = try await makeTrainingPlanPaywallTrigger()
        _ = coordinator.enqueue(.paywall(trigger))
        appViewModel.handleDataSourceNotBoundNotification()
        announcementViewModel.loadAnnouncementsIfNeeded()

        await waitUntil {
            self.coordinator.currentItem?.type == .paywall
                && self.coordinator.pendingItems.map(\.type) == [.announcement, .dataSourceBindingReminder]
                && self.appViewModel.showDataSourceNotBoundAlert == false
                && self.announcementViewModel.currentPopup == nil
        }

        XCTAssertEqual(coordinator.currentItem?.type, .paywall)
        XCTAssertEqual(coordinator.pendingItems.map(\.type), [.announcement, .dataSourceBindingReminder])
    }

    private func waitUntil(
        timeout: TimeInterval = 1.5,
        pollInterval: UInt64 = 50_000_000,
        condition: @escaping @MainActor () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() {
                return
            }
            try? await Task.sleep(nanoseconds: pollInterval)
        }

        XCTFail("Timed out waiting for condition")
    }

    private func makeAnnouncement(
        id: String,
        publishedAt: Date,
        expiresAt: Date? = nil,
        isSeen: Bool
    ) -> Announcement {
        Announcement(
            id: id,
            title: id,
            body: "body",
            imageUrl: nil,
            ctaLabel: nil,
            ctaUrl: nil,
            publishedAt: publishedAt,
            expiresAt: expiresAt,
            isSeen: isSeen
        )
    }

    private func makeTrainingPlanPaywallTrigger() async throws -> PaywallTrigger {
        let repository = MockTrainingPlanV2Repository()
        repository.errorToThrow = HTTPError.subscriptionRequired(
            SubscriptionErrorPayload(
                error: "subscription_required",
                subscription: SubscriptionErrorStatusRaw(
                    status: "trial",
                    expiresAt: nil,
                    planType: nil,
                    billingIssue: nil
                )
            )
        )

        let container = DependencyContainer.shared
        if !container.isRegistered(TrainingVersionRouter.self) {
            container.registerTrainingVersionRouter()
        }
        let versionRouter: TrainingVersionRouter = container.resolve()

        let viewModel = TrainingPlanV2ViewModel(
            repository: repository,
            workoutRepository: workoutRepository,
            versionRouter: versionRouter
        )

        viewModel.loader.planOverview = makeTrainingPlanOverview()
        await viewModel.methodology.changeMethodology(methodologyId: "methodology-gated")
        return try XCTUnwrap(viewModel.paywallTrigger)
    }

    private func makeTrainingPlanOverview() -> PlanOverviewV2 {
        PlanOverviewV2(
            id: "overview-1",
            targetId: nil,
            targetType: "race_run",
            targetDescription: nil,
            methodologyId: nil,
            totalWeeks: 12,
            startFromStage: nil,
            raceDate: nil,
            distanceKm: nil,
            distanceKmDisplay: nil,
            distanceUnit: nil,
            targetPace: nil,
            targetTime: nil,
            isMainRace: nil,
            targetName: nil,
            methodologyOverview: nil,
            targetEvaluate: nil,
            approachSummary: nil,
            trainingStages: [],
            milestones: [],
            createdAt: nil,
            methodologyVersion: nil,
            milestoneBasis: nil
        )
    }

    private func date(offset: TimeInterval) -> Date {
        Date().addingTimeInterval(offset)
    }
}

private actor AnnouncementRepositorySpy: AnnouncementRepository {
    private var announcements: [Announcement] = []
    private var markSeenIDs: [String] = []
    private var markSeenBatchCalls: [[String]] = []

    func setAnnouncements(_ announcements: [Announcement]) {
        self.announcements = announcements
    }

    func fetchAnnouncements() async throws -> [Announcement] {
        announcements
    }

    func markSeen(id: String) async throws {
        markSeenIDs.append(id)
    }

    func markSeenBatch(ids: [String]) async throws {
        markSeenBatchCalls.append(ids)
    }

    func markSeenIDsSnapshot() -> [String] {
        markSeenIDs
    }

    func markSeenBatchCallsSnapshot() -> [[String]] {
        markSeenBatchCalls
    }
}
