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

    /// Fired when completeOnboarding() succeeds for a new user.
    case onboardingComplete(durationSeconds: Int)

    /// Fired when re-onboarding completes successfully.
    case reonboardingComplete(targetType: String)

    // MARK: Subscription

    /// Fired when PaywallView becomes visible (AC-PAYWALL-28).
    /// Every paywall sheet opening must fire this event with a valid source.
    /// sub_source is required when source = "resubscribe"; nil for all other sources.
    case paywallOpened(source: String, subSource: String?)

    /// Fired when PaywallView appears on screen.
    case paywallView(trigger: String, trialRemainingDays: Int?)

    /// Fired when the user taps a subscribe button.
    case paywallTapSubscribe(planType: String, offerType: String)

    /// Fired when a purchase fails (user-cancelled purchases excluded).
    case purchaseFail(errorType: String, offerType: String)

    /// Fired when RevenueCat offerings are loaded, for non-PII IAP price diagnostics.
    case iapPriceDiagnostic(
        offeringId: String,
        packageId: String,
        productId: String,
        localizedPrice: String,
        currencyCode: String?,
        localeIdentifier: String?,
        period: String,
        isCurrentOffering: Bool,
        isEarlyBirdProduct: Bool
    )

    // MARK: Retention

    /// Fired once per cold-launch when the app reaches .ready state.
    case appOpen(daysSinceInstall: Int, subscriptionStatus: String)

    /// Fired each time the app returns to the foreground (after first launch).
    case sessionStart(sessionCountToday: Int)

    // MARK: Onboarding P1 — Data Source

    /// AC-IOS-ANALYTICS-P1-02: Fired when user enters .dataSource step (session-deduped).
    case onboardingDataSourcePrompted

    /// AC-IOS-ANALYTICS-P1-03: Fired when user skips / selects unbound in .dataSource step.
    case onboardingDataSourceSkipped

    /// AC-IOS-ANALYTICS-P1-04: Fired when Garmin OAuth or Apple Health authorization succeeds.
    case onboardingDataSourceConnected(provider: String)

    // MARK: Onboarding P1 — Goal & Race

    /// AC-IOS-ANALYTICS-P1-05: Fired when user confirms goal type selection in .goalType step.
    case onboardingGoalTypeSelected(targetType: String)

    /// AC-IOS-ANALYTICS-P1-06: Fired when user confirms race/distance in .raceEventList or .maintenanceRaceDistance.
    case onboardingTargetRaceSet(targetType: String, raceId: String?, distanceKm: Double?)

    // MARK: Onboarding P1 — Schedule & Plan

    /// AC-IOS-ANALYTICS-P1-07: Fired when user confirms training days in .trainingDays step.
    case onboardingScheduleSet(availableDays: Int)

    /// AC-IOS-ANALYTICS-P1-08: Fired when .trainingOverview (plan generation loading) appears.
    case onboardingPlanGenerating(targetType: String)

    // MARK: Core Feature Views — P1

    /// AC-IOS-ANALYTICS-P1-09: Fired when TrainingPlanV2View appears (session-deduped by plan_id+week).
    case weeklyPlanView(planId: String, weekOfTraining: Int)

    /// AC-IOS-ANALYTICS-P1-10: Fired when workout detail view appears.
    case workoutAnalysisView(workoutId: String, hasCoachNotes: Bool)

    /// AC-IOS-ANALYTICS-P1-11: Fired when WeeklySummaryV2View appears.
    case weeklySummaryView(summaryId: String, weekOfTraining: Int)

    /// AC-IOS-ANALYTICS-P1-12: Fired when PlanOverviewSheetV2 appears.
    case planOverviewView(overviewId: String, targetType: String)

    /// AC-IOS-ANALYTICS-P1-13: Fired when race prediction view appears with loaded prediction data.
    case racePredictionView(predictedTime: String, distanceKm: Double)

    /// Fired for PB Moment view/share/save/close. Payload must not include workout id, route, location, or PII.
    case pbMoment(action: String, distance: String, entry: String, isFirstRecord: Bool)

    // MARK: Achievements

    /// Fired when the Personal Achievements tab is opened.
    case achievementTabOpen(entry: String)

    /// Fired when a badge detail is opened. Payload must stay low sensitivity.
    case achievementBadgeOpen(entry: String, badgeId: String, chapter: String, status: String)

    /// Fired when a public achievement share material is tapped.
    case achievementShareTap(entry: String, materialType: String, badgeId: String?, chapter: String?)

    /// Fired when an achievement share is completed by the platform share sheet.
    case achievementShareComplete(entry: String, materialType: String, badgeId: String?, chapter: String?)

    /// Fired when the achievement share preview is closed.
    case achievementShareClose(entry: String, materialType: String, badgeId: String?, chapter: String?)
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
        case .reonboardingComplete:   return "reonboarding_complete"
        case .paywallOpened:          return "paywall_opened"
        case .paywallView:            return "paywall_view"
        case .paywallTapSubscribe:    return "paywall_tap_subscribe"
        case .purchaseFail:           return "purchase_fail"
        case .iapPriceDiagnostic:     return "iap_price_diagnostic"
        case .appOpen:                return "app_open"
        case .sessionStart:           return "session_start"

        // P1 Onboarding
        case .onboardingDataSourcePrompted:  return "onboarding_data_source_prompted"
        case .onboardingDataSourceSkipped:   return "onboarding_data_source_skipped"
        case .onboardingDataSourceConnected: return "onboarding_data_source_connected"
        case .onboardingGoalTypeSelected:    return "onboarding_goal_type_selected"
        case .onboardingTargetRaceSet:       return "onboarding_target_race_set"
        case .onboardingScheduleSet:         return "onboarding_schedule_set"
        case .onboardingPlanGenerating:      return "onboarding_plan_generating"

        // P1 Core Feature Views
        case .weeklyPlanView:         return "weekly_plan_view"
        case .workoutAnalysisView:    return "workout_analysis_view"
        case .weeklySummaryView:      return "weekly_summary_view"
        case .planOverviewView:       return "plan_overview_view"
        case .racePredictionView:     return "race_prediction_view"
        case .pbMoment:               return "pb_moment"
        case .achievementTabOpen:      return "achievement_tab_open"
        case .achievementBadgeOpen:    return "achievement_badge_open"
        case .achievementShareTap:     return "achievement_share_tap"
        case .achievementShareComplete: return "achievement_share_complete"
        case .achievementShareClose:   return "achievement_share_close"
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

        case .reonboardingComplete(let targetType):
            return ["target_type": targetType]

        case .paywallOpened(let source, let subSource):
            var params: [String: Any] = ["source": source]
            if let sub = subSource { params["sub_source"] = sub }
            return params

        case .paywallView(let trigger, let trialRemainingDays):
            var params: [String: Any] = ["trigger": trigger]
            if let days = trialRemainingDays { params["trial_remaining_days"] = days }
            return params

        case .paywallTapSubscribe(let planType, let offerType):
            return [
                "plan_type": planType,
                "offer_type": offerType
            ]

        case .purchaseFail(let errorType, let offerType):
            return [
                "error_type": errorType,
                "offer_type": offerType
            ]

        case .iapPriceDiagnostic(
            let offeringId,
            let packageId,
            let productId,
            let localizedPrice,
            let currencyCode,
            let localeIdentifier,
            let period,
            let isCurrentOffering,
            let isEarlyBirdProduct
        ):
            var params: [String: Any] = [
                "offering_id": offeringId,
                "package_id": packageId,
                "product_id": productId,
                "localized_price": localizedPrice,
                "period": period,
                "is_current_offering": isCurrentOffering,
                "is_early_bird_product": isEarlyBirdProduct
            ]
            if let currencyCode { params["currency_code"] = currencyCode }
            if let localeIdentifier { params["locale_identifier"] = localeIdentifier }
            return params

        case .appOpen(let daysSinceInstall, let subscriptionStatus):
            return [
                "days_since_install": daysSinceInstall,
                "subscription_status": subscriptionStatus
            ]

        case .sessionStart(let sessionCountToday):
            return ["session_count_today": sessionCountToday]

        // MARK: P1 Onboarding — parameters

        case .onboardingDataSourcePrompted:
            return [:]

        case .onboardingDataSourceSkipped:
            return [:]

        case .onboardingDataSourceConnected(let provider):
            return ["provider": provider]

        case .onboardingGoalTypeSelected(let targetType):
            return ["target_type": targetType]

        case .onboardingTargetRaceSet(let targetType, let raceId, let distanceKm):
            var params: [String: Any] = ["target_type": targetType]
            if let raceId { params["race_id"] = raceId }
            if let distanceKm { params["distance_km"] = distanceKm }
            return params

        case .onboardingScheduleSet(let availableDays):
            return ["available_days": availableDays]

        case .onboardingPlanGenerating(let targetType):
            return ["target_type": targetType]

        // MARK: P1 Core Feature Views — parameters

        case .weeklyPlanView(let planId, let weekOfTraining):
            return [
                "plan_id": planId,
                "week_of_training": weekOfTraining
            ]

        case .workoutAnalysisView(let workoutId, let hasCoachNotes):
            return [
                "workout_id": workoutId,
                "has_coach_notes": hasCoachNotes
            ]

        case .weeklySummaryView(let summaryId, let weekOfTraining):
            return [
                "summary_id": summaryId,
                "week_of_training": weekOfTraining
            ]

        case .planOverviewView(let overviewId, let targetType):
            return [
                "overview_id": overviewId,
                "target_type": targetType
            ]

        case .racePredictionView(let predictedTime, let distanceKm):
            return [
                "predicted_time": predictedTime,
                "distance_km": distanceKm
            ]

        case .pbMoment(let action, let distance, let entry, let isFirstRecord):
            return [
                "action": action,
                "distance": distance,
                "entry": entry,
                "is_first_record": isFirstRecord
            ]

        case .achievementTabOpen(let entry):
            return AchievementAnalyticsPayloadGuard.sanitized([
                "entry": entry
            ])

        case .achievementBadgeOpen(let entry, let badgeId, let chapter, let status):
            return AchievementAnalyticsPayloadGuard.sanitized([
                "entry": entry,
                "badge_id": badgeId,
                "chapter": chapter,
                "status": status
            ])

        case .achievementShareTap(let entry, let materialType, let badgeId, let chapter),
             .achievementShareComplete(let entry, let materialType, let badgeId, let chapter),
             .achievementShareClose(let entry, let materialType, let badgeId, let chapter):
            var params: [String: Any] = [
                "entry": entry,
                "material_type": materialType
            ]
            if let badgeId { params["badge_id"] = badgeId }
            if let chapter { params["chapter"] = chapter }
            return AchievementAnalyticsPayloadGuard.sanitized(params)
        }
    }
}
