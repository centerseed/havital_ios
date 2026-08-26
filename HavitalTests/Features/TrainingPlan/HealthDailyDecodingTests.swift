import XCTest
@testable import paceriz_dev

/// `GET /v2/workouts/health_daily` 的解碼容忍度。
///
/// 起因：2026-08-26 Android 回報同一條端點的 `resting_heart_rate` 是**浮點**
/// （dev 實查 `51.0`），Android 的 DTO 宣告 Int，整包解碼失敗、HRV／RHR 圖
/// 全部變錯誤態。iOS 的 `HealthRecord` 也把 `resting_heart_rate`／`daily_calories`
/// 宣告成 `Int?` —— `51.0` 剛好過得去，`51.5` 會 throw。
///
/// 這條端點是 2.0 恢復詳情頁（checklist §53）HRV × RHR 雙線與訓練負荷卡的唯一
/// producer，一筆炸掉整條序列就沒了，所以在這裡鎖住：**整數欄先當數字讀，再取整。**
///
/// 既有的 `TrainingLoadDataManagerTests.makeHealthRecord()`
/// （`HavitalTests/Features/TrainingPlan/Infrastructure/TrainingLoadDataManagerTests.swift:53`）
/// 也解同一個 payload，但它是那組快取測試的 helper、餵的是整數、也不斷言值 ——
/// 蓋不到這件事，所以這裡是新增而不是重複。
final class HealthDailyDecodingTests: XCTestCase {

    private func decode(_ json: String) throws -> HealthDailyResponse {
        try JSONDecoder().decode(HealthDailyResponse.self, from: Data(json.utf8))
    }

    /// dev 現況的真實形狀（2026-08-26 GET，創辦人 dev 帳號）：
    /// `resting_heart_rate` 是浮點、`tsb_metrics` 是 null。
    func testDecodesRealDevPayloadShape() throws {
        let response = try decode("""
        { "health_data": [
            { "date": "2026-08-26", "daily_calories": 1831, "tsb_metrics": null,
              "hrv_last_night_avg": 47.0, "resting_heart_rate": 51.0 },
            { "date": "2026-08-25", "daily_calories": 2120, "tsb_metrics": null,
              "hrv_last_night_avg": 81.0, "resting_heart_rate": 48.0 }
          ], "count": 2, "limit": 2 }
        """)

        XCTAssertEqual(response.healthData.count, 2)
        XCTAssertEqual(response.healthData[0].restingHeartRate, 51)
        XCTAssertEqual(response.healthData[0].hrvLastNightAvg, 47.0)
        XCTAssertNil(response.healthData[0].tsb)
    }

    /// 非整除的浮點（RHR 是聚合平均，遲早會出現）**不得讓整包解碼失敗**。
    func testDecodesNonIntegralFloatsWithoutThrowing() throws {
        let response = try decode("""
        { "health_data": [
            { "date": "2026-08-26", "daily_calories": 1831.4,
              "hrv_last_night_avg": 47.3, "resting_heart_rate": 51.5 }
          ], "count": 1, "limit": 1 }
        """)

        XCTAssertEqual(response.healthData[0].restingHeartRate, 52)   // 四捨五入
        XCTAssertEqual(response.healthData[0].dailyCalories, 1831)
    }

    /// 既有的整數形狀不能因為容忍浮點就壞掉。
    func testStillDecodesPlainIntegers() throws {
        let response = try decode("""
        { "health_data": [
            { "date": "2026-08-24", "daily_calories": 103, "resting_heart_rate": 54 }
          ], "count": 1, "limit": 1 }
        """)
        XCTAssertEqual(response.healthData[0].restingHeartRate, 54)
        XCTAssertEqual(response.healthData[0].dailyCalories, 103)
    }

    /// prod 有 `tsb_metrics` 的形狀（§51-6／§51-7 的訓練負荷卡靠它）。
    func testDecodesTsbMetricsIncludingFloatTimestamp() throws {
        let response = try decode("""
        { "health_data": [
            { "date": "2026-08-26", "resting_heart_rate": 51.0,
              "tsb_metrics": { "atl": 56.2, "ctl": 42.1, "fitness": 42.1, "tsb": -14.1,
                               "updated_at": 1787702400.0, "workout_trigger": true,
                               "total_tss": 88.5, "created_at": "2026-08-26" } }
          ], "count": 1, "limit": 1 }
        """)

        let record = response.healthData[0]
        XCTAssertEqual(record.tsb ?? 0, -14.1, accuracy: 0.001)
        XCTAssertEqual(record.ctl ?? 0, 42.1, accuracy: 0.001)
        XCTAssertEqual(record.updatedAt, 1_787_702_400)
    }

    /// `GET /v2/workouts/vdots` 的診斷欄（§52-4）同一條規則：`daily_count`
    /// 若以浮點交出來也要解得開。
    func testVdotEntryToleratesFloatDailyCount() throws {
        let response = try JSONDecoder().decode(VDOTResponse.self, from: Data("""
        { "need_updated_hr_range": false,
          "vdots": [ { "datetime": 1787702400, "dynamic_vdot": 38.7, "pace_vdot": 38.7,
                       "daily_count": 10.0, "source": "personal_best",
                       "anchor_date": "2026-08-25", "anchor_decision": "weighted_16x",
                       "confidence": "high" } ] }
        """.utf8))

        let entry = response.vdots[0]
        XCTAssertEqual(entry.dailyCount, 10)
        // `vdot_source` 缺席時退 `source`（後端兩個欄位同義）
        XCTAssertEqual(entry.vdotSource, "personal_best")
        XCTAssertEqual(entry.anchorDate, "2026-08-25")
    }
}
