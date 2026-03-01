//
//  OnboardingError.swift
//  Havital
//
//  Onboarding Error Types
//  Domain Layer - Business error definitions for onboarding flow
//

import Foundation

// MARK: - Onboarding Error
/// Onboarding specific error types
/// Domain Layer - Encapsulates all onboarding-related errors
enum OnboardingError: Error, LocalizedError, Equatable {

    // MARK: - Data Source Errors

    /// Failed to update data source preference
    case dataSourceUpdateFailed(String)

    /// HealthKit authorization failed
    case healthKitAuthorizationFailed(String)

    /// OAuth flow failed (Garmin/Strava)
    case oauthFailed(provider: String, reason: String)

    // MARK: - User Profile Errors

    /// Failed to update user profile
    case profileUpdateFailed(String)

    /// Failed to update personal best data
    case personalBestUpdateFailed(String)

    /// Failed to update weekly distance
    case weeklyDistanceUpdateFailed(String)

    // MARK: - Target Errors

    /// Failed to create race target
    case targetCreationFailed(String)

    /// Invalid race date (too close or in the past)
    case invalidRaceDate(reason: String)

    /// Insufficient training weeks
    case insufficientTrainingWeeks(required: Int, available: Int)

    // MARK: - Training Plan Errors

    /// Failed to generate training plan overview
    case trainingPlanGenerationFailed(String)

    /// Failed to create weekly plan
    case weeklyPlanCreationFailed(String)

    // MARK: - Flow Errors

    /// Missing required data for step
    case missingRequiredData(step: String, field: String)

    /// Invalid flow state
    case invalidFlowState(String)

    /// Network error during onboarding
    case networkError(String)

    /// Unknown error
    case unknown(String)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .dataSourceUpdateFailed(let reason):
            return "Failed to update data source: \(reason)"
        case .healthKitAuthorizationFailed(let reason):
            return "HealthKit authorization failed: \(reason)"
        case .oauthFailed(let provider, let reason):
            return "\(provider) connection failed: \(reason)"
        case .profileUpdateFailed(let reason):
            return "Failed to update profile: \(reason)"
        case .personalBestUpdateFailed(let reason):
            return "Failed to update personal best: \(reason)"
        case .weeklyDistanceUpdateFailed(let reason):
            return "Failed to update weekly distance: \(reason)"
        case .targetCreationFailed(let reason):
            return "Failed to create race target: \(reason)"
        case .invalidRaceDate(let reason):
            return "Invalid race date: \(reason)"
        case .insufficientTrainingWeeks(let required, let available):
            return "Need at least \(required) weeks for training, but only \(available) weeks available"
        case .trainingPlanGenerationFailed(let reason):
            return "Failed to generate training plan: \(reason)"
        case .weeklyPlanCreationFailed(let reason):
            return "Failed to create weekly plan: \(reason)"
        case .missingRequiredData(let step, let field):
            return "Missing required data for \(step): \(field)"
        case .invalidFlowState(let state):
            return "Invalid onboarding state: \(state)"
        case .networkError(let reason):
            return "Network error: \(reason)"
        case .unknown(let reason):
            return "Unknown error: \(reason)"
        }
    }

    // MARK: - Equatable

    static func == (lhs: OnboardingError, rhs: OnboardingError) -> Bool {
        switch (lhs, rhs) {
        case (.dataSourceUpdateFailed(let l), .dataSourceUpdateFailed(let r)):
            return l == r
        case (.healthKitAuthorizationFailed(let l), .healthKitAuthorizationFailed(let r)):
            return l == r
        case (.oauthFailed(let lp, let lr), .oauthFailed(let rp, let rr)):
            return lp == rp && lr == rr
        case (.profileUpdateFailed(let l), .profileUpdateFailed(let r)):
            return l == r
        case (.personalBestUpdateFailed(let l), .personalBestUpdateFailed(let r)):
            return l == r
        case (.weeklyDistanceUpdateFailed(let l), .weeklyDistanceUpdateFailed(let r)):
            return l == r
        case (.targetCreationFailed(let l), .targetCreationFailed(let r)):
            return l == r
        case (.invalidRaceDate(let l), .invalidRaceDate(let r)):
            return l == r
        case (.insufficientTrainingWeeks(let lr, let la), .insufficientTrainingWeeks(let rr, let ra)):
            return lr == rr && la == ra
        case (.trainingPlanGenerationFailed(let l), .trainingPlanGenerationFailed(let r)):
            return l == r
        case (.weeklyPlanCreationFailed(let l), .weeklyPlanCreationFailed(let r)):
            return l == r
        case (.missingRequiredData(let ls, let lf), .missingRequiredData(let rs, let rf)):
            return ls == rs && lf == rf
        case (.invalidFlowState(let l), .invalidFlowState(let r)):
            return l == r
        case (.networkError(let l), .networkError(let r)):
            return l == r
        case (.unknown(let l), .unknown(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - DomainError Conversion
extension OnboardingError {

    /// Convert to DomainError for unified error handling
    func toDomainError() -> DomainError {
        switch self {
        case .networkError(let reason):
            return .networkFailure(reason)
        case .targetCreationFailed(let reason),
             .trainingPlanGenerationFailed(let reason),
             .weeklyPlanCreationFailed(let reason):
            return .serverError(500, reason)
        case .invalidRaceDate,
             .insufficientTrainingWeeks,
             .missingRequiredData:
            return .validationFailure(errorDescription ?? "Validation failed")
        case .healthKitAuthorizationFailed,
             .oauthFailed:
            return .unauthorized
        default:
            return .unknown(errorDescription ?? "Unknown error")
        }
    }
}
