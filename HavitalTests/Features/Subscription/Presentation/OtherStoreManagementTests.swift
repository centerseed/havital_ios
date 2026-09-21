import SwiftUI
import XCTest
@testable import paceriz_dev

@MainActor
final class OtherStoreManagementTests: XCTestCase {
    func testRun_WhenActiveOnOtherStore_SetsMessageAndSkipsAction() {
        let status = SubscriptionStatusEntity(status: .active, store: "PLAY_STORE")
        var message: String?
        let binding = Binding(get: { message }, set: { message = $0 })
        var ran = false

        OtherStoreManagement.run(status: status, message: binding) {
            ran = true
        }

        XCTAssertFalse(ran)
        XCTAssertEqual(message, status.otherStoreManagementMessage)
    }

    func testRun_WhenActiveOnAppStore_RunsActionAndLeavesMessageNil() {
        let status = SubscriptionStatusEntity(status: .active, store: "APP_STORE")
        var message: String?
        let binding = Binding(get: { message }, set: { message = $0 })
        var ran = false

        OtherStoreManagement.run(status: status, message: binding) {
            ran = true
        }

        XCTAssertTrue(ran)
        XCTAssertNil(message)
    }

    func testRun_WhenStatusIsNil_RunsAction() {
        var message: String?
        let binding = Binding(get: { message }, set: { message = $0 })
        var ran = false

        OtherStoreManagement.run(status: nil, message: binding) {
            ran = true
        }

        XCTAssertTrue(ran)
        XCTAssertNil(message)
    }
}
