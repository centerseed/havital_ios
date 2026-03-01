import Foundation

// MARK: - User Sync Response DTO
/// Data Transfer Object for backend user sync response
/// Maps to backend API response: POST /auth/sync
struct UserSyncResponse: Codable {
    /// User basic information from backend
    let user: UserDTO

    /// Current onboarding status
    let onboardingStatus: OnboardingStatusDTO

    /// Whether user should complete onboarding flow
    let shouldCompleteOnboarding: Bool

    enum CodingKeys: String, CodingKey {
        case user
        case onboardingStatus = "onboarding_status"
        case shouldCompleteOnboarding = "should_complete_onboarding"
    }
}

// MARK: - User DTO
/// Basic user information from backend
struct UserDTO: Codable {
    /// User unique identifier (matches Firebase UID)
    let uid: String

    /// User email address
    let email: String?

    /// Display name
    let displayName: String?

    /// Profile photo URL
    let photoUrl: String?

    /// Account creation timestamp
    let createdAt: String?

    /// Last update timestamp
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case uid
        case email
        case displayName = "display_name"
        case photoUrl = "photo_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Onboarding Status DTO
/// Onboarding status information from backend
struct OnboardingStatusDTO: Codable {
    /// Whether onboarding has been completed
    let isCompleted: Bool

    /// Current onboarding mode
    let mode: String

    /// Onboarding completion timestamp
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case isCompleted = "is_completed"
        case mode
        case completedAt = "completed_at"
    }

    // MARK: - Conversion to Domain OnboardingMode

    /// Convert backend mode string to domain OnboardingMode
    func toOnboardingMode() -> OnboardingMode {
        switch mode.lowercased() {
        case "initial":
            return .initial
        case "reonboarding":
            return .reonboarding
        case "none":
            return .none
        default:
            return .none
        }
    }
}
