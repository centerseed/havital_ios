import Foundation

enum PinnedBadgeStorage {
    private static let key = "paceriz.achievement.pinnedBadgeId"

    static func load() -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    static func save(_ badgeId: String?) {
        if let badgeId, !badgeId.isEmpty {
            UserDefaults.standard.set(badgeId, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
