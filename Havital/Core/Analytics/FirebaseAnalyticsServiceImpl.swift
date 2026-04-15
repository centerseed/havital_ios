import FirebaseAnalytics

// MARK: - FirebaseAnalyticsServiceImpl

/// Concrete AnalyticsService backed by Firebase Analytics SDK.
/// All calls are synchronous fire-and-forget; the SDK handles queuing internally.
final class FirebaseAnalyticsServiceImpl: AnalyticsService {

    func track(_ event: AnalyticsEvent) {
        #if DEBUG
        Logger.debug("[Analytics] 📊 \(event.name) | params: \(event.parameters)")
        #endif
        Analytics.logEvent(event.name, parameters: event.parameters.isEmpty ? nil : event.parameters)
    }

    func setUserProperty(_ value: String, forName name: String) {
        #if DEBUG
        Logger.debug("[Analytics] 👤 userProperty: \(name) = \(value)")
        #endif
        Analytics.setUserProperty(value, forName: name)
    }
}
