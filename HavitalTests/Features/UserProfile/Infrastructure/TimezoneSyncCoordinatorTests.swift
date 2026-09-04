import XCTest
@testable import paceriz_dev

/// T-0430 Contract 3：純測試（不碰網路，`TimezoneSyncCoordinator` 用注入的
/// `TimezoneSyncGateway` mock 覆蓋三個決策分支）。
final class TimezoneSyncCoordinatorTests: XCTestCase {

    // MARK: - timezone_is_set == false → 觸發一次 PUT，帶裝置時區

    func testTimezoneIsSetFalseTriggersOnePutWithDeviceTimezone() async {
        let gateway = MockTimezoneSyncGateway(
            backendStatus: (timezoneIsSet: false, timezone: "Asia/Taipei")
        )
        let sut = TimezoneSyncCoordinator(
            gateway: gateway,
            deviceTimezoneProvider: { "America/New_York" },
            log: { _ in }
        )

        let outcome = await sut.run()

        XCTAssertEqual(outcome, .putSucceeded("America/New_York"))
        XCTAssertEqual(gateway.putTimezoneCalls, ["America/New_York"])
        XCTAssertEqual(gateway.syncLocalTimezoneCalls, [])
    }

    // MARK: - timezone_is_set == true → 不 PUT

    func testTimezoneIsSetTrueDoesNotPut() async {
        let gateway = MockTimezoneSyncGateway(
            backendStatus: (timezoneIsSet: true, timezone: "Asia/Taipei"),
            localTimezone: "Asia/Taipei"
        )
        let sut = TimezoneSyncCoordinator(
            gateway: gateway,
            deviceTimezoneProvider: { "America/New_York" },
            log: { _ in }
        )

        let outcome = await sut.run()

        XCTAssertEqual(outcome, .alreadySet)
        XCTAssertEqual(gateway.putTimezoneCalls, [])
    }

    func testTimezoneIsSetTrueWithLocalMismatchSyncsLocalOnlyNoPut() async {
        let gateway = MockTimezoneSyncGateway(
            backendStatus: (timezoneIsSet: true, timezone: "Asia/Tokyo"),
            localTimezone: "Asia/Taipei"
        )
        let sut = TimezoneSyncCoordinator(
            gateway: gateway,
            deviceTimezoneProvider: { "America/New_York" },
            log: { _ in }
        )

        let outcome = await sut.run()

        XCTAssertEqual(outcome, .localSynced("Asia/Tokyo"))
        XCTAssertEqual(gateway.putTimezoneCalls, [])
        XCTAssertEqual(gateway.syncLocalTimezoneCalls, ["Asia/Tokyo"])
    }

    // MARK: - PUT 失敗 → 本地不標已同步（不呼叫任何本地寫入）

    func testPutFailureDoesNotMarkLocalAsSynced() async {
        let gateway = MockTimezoneSyncGateway(
            backendStatus: (timezoneIsSet: false, timezone: "Asia/Taipei"),
            putError: URLError(.notConnectedToInternet)
        )
        let sut = TimezoneSyncCoordinator(
            gateway: gateway,
            deviceTimezoneProvider: { "America/New_York" },
            log: { _ in }
        )

        let outcome = await sut.run()

        XCTAssertEqual(outcome, .putFailed)
        XCTAssertEqual(gateway.putTimezoneCalls, ["America/New_York"])
        XCTAssertEqual(gateway.syncLocalTimezoneCalls, [])
    }

    // MARK: - GET 失敗 → 本次啟動放棄，不 PUT

    func testFetchFailureSkipsWithoutPut() async {
        let gateway = MockTimezoneSyncGateway(backendStatus: nil)
        let sut = TimezoneSyncCoordinator(
            gateway: gateway,
            deviceTimezoneProvider: { "America/New_York" },
            log: { _ in }
        )

        let outcome = await sut.run()

        XCTAssertEqual(outcome, .fetchFailed)
        XCTAssertEqual(gateway.putTimezoneCalls, [])
    }
}

// MARK: - Mock Gateway

private final class MockTimezoneSyncGateway: TimezoneSyncGateway {
    private let backendStatus: (timezoneIsSet: Bool, timezone: String)?
    var localTimezone: String?
    private let putError: Error?

    private(set) var putTimezoneCalls: [String] = []
    private(set) var syncLocalTimezoneCalls: [String] = []

    init(
        backendStatus: (timezoneIsSet: Bool, timezone: String)?,
        localTimezone: String? = nil,
        putError: Error? = nil
    ) {
        self.backendStatus = backendStatus
        self.localTimezone = localTimezone
        self.putError = putError
    }

    func fetchBackendTimezoneStatus() async -> (timezoneIsSet: Bool, timezone: String)? {
        backendStatus
    }

    func putTimezone(_ timezone: String) async throws {
        putTimezoneCalls.append(timezone)
        if let putError {
            throw putError
        }
    }

    func syncLocalTimezone(_ timezone: String) {
        syncLocalTimezoneCalls.append(timezone)
        localTimezone = timezone
    }
}
