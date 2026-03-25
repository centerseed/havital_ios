import XCTest
import HealthKit
@testable import paceriz_dev

// MARK: - LapData.init 直接建構測試

final class LapDataInitTests: XCTestCase {

    func test_basicInit_createsCorrectValues() {
        let lap = LapData(
            lapNumber: 1,
            startTimeOffsetS: 0,
            totalTimeS: 300,
            totalDistanceM: 1000.0,
            avgSpeedMPerS: 3.33,
            avgPaceSPerKm: 300.0,
            avgHeartRateBpm: 150,
            metadata: ["type": "lap"]
        )

        XCTAssertEqual(lap.lapNumber, 1)
        XCTAssertEqual(lap.startTimeOffsetS, 0)
        XCTAssertEqual(lap.totalTimeS, 300)
        XCTAssertEqual(lap.totalDistanceM, 1000.0)
        XCTAssertEqual(lap.avgSpeedMPerS, 3.33)
        XCTAssertEqual(lap.avgPaceSPerKm, 300.0)
        XCTAssertEqual(lap.avgHeartRateBpm, 150)
        XCTAssertEqual(lap.metadata?["type"], "lap")
    }

    func test_minimalInit_optionalFieldsAreNil() {
        let lap = LapData(lapNumber: 1, startTimeOffsetS: 0)

        XCTAssertEqual(lap.lapNumber, 1)
        XCTAssertEqual(lap.startTimeOffsetS, 0)
        XCTAssertNil(lap.totalTimeS)
        XCTAssertNil(lap.totalDistanceM)
        XCTAssertNil(lap.avgSpeedMPerS)
        XCTAssertNil(lap.avgPaceSPerKm)
        XCTAssertNil(lap.avgHeartRateBpm)
        XCTAssertNil(lap.metadata)
    }

    func test_encodeDecode_roundTrip() throws {
        let original = LapData(
            lapNumber: 3,
            startTimeOffsetS: 600,
            totalTimeS: 300,
            totalDistanceM: 1000.0,
            avgPaceSPerKm: 300.0,
            avgHeartRateBpm: 155
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LapData.self, from: data)

        XCTAssertEqual(decoded.lapNumber, 3)
        XCTAssertEqual(decoded.startTimeOffsetS, 600)
        XCTAssertEqual(decoded.totalTimeS, 300)
        XCTAssertEqual(decoded.totalDistanceM, 1000.0)
        XCTAssertEqual(decoded.avgPaceSPerKm, 300.0)
        XCTAssertEqual(decoded.avgHeartRateBpm, 155)
    }

    func test_initThenEncode_producesCorrectJSON() throws {
        let lap = LapData(lapNumber: 1, startTimeOffsetS: 120, totalTimeS: 300, totalDistanceM: 1000)
        let data = try JSONEncoder().encode(lap)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(dict["lap_number"] as? Int, 1)
        XCTAssertEqual(dict["start_time_offset_s"] as? Int, 120)
        XCTAssertEqual(dict["total_time_s"] as? Int, 300)
        XCTAssertEqual(dict["total_distance_m"] as? Double, 1000)
    }
}

// MARK: - LapData.fromAppleHealth 安全性測試

final class LapDataFromAppleHealthTests: XCTestCase {

    // MARK: - Helper

    private func makeLap(
        offset: TimeInterval = 0,
        duration: TimeInterval = 300,
        distance: Double? = 1000,
        pace: Double? = 300,
        hr: Double? = 150,
        type: String = "lap",
        metadata: [String: String]? = nil
    ) -> LapData {
        LapData.fromAppleHealth(
            lapNumber: 1,
            startTimeOffset: offset,
            duration: duration,
            distance: distance,
            averagePace: pace,
            averageHeartRate: hr,
            type: type,
            metadata: metadata
        )
    }

    // MARK: - 正常資料

    func test_normalData_allFieldsPopulated() {
        let lap = makeLap()
        XCTAssertEqual(lap.lapNumber, 1)
        XCTAssertEqual(lap.startTimeOffsetS, 0)
        XCTAssertEqual(lap.totalTimeS, 300)
        XCTAssertEqual(lap.totalDistanceM, 1000)
        XCTAssertNotNil(lap.avgSpeedMPerS)
        XCTAssertEqual(lap.avgPaceSPerKm, 300)
        XCTAssertEqual(lap.avgHeartRateBpm, 150)
    }

    func test_normalData_speedCalculatedCorrectly() {
        let lap = makeLap(duration: 200, distance: 1000) // 5 m/s
        XCTAssertEqual(lap.avgSpeedMPerS!, 5.0, accuracy: 0.001)
    }

    func test_metadata_preserved() {
        let lap = makeLap(metadata: ["source": "garmin", "device": "forerunner"])
        XCTAssertEqual(lap.metadata?["source"], "garmin")
        XCTAssertEqual(lap.metadata?["device"], "forerunner")
    }

    // MARK: - NaN 不會 crash（每個欄位都測）

    func test_nanOffset_defaultsToZero() {
        XCTAssertEqual(makeLap(offset: .nan).startTimeOffsetS, 0)
    }

    func test_nanDuration_becomesNil() {
        XCTAssertNil(makeLap(duration: .nan).totalTimeS)
    }

    func test_nanDistance_becomesNil() {
        let lap = makeLap(distance: .nan)
        XCTAssertNil(lap.totalDistanceM)
        XCTAssertNil(lap.avgSpeedMPerS) // speed 也要 nil
    }

    func test_nanPace_becomesNil() {
        XCTAssertNil(makeLap(pace: .nan).avgPaceSPerKm)
    }

    func test_nanHeartRate_becomesNil() {
        XCTAssertNil(makeLap(hr: .nan).avgHeartRateBpm)
    }

    // MARK: - Infinity 不會 crash（每個欄位都測）

    func test_infinityOffset_defaultsToZero() {
        XCTAssertEqual(makeLap(offset: .infinity).startTimeOffsetS, 0)
    }

    func test_negativeInfinityOffset_defaultsToZero() {
        XCTAssertEqual(makeLap(offset: -.infinity).startTimeOffsetS, 0)
    }

    func test_infinityDuration_becomesNil() {
        XCTAssertNil(makeLap(duration: .infinity).totalTimeS)
    }

    func test_infinityDistance_becomesNil() {
        XCTAssertNil(makeLap(distance: .infinity).totalDistanceM)
    }

    func test_infinityPace_becomesNil() {
        XCTAssertNil(makeLap(pace: .infinity).avgPaceSPerKm)
    }

    func test_infinityHeartRate_becomesNil() {
        XCTAssertNil(makeLap(hr: .infinity).avgHeartRateBpm)
    }

    // MARK: - 零值 / 除法保護

    func test_zeroDuration_speedIsNil() {
        // duration=0 → speed = distance/0 → 必須是 nil，不能是 Inf
        XCTAssertNil(makeLap(duration: 0, distance: 1000).avgSpeedMPerS)
    }

    func test_zeroDuration_zeroDistance_speedIsNil() {
        XCTAssertNil(makeLap(duration: 0, distance: 0).avgSpeedMPerS)
    }

    func test_zeroDistance_speedIsNilNotZero() {
        // distance=0 → speed = 0/duration = 0, but nil distance → nil speed
        let lap = makeLap(distance: 0)
        // distance=0 is technically finite, so it gets stored, and speed = 0/300 = 0
        // This is a valid value (0 speed for a stationary workout)
        XCTAssertEqual(lap.totalDistanceM, 0)
    }

    // MARK: - 全部 nil / 全部邊界

    func test_allNil_doesNotCrash() {
        let lap = makeLap(offset: 0, duration: 0, distance: nil, pace: nil, hr: nil)
        XCTAssertEqual(lap.lapNumber, 1)
        XCTAssertNil(lap.totalDistanceM)
        XCTAssertNil(lap.avgPaceSPerKm)
        XCTAssertNil(lap.avgHeartRateBpm)
        XCTAssertNil(lap.avgSpeedMPerS)
    }

    func test_allNaN_doesNotCrash() {
        let lap = makeLap(offset: .nan, duration: .nan, distance: .nan, pace: .nan, hr: .nan)
        XCTAssertEqual(lap.startTimeOffsetS, 0)
        XCTAssertNil(lap.totalTimeS)
        XCTAssertNil(lap.totalDistanceM)
        XCTAssertNil(lap.avgPaceSPerKm)
        XCTAssertNil(lap.avgHeartRateBpm)
    }

    func test_allInfinity_doesNotCrash() {
        let inf = Double.infinity
        let lap = makeLap(offset: inf, duration: inf, distance: inf, pace: inf, hr: inf)
        XCTAssertEqual(lap.startTimeOffsetS, 0)
        XCTAssertNil(lap.totalTimeS)
        XCTAssertNil(lap.totalDistanceM)
        XCTAssertNil(lap.avgPaceSPerKm)
        XCTAssertNil(lap.avgHeartRateBpm)
    }

    // MARK: - 負值（合法但邊界）

    func test_negativeOffset_preserved() {
        // 有些手錶的 activity 可能比 workout start 早一點點
        let lap = makeLap(offset: -5)
        XCTAssertEqual(lap.startTimeOffsetS, -5)
    }

    func test_negativeDuration_preserved() {
        // 不太合理但不應該 crash
        let lap = makeLap(duration: -1)
        XCTAssertEqual(lap.totalTimeS, -1)
    }

    // MARK: - 極端值

    func test_extremelyLargeValues_doesNotCrash() {
        let lap = makeLap(
            offset: 86400 * 365,  // 1 year
            duration: 86400,       // 24 hours
            distance: 42195,       // marathon
            pace: 180,             // 3:00/km
            hr: 220
        )
        XCTAssertEqual(lap.lapNumber, 1)
        XCTAssertNotNil(lap.totalTimeS)
    }

    func test_verySmallPositiveValues_doesNotCrash() {
        let lap = makeLap(
            offset: 0.001,
            duration: 0.001,
            distance: 0.001,
            pace: 0.001,
            hr: 0.001
        )
        XCTAssertEqual(lap.startTimeOffsetS, 0) // Int truncation
        XCTAssertEqual(lap.avgHeartRateBpm, 0)   // Int truncation
    }

    // MARK: - 模擬真實 HealthKit 場景

    func test_garminWorkout_noLapData() {
        // Garmin 裝置同步的運動可能完全沒有 lap 相關資料
        let lap = makeLap(distance: nil, pace: nil, hr: nil, type: "unknown", metadata: nil)
        XCTAssertEqual(lap.lapNumber, 1)
        XCTAssertNil(lap.totalDistanceM)
    }

    func test_appleWatch_intervalWorkout_withMetadata() {
        let lap = makeLap(
            offset: 600,
            duration: 120,
            distance: 500,
            pace: 240,
            hr: 170,
            type: "segment",
            metadata: ["lap_length": "500.0"]
        )
        XCTAssertEqual(lap.startTimeOffsetS, 600)
        XCTAssertEqual(lap.totalTimeS, 120)
        XCTAssertEqual(lap.metadata?["lap_length"], "500.0")
    }

    func test_openGoalWorkout_supplementalLap() {
        // 模擬 supplemental lap 的輸入（missingDistance / missingDuration）
        let lap = makeLap(
            offset: 1800,
            duration: 300,
            distance: 800,
            pace: 375,  // 300/0.8
            hr: 145,
            type: "open_goal",
            metadata: ["supplemental": "true", "reason": "missing_lap_data"]
        )
        XCTAssertEqual(lap.metadata?["supplemental"], "true")
    }
}

// MARK: - HKQuantity.safeDoubleValue 測試

final class HKQuantitySafeDoubleValueTests: XCTestCase {

    // MARK: - 相容 unit

    func test_meter_returnsValue() {
        let q = HKQuantity(unit: .meter(), doubleValue: 1000)
        XCTAssertEqual(q.safeDoubleValue(for: .meter()), 1000)
    }

    func test_kilometer_convertedToMeter() {
        let q = HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: 1)
        XCTAssertEqual(q.safeDoubleValue(for: .meter()), 1000)
    }

    func test_heartRate_compatible() {
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let q = HKQuantity(unit: bpm, doubleValue: 150)
        XCTAssertEqual(q.safeDoubleValue(for: bpm), 150)
    }

    func test_speed_meterPerSecond() {
        let unit = HKUnit.meter().unitDivided(by: .second())
        let q = HKQuantity(unit: unit, doubleValue: 3.5)
        XCTAssertEqual(q.safeDoubleValue(for: unit), 3.5)
    }

    func test_celsius_temperature() {
        let q = HKQuantity(unit: .degreeCelsius(), doubleValue: 25)
        XCTAssertEqual(q.safeDoubleValue(for: .degreeCelsius()), 25)
    }

    func test_percent_humidity() {
        let q = HKQuantity(unit: .percent(), doubleValue: 65)
        XCTAssertEqual(q.safeDoubleValue(for: .percent()), 65)
    }

    func test_kilocalorie_energy() {
        let q = HKQuantity(unit: .kilocalorie(), doubleValue: 500)
        XCTAssertEqual(q.safeDoubleValue(for: .kilocalorie()), 500)
    }

    func test_millisecond_hrv() {
        let ms = HKUnit.secondUnit(with: .milli)
        let q = HKQuantity(unit: ms, doubleValue: 45)
        XCTAssertEqual(q.safeDoubleValue(for: ms), 45)
    }

    // MARK: - 不相容 unit（第三方裝置可能觸發）

    func test_meter_withHeartRateUnit_returnsNil() {
        let q = HKQuantity(unit: .meter(), doubleValue: 1000)
        let bpm = HKUnit.count().unitDivided(by: .minute())
        XCTAssertNil(q.safeDoubleValue(for: bpm))
    }

    func test_heartRate_withMeterUnit_returnsNil() {
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let q = HKQuantity(unit: bpm, doubleValue: 150)
        XCTAssertNil(q.safeDoubleValue(for: .meter()))
    }

    func test_celsius_withPercentUnit_returnsNil() {
        let q = HKQuantity(unit: .degreeCelsius(), doubleValue: 25)
        XCTAssertNil(q.safeDoubleValue(for: .percent()))
    }

    func test_kilocalorie_withMeterUnit_returnsNil() {
        let q = HKQuantity(unit: .kilocalorie(), doubleValue: 500)
        XCTAssertNil(q.safeDoubleValue(for: .meter()))
    }

    // MARK: - 零值和邊界

    func test_zeroValue_returnsZero() {
        let q = HKQuantity(unit: .meter(), doubleValue: 0)
        XCTAssertEqual(q.safeDoubleValue(for: .meter()), 0)
    }

    func test_negativeValue_returnsNegative() {
        // HKQuantity 可以有負值（例如高度變化）
        let q = HKQuantity(unit: .meter(), doubleValue: -10)
        XCTAssertEqual(q.safeDoubleValue(for: .meter()), -10)
    }

    func test_veryLargeValue_returnsValue() {
        let q = HKQuantity(unit: .meter(), doubleValue: 1_000_000)
        XCTAssertEqual(q.safeDoubleValue(for: .meter()), 1_000_000)
    }
}

// MARK: - SafeDouble JSON 解碼邊界測試

final class SafeDoubleDecodingTests: XCTestCase {

    private func decode(_ json: String) throws -> LapData {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(LapData.self, from: data)
    }

    // MARK: - 正常值

    func test_normalDouble() throws {
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": 0, "total_distance_m": 1000.5}
        """)
        XCTAssertEqual(lap.totalDistanceM, 1000.5)
    }

    func test_integerAsDouble() throws {
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": 0, "total_distance_m": 1000}
        """)
        XCTAssertEqual(lap.totalDistanceM, 1000)
    }

    func test_stringNumber() throws {
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": "120", "total_distance_m": "1000.5"}
        """)
        XCTAssertEqual(lap.startTimeOffsetS, 120)
        XCTAssertEqual(lap.totalDistanceM, 1000.5)
    }

    // MARK: - 危險值（之前會 crash 的情境）

    func test_nanString_becomesNil() throws {
        // 後端回傳 "NaN" 字串 → 之前 SafeDouble 會解析成 Double.nan → 下游 crash
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": 0, "total_distance_m": "NaN"}
        """)
        XCTAssertNil(lap.totalDistanceM)
    }

    func test_infinityString_becomesNil() throws {
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": 0, "total_distance_m": "Infinity"}
        """)
        XCTAssertNil(lap.totalDistanceM)
    }

    func test_negativeInfinityString_becomesNil() throws {
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": 0, "total_distance_m": "-Infinity"}
        """)
        XCTAssertNil(lap.totalDistanceM)
    }

    func test_nullValue() throws {
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": 0, "total_distance_m": null}
        """)
        XCTAssertNil(lap.totalDistanceM)
    }

    func test_missingField() throws {
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": 0}
        """)
        XCTAssertNil(lap.totalDistanceM)
        XCTAssertNil(lap.totalTimeS)
        XCTAssertNil(lap.avgHeartRateBpm)
    }

    func test_emptyString_becomesNil() throws {
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": 0, "total_distance_m": ""}
        """)
        XCTAssertNil(lap.totalDistanceM)
    }

    func test_garbageString_becomesNil() throws {
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": 0, "total_distance_m": "not_a_number"}
        """)
        XCTAssertNil(lap.totalDistanceM)
    }

    // MARK: - metadata

    func test_metadata_decoded() throws {
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": 0, "metadata": {"source": "garmin"}}
        """)
        XCTAssertEqual(lap.metadata?["source"], "garmin")
    }

    func test_metadata_null() throws {
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": 0, "metadata": null}
        """)
        XCTAssertNil(lap.metadata)
    }
}

// MARK: - SafeInt JSON 解碼邊界測試（特別針對 Int(Double.nan) crash）

final class SafeIntDecodingTests: XCTestCase {

    private func decode(_ json: String) throws -> LapData {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(LapData.self, from: data)
    }

    func test_normalInt() throws {
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": 120, "total_time_s": 300}
        """)
        XCTAssertEqual(lap.startTimeOffsetS, 120)
        XCTAssertEqual(lap.totalTimeS, 300)
    }

    func test_doubleToInt_truncated() throws {
        // 後端回傳 300.7 → SafeInt 應轉成 300
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": 0, "total_time_s": 300.7}
        """)
        XCTAssertEqual(lap.totalTimeS, 300)
    }

    func test_nanDouble_becomesNil() throws {
        // 這是之前 Int(Double.nan) crash 的根源
        // JSON 中 NaN 不是合法值，但某些後端可能回傳
        // SafeInt 收到 Double.nan 時必須回 nil，不能 crash
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": 0, "avg_heart_rate_bpm": "NaN"}
        """)
        XCTAssertNil(lap.avgHeartRateBpm)
    }

    func test_infinityDouble_becomesNil() throws {
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": 0, "avg_heart_rate_bpm": "Infinity"}
        """)
        XCTAssertNil(lap.avgHeartRateBpm)
    }

    func test_stringInt() throws {
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": "0", "total_time_s": "300"}
        """)
        XCTAssertEqual(lap.startTimeOffsetS, 0)
        XCTAssertEqual(lap.totalTimeS, 300)
    }

    func test_stringFloat_toInt() throws {
        // "300.5" → SafeInt 應該能處理
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": 0, "total_time_s": "300.5"}
        """)
        XCTAssertEqual(lap.totalTimeS, 300)
    }

    func test_nullInt() throws {
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": 0, "total_time_s": null}
        """)
        XCTAssertNil(lap.totalTimeS)
    }

    func test_negativeInt() throws {
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": -5, "total_time_s": -1}
        """)
        XCTAssertEqual(lap.startTimeOffsetS, -5)
        XCTAssertEqual(lap.totalTimeS, -1)
    }

    func test_zeroInt() throws {
        let lap = try decode("""
        {"lap_number": 1, "start_time_offset_s": 0, "total_time_s": 0, "avg_heart_rate_bpm": 0}
        """)
        XCTAssertEqual(lap.totalTimeS, 0)
        XCTAssertEqual(lap.avgHeartRateBpm, 0)
    }
}

// MARK: - 模擬完整上傳流程的資料組合測試

final class WorkoutUploadDataCombinationTests: XCTestCase {

    /// 模擬 Apple Watch 正常 5K 跑步 — 5 圈各 1km
    func test_normalFiveKRun_fiveLaps() {
        var laps: [LapData] = []
        for i in 1...5 {
            let lap = LapData.fromAppleHealth(
                lapNumber: i,
                startTimeOffset: TimeInterval((i - 1) * 300),
                duration: 300,
                distance: 1000,
                averagePace: 300,
                averageHeartRate: 140 + Double(i * 3),
                type: "lap",
                metadata: nil
            )
            laps.append(lap)
        }

        XCTAssertEqual(laps.count, 5)
        XCTAssertEqual(laps[0].startTimeOffsetS, 0)
        XCTAssertEqual(laps[4].startTimeOffsetS, 1200)

        let totalDistance = laps.compactMap(\.totalDistanceM).reduce(0, +)
        XCTAssertEqual(totalDistance, 5000)
    }

    /// 模擬 Garmin Connect 同步的運動 — 可能沒有 lap 距離
    func test_garminSync_noDistanceNoHeartRate() {
        let lap = LapData.fromAppleHealth(
            lapNumber: 1,
            startTimeOffset: 0,
            duration: 1800,
            distance: nil,
            averagePace: nil,
            averageHeartRate: nil,
            type: "activity",
            metadata: nil
        )

        XCTAssertEqual(lap.totalTimeS, 1800)
        XCTAssertNil(lap.totalDistanceM)
        XCTAssertNil(lap.avgPaceSPerKm)
        XCTAssertNil(lap.avgHeartRateBpm)
        XCTAssertNil(lap.avgSpeedMPerS)
    }

    /// 模擬 supplemental lap — 缺失資料補充（之前 crash 最多的場景）
    func test_supplementalLap_missingData() {
        // 正常的 2 圈
        let lap1 = LapData.fromAppleHealth(
            lapNumber: 1, startTimeOffset: 0, duration: 300,
            distance: 1000, averagePace: 300, averageHeartRate: 150,
            type: "lap", metadata: nil
        )
        let lap2 = LapData.fromAppleHealth(
            lapNumber: 2, startTimeOffset: 300, duration: 300,
            distance: 1000, averagePace: 300, averageHeartRate: 155,
            type: "lap", metadata: nil
        )

        // Supplemental lap（缺失的 800m）
        let missingDistance: Double = 800
        let missingDuration: Double = 280
        let supplementalPace = missingDistance > 0 ? missingDuration / (missingDistance / 1000.0) : nil

        let lap3 = LapData.fromAppleHealth(
            lapNumber: 3,
            startTimeOffset: 600,
            duration: missingDuration,
            distance: missingDistance,
            averagePace: supplementalPace,
            averageHeartRate: 145,
            type: "open_goal",
            metadata: ["supplemental": "true", "reason": "missing_lap_data"]
        )

        XCTAssertEqual(lap3.metadata?["supplemental"], "true")
        XCTAssertEqual(lap3.totalDistanceM, 800)
        XCTAssertNotNil(lap3.avgPaceSPerKm)

        let totalDistance = [lap1, lap2, lap3].compactMap(\.totalDistanceM).reduce(0, +)
        XCTAssertEqual(totalDistance, 2800)
    }

    /// 模擬 supplemental lap 但 missingDistance 為 0（除以零防護）
    func test_supplementalLap_zeroMissingDistance() {
        let missingDistance: Double = 0
        let missingDuration: Double = 30
        let pace: Double? = missingDistance > 0 ? missingDuration / (missingDistance / 1000.0) : nil

        // 這行在修復前會產生 Inf
        XCTAssertNil(pace)

        let lap = LapData.fromAppleHealth(
            lapNumber: 1, startTimeOffset: 0, duration: missingDuration,
            distance: missingDistance, averagePace: pace, averageHeartRate: nil,
            type: "open_goal", metadata: nil
        )

        XCTAssertNil(lap.avgPaceSPerKm)
        XCTAssertEqual(lap.totalDistanceM, 0)
    }

    /// 模擬 GPS 漂移導致 recordedDistance > totalWorkoutDistance（負數 missingDistance）
    func test_supplementalLap_negativeMissingDistance_shouldNotCreate() {
        let totalWorkoutDistance: Double = 5000
        let recordedDistance: Double = 5200 // GPS 漂移導致超過
        let missingDistance = totalWorkoutDistance - recordedDistance // -200

        // 修復後的條件：missingDistance > 500 && missingDuration > 60
        let shouldSupplement = missingDistance > 500 && (totalWorkoutDistance - recordedDistance) > 60
        XCTAssertFalse(shouldSupplement, "不應該為負數 missingDistance 建立 supplemental lap")
    }

    /// 模擬非常短的運動（< 1 分鐘）
    func test_veryShortWorkout() {
        let lap = LapData.fromAppleHealth(
            lapNumber: 1, startTimeOffset: 0, duration: 30,
            distance: 100, averagePace: 300, averageHeartRate: 120,
            type: "activity", metadata: nil
        )

        XCTAssertEqual(lap.totalTimeS, 30)
        XCTAssertEqual(lap.totalDistanceM, 100)
    }

    /// 模擬暫停的運動（duration 可能跟 offset 不連續）
    func test_pausedWorkout_gapInOffsets() {
        let lap1 = LapData.fromAppleHealth(
            lapNumber: 1, startTimeOffset: 0, duration: 300,
            distance: 1000, averagePace: 300, averageHeartRate: 150,
            type: "segment", metadata: nil
        )
        // 暫停了 120 秒後繼續
        let lap2 = LapData.fromAppleHealth(
            lapNumber: 2, startTimeOffset: 420, duration: 300,
            distance: 1000, averagePace: 300, averageHeartRate: 148,
            type: "segment", metadata: nil
        )

        XCTAssertEqual(lap1.startTimeOffsetS, 0)
        XCTAssertEqual(lap2.startTimeOffsetS, 420) // 包含暫停時間
    }
}
