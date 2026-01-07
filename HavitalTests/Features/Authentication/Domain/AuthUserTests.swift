import XCTest
@testable import paceriz_dev

/// Unit tests for AuthUser Entity
/// Tests pure business logic without dependencies
final class AuthUserTests: XCTestCase {

    // MARK: - Initialization Tests

    func testAuthUserInitialization() {
        // Given
        let uid = "test_uid_123"
        let email = "test@example.com"
        let displayName = "Test User"

        // When
        let authUser = AuthUser(
            uid: uid,
            email: email,
            displayName: displayName,
            photoURL: nil,
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            onboardingMode: .none
        )

        // Then
        XCTAssertEqual(authUser.uid, uid)
        XCTAssertEqual(authUser.email, email)
        XCTAssertEqual(authUser.displayName, displayName)
        XCTAssertNil(authUser.photoURL)
        XCTAssertTrue(authUser.isAuthenticated)
        XCTAssertTrue(authUser.hasCompletedOnboarding)
        XCTAssertEqual(authUser.onboardingMode, .none)
    }

    func testAuthUserWithDefaultValues() {
        // Given & When
        let authUser = AuthUser(uid: "test_123")

        // Then
        XCTAssertEqual(authUser.uid, "test_123")
        XCTAssertNil(authUser.email)
        XCTAssertNil(authUser.displayName)
        XCTAssertNil(authUser.photoURL)
        XCTAssertTrue(authUser.isAuthenticated) // Default is true
        XCTAssertFalse(authUser.hasCompletedOnboarding) // Default is false
        XCTAssertEqual(authUser.onboardingMode, .none) // Default is .none
    }

    // MARK: - Convenience Properties Tests

    func testNeedsOnboarding_WhenNotCompletedAndModeIsInitial() {
        // Given
        let authUser = AuthUser(
            uid: "test_123",
            hasCompletedOnboarding: false,
            onboardingMode: .initial
        )

        // Then
        XCTAssertTrue(authUser.needsOnboarding)
    }

    func testNeedsOnboarding_WhenNotCompletedAndModeIsReonboarding() {
        // Given
        let authUser = AuthUser(
            uid: "test_123",
            hasCompletedOnboarding: false,
            onboardingMode: .reonboarding
        )

        // Then
        XCTAssertTrue(authUser.needsOnboarding)
    }

    func testNeedsOnboarding_WhenCompleted() {
        // Given
        let authUser = AuthUser(
            uid: "test_123",
            hasCompletedOnboarding: true,
            onboardingMode: .none
        )

        // Then
        XCTAssertFalse(authUser.needsOnboarding)
    }

    func testNeedsOnboarding_WhenNotCompletedButModeIsNone() {
        // Given
        let authUser = AuthUser(
            uid: "test_123",
            hasCompletedOnboarding: false,
            onboardingMode: .none
        )

        // Then
        XCTAssertFalse(authUser.needsOnboarding)
    }

    func testIsNewUser() {
        // Given
        let newUser = AuthUser(
            uid: "new_123",
            onboardingMode: .initial
        )
        let existingUser = AuthUser(
            uid: "existing_123",
            onboardingMode: .none
        )

        // Then
        XCTAssertTrue(newUser.isNewUser)
        XCTAssertFalse(existingUser.isNewUser)
    }

    func testIsReonboarding() {
        // Given
        let reonboardingUser = AuthUser(
            uid: "reonboard_123",
            onboardingMode: .reonboarding
        )
        let normalUser = AuthUser(
            uid: "normal_123",
            onboardingMode: .none
        )

        // Then
        XCTAssertTrue(reonboardingUser.isReonboarding)
        XCTAssertFalse(normalUser.isReonboarding)
    }

    // MARK: - Equatable Tests

    func testEquatable_SameProperties() {
        // Given
        let user1 = AuthUser(
            uid: "test_123",
            email: "test@example.com",
            displayName: "Test User",
            hasCompletedOnboarding: true,
            onboardingMode: .none
        )
        let user2 = AuthUser(
            uid: "test_123",
            email: "test@example.com",
            displayName: "Test User",
            hasCompletedOnboarding: true,
            onboardingMode: .none
        )

        // Then
        XCTAssertEqual(user1, user2)
    }

    func testEquatable_DifferentUID() {
        // Given
        let user1 = AuthUser(uid: "test_123")
        let user2 = AuthUser(uid: "test_456")

        // Then
        XCTAssertNotEqual(user1, user2)
    }

    func testEquatable_DifferentOnboardingMode() {
        // Given
        let user1 = AuthUser(uid: "test_123", onboardingMode: .initial)
        let user2 = AuthUser(uid: "test_123", onboardingMode: .none)

        // Then
        XCTAssertNotEqual(user1, user2)
    }

    // MARK: - Codable Tests

    func testCodableEncoding() throws {
        // Given
        let authUser = AuthUser(
            uid: "test_123",
            email: "test@example.com",
            displayName: "Test User",
            hasCompletedOnboarding: true,
            onboardingMode: .initial
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(authUser)

        // Then
        XCTAssertNotNil(data)
        XCTAssertTrue(data.count > 0)
    }

    func testCodableDecoding() throws {
        // Given
        let originalUser = AuthUser(
            uid: "test_123",
            email: "test@example.com",
            displayName: "Test User",
            hasCompletedOnboarding: true,
            onboardingMode: .reonboarding
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalUser)

        let decoder = JSONDecoder()
        let decodedUser = try decoder.decode(AuthUser.self, from: data)

        // Then
        XCTAssertEqual(decodedUser, originalUser)
        XCTAssertEqual(decodedUser.uid, originalUser.uid)
        XCTAssertEqual(decodedUser.email, originalUser.email)
        XCTAssertEqual(decodedUser.displayName, originalUser.displayName)
        XCTAssertEqual(decodedUser.hasCompletedOnboarding, originalUser.hasCompletedOnboarding)
        XCTAssertEqual(decodedUser.onboardingMode, originalUser.onboardingMode)
    }

    // MARK: - OnboardingMode Tests

    func testOnboardingModeRawValues() {
        // Test that OnboardingMode raw values match expected strings
        XCTAssertEqual(OnboardingMode.none.rawValue, "none")
        XCTAssertEqual(OnboardingMode.initial.rawValue, "initial")
        XCTAssertEqual(OnboardingMode.reonboarding.rawValue, "reonboarding")
    }

    func testOnboardingModeCodable() throws {
        // Given
        let modes: [OnboardingMode] = [.none, .initial, .reonboarding]

        for mode in modes {
            // When
            let encoder = JSONEncoder()
            let data = try encoder.encode(mode)

            let decoder = JSONDecoder()
            let decodedMode = try decoder.decode(OnboardingMode.self, from: data)

            // Then
            XCTAssertEqual(decodedMode, mode)
        }
    }
}
