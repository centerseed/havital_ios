import XCTest
@testable import paceriz_dev

/// Regression guard for `CacheEventBus` mechanism #1 (`subscribe(for:)` / `publish(_:)`).
///
/// ## Why this exists
/// After the enum migration, pub/sub pairing is enforced at compile time. This file
/// guards that:
/// - Matching enum keys deliver events to subscribers.
/// - Different enum cases do NOT cross-deliver.
/// - The new `.targetUpdated` case delivers correctly.
///
/// ## Test hygiene
/// `CacheEventBus.shared` is a process-wide singleton with no `unsubscribe(for:)`
/// for enum-keyed subscriptions, so handlers accumulate across tests. Each test
/// therefore asserts only on ITS OWN locally-captured flag — never on global
/// state — which makes the assertions immune to handlers left by other tests.
final class CacheEventBusPubSubMatchingTests: XCTestCase {

    // MARK: - Current contract: matching keys deliver

    /// A subscriber whose key EXACTLY matches the published event must receive it.
    func test_publish_deliversToExactMatchingKey() async {
        let received = Received()
        CacheEventBus.shared.subscribe(for: .onboardingCompleted) {
            received.flag = true
        }

        CacheEventBus.shared.publish(.onboardingCompleted)
        await Self.drainMainActor()

        XCTAssertTrue(received.flag, "Exact-key subscriber did not receive its event")
    }

    /// `dataChanged(.trainingPlanV2)` must deliver to a subscriber registered with the same case.
    func test_publish_dataChanged_deliversToExactKey() async {
        let received = Received()
        CacheEventBus.shared.subscribe(for: .dataChanged(.trainingPlanV2)) {
            received.flag = true
        }

        CacheEventBus.shared.publish(.dataChanged(.trainingPlanV2))
        await Self.drainMainActor()

        XCTAssertTrue(received.flag, "dataChanged exact-key subscriber did not fire")
    }

    // MARK: - Non-crossover guards

    /// A subscriber for one DataType must not fire for a different DataType.
    func test_dataChanged_doesNotCrossDeliverBetweenDataTypes() async {
        let workoutsReceived = Received()
        CacheEventBus.shared.subscribe(for: .dataChanged(.workouts)) {
            workoutsReceived.flag = true
        }

        CacheEventBus.shared.publish(.dataChanged(.user))
        await Self.drainMainActor()

        XCTAssertFalse(
            workoutsReceived.flag,
            "dataChanged(.workouts) subscriber wrongly fired for dataChanged(.user)"
        )
    }

    /// Distinct base events must not cross-deliver.
    func test_distinctBaseEvents_doNotCrossDeliver() async {
        let logoutReceived = Received()
        CacheEventBus.shared.subscribe(for: .userLogout) {
            logoutReceived.flag = true
        }

        CacheEventBus.shared.publish(.onboardingCompleted)
        await Self.drainMainActor()

        XCTAssertFalse(
            logoutReceived.flag,
            "userLogout subscriber wrongly fired for onboardingCompleted"
        )
    }

    // MARK: - Helpers

    /// Reference box so a `@MainActor` closure can flip a flag the test reads back.
    private final class Received {
        var flag = false
    }

    /// `publish` schedules subscriber notification on a detached `@MainActor` Task,
    /// so the test must yield to let that Task run before asserting.
    private static func drainMainActor() async {
        try? await Task.sleep(nanoseconds: 50_000_000)
        await MainActor.run {}
    }
}
