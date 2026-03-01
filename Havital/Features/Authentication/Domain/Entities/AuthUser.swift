import Foundation

// MARK: - Onboarding Mode
/// Defines the onboarding state and flow for the user
enum OnboardingMode: String, Codable, Equatable {
    /// No onboarding required
    case none

    /// Initial onboarding for new users (full profile setup required)
    case initial

    /// Re-onboarding for existing users (profile update flow)
    case reonboarding
}

// MARK: - AuthUser Entity
/// Pure business model for authenticated user
/// Contains only business-relevant properties, no technical implementation details
/// Token management is handled separately in Data Layer (AuthSessionRepository)
struct AuthUser: Codable, Equatable {
    // MARK: - Core Properties

    /// Unique user identifier (Firebase UID)
    let uid: String

    /// User email address
    let email: String?

    /// Display name shown in UI
    let displayName: String?

    /// Profile photo URL
    let photoURL: URL?

    // MARK: - Business State

    /// Authentication status (business layer concept)
    let isAuthenticated: Bool

    /// Whether user has completed onboarding process
    let hasCompletedOnboarding: Bool

    /// Current onboarding mode/flow
    let onboardingMode: OnboardingMode

    // MARK: - Initialization

    init(
        uid: String,
        email: String? = nil,
        displayName: String? = nil,
        photoURL: URL? = nil,
        isAuthenticated: Bool = true,
        hasCompletedOnboarding: Bool = false,
        onboardingMode: OnboardingMode = .none
    ) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.isAuthenticated = isAuthenticated
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.onboardingMode = onboardingMode
    }
}

// MARK: - Convenience Properties
extension AuthUser {
    /// Check if user needs to complete onboarding
    var needsOnboarding: Bool {
        !hasCompletedOnboarding && onboardingMode != .none
    }

    /// Check if this is a new user (initial onboarding)
    var isNewUser: Bool {
        onboardingMode == .initial
    }

    /// Check if user is re-onboarding (profile update)
    var isReonboarding: Bool {
        onboardingMode == .reonboarding
    }
}
