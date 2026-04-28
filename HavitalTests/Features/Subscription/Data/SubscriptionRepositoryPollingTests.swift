// SubscriptionRepositoryPollingTests.swift
// Bug 3 regression tests: polling must not overwrite optimistic state.
//
// Tests call waitForBackendAuthorizedStatus(maxAttempts:delaySeconds:) directly
// (method is `internal`, not `private`, specifically to enable this test path).
// delaySeconds: 0 is used to eliminate wall-clock wait time.

import XCTest
@testable import paceriz_dev

@MainActor
final class SubscriptionRepositoryPollingTests: XCTestCase {

    private var remoteDataSource: StubRemoteDataSource!
    private var localDataSource: SpyLocalDataSource!
    private var sut: SubscriptionRepositoryImpl!

    override func setUp() {
        super.setUp()
        remoteDataSource = StubRemoteDataSource()
        localDataSource = SpyLocalDataSource()
        sut = SubscriptionRepositoryImpl(
            remoteDataSource: remoteDataSource,
            localDataSource: localDataSource
        )
        // Start from a clean slate
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .none))
        SubscriptionStateManager.shared.clearDowngrade()
    }

    override func tearDown() {
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .none))
        SubscriptionStateManager.shared.clearDowngrade()
        sut = nil
        localDataSource = nil
        remoteDataSource = nil
        super.tearDown()
    }

    // MARK: - Test 1: Polling with stale backend must not overwrite optimistic state

    /// Bug 3 fix: backend returns .none for all 15 attempts.
    /// SubscriptionStateManager.currentStatus must stay at the optimistic .active
    /// that was set before polling began.
    func testPolling_WhenBackendAlwaysReturnsNone_OptimisticActiveIsPreserved() async throws {
        // Arrange: set optimistic .active (simulates what publishOptimisticStatusIfPossible does)
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .active))

        // Backend is stale — will return .none for every attempt
        remoteDataSource.statusSequence = Array(repeating: SubscriptionStatusDTO(status: "none"), count: 15)

        // Act: run polling with 0-second delay so test is instant
        let result = try await sut.waitForBackendAuthorizedStatus(maxAttempts: 15, delaySeconds: 0)

        // Assert: polling timed out (backend never confirmed)
        guard case .pendingProcessing = result else {
            XCTFail("waitForBackendAuthorizedStatus must return .pendingProcessing after all attempts with stale backend, got \(result)")
            return
        }

        // Assert: optimistic .active is still in place — NOT overwritten to .none
        XCTAssertEqual(SubscriptionStateManager.shared.currentStatus?.status, .active,
                       "SubscriptionStateManager must retain optimistic .active when backend only returns .none")

        // Assert: localDataSource was NOT written during polling (stale responses must not be cached)
        XCTAssertEqual(localDataSource.saveStatusCallCount, 0,
                       "Cache must not be written for stale (.none) backend responses")
    }

    /// Bug 3 fix: backend returns .expired for all 15 attempts.
    /// Same guarantee as .none — optimistic .active must not be overwritten.
    func testPolling_WhenBackendAlwaysReturnsExpired_OptimisticActiveIsPreserved() async throws {
        // Arrange: set optimistic .active
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .active))

        // Backend returns .expired for every attempt
        remoteDataSource.statusSequence = Array(repeating: SubscriptionStatusDTO(status: "expired"), count: 10)

        // Act
        let result = try await sut.waitForBackendAuthorizedStatus(maxAttempts: 10, delaySeconds: 0)

        // Assert
        guard case .pendingProcessing = result else {
            XCTFail("Expected .pendingProcessing when backend returns only .expired, got \(result)")
            return
        }
        XCTAssertEqual(SubscriptionStateManager.shared.currentStatus?.status, .active,
                       "SubscriptionStateManager must retain optimistic .active when backend only returns .expired")
        XCTAssertEqual(localDataSource.saveStatusCallCount, 0)
    }

    // MARK: - Test 2: Authoritative backend confirmation overrides optimistic

    /// Bug 3 fix: backend returns .none for the first 4 attempts, then .active on attempt 5.
    /// The final state in SubscriptionStateManager must be the backend's confirmed .active entity.
    func testPolling_WhenBackendConfirmsActiveOnAttempt5_StateIsAuthoritativeActive() async throws {
        // Arrange: set optimistic .active first
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .active))

        // Backend: .none × 4, then .active on the 5th call
        var sequence: [SubscriptionStatusDTO] = Array(repeating: SubscriptionStatusDTO(status: "none"), count: 4)
        sequence.append(SubscriptionStatusDTO(status: "subscribed", planType: "yearly"))
        remoteDataSource.statusSequence = sequence

        // Act
        let result = try await sut.waitForBackendAuthorizedStatus(maxAttempts: 15, delaySeconds: 0)

        // Assert: polling succeeded
        guard case .success = result else {
            XCTFail("waitForBackendAuthorizedStatus must return .success when backend confirms .active, got \(result)")
            return
        }

        // Assert: state is backend's authoritative entity (still .active status)
        XCTAssertEqual(SubscriptionStateManager.shared.currentStatus?.status, .active,
                       "SubscriptionStateManager must reflect backend-confirmed .active after authoritative override")

        // Assert: localDataSource was written exactly once (for the confirmed response)
        XCTAssertEqual(localDataSource.saveStatusCallCount, 1,
                       "Cache must be written exactly once when backend confirms authorized status")

        // Assert: remoteDataSource was called exactly 5 times (4 stale + 1 confirmed)
        XCTAssertEqual(remoteDataSource.fetchStatusCallCount, 5,
                       "fetchStatus must be called exactly as many times as attempts before confirmation")
    }

    /// Authoritative backend returns .trial — polling must succeed and update state to .trial.
    func testPolling_WhenBackendConfirmsTrial_StateUpdatesToTrial() async throws {
        // Arrange: set optimistic .active
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .active))

        // Backend: .none × 2, then .trial
        var sequence: [SubscriptionStatusDTO] = Array(repeating: SubscriptionStatusDTO(status: "none"), count: 2)
        sequence.append(SubscriptionStatusDTO(status: "trial"))
        remoteDataSource.statusSequence = sequence

        // Act
        let result = try await sut.waitForBackendAuthorizedStatus(maxAttempts: 5, delaySeconds: 0)

        // Assert
        guard case .success = result else {
            XCTFail("Expected .success when backend confirms trial, got \(result)")
            return
        }
        XCTAssertEqual(SubscriptionStateManager.shared.currentStatus?.status, .trial,
                       "Authoritative .trial from backend must override optimistic .active in SubscriptionStateManager")
        XCTAssertEqual(localDataSource.saveStatusCallCount, 1)
    }

    // MARK: - Test 3: Generic refreshStatus must also preserve optimistic purchase state

    /// Bug 3 regression: the first fix protected waitForBackendAuthorizedStatus(),
    /// but generic refreshStatus() calls (foreground refresh / app active refresh) still used
    /// fetchAndCache() and could overwrite optimistic .active with stale backend .none.
    func testRefreshStatus_DuringOptimisticHold_WhenBackendReturnsNone_PreservesOptimisticActive() async throws {
        // Arrange: purchase path has saved and published an optimistic active status.
        let optimisticDTO = SubscriptionStatusDTO(
            status: "subscribed",
            expiresAt: Self.iso8601String(from: Date().addingTimeInterval(30 * 86400)),
            planType: "yearly"
        )
        localDataSource.saveStatus(optimisticDTO)
        localDataSource.resetSaveStatusCallCount()
        SubscriptionStateManager.shared.update(SubscriptionMapper.toEntity(from: optimisticDTO))
        sut.setOptimisticAuthorizationHoldUntilForTesting(Date().addingTimeInterval(30))

        // Backend is still stale while RevenueCat webhook has not landed.
        remoteDataSource.statusSequence = [SubscriptionStatusDTO(status: "none")]

        // Act
        let refreshed = try await sut.refreshStatus()

        // Assert: refreshStatus returns the optimistic authorized status and does not cache stale backend.
        XCTAssertEqual(refreshed.status, .active)
        XCTAssertEqual(SubscriptionStateManager.shared.currentStatus?.status, .active)
        XCTAssertEqual(localDataSource.saveStatusCallCount, 0,
                       "Stale backend .none must not be cached during optimistic hold")
    }

    /// When backend confirms active during the optimistic hold, refreshStatus() must accept
    /// backend as authoritative, write cache once, and clear the stale-protection path.
    func testRefreshStatus_DuringOptimisticHold_WhenBackendConfirmsActive_CachesAuthoritativeStatus() async throws {
        // Arrange: optimistic monthly cache exists, backend will confirm yearly.
        let optimisticDTO = SubscriptionStatusDTO(
            status: "subscribed",
            expiresAt: Self.iso8601String(from: Date().addingTimeInterval(30 * 86400)),
            planType: "monthly"
        )
        localDataSource.saveStatus(optimisticDTO)
        localDataSource.resetSaveStatusCallCount()
        SubscriptionStateManager.shared.update(SubscriptionMapper.toEntity(from: optimisticDTO))
        sut.setOptimisticAuthorizationHoldUntilForTesting(Date().addingTimeInterval(30))

        remoteDataSource.statusSequence = [
            SubscriptionStatusDTO(
                status: "subscribed",
                expiresAt: Self.iso8601String(from: Date().addingTimeInterval(365 * 86400)),
                planType: "yearly"
            )
        ]

        // Act
        let refreshed = try await sut.refreshStatus()

        // Assert
        XCTAssertEqual(refreshed.status, .active)
        XCTAssertEqual(refreshed.planType, "yearly")
        XCTAssertEqual(SubscriptionStateManager.shared.currentStatus?.planType, "yearly")
        XCTAssertEqual(localDataSource.saveStatusCallCount, 1,
                       "Authoritative backend active status must be cached")
    }

    /// If the optimistic hold has expired, refreshStatus() should accept backend .none
    /// so real downgrades are not hidden indefinitely.
    func testRefreshStatus_AfterOptimisticHoldExpires_AcceptsBackendNone() async throws {
        // Arrange
        let optimisticDTO = SubscriptionStatusDTO(
            status: "subscribed",
            expiresAt: Self.iso8601String(from: Date().addingTimeInterval(30 * 86400)),
            planType: "yearly"
        )
        localDataSource.saveStatus(optimisticDTO)
        localDataSource.resetSaveStatusCallCount()
        SubscriptionStateManager.shared.update(SubscriptionMapper.toEntity(from: optimisticDTO))
        sut.setOptimisticAuthorizationHoldUntilForTesting(Date().addingTimeInterval(-1))
        remoteDataSource.statusSequence = [SubscriptionStatusDTO(status: "none")]

        // Act
        let refreshed = try await sut.refreshStatus()

        // Assert
        XCTAssertEqual(refreshed.status, SubscriptionStatus.none)
        XCTAssertEqual(SubscriptionStateManager.shared.currentStatus?.status, SubscriptionStatus.none)
        XCTAssertEqual(localDataSource.saveStatusCallCount, 1)
    }

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

// MARK: - Stubs

/// Stub that returns DTOs from a predefined sequence.
/// Thread-safe for single-threaded async test contexts.
private final class StubRemoteDataSource: SubscriptionRemoteDataSourceProtocol {
    var statusSequence: [SubscriptionStatusDTO] = []
    private(set) var fetchStatusCallCount = 0

    func fetchStatus() async throws -> SubscriptionStatusDTO {
        let index = fetchStatusCallCount
        fetchStatusCallCount += 1
        guard index < statusSequence.count else {
            // Out of sequence — return .none to simulate continued staleness
            return SubscriptionStatusDTO(status: "none")
        }
        return statusSequence[index]
    }
}

/// Spy that records saveStatus calls without writing to UserDefaults.
private final class SpyLocalDataSource: SubscriptionLocalDataSourceProtocol {
    private(set) var saveStatusCallCount = 0
    private var stored: SubscriptionStatusDTO?

    func getStatus() -> SubscriptionStatusDTO? { stored }
    func saveStatus(_ dto: SubscriptionStatusDTO) {
        saveStatusCallCount += 1
        stored = dto
    }
    func isExpired() -> Bool { true }
    func clearAll() { stored = nil }

    func resetSaveStatusCallCount() {
        saveStatusCallCount = 0
    }
}
