import Foundation

// MARK: - Target Error Types
/// Domain-specific errors for Target feature
enum TargetError: Error, Equatable {
    /// Target not found
    case targetNotFound(targetId: String)

    /// Failed to create target
    case createFailed(reason: String)

    /// Failed to update target
    case updateFailed(reason: String)

    /// Failed to delete target
    case deleteFailed(reason: String)

    /// Invalid target data
    case invalidData(field: String)

    /// Network error
    case networkError(String)

    /// User not authenticated
    case notAuthenticated

    /// General operation failed
    case operationFailed(String)

    /// No main race target found
    case noMainRaceTarget

    /// Cache error
    case cacheError(String)
}

// MARK: - Conversion to DomainError
extension TargetError {
    func toDomainError() -> DomainError {
        switch self {
        case .targetNotFound(let targetId):
            return .notFound("Target not found: \(targetId)")
        case .createFailed(let reason):
            return .unknown(reason)
        case .updateFailed(let reason):
            return .unknown(reason)
        case .deleteFailed(let reason):
            return .unknown(reason)
        case .invalidData(let field):
            return .validationFailure("Invalid data for field: \(field)")
        case .networkError(let message):
            return .networkFailure(message)
        case .notAuthenticated:
            return .unauthorized
        case .operationFailed(let message):
            return .unknown(message)
        case .noMainRaceTarget:
            return .notFound("No main race target found")
        case .cacheError(let message):
            return .dataCorruption(message)
        }
    }
}

// MARK: - Localized Description
extension TargetError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .targetNotFound(let targetId):
            return String(format: NSLocalizedString("error.target_not_found", comment: "Target not found"), targetId)
        case .createFailed(let reason):
            return reason
        case .updateFailed(let reason):
            return reason
        case .deleteFailed(let reason):
            return reason
        case .invalidData(let field):
            return String(format: NSLocalizedString("error.invalid_target_data", comment: "Invalid target data"), field)
        case .networkError(let message):
            return message
        case .notAuthenticated:
            return NSLocalizedString("error.not_authenticated", comment: "User not authenticated")
        case .operationFailed(let message):
            return message
        case .noMainRaceTarget:
            return NSLocalizedString("error.no_main_race", comment: "No main race target found")
        case .cacheError(let message):
            return message
        }
    }
}
