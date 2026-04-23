import Foundation

@MainActor
final class DataSourceBindingReminderManager {
    static let shared = DataSourceBindingReminderManager()

    private enum Keys {
        static let lastShownAt = "data_source_unbound_last_shown_at"
    }

    private let reminderInterval: TimeInterval = 3 * 24 * 60 * 60
    private var hasShownThisSession = false

    private init() {}

    func canShowReminder(now: Date = Date()) -> Bool {
        guard !hasShownThisSession else { return false }

        let lastShownAt = UserDefaults.standard.double(forKey: Keys.lastShownAt)
        if lastShownAt > 0, now.timeIntervalSince1970 - lastShownAt < reminderInterval {
            return false
        }

        return true
    }

    func dismissReminder(now: Date = Date()) {
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: Keys.lastShownAt)
        hasShownThisSession = true
    }

    func resetSession() {
        hasShownThisSession = false
    }

    func clearReminderHistory() {
        UserDefaults.standard.removeObject(forKey: Keys.lastShownAt)
        hasShownThisSession = false
    }
}
