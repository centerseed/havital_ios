import XCTest
@testable import paceriz_dev

final class AuthenticationServiceTests: XCTestCase {

    func testFetchUserProfileUnauthorized_preservesAuthenticationState() async throws {
        try await assertFetchUserProfilePreservesAuthenticationState(for: .unauthorized("expired token"))
    }

    func testFetchUserProfileForbidden_preservesAuthenticationState() async throws {
        try await assertFetchUserProfilePreservesAuthenticationState(for: .forbidden("insufficient permission"))
    }

    private func assertFetchUserProfilePreservesAuthenticationState(
        for error: HTTPError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let repository = MockUserProfileRepository()
        repository.errorToThrow = error
        let sut = AuthenticationService(
            userProfileRepository: repository,
            observeAuthState: false
        )
        sut.isAuthenticated = true

        sut.fetchUserProfile()
        try await waitUntilLoadingFinishes(sut, file: file, line: line)

        XCTAssertTrue(sut.isAuthenticated, "HTTP 401/403 must preserve the authenticated state", file: file, line: line)
    }

    private func waitUntilLoadingFinishes(
        _ sut: AuthenticationService,
        file: StaticString,
        line: UInt
    ) async throws {
        for _ in 0..<100 {
            if !sut.isLoading { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("fetchUserProfile did not finish", file: file, line: line)
    }
}
