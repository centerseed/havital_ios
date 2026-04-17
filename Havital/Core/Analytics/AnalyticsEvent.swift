import Foundation

// MARK: - AnalyticsEvent

/// Type-safe analytics event enum.
/// Each case maps to one GA4 event with its required parameters.
enum AnalyticsEvent {

    // MARK: Onboarding

    /// Fired when OnboardingCoordinator initialises for a new (non re-onboarding) user.
    case onboardingStart(source: String, campaignId: String?)

    /// Fired after Garmin OAuth callback completes.
    case onboardingGarminConnect(success: Bool)

    /// Fired when Garmin history sync / check completes.
    case onboardingGarminComplete(hasHistory: Bool)

    /// Fired when the user finishes selecting their training target.
    case onboardingTargetSet(targetType: String, raceId: String?, distanceKm: Double?)

    /// Fired when completeOnboarding() succeeds.
    case onboardingComplete(durationSeconds: Int)

    // MARK: Subscription

    /// Fired when PaywallView appears on screen.
    case paywallView(trigger: String, trialRemainingDays: Int?)

    /// Fired when the user taps a subscribe button.
    case paywallTapSubscribe(planType: String)

    /// Fired when a purchase fails (user-cancelled purchases excluded).
    case purchaseFail(errorType: String)

    // MARK: Retention

    /// Fired once per cold-launch when the app reaches .ready state.
    case appOpen(daysSinceInstall: Int, subscriptionStatus: String)

    /// Fired each time the app returns to the foreground (after first launch).
    case sessionStart(sessionCountToday: Int)
}

// MARK: - Event metadata

extension AnalyticsEvent {

    /// GA4 event name — snake_case, max 40 chars.
    var name: String {
        switch self {
        case .onboardingStart:        return "onboarding_start"
        case .onboardingGarminConnect: return "onboarding_garmin_connect"
        case .onboardingGarminComplete: return "onboarding_garmin_complete"
        case .onboardingTargetSet:    return "onboarding_target_set"
        case .onboardingComplete:     return "onboarding_complete"
        case .paywallView:            return "paywall_view"
        case .paywallTapSubscribe:    return "paywall_tap_subscribe"
        case .purchaseFail:           return "purchase_fail"
        case .appOpen:                return "app_open"
        case .sessionStart:           return "session_start"
        }
    }

    /// Event parameters dict. Nil values are omitted.
    var parameters: [String: Any] {
        switch self {

        case .onboardingStart(let source, let campaignId):
            var params: [String: Any] = ["source": source]
            if let campaignId { params["campaign_id"] = campaignId }
            return params

        case .onboardingGarminConnect(let success):
            return ["success": success]

        case .onboardingGarminComplete(let hasHistory):
            return ["has_history": hasHistory]

        case .onboardingTargetSet(let targetType, let raceId, let distanceKm):
            var params: [String: Any] = ["target_type": targetType]
            if let raceId { params["race_id"] = raceId }
            if let distanceKm { params["distance_km"] = distanceKm }
            return params

        case .onboardingComplete(let durationSeconds):
            return ["duration_seconds": durationSeconds]

        case .paywallView(let trigger, let trialRemainingDays):
            var params: [String: Any] = ["trigger": trigger]
            if let days = trialRemainingDays { params["trial_remaining_days"] = days }
            return params

        case .paywallTapSubscribe(let planType):
            return ["plan_type": planType]

        case .purchaseFail(let errorType):
            return ["error_type": errorType]

        case .appOpen(let daysSinceInstall, let subscriptionStatus):
            return [
                "days_since_install": daysSinceInstall,
                "subscription_status": subscriptionStatus
            ]

        case .sessionStart(let sessionCountToday):
            return ["session_count_today": sessionCountToday]
        }
    }
}
