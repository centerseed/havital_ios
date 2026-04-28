import Foundation
import Combine

// MARK: - PlanOverviewObserver
//
// AC-PAYWALL-37 fix: holds a stable Combine subscription to
// TrainingPlanV2Repository.overviewDidUpdate.
//
// Problem with the previous approach (ContentView.onReceive + computed publisher):
//   SwiftUI re-creates .onReceive subscriptions on every body re-render.
//   PassthroughSubject does not replay missed values, so if the plan loader
//   fires overviewDidUpdate during a body re-render cycle, the event is lost
//   and the reminder is never suppressed.
//
// Correct approach:
//   Make this a singleton. ContentView uses @ObservedObject on the shared instance.
//   The subscription is established once in init and lives until the app is terminated
//   — completely immune to body re-renders.
//
// ContentView usage pattern:
//   @ObservedObject private var planOverviewObserver = PlanOverviewObserver.shared
//
//   .onAppear:
//     Skip calling checkAndShowReminder for expired status if plan loading outcome
//     is not yet known (hasOverview=false AND planCheckConfirmed=false).
//     Defer until either:
//       - onChange(of: planOverviewObserver.hasOverview) fires (plan found → suppress dialog)
//       - onChange(of: planOverviewObserver.planCheckConfirmed) fires (no plan → show dialog)
//
//   This prevents the dialog from being enqueued before we know whether FreeTierBanner
//   should be the primary UX — which is the root cause of AC-PAYWALL-37.

@MainActor
final class PlanOverviewObserver: ObservableObject {

    // MARK: - Singleton
    //
    // PlanOverviewObserver is a singleton so that WeeklyPlanLoader (Domain) can
    // call confirmNoPlan() without a SwiftUI dependency injection chain.
    // ContentView and UITestAC37HostView use @ObservedObject on the shared instance.
    static let shared = PlanOverviewObserver()

    /// True once TrainingPlanV2Repository has written an overview to cache.
    /// Presentation layer reads this to decide whether FreeTierBanner is the
    /// active UX (hasOverview == true) vs expired dialog (hasOverview == false).
    @Published private(set) var hasOverview: Bool = false

    /// True once we have a definitive answer: either plan found (hasOverview=true)
    /// or plan loader confirmed no plan exists (hasOverview=false but check completed).
    /// Used by ContentView to know when it is safe to show the expired reminder
    /// for users without a plan, without risking the race condition.
    @Published private(set) var planCheckConfirmed: Bool = false

    private var cancellable: AnyCancellable?

    /// Resets all state — call on user logout so the next user starts clean.
    func reset() {
        hasOverview = false
        planCheckConfirmed = false
        // Re-establish subscription with current repository
        setupSubscription()
    }

    private init() {
        setupSubscription()
    }

    private func setupSubscription() {
        // Establish subscription immediately.
        // DependencyContainer is safe to access here because the observer is
        // created after AppDependencyBootstrap.registerAllModules() completes.
        let repo: TrainingPlanV2Repository? = DependencyContainer.shared.tryResolve()

        // Pre-populate from synchronous cache so warm launches don't flash the dialog.
        // If cache already has an overview, both flags are immediately confirmed.
        if repo?.getCachedOverview() != nil {
            hasOverview = true
            planCheckConfirmed = true
        }

        cancellable = repo?.overviewDidUpdate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.hasOverview = true
                self?.planCheckConfirmed = true
            }
    }

    /// Called by the plan loader (or its delegate) when it has definitively confirmed
    /// that no plan exists for this user. Allows ContentView to show the expired dialog
    /// for users who genuinely have no Week 1 plan.
    ///
    /// Call sites: WeeklyPlanLoader when getPlanStatus() returns a "create_plan" next action
    /// or when getOverview() throws .overviewNotFound / .noActivePlan.
    func confirmNoPlan() {
        guard !hasOverview else { return }  // don't downgrade a confirmed plan
        planCheckConfirmed = true
    }
}
