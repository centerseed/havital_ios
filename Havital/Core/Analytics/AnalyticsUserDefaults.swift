import Foundation

// MARK: - Analytics UserDefaults Keys

extension UserDefaults {

    // MARK: Install date (set once on first launch)

    private static let firstInstallDateKey = "analytics_first_install_date"

    /// Returns the first-install date, writing it on first access.
    var analyticsFirstInstallDate: Date {
        if let stored = object(forKey: Self.firstInstallDateKey) as? Date {
            return stored
        }
        let now = Date()
        set(now, forKey: Self.firstInstallDateKey)
        return now
    }

    // MARK: Session count (resets at midnight)

    private static let sessionCountTodayKey = "analytics_session_count_today"
    private static let sessionCountDateKey = "analytics_session_count_date"

    /// Increments today's session counter, resetting if the calendar date has changed.
    /// Returns the updated count.
    func incrementSessionCount() -> Int {
        let today = todayString()
        let storedDate = string(forKey: Self.sessionCountDateKey) ?? ""

        var count: Int
        if storedDate == today {
            count = integer(forKey: Self.sessionCountTodayKey) + 1
        } else {
            // New day — reset
            count = 1
            set(today, forKey: Self.sessionCountDateKey)
        }
        set(count, forKey: Self.sessionCountTodayKey)
        return count
    }

    // MARK: Onboarding start time

    private static let onboardingStartTimeKey = "analytics_onboarding_start_time"

    var analyticsOnboardingStartTime: TimeInterval {
        get { double(forKey: Self.onboardingStartTimeKey) }
        set { set(newValue, forKey: Self.onboardingStartTimeKey) }
    }

    // MARK: Private helpers

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - DependencyContainer: Analytics Module

extension DependencyContainer {

    /// Register the AnalyticsService singleton.
    /// Call this once during app bootstrap (see AppDependencyBootstrap).
    func registerAnalyticsModule() {
        let service = FirebaseAnalyticsServiceImpl()
        register(service as AnalyticsService, forProtocol: AnalyticsService.self)
        Logger.debug("[Bootstrap] Analytics module registered")
    }
}
