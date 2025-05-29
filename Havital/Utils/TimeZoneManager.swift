import Foundation

class TimeZoneManager {
    static let shared = TimeZoneManager()

    private var currentTimeZone: TimeZone

    private init() {
        // Default to Asia/Taipei, can be made configurable later
        self.currentTimeZone = TimeZone(identifier: "Asia/Taipei") ?? TimeZone.current
        Logger.info("TimeZoneManager initialized with time zone: \(self.currentTimeZone.identifier)")
    }

    func getCurrentTimeZone() -> TimeZone {
        return currentTimeZone
    }

    func setCurrentTimeZone(_ timeZone: TimeZone) {
        self.currentTimeZone = timeZone
        Logger.info("TimeZoneManager current time zone set to: \(self.currentTimeZone.identifier)")
    }

    func setCurrentTimeZone(identifier: String) {
        if let newTimeZone = TimeZone(identifier: identifier) {
            self.currentTimeZone = newTimeZone
            Logger.info("TimeZoneManager current time zone set to: \(self.currentTimeZone.identifier)")
        } else {
            Logger.warn("TimeZoneManager failed to set time zone with identifier: \(identifier). Using previous: \(self.currentTimeZone.identifier)")
        }
    }
}
