import Foundation

// MARK: - AnalyticsService

/// Protocol for fire-and-forget analytics tracking.
/// Callers never await results — failures are silently swallowed inside the impl.
protocol AnalyticsService {
    func track(_ event: AnalyticsEvent)
    func setUserProperty(_ value: String, forName name: String)
}
