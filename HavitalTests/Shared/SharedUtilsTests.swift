import XCTest
@testable import Havital

/// 配速格式化工具測試
class PaceFormatterTests: XCTestCase {

    // MARK: - 配速轉換測試

    func testPaceToSeconds_ValidPace() {
        // 測試有效的配速字符串
        XCTAssertEqual(PaceFormatter.paceToSeconds("5:30"), 330)
        XCTAssertEqual(PaceFormatter.paceToSeconds("4:00"), 240)
        XCTAssertEqual(PaceFormatter.paceToSeconds("6:45"), 405)
    }

    func testPaceToSeconds_InvalidPace() {
        // 測試無效的配速字符串
        XCTAssertNil(PaceFormatter.paceToSeconds("invalid"))
        XCTAssertNil(PaceFormatter.paceToSeconds("5"))
        XCTAssertNil(PaceFormatter.paceToSeconds(""))
    }

    func testSecondsToPace() {
        // 測試秒數轉配速字符串
        XCTAssertEqual(PaceFormatter.secondsToPace(330), "5:30")
        XCTAssertEqual(PaceFormatter.secondsToPace(240), "4:00")
        XCTAssertEqual(PaceFormatter.secondsToPace(65), "1:05")
    }

    // MARK: - 配速區間測試

    func testPaceRange() {
        // 測試配速區間計算（±20秒）
        let range = PaceFormatter.paceRange(targetPace: "5:00")
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.min, "5:20") // 慢的在左
        XCTAssertEqual(range?.max, "4:40") // 快的在右
    }

    func testPaceRange_CustomVariance() {
        // 測試自定義偏差值
        let range = PaceFormatter.paceRange(targetPace: "4:30", variance: 30)
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.min, "5:00") // 4:30 + 30s
        XCTAssertEqual(range?.max, "4:00") // 4:30 - 30s
    }

    // MARK: - 配速狀態判斷測試

    func testIsPaceInRange_Ideal() {
        // 在目標區間內（±20秒）
        let status = PaceFormatter.isPaceInRange(
            currentPace: 300, // 5:00
            targetPace: "5:00"
        )
        XCTAssertEqual(status, .ideal)
    }

    func testIsPaceInRange_TooFast() {
        // 配速過快（< 目標 - 20秒）
        let status = PaceFormatter.isPaceInRange(
            currentPace: 260, // 4:20
            targetPace: "5:00" // 目標 5:00，快的界限 4:40
        )
        XCTAssertEqual(status, .tooFast)
    }

    func testIsPaceInRange_TooSlow() {
        // 配速過慢（> 目標 + 20秒）
        let status = PaceFormatter.isPaceInRange(
            currentPace: 340, // 5:40
            targetPace: "5:00" // 目標 5:00，慢的界限 5:20
        )
        XCTAssertEqual(status, .tooSlow)
    }

    func testIsPaceInRange_EdgeCases() {
        // 邊界情況：剛好在區間邊緣
        let statusAtLowEdge = PaceFormatter.isPaceInRange(
            currentPace: 320, // 5:20（慢的界限）
            targetPace: "5:00"
        )
        XCTAssertEqual(statusAtLowEdge, .ideal)

        let statusAtHighEdge = PaceFormatter.isPaceInRange(
            currentPace: 280, // 4:40（快的界限）
            targetPace: "5:00"
        )
        XCTAssertEqual(statusAtHighEdge, .ideal)
    }
}

/// 訓練類型判斷測試
class TrainingTypeHelperTests: XCTestCase {

    func testIsEasyWorkout() {
        // 輕鬆課表
        XCTAssertTrue(TrainingTypeHelper.isEasyWorkout("easy"))
        XCTAssertTrue(TrainingTypeHelper.isEasyWorkout("recovery_run"))
        XCTAssertTrue(TrainingTypeHelper.isEasyWorkout("lsd"))

        // 非輕鬆課表
        XCTAssertFalse(TrainingTypeHelper.isEasyWorkout("interval"))
        XCTAssertFalse(TrainingTypeHelper.isEasyWorkout("tempo"))
        XCTAssertFalse(TrainingTypeHelper.isEasyWorkout("threshold"))
    }

    func testIsIntervalWorkout() {
        XCTAssertTrue(TrainingTypeHelper.isIntervalWorkout("interval"))
        XCTAssertFalse(TrainingTypeHelper.isIntervalWorkout("easy"))
    }

    func testIsCombinationWorkout() {
        XCTAssertTrue(TrainingTypeHelper.isCombinationWorkout("combination"))
        XCTAssertTrue(TrainingTypeHelper.isCombinationWorkout("progression"))
        XCTAssertFalse(TrainingTypeHelper.isCombinationWorkout("interval"))
    }

    func testGetWorkoutMode() {
        // 心率模式
        XCTAssertEqual(
            TrainingTypeHelper.getWorkoutMode("easy"),
            .heartRate
        )

        // 配速模式
        XCTAssertEqual(
            TrainingTypeHelper.getWorkoutMode("tempo"),
            .pace
        )

        // 間歇模式
        XCTAssertEqual(
            TrainingTypeHelper.getWorkoutMode("interval"),
            .interval
        )

        // 組合跑模式
        XCTAssertEqual(
            TrainingTypeHelper.getWorkoutMode("combination"),
            .combination
        )

        // 休息
        XCTAssertEqual(
            TrainingTypeHelper.getWorkoutMode("rest"),
            .rest
        )
    }
}

/// 心率區間判斷測試
class HeartRateZoneDetectorTests: XCTestCase {

    var mockZones: [WatchHeartRateZone]!

    override func setUp() {
        super.setUp()
        // 創建模擬心率區間（基於 MaxHR=190, RestingHR=55）
        mockZones = [
            WatchHeartRateZone(zone: 1, name: "輕鬆", minHR: 135, maxHR: 155, description: "Z1"),
            WatchHeartRateZone(zone: 2, name: "馬拉松", minHR: 155, maxHR: 168, description: "Z2"),
            WatchHeartRateZone(zone: 3, name: "閾值", minHR: 168, maxHR: 174, description: "Z3"),
            WatchHeartRateZone(zone: 4, name: "有氧", minHR: 174, maxHR: 183, description: "Z4"),
            WatchHeartRateZone(zone: 5, name: "無氧", minHR: 183, maxHR: 190, description: "Z5")
        ]
    }

    func testDetectZone_Z1() {
        let zone = HeartRateZoneDetector.detectZone(currentHR: 145, zones: mockZones)
        XCTAssertNotNil(zone)
        XCTAssertEqual(zone?.zone, 1)
    }

    func testDetectZone_Z3() {
        let zone = HeartRateZoneDetector.detectZone(currentHR: 170, zones: mockZones)
        XCTAssertNotNil(zone)
        XCTAssertEqual(zone?.zone, 3)
    }

    func testDetectZone_OutOfRange() {
        // 心率過低
        let lowZone = HeartRateZoneDetector.detectZone(currentHR: 100, zones: mockZones)
        XCTAssertNil(lowZone)

        // 心率過高
        let highZone = HeartRateZoneDetector.detectZone(currentHR: 200, zones: mockZones)
        XCTAssertNil(highZone)
    }

    func testHeartRateStatus_InRange() {
        let range = WatchHeartRateRange(min: 120, max: 145)
        let status = HeartRateZoneDetector.heartRateStatus(
            currentHR: 135,
            targetRange: range
        )
        XCTAssertEqual(status, .inRange)
    }

    func testHeartRateStatus_TooHigh() {
        let range = WatchHeartRateRange(min: 120, max: 145)
        let status = HeartRateZoneDetector.heartRateStatus(
            currentHR: 160,
            targetRange: range
        )
        XCTAssertEqual(status, .tooHigh)
    }

    func testHeartRateStatus_TooLow() {
        let range = WatchHeartRateRange(min: 120, max: 145)
        let status = HeartRateZoneDetector.heartRateStatus(
            currentHR: 110,
            targetRange: range
        )
        XCTAssertEqual(status, .tooLow)
    }
}

/// 恢復段類型檢測測試
class RecoveryTypeDetectorTests: XCTestCase {

    func testGetRecoveryType_ActiveRecovery() {
        // 主動恢復跑（有距離）
        let segment = WatchWorkoutSegment(
            description: "恢復跑",
            distanceKm: nil,
            distanceM: 400,
            timeMinutes: nil,
            pace: "6:00",
            heartRateRange: nil
        )

        let type = RecoveryTypeDetector.getRecoveryType(from: segment)

        switch type {
        case .activeRecovery(let distance, let pace):
            XCTAssertEqual(distance, 400)
            XCTAssertEqual(pace, "6:00")
        default:
            XCTFail("應該是主動恢復跑")
        }
    }

    func testGetRecoveryType_Rest() {
        // 全休（有時間）
        let segment = WatchWorkoutSegment(
            description: "全休",
            distanceKm: nil,
            distanceM: nil,
            timeMinutes: 2.0,
            pace: nil,
            heartRateRange: nil
        )

        let type = RecoveryTypeDetector.getRecoveryType(from: segment)

        switch type {
        case .rest(let duration):
            XCTAssertEqual(duration, 120) // 2 分鐘 = 120 秒
        default:
            XCTFail("應該是全休")
        }
    }

    func testGetRecoveryType_None() {
        // 無恢復段
        let type = RecoveryTypeDetector.getRecoveryType(from: nil)

        switch type {
        case .none:
            XCTAssertTrue(true)
        default:
            XCTFail("應該是無恢復段")
        }
    }
}

/// 距離格式化測試
class DistanceFormatterTests: XCTestCase {

    func testFormatKilometers_LongDistance() {
        // >= 10km，顯示 1 位小數
        XCTAssertEqual(DistanceFormatter.formatKilometers(10.5), "10.5 km")
        XCTAssertEqual(DistanceFormatter.formatKilometers(15.0), "15.0 km")
    }

    func testFormatKilometers_ShortDistance() {
        // < 10km，顯示 2 位小數
        XCTAssertEqual(DistanceFormatter.formatKilometers(5.25), "5.25 km")
        XCTAssertEqual(DistanceFormatter.formatKilometers(3.14), "3.14 km")
    }

    func testFormatMeters_Kilometers() {
        // >= 1000m，轉換為公里
        XCTAssertEqual(DistanceFormatter.formatMeters(1500), "1.50 km")
        XCTAssertEqual(DistanceFormatter.formatMeters(10000), "10.0 km")
    }

    func testFormatMeters_Meters() {
        // < 1000m，顯示米
        XCTAssertEqual(DistanceFormatter.formatMeters(500), "500 m")
        XCTAssertEqual(DistanceFormatter.formatMeters(123), "123 m")
    }
}

/// 時間格式化測試
class DurationFormatterTests: XCTestCase {

    func testFormatDuration_WithHours() {
        // 有小時
        let duration: TimeInterval = 3665 // 1h 1m 5s
        XCTAssertEqual(DurationFormatter.formatDuration(duration), "1:01:05")
    }

    func testFormatDuration_WithoutHours() {
        // 無小時
        let duration: TimeInterval = 665 // 11m 5s
        XCTAssertEqual(DurationFormatter.formatDuration(duration), "11:05")
    }

    func testFormatShort() {
        // 簡短格式
        XCTAssertEqual(DurationFormatter.formatShort(3665), "1h 1m")
        XCTAssertEqual(DurationFormatter.formatShort(665), "11m")
        XCTAssertEqual(DurationFormatter.formatShort(45), "0m")
    }
}
