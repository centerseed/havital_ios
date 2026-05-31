import Foundation

// MARK: - Email Auth Result Entities
// Domain-layer results for email registration / verification / resend flows.
// Kept serialization-free so Domain does not depend on Data layer DTOs.

struct EmailRegistrationResult {
    let uid: String
    let email: String
    let message: String
}

struct EmailVerificationResult {
    let uid: String
    let message: String
}

struct EmailResendResult {
    let email: String
    let message: String
}
