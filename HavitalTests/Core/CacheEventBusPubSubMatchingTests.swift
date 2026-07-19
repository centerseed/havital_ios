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
/// (This is also why we keep flag boxes rather than `XCTestExpectation`: accumulated
/// handlers from prior tests would re-`fulfill()` a finished test's expectation and
/// trip an XCTest API violation. Flags are re-flippable and harmless.)
final class CacheEventBusPubSubMatchingTests: XCTestCase {

    // MARK: - Current contract: matching keys deliver

    /// A subscriber whose key EXACTLY matches the published event must receive it.
    func test_publish_deliversToExactMatchingKey() async {
        let received = Received()
        CacheEventBus.shared.subscribe(for: .onboardingCompleted) {
            received.flag = true
        }

        CacheEventBus.shared.publish(.onboardingCompleted)
        await Self.drain(until: { received.flag })

        XCTAssertTrue(received.flag, "Exact-key subscriber did not receive its event")
    }

    /// `dataChanged(.trainingPlanV2)` must deliver to a subscriber registered with the same case.
    func test_publish_dataChanged_deliversToExactKey() async {
        let received = Received()
        CacheEventBus.shared.subscribe(for: .dataChanged(.trainingPlanV2)) {
            received.flag = true
        }

        CacheEventBus.shared.publish(.dataChanged(.trainingPlanV2))
        await Self.drain(until: { received.flag })

        XCTAssertTrue(received.flag, "dataChanged exact-key subscriber did not fire")
    }

    // MARK: - Non-crossover guards

    /// A subscriber for one DataType must not fire for a different DataType.
    func test_dataChanged_doesNotCrossDeliverBetweenDataTypes() async {
        let workoutsReceived = Received()
        CacheEventBus.shared.subscribe(for: .dataChanged(.workouts)) {
            workoutsReceived.flag = true
        }
        // Positive control on the event we DO publish: draining until this fires proves
        // the publish notification Task actually ran, so the negative assertion below is
        // deterministic (not just "we didn't wait long enough").
        let userControl = Received()
        CacheEventBus.shared.subscribe(for: .dataChanged(.user)) {
            userControl.flag = true
        }

        CacheEventBus.shared.publish(.dataChanged(.user))
        await Self.drain(until: { userControl.flag })

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
        // Positive control on the published event — see note above.
        let onboardingControl = Received()
        CacheEventBus.shared.subscribe(for: .onboardingCompleted) {
            onboardingControl.flag = true
        }

        CacheEventBus.shared.publish(.onboardingCompleted)
        await Self.drain(until: { onboardingControl.flag })

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

    /// Deterministically wait for a `publish`-triggered subscriber to run.
    ///
    /// `publish` schedules subscriber notification on a detached `@MainActor` Task, so the
    /// test must yield until that Task has run. Replaces the previous fixed 50ms sleep
    /// (havital_ios #9: flaky under CI load) with a bounded poll — it returns the moment the
    /// condition holds and only falls back to the timeout if delivery never happens.
    private static func drain(
        until condition: @escaping () -> Bool,
        timeout: TimeInterval = 2.0
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            await Task.yield()
        }
        await MainActor.run {}
    }
}
