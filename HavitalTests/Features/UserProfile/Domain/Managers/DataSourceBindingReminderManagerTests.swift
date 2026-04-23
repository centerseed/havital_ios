import XCTest
@testable import paceriz_dev

@MainActor
final class DataSourceBindingReminderManagerTests: XCTestCase {
    private let reminderKey = "data_source_unbound_last_shown_at"
    private var sut: DataSourceBindingReminderManager { .shared }

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: reminderKey)
        sut.resetSession()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: reminderKey)
        sut.resetSession()
        super.tearDown()
    }

    func testCanShowReminder_FirstEligibleRequest_ReturnsTrue() {
        XCTAssertTrue(sut.canShowReminder(now: Date(timeIntervalSince1970: 1_000)))
    }

    func testCanShowReminder_DoesNotWriteTimestampUntilMarkedShown() {
        let now = Date(timeIntervalSince1970: 10_000)
        XCTAssertTrue(sut.canShowReminder(now: now))
        XCTAssertEqual(UserDefaults.standard.double(forKey: reminderKey), 0)
    }

    func testCanShowReminder_WithinThreeDaysAfterDismiss_ReturnsFalse() {
        let now = Date(timeIntervalSince1970: 10_000)
        XCTAssertTrue(sut.canShowReminder(now: now))

        sut.dismissReminder(now: now)
        sut.resetSession()

        let twoDaysLater = now.addingTimeInterval(2 * 24 * 60 * 60)
        XCTAssertFalse(sut.canShowReminder(now: twoDaysLater))
    }

    func testCanShowReminder_AfterThreeDaysAndSessionReset_ReturnsTrue() {
        let now = Date(timeIntervalSince1970: 20_000)
        XCTAssertTrue(sut.canShowReminder(now: now))

        sut.dismissReminder(now: now)
        sut.resetSession()

        let fourDaysLater = now.addingTimeInterval(4 * 24 * 60 * 60)
        XCTAssertTrue(sut.canShowReminder(now: fourDaysLater))
    }

    func testClearReminderHistory_RemovesCooldownAndResetsSession() {
        let now = Date(timeIntervalSince1970: 30_000)
        sut.dismissReminder(now: now)

        sut.clearReminderHistory()

        XCTAssertEqual(UserDefaults.standard.double(forKey: reminderKey), 0)
        XCTAssertTrue(sut.canShowReminder(now: now.addingTimeInterval(60)))
    }
}
