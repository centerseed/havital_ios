import XCTest
@testable import paceriz_dev

final class HeartRateProfileRefreshNotifierTests: XCTestCase {
    func test_profileModeSavePublishesUserDataChangedEvent() async {
        let identifier = "HeartRateProfileRefreshNotifierTests.profile.\(UUID().uuidString)"
        let received = expectation(description: "profile mode heart-rate save publishes user refresh")

        CacheEventBus.shared.subscribe(forIdentifier: identifier) { event in
            if case .dataChanged(.user) = event {
                received.fulfill()
            }
        }

        HeartRateProfileRefreshNotifier.notifySaved(isOnboardingMode: false)

        await fulfillment(of: [received], timeout: 1.0)
        CacheEventBus.shared.unsubscribe(forIdentifier: identifier)
    }

    func test_onboardingModeSaveDoesNotPublishUserDataChangedEvent() async {
        let identifier = "HeartRateProfileRefreshNotifierTests.onboarding.\(UUID().uuidString)"
        let notExpected = expectation(description: "onboarding mode heart-rate save should not publish user refresh")
        notExpected.isInverted = true

        CacheEventBus.shared.subscribe(forIdentifier: identifier) { event in
            if case .dataChanged(.user) = event {
                notExpected.fulfill()
            }
        }

        HeartRateProfileRefreshNotifier.notifySaved(isOnboardingMode: true)

        await fulfillment(of: [notExpected], timeout: 0.2)
        CacheEventBus.shared.unsubscribe(forIdentifier: identifier)
    }
}
