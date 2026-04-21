import XCTest
import UIKit
@testable import paceriz_dev

final class AppDelegateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        DependencyContainer.shared.reset()
    }

    func testInitDoesNotRequireFeatureDependencies() {
        let appDelegate = AppDelegate()

        XCTAssertNotNil(appDelegate)
    }

    func testWorkoutProcessedNotificationReturnsNoDataWhenRepositoryUnavailable() {
        let appDelegate = AppDelegate()
        let completion = expectation(description: "completion handler called")
        var result: UIBackgroundFetchResult?

        appDelegate.application(
            UIApplication.shared,
            didReceiveRemoteNotification: ["type": "workout_processed"]
        ) { fetchResult in
            result = fetchResult
            completion.fulfill()
        }

        wait(for: [completion], timeout: 1)
        XCTAssertEqual(result, .noData)
    }
}
