import Foundation

enum AnnouncementError: Error, LocalizedError {
    case fetchFailed(String)
    case markSeenFailed(String)

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return "公告載入失敗: \(message)"
        case .markSeenFailed(let message):
            return "標記已讀失敗: \(message)"
        }
    }
}
