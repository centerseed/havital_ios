import Foundation

enum AchievementError: LocalizedError, Equatable {
    case fetchFailed(String)
    case markFeedbackSeenFailed(String)
    case ackBackfillFailed(String)

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return message.isEmpty ? L10n.Achievements.Error.loadFailed.localized : message
        case .markFeedbackSeenFailed(let message), .ackBackfillFailed(let message):
            return message
        }
    }
}
