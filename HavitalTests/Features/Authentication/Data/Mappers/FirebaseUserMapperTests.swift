import XCTest
@testable import paceriz_dev

final class FirebaseUserMapperTests: XCTestCase {
    private let legacyOnboardingKey = "hasCompletedOnboarding"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: legacyOnboardingKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: legacyOnboardingKey)
        super.tearDown()
    }

    func testToDomainSyncResponse_BackendCompleted_UsesCompletedState() {
        let response = makeSyncResponse(
            isCompleted: true,
            mode: "initial",
            photoUrl: "https://example.com/photo.png"
        )

        let user = FirebaseUserMapper.toDomain(syncResponse: response)

        XCTAssertEqual(user.uid, "uid-123")
        XCTAssertEqual(user.email, "backend@example.com")
        XCTAssertEqual(user.displayName, "Backend User")
        XCTAssertEqual(user.photoURL?.absoluteString, "https://example.com/photo.png")
        XCTAssertTrue(user.hasCompletedOnboarding)
        XCTAssertEqual(user.onboardingMode, .none)
    }

    func testToDomainSyncResponse_BackendIncompleteLegacyComplete_UsesLegacyStatus() {
        UserDefaults.standard.set(true, forKey: legacyOnboardingKey)
        let response = makeSyncResponse(isCompleted: false, mode: "reonboarding")

        let user = FirebaseUserMapper.toDomain(syncResponse: response)

        XCTAssertTrue(user.hasCompletedOnboarding)
        XCTAssertEqual(user.onboardingMode, .none)
    }

    func testToDomainSyncResponse_BackendIncompleteLegacyIncomplete_UsesBackendMode() {
        UserDefaults.standard.set(false, forKey: legacyOnboardingKey)
        let response = makeSyncResponse(isCompleted: false, mode: "reonboarding")

        let user = FirebaseUserMapper.toDomain(syncResponse: response)

        XCTAssertFalse(user.hasCompletedOnboarding)
        XCTAssertEqual(user.onboardingMode, .reonboarding)
    }

    func testToDomainSyncResponse_PercentEncodedPhotoURL_IsMappedAsURL() {
        let response = makeSyncResponse(
            isCompleted: false,
            mode: "initial",
            photoUrl: "%%%invalid-url%%%"
        )

        let user = FirebaseUserMapper.toDomain(syncResponse: response)

        XCTAssertEqual(user.photoURL?.absoluteString, "%25%25%25invalid-url%25%25%25")
        XCTAssertEqual(user.onboardingMode, .initial)
    }

    private func makeSyncResponse(
        isCompleted: Bool,
        mode: String,
        photoUrl: String? = nil
    ) -> UserSyncResponse {
        UserSyncResponse(
            user: UserDTO(
                uid: "uid-123",
                email: "backend@example.com",
                displayName: "Backend User",
                photoUrl: photoUrl,
                createdAt: nil,
                updatedAt: nil
            ),
            onboardingStatus: OnboardingStatusDTO(
                isCompleted: isCompleted,
                mode: mode,
                completedAt: nil
            ),
            shouldCompleteOnboarding: !isCompleted,
            versionCheck: nil
        )
    }
}
