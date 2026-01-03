import Foundation

// MARK: - UserProfile Error Types
/// Domain-specific errors for UserProfile feature
enum UserProfileError: Error, Equatable {
    /// User profile not found
    case profileNotFound

    /// Invalid heart rate values (e.g., maxHR <= restingHR)
    case invalidHeartRate(message: String)

    /// User preferences not found
    case preferencesNotFound

    /// Target not found
    case targetNotFound(targetId: String)

    /// Account deletion failed
    case deletionFailed(reason: String)

    /// Invalid update data
    case invalidUpdateData(field: String)

    /// Cache expired
    case cacheExpired

    /// Network error
    case networkError(String)

    /// User not authenticated
    case notAuthenticated

    /// General operation failed
    case operationFailed(String)
}

// MARK: - Conversion to DomainError
extension UserProfileError {
    func toDomainError() -> DomainError {
        switch self {
        case .profileNotFound:
            return .notFound("User profile not found")
        case .invalidHeartRate(let message):
            return .validationFailure(message)
        case .preferencesNotFound:
            return .notFound("User preferences not found")
        case .targetNotFound(let targetId):
            return .notFound("Target not found: \(targetId)")
        case .deletionFailed(let reason):
            return .unknown(reason)
        case .invalidUpdateData(let field):
            return .validationFailure("Invalid update data for field: \(field)")
        case .cacheExpired:
            return .dataCorruption("Cache expired")
        case .networkError(let message):
            return .networkFailure(message)
        case .notAuthenticated:
            return .unauthorized
        case .operationFailed(let message):
            return .unknown(message)
        }
    }
}

// MARK: - Localized Description
extension UserProfileError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return NSLocalizedString("error.profile_not_found", comment: "User profile not found")
        case .invalidHeartRate(let message):
            return message
        case .preferencesNotFound:
            return NSLocalizedString("error.preferences_not_found", comment: "User preferences not found")
        case .targetNotFound(let targetId):
            return String(format: NSLocalizedString("error.target_not_found", comment: "Target not found"), targetId)
        case .deletionFailed(let reason):
            return reason
        case .invalidUpdateData(let field):
            return String(format: NSLocalizedString("error.invalid_update_data", comment: "Invalid update data"), field)
        case .cacheExpired:
            return NSLocalizedString("error.cache_expired", comment: "Cache expired")
        case .networkError(let message):
            return message
        case .notAuthenticated:
            return NSLocalizedString("error.not_authenticated", comment: "User not authenticated")
        case .operationFailed(let message):
            return message
        }
    }
}
