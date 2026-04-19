import XCTest
import HealthKit
@testable import paceriz_dev

@MainActor
final class HRVChartViewModelTests: XCTestCase {
    private var sut: HRVChartViewModel!
    private var healthKitManager: MockHRVHealthKitManager!
    private let cacheKey = "hrv_data_cache"
    private let cacheTimeKey = "hrv_data_cache_time"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimeKey)
        healthKitManager = MockHRVHealthKitManager()
        sut = HRVChartViewModel(healthKitManager: healthKitManager)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimeKey)
        sut = nil
        healthKitManager = nil
        super.tearDown()
    }

    func testLoadHRVDataGroupsMorningSamplesByDayAndSortsAscending() async {
        let calendar = Calendar.current
        let dayOne = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 1))!
        let dayOneLater = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 5))!
        let dayOneIgnored = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 8))!
        let dayTwo = calendar.date(from: DateComponents(year: 2026, month: 4, day: 11, hour: 2))!
        healthKitManager.hrvDataToReturn = [
            (dayTwo, 72),
            (dayOneIgnored, 99),
            (dayOne, 60),
            (dayOneLater, 66)
        ]

        await sut.loadHRVData()

        XCTAssertEqual(healthKitManager.requestAuthorizationCallCount, 1)
        XCTAssertEqual(sut.hrvData.count, 2)
        XCTAssertEqual(calendar.component(.day, from: sut.hrvData[0].0), 10)
        XCTAssertEqual(calendar.component(.day, from: sut.hrvData[1].0), 11)
        XCTAssertEqual(sut.hrvData[0].1, 63, accuracy: 0.001)
        XCTAssertEqual(sut.hrvData[1].1, 72, accuracy: 0.001)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isLoading)
    }

    func testLoadHRVDataFailureClearsDataAndSetsError() async {
        sut.hrvData = [(Date(), 55)]
        healthKitManager.requestAuthorizationError = NSError(domain: "MockHRVHealthKitManager", code: -1)

        await sut.loadHRVData()

        XCTAssertEqual(sut.error, "無法載入心率變異性數據")
        XCTAssertTrue(sut.hrvData.isEmpty)
        XCTAssertFalse(sut.isLoading)
    }

    func testFetchDiagnosticsBuildsReadableSummary() async {
        healthKitManager.authStatusToReturn = .shouldRequest
        healthKitManager.diagnosticsToReturn = (.sharingAuthorized, 4, ["Apple Watch", "Polar H10"])

        await sut.fetchDiagnostics()

        let diagnosticsText = try? XCTUnwrap(sut.diagnosticsText)
        XCTAssertTrue(diagnosticsText?.contains("讀取授權:") == true)
        XCTAssertTrue(diagnosticsText?.contains("原始樣本數: 4") == true)
        XCTAssertTrue(diagnosticsText?.contains("來源: [Apple Watch, Polar H10]") == true)
    }

    func testFetchReadAuthStatusFailureStoresError() async {
        healthKitManager.authStatusError = NSError(domain: "MockHRVHealthKitManager", code: -2)

        await sut.fetchReadAuthStatus()

        XCTAssertNil(sut.readAuthStatus)
        XCTAssertTrue(sut.error?.contains("讀取授權檢查失敗:") == true)
        XCTAssertTrue(sut.error?.contains("MockHRVHealthKitManager") == true)
        XCTAssertTrue(sut.error?.contains("-2") == true)
    }
}

private final class MockHRVHealthKitManager: HealthKitManager {
    var requestAuthorizationCallCount = 0
    var requestAuthorizationError: Error?
    var hrvDataToReturn: [(Date, Double)] = []
    var hrvDataError: Error?
    var authStatusToReturn: HKAuthorizationRequestStatus = .unknown
    var authStatusError: Error?
    var diagnosticsToReturn: (authStatus: HKAuthorizationStatus, rawSampleCount: Int, sources: [String]) =
        (.notDetermined, 0, [])
    var diagnosticsError: Error?

    override func requestAuthorization() async throws {
        requestAuthorizationCallCount += 1
        if let requestAuthorizationError {
            throw requestAuthorizationError
        }
    }

    override func fetchHRVData(start: Date, end: Date) async throws -> [(Date, Double)] {
        if let hrvDataError {
            throw hrvDataError
        }
        return hrvDataToReturn
    }

    override func checkHRVReadAuthorization() async throws -> HKAuthorizationRequestStatus {
        if let authStatusError {
            throw authStatusError
        }
        return authStatusToReturn
    }

    override func fetchHRVDiagnostics(start: Date, end: Date) async throws -> (authStatus: HKAuthorizationStatus, rawSampleCount: Int, sources: [String]) {
        if let diagnosticsError {
            throw diagnosticsError
        }
        return diagnosticsToReturn
    }
}
