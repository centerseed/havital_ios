import XCTest
@testable import paceriz_dev

/// Unit tests for LoginViewModel
/// Tests UI state management and authentication operations with Mock Repository
@MainActor
final class LoginViewModelTests: XCTestCase {
    private let reviewerPasscode = "test-reviewer-passcode"

    // System Under Test
    var sut: LoginViewModel!

    // Mock Dependencies
    var mockAuthRepository: MockAuthRepository!
    var mockAuthSessionRepository: MockAuthSessionRepository!

    override func setUp() {
        super.setUp()
        mockAuthRepository = MockAuthRepository()
        mockAuthSessionRepository = MockAuthSessionRepository()
        sut = LoginViewModel(
            authRepository: mockAuthRepository,
            authSessionRepository: mockAuthSessionRepository
        )
    }

    override func tearDown() {
        sut = nil
        mockAuthRepository = nil
        mockAuthSessionRepository = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        // Then
        XCTAssertEqual(sut.state, .empty)
        XCTAssertFalse(sut.isGoogleSignInLoading)
        XCTAssertFalse(sut.isAppleSignInLoading)
        XCTAssertFalse(sut.hasError)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.authenticatedUser)
    }

    // MARK: - Google Sign-In Tests

    func testSignInWithGoogle_Success() async {
        // Given
        let expectedUser = AuthUserFactory.makeAuthenticatedUser()
        mockAuthRepository.signInWithGoogleResult = .success(expectedUser)

        // When
        await sut.signInWithGoogle()

        // Then
        XCTAssertTrue(mockAuthRepository.signInWithGoogleCalled)
        XCTAssertFalse(sut.isGoogleSignInLoading) // Should reset after completion
        XCTAssertFalse(sut.hasError)
        XCTAssertEqual(sut.authenticatedUser, expectedUser)

        if case .loaded(let user) = sut.state {
            XCTAssertEqual(user, expectedUser)
        } else {
            XCTFail("Expected .loaded state, got \(sut.state)")
        }
    }

    func testSignInWithGoogle_Failure() async {
        // Given
        let expectedError = AuthenticationError.googleSignInFailed("User cancelled")
        mockAuthRepository.signInWithGoogleResult = .failure(expectedError)

        // When
        await sut.signInWithGoogle()

        // Then
        XCTAssertTrue(mockAuthRepository.signInWithGoogleCalled)
        XCTAssertFalse(sut.isGoogleSignInLoading)
        XCTAssertTrue(sut.hasError)
        XCTAssertNil(sut.authenticatedUser)

        if case .error(let domainError) = sut.state {
            // Verify error was converted to DomainError
            XCTAssertEqual(domainError, .unauthorized)
        } else {
            XCTFail("Expected .error state, got \(sut.state)")
        }
    }

    func testSignInWithGoogle_LoadingStateReset() async {
        // Given
        let expectedUser = AuthUserFactory.makeAuthenticatedUser()
        mockAuthRepository.signInWithGoogleResult = .success(expectedUser)

        // Verify initial state
        XCTAssertFalse(sut.isGoogleSignInLoading)

        // When
        await sut.signInWithGoogle()

        // Then - Verify loading state is reset after completion
        XCTAssertFalse(sut.isGoogleSignInLoading)
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.authenticatedUser, expectedUser)
    }

    // MARK: - Apple Sign-In Tests

    func testSignInWithApple_Success() async {
        // Given
        let expectedUser = AuthUserFactory.makeAuthenticatedUser()
        let credential = TestCredentialFactory.makeAppleAuthCredential()
        mockAuthRepository.signInWithAppleResult = .success(expectedUser)

        // When
        await sut.signInWithApple(credential: credential)

        // Then
        XCTAssertTrue(mockAuthRepository.signInWithAppleCalled)
        XCTAssertFalse(sut.isAppleSignInLoading)
        XCTAssertFalse(sut.hasError)
        XCTAssertEqual(sut.authenticatedUser, expectedUser)

        if case .loaded(let user) = sut.state {
            XCTAssertEqual(user, expectedUser)
        } else {
            XCTFail("Expected .loaded state, got \(sut.state)")
        }
    }

    func testSignInWithApple_Failure() async {
        // Given
        let expectedError = AuthenticationError.appleSignInFailed("Invalid credentials")
        let credential = TestCredentialFactory.makeAppleAuthCredential()
        mockAuthRepository.signInWithAppleResult = .failure(expectedError)

        // When
        await sut.signInWithApple(credential: credential)

        // Then
        XCTAssertTrue(mockAuthRepository.signInWithAppleCalled)
        XCTAssertFalse(sut.isAppleSignInLoading)
        XCTAssertTrue(sut.hasError)
        XCTAssertNil(sut.authenticatedUser)

        if case .error(let domainError) = sut.state {
            XCTAssertEqual(domainError, .unauthorized)
        } else {
            XCTFail("Expected .error state, got \(sut.state)")
        }
    }

    // MARK: - Demo Login Tests

    func testDemoLogin_Success() async {
        // Given
        let expectedUser = AuthUserFactory.makeAuthenticatedUser(uid: "demo_user")
        mockAuthRepository.demoLoginResult = .success(expectedUser)

        // When
        await sut.demoLogin(passcode: reviewerPasscode)

        // Then
        XCTAssertTrue(mockAuthRepository.demoLoginCalled)
        XCTAssertFalse(sut.hasError)
        XCTAssertEqual(sut.authenticatedUser, expectedUser)
    }

    func testDemoLogin_Failure() async {
        // Given
        let expectedError = AuthenticationError.firebaseAuthFailed("Demo not available")
        mockAuthRepository.demoLoginResult = .failure(expectedError)

        // When
        await sut.demoLogin(passcode: reviewerPasscode)

        // Then
        XCTAssertTrue(mockAuthRepository.demoLoginCalled)
        XCTAssertTrue(sut.hasError)
        XCTAssertNil(sut.authenticatedUser)
    }

    func testSignInWithApple_UserSwitch_PublishesLogoutBeforeUserChanged() async {
        let credential = TestCredentialFactory.makeAppleAuthCredential()
        mockAuthSessionRepository.currentUser = AuthUserFactory.makeAuthenticatedUser(uid: "apple-user")
        mockAuthRepository.signInWithAppleResult = .success(
            AuthUserFactory.makeAuthenticatedUser(uid: "my-user")
        )

        let expectation = expectation(description: "Observe user switch events")
        expectation.expectedFulfillmentCount = 2

        var observedEvents: [String] = []
        var sawLogout = false
        let identifier = "LoginViewModelTests.userSwitch.\(UUID().uuidString)"
        CacheEventBus.shared.subscribe(forIdentifier: identifier) { reason in
            switch reason {
            case .userLogout:
                guard !sawLogout else { return }
                sawLogout = true
                observedEvents.append("userLogout")
                expectation.fulfill()
            case .dataChanged(.user):
                guard sawLogout, observedEvents.count == 1 else { return }
                observedEvents.append("dataChanged.user")
                expectation.fulfill()
            default:
                break
            }
        }

        await sut.signInWithApple(credential: credential)
        await fulfillment(of: [expectation], timeout: 1.0)
        CacheEventBus.shared.unsubscribe(forIdentifier: identifier)

        XCTAssertEqual(observedEvents, ["userLogout", "dataChanged.user"])
    }

    // MARK: - State Management Tests

    func testStateTransitions_FromEmptyToLoadingToLoaded() async {
        // Given
        let expectedUser = AuthUserFactory.makeAuthenticatedUser()
        mockAuthRepository.signInWithGoogleResult = .success(expectedUser)

        // Initial state
        XCTAssertEqual(sut.state, .empty)

        // When
        await sut.signInWithGoogle()

        // Then - Should be in loaded state
        if case .loaded(let user) = sut.state {
            XCTAssertEqual(user, expectedUser)
        } else {
            XCTFail("Expected .loaded state")
        }
    }

    func testStateTransitions_FromEmptyToLoadingToError() async {
        // Given
        mockAuthRepository.signInWithGoogleResult = .failure(.networkFailure)

        // Initial state
        XCTAssertEqual(sut.state, .empty)

        // When
        await sut.signInWithGoogle()

        // Then - Should be in error state
        XCTAssertTrue(sut.hasError)
        XCTAssertNotNil(sut.getErrorMessage())
    }

    // MARK: - Error Message Tests

    func testGetErrorMessage_WhenInErrorState() async {
        // Given
        mockAuthRepository.signInWithGoogleResult = .failure(.googleSignInFailed("Test error"))

        // When
        await sut.signInWithGoogle()

        // Then
        let errorMessage = sut.getErrorMessage()
        XCTAssertNotNil(errorMessage)
        XCTAssertFalse(errorMessage!.isEmpty)
    }

    func testGetErrorMessage_WhenNotInErrorState() {
        // Given - Initial empty state

        // When
        let errorMessage = sut.getErrorMessage()

        // Then
        XCTAssertNil(errorMessage)
    }

    // MARK: - Helper Properties Tests

    func testIsLoading_WhenInLoadingState() {
        // Given
        sut.state = .loading

        // Then
        XCTAssertTrue(sut.isLoading)
    }

    func testIsLoading_WhenNotInLoadingState() {
        // Given
        sut.state = .empty

        // Then
        XCTAssertFalse(sut.isLoading)
    }

    func testHasError_WhenInErrorState() {
        // Given
        sut.state = .error(.unauthorized)

        // Then
        XCTAssertTrue(sut.hasError)
    }

    func testHasError_WhenNotInErrorState() {
        // Given
        sut.state = .loaded(AuthUserFactory.makeAuthenticatedUser())

        // Then
        XCTAssertFalse(sut.hasError)
    }

    func testAuthenticatedUser_WhenInLoadedState() {
        // Given
        let expectedUser = AuthUserFactory.makeAuthenticatedUser()
        sut.state = .loaded(expectedUser)

        // Then
        XCTAssertEqual(sut.authenticatedUser, expectedUser)
    }

    func testAuthenticatedUser_WhenNotInLoadedState() {
        // Given
        sut.state = .empty

        // Then
        XCTAssertNil(sut.authenticatedUser)
    }

    // MARK: - Multiple Sign-In Attempts Tests

    func testMultipleSignInAttempts() async {
        // First attempt - failure
        mockAuthRepository.signInWithGoogleResult = .failure(.networkFailure)
        await sut.signInWithGoogle()
        XCTAssertTrue(sut.hasError)

        // Second attempt - success
        let expectedUser = AuthUserFactory.makeAuthenticatedUser()
        mockAuthRepository.signInWithGoogleResult = .success(expectedUser)
        mockAuthRepository.signInWithGoogleCalled = false // Reset

        await sut.signInWithGoogle()

        // Then
        XCTAssertTrue(mockAuthRepository.signInWithGoogleCalled)
        XCTAssertFalse(sut.hasError)
        XCTAssertEqual(sut.authenticatedUser, expectedUser)
    }

    // MARK: - Error Type Conversion Tests

    func testErrorConversion_NetworkFailure() async {
        // Given
        mockAuthRepository.signInWithGoogleResult = .failure(.networkFailure)

        // When
        await sut.signInWithGoogle()

        // Then
        if case .error(let domainError) = sut.state {
            if case .networkFailure = domainError {
                // Success
            } else {
                XCTFail("Expected .networkFailure DomainError")
            }
        } else {
            XCTFail("Expected .error state")
        }
    }

    func testErrorConversion_InvalidCredentials() async {
        // Given
        mockAuthRepository.signInWithGoogleResult = .failure(.invalidCredentials)

        // When
        await sut.signInWithGoogle()

        // Then
        if case .error(let domainError) = sut.state {
            if case .validationFailure = domainError {
                // Success
            } else {
                XCTFail("Expected .validationFailure DomainError")
            }
        } else {
            XCTFail("Expected .error state")
        }
    }
}
