import Foundation

enum AnnouncementError: Error, LocalizedError {
    case fetchFailed(String)
    case markSeenFailed(String)

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return String(format: NSLocalizedString("announcement.error.fetch_failed_format", comment: "Announcement fetch failed error"), message)
        case .markSeenFailed(let message):
            return String(format: NSLocalizedString("announcement.error.mark_seen_failed_format", comment: "Announcement mark seen failed error"), message)
        }
    }
}
