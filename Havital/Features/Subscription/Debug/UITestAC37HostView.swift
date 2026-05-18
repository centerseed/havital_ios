#if DEBUG
import SwiftUI
import Combine

// MARK: - UITestAC37HostView
//
// Minimal UITest harness that reproduces the AC-PAYWALL-37 race condition:
//
//   expired subscription + planOverview nil at onAppear (cache cold)
//   → expired dialog fires
//   → plan loader completes later → overviewDidUpdate fires
//   → dialog should be suppressed, FreeTierBanner becomes sole UX
//
// This view replicates the two layers that interact in the real app:
//   1. TrainingPlanV2View layer  — shows FreeTierBanner when planOverview != nil
//   2. ContentView / InterruptHostView layer — checks reminder on onAppear
//
// Accessibility identifiers:
//   "UITest_AC37_HostReady"    — view is fully initialized
//   "FreeTierBanner"           — from FreeTierBanner component (already tagged)
//   app.alerts.firstMatch      — the expired-dialog that should NOT appear

struct UITestAC37HostView: View {
    @ObservedObject private var subscriptionState = SubscriptionStateManager.shared
    @ObservedObject private var reminderManager = SubscriptionReminderManager.shared
    @ObservedObject private var interruptCoordinator = InterruptCoordinator.shared

    // AC-PAYWALL-37 fix: use shared singleton observer (same pattern as ContentView).
    // WeeklyPlanLoader calls PlanOverviewObserver.shared.confirmNoPlan() directly.
    @ObservedObject private var planOverviewObserver = PlanOverviewObserver.shared

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Diagnostic label so UITest knows the harness is ready
                Text("AC37 Host Ready")
                    .font(AppFont.headline())
                    .accessibilityIdentifier("UITest_AC37_HostReady")

                // Diagnostic: expose hasOverview state for debugging
                Text("hasOverview:\(planOverviewObserver.hasOverview ? "true" : "false")")
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("UITest_AC37_HasOverview")

                // Diagnostic: expose planCheckConfirmed state for no-plan scenarios
                Text("planCheckConfirmed:\(planOverviewObserver.planCheckConfirmed ? "true" : "false")")
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("UITest_AC37_PlanCheckConfirmed")

                // Mirrors TrainingPlanV2View.shouldShowFreeTierBanner logic
                if shouldShowFreeTierBanner {
                    FreeTierBanner(onTap: {})
                        .padding(.horizontal, 16)
                        .transition(.opacity)
                }

                Spacer()
            }
            .padding(.top, 40)

            // Interrupt host renders the subscription expired dialog
            InterruptHostView(
                coordinator: interruptCoordinator,
                onGoToDataSourceSettings: {}
            )
        }
        // Step 1: onAppear fires when cache is still cold.
        // AC-PAYWALL-37 fix: mirror ContentView deferred logic.
        // For expired status, do NOT queue the dialog until plan-load outcome is confirmed.
        .onAppear {
            // Inject expired subscription status so enforcement is active
            injectExpiredSubscriptionStatus()
            // Deferred check: expired status + plan not yet confirmed → skip dialog for now.
            // The onChange(of: planOverviewObserver.hasOverview) or
            // onChange(of: planOverviewObserver.planCheckConfirmed) will fire the check
            // once the plan loader completes.
            let isExpiredStatus = subscriptionState.currentStatus?.status == .expired
            if isExpiredStatus && !planOverviewObserver.planCheckConfirmed {
                syncInterrupt()  // sync any pre-existing state, but don't enqueue expired reminder
            } else {
                checkReminder(hasPlan: planOverviewObserver.hasOverview)
            }
            // Simulate plan loader starting in the background (mirrors WeeklyPlanLoader.loadData)
            // The mock's getOverview() fires overviewDidUpdate after a ~0.6s delay,
            // creating the race window that the fix must close.
            // If getOverview() throws .notFound, call confirmNoPlan() — mirrors
            // WeeklyPlanLoader.refreshOverviewQuietly() behaviour.
            Task {
                let repo: TrainingPlanV2Repository? = DependencyContainer.shared.tryResolve()
                do {
                    _ = try await repo?.getOverview()
                } catch {
                    let domainError = error.toDomainError()
                    if case .notFound = domainError {
                        PlanOverviewObserver.shared.confirmNoPlan()
                    }
                }
            }
        }
        // Step 3 of fix: PlanOverviewObserver.hasOverview flips when overviewDidUpdate fires.
        // Unlike .onReceive(computedPublisher), this fires reliably regardless of body re-renders.
        // When plan is found: suppress expired dialog (call checkAndShowReminder with hasPlan=true).
        .onChange(of: planOverviewObserver.hasOverview) { _, hasOverview in
            guard hasOverview else { return }
            checkReminder(hasPlan: true)
        }
        // When plan loader confirms no plan: now it is safe to show expired dialog.
        .onChange(of: planOverviewObserver.planCheckConfirmed) { _, confirmed in
            guard confirmed, !planOverviewObserver.hasOverview else { return }
            checkReminder(hasPlan: false)
        }
        // Keep interrupt coordinator in sync whenever reminder changes
        .onChange(of: reminderManager.pendingReminder?.id) { _, _ in
            syncInterrupt()
        }
    }

    // MARK: - Banner Visibility

    // Mirrors ContentView → TrainingPlanV2View logic:
    // banner visible when expired (no premium) AND plan was generated.
    private var shouldShowFreeTierBanner: Bool {
        guard !subscriptionState.hasPremiumAccess else { return false }
        return planOverviewObserver.hasOverview
    }

    // MARK: - Reminder Logic (mirrors ContentView)

    private func checkReminder(hasPlan: Bool) {
        reminderManager.checkAndShowReminder(
            status: subscriptionState.currentStatus,
            hasGeneratedTrainingPlan: hasPlan
        )
        syncInterrupt()
    }

    private func syncInterrupt() {
        guard let reminder = reminderManager.pendingReminder else {
            interruptCoordinator.removeAll(ofType: .subscriptionReminder)
            return
        }

        _ = interruptCoordinator.enqueue(
            .subscriptionReminder(reminder) { reason in
                guard reason != .cancelled else { return }
                reminderManager.dismissReminder()
            }
        )
    }

    // MARK: - Helpers

    /// Force-sets subscription state to expired with enforcement enabled.
    /// The harness DI already provides UITestAC37MockSubscriptionRepository,
    /// but SubscriptionStateManager is only populated after getStatus() resolves.
    /// We set it eagerly here so onAppear has a non-nil status to act on.
    ///
    /// subscribedAt is set based on the current scenario:
    ///   - .newUserNoPlan  → nil (never subscribed)
    ///   - everything else → 90 days ago (churned user)
    private func injectExpiredSubscriptionStatus() {
        let scenario = UITestAC37Scenario.current()
        let subscribedAt: TimeInterval? = scenario == .newUserNoPlan
            ? nil
            : AC37SubscribedAtChurnedFixture

        let expiredStatus = SubscriptionStatusEntity(
            status: .expired,
            expiresAt: Date().addingTimeInterval(-3600).timeIntervalSince1970,
            billingIssue: false,
            enforcementEnabled: true,
            subscribedAt: subscribedAt
        )
        SubscriptionStateManager.shared.update(expiredStatus)
        // Reset session guard so this fresh launch sees the reminder
        SubscriptionReminderManager.shared.resetSession()
        // Reset plan observer so each test cohort starts clean
        PlanOverviewObserver.shared.reset()
    }
}

#endif
