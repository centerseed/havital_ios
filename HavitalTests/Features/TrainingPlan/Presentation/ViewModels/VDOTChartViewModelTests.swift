import XCTest
@testable import paceriz_dev

final class VDOTChartViewModelTests: XCTestCase {
    private let pointsKey = "vdot_points"
    private let needUpdateKey = "vdot_need_update_hr_range"
    private let lastFetchKey = "vdot_last_fetch_time"

    override func setUp() {
        super.setUp()
        clearVDOTStorage()
    }

    override func tearDown() {
        clearVDOTStorage()
        super.tearDown()
    }

    func testInit_LoadsLocalDataAndComputesStatistics() {
        let points = makeSamplePoints()
        VDOTStorage.shared.saveVDOTData(points: points, needUpdatedHrRange: true)

        let viewModel = VDOTChartViewModel()

        XCTAssertEqual(viewModel.vdotPoints.count, 2)
        XCTAssertEqual(viewModel.latestVdot, 42, accuracy: 0.001)
        XCTAssertEqual(viewModel.averageVdot, 43, accuracy: 0.001)
        XCTAssertTrue(viewModel.needUpdatedHrRange)
        XCTAssertEqual(viewModel.yAxisRange.lowerBound, 38.5, accuracy: 0.001)
        XCTAssertEqual(viewModel.yAxisRange.upperBound, 43.5, accuracy: 0.001)
    }

    func testGetVDOTForDate_ReturnsNearestPointNotAfterDate() {
        let points = makeSamplePoints()
        VDOTStorage.shared.saveVDOTData(points: points, needUpdatedHrRange: false)
        let viewModel = VDOTChartViewModel()

        let dateAfterLatest = Date(timeIntervalSince1970: 2_000)
        let dateBetween = Date(timeIntervalSince1970: 1_500)
        let dateBeforeAll = Date(timeIntervalSince1970: 500)

        XCTAssertEqual(viewModel.getVDOTForDate(dateAfterLatest) ?? -1, 42, accuracy: 0.001)
        XCTAssertEqual(viewModel.getVDOTForDate(dateBetween) ?? -1, 40, accuracy: 0.001)
        XCTAssertEqual(viewModel.getVDOTForDate(dateBeforeAll) ?? -1, 40, accuracy: 0.001)
    }

    func testFetchVDOTData_WithFreshCache_DoesNotChangeState() async {
        let points = makeSamplePoints()
        VDOTStorage.shared.saveVDOTData(points: points, needUpdatedHrRange: false)
        let viewModel = VDOTChartViewModel()
        let originalValues = viewModel.vdotPoints.map(\.value)

        await viewModel.fetchVDOTData(limit: 14, forceFetch: false)

        XCTAssertEqual(viewModel.vdotPoints.map(\.value), originalValues)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
    }

    private func makeSamplePoints() -> [VDOTDataPoint] {
        [
            VDOTDataPoint(date: Date(timeIntervalSince1970: 1_000), value: 40, weightVdot: 41),
            VDOTDataPoint(date: Date(timeIntervalSince1970: 1_800), value: 42, weightVdot: 43),
        ]
    }

    private func clearVDOTStorage() {
        UserDefaults.standard.removeObject(forKey: pointsKey)
        UserDefaults.standard.removeObject(forKey: needUpdateKey)
        UserDefaults.standard.removeObject(forKey: lastFetchKey)
    }
}
