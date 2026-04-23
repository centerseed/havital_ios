import XCTest
@testable import paceriz_dev

class WeeklyPlanDecodingTests: XCTestCase {
    // 將測試 JSON 放在 Fixtures 資料夾
    let fixturesFolder = "WeeklyPlanFixtures"

    // MARK: - 通用 fixture 測試（V1/V2/V3 全部）

    func testAllWeeklyPlanJSONs() throws {
        let testFilePath = #file
        let testDir = (testFilePath as NSString).deletingLastPathComponent
        let fixturesDir = (testDir as NSString).appendingPathComponent("WeeklyPlanFixtures")

        let fileManager = FileManager.default
        let jsonFiles = try fileManager.contentsOfDirectory(atPath: fixturesDir)
            .filter { $0.hasSuffix(".json") }

        XCTAssertFalse(jsonFiles.isEmpty, "測試資料夾沒有任何 JSON 檔案")

        for jsonFile in jsonFiles {
            let jsonPath = (fixturesDir as NSString).appendingPathComponent(jsonFile)
            let data = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
            do {
                let plan = try JSONDecoder().decode(WeeklyPlan.self, from: data)
                XCTAssertNotNil(plan, "解析失敗: \(jsonFile)")
            } catch {
                XCTFail("解析 \(jsonFile) 失敗: \(error)")
            }
        }
    }

    // MARK: - V3 Easy Run 解碼

    func testV3EasyRunDecoding() throws {
        let json = """
        {
          "id": "v3_easy_1", "purpose": "test", "week_of_plan": 1, "total_weeks": 4,
          "total_distance_km": 30, "total_distance_reason": "test", "design_reason": ["test"],
          "days": [{
            "day_index": 1, "category": "run",
            "primary": {
              "run_type": "easy", "distance_km": 8.0, "pace": "5:45",
              "heart_rate_range": {"min": 130, "max": 145},
              "description": "輕鬆跑"
            },
            "warmup": {"distance_km": 1.0, "pace": "6:30"},
            "cooldown": {"distance_km": 1.0, "pace": "6:30"},
            "day_target": "有氧", "reason": "基礎"
          },
          {"day_index": 2, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 3, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 4, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 5, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 6, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 7, "category": "rest", "day_target": "休息", "reason": "恢復"}]
        }
        """.data(using: .utf8)!

        let plan = try JSONDecoder().decode(WeeklyPlan.self, from: json)
        let day1 = plan.days[0]

        XCTAssertEqual(day1.trainingType, "easy")
        XCTAssertEqual(day1.trainingDetails?.distanceKm, 8.0)
        XCTAssertEqual(day1.trainingDetails?.pace, "5:45")
        XCTAssertEqual(day1.trainingDetails?.heartRateRange?.min, 130)
        XCTAssertEqual(day1.trainingDetails?.heartRateRange?.max, 145)
        XCTAssertEqual(day1.trainingDetails?.warmup?.distanceKm, 1.0)
        XCTAssertEqual(day1.trainingDetails?.cooldown?.pace, "6:30")
        XCTAssertEqual(day1.type, .easy)
        XCTAssertTrue(day1.isTrainingDay)
    }

    // MARK: - V3 Interval with variant 解碼

    func testV3IntervalWithVariantDecoding() throws {
        let json = """
        {
          "id": "v3_iv_1", "purpose": "test", "week_of_plan": 1, "total_weeks": 4,
          "total_distance_km": 30, "total_distance_reason": "test", "design_reason": ["test"],
          "days": [{
            "day_index": 1, "category": "run",
            "primary": {
              "run_type": "interval",
              "interval": {
                "repeats": 6, "work_distance_m": 100, "work_pace": "3:30",
                "work_description": "大步跑",
                "recovery_duration_seconds": 60,
                "recovery_description": "原地休息",
                "variant": "strides"
              },
              "description": "6x100m strides"
            },
            "day_target": "跑姿", "reason": "test"
          },
          {"day_index": 2, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 3, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 4, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 5, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 6, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 7, "category": "rest", "day_target": "休息", "reason": "恢復"}]
        }
        """.data(using: .utf8)!

        let plan = try JSONDecoder().decode(WeeklyPlan.self, from: json)
        let day1 = plan.days[0]

        // variant=strides → trainingType 應映射為 "strides"
        XCTAssertEqual(day1.trainingType, "strides")
        XCTAssertEqual(day1.type, .strides)
        XCTAssertEqual(day1.trainingDetails?.repeats, 6)
        XCTAssertEqual(day1.trainingDetails?.work?.distanceM, 100)
        XCTAssertEqual(day1.trainingDetails?.work?.pace, "3:30")
        XCTAssertEqual(day1.trainingDetails?.recovery?.timeSeconds, 60)
        XCTAssertNil(day1.trainingDetails?.recovery?.distanceKm)
    }

    // MARK: - V3 Tempo with segments 解碼

    func testV3TempoWithSegmentsDecoding() throws {
        let json = """
        {
          "id": "v3_tempo_1", "purpose": "test", "week_of_plan": 1, "total_weeks": 4,
          "total_distance_km": 30, "total_distance_reason": "test", "design_reason": ["test"],
          "days": [{
            "day_index": 1, "category": "run",
            "primary": {
              "run_type": "tempo",
              "segments": [
                {"distance_km": 2.0, "pace": "5:30", "description": "暖身段"},
                {"distance_km": 4.0, "pace": "4:50", "description": "節奏段"},
                {"distance_km": 2.0, "pace": "5:30", "description": "緩和段"}
              ],
              "description": "分段節奏跑"
            },
            "day_target": "乳酸閾值", "reason": "test"
          },
          {"day_index": 2, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 3, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 4, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 5, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 6, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 7, "category": "rest", "day_target": "休息", "reason": "恢復"}]
        }
        """.data(using: .utf8)!

        let plan = try JSONDecoder().decode(WeeklyPlan.self, from: json)
        let day1 = plan.days[0]

        XCTAssertEqual(day1.trainingType, "tempo")
        XCTAssertEqual(day1.type, .tempo)
        XCTAssertEqual(day1.trainingDetails?.segments?.count, 3)
        XCTAssertEqual(day1.trainingDetails?.totalDistanceKm, 8.0)
        XCTAssertEqual(day1.trainingDetails?.segments?[1].pace, "4:50")
    }

    // MARK: - V3 Strength 解碼

    func testV3StrengthDecoding() throws {
        let json = """
        {
          "id": "v3_str_1", "purpose": "test", "week_of_plan": 1, "total_weeks": 4,
          "total_distance_km": 30, "total_distance_reason": "test", "design_reason": ["test"],
          "days": [{
            "day_index": 1, "category": "strength",
            "primary": {
              "strength_type": "core_stability",
              "exercises": [
                {"name": "棒式", "sets": 3, "duration_seconds": 45},
                {"name": "深蹲", "sets": 3, "reps": 12}
              ],
              "duration_minutes": 30,
              "description": "核心訓練"
            },
            "day_target": "強化核心", "reason": "test"
          },
          {"day_index": 2, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 3, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 4, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 5, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 6, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 7, "category": "rest", "day_target": "休息", "reason": "恢復"}]
        }
        """.data(using: .utf8)!

        let plan = try JSONDecoder().decode(WeeklyPlan.self, from: json)
        let day1 = plan.days[0]

        XCTAssertEqual(day1.trainingType, "strength")
        XCTAssertEqual(day1.type, .strength)
        XCTAssertFalse(day1.type.isRunningActivity)
        XCTAssertEqual(day1.trainingDetails?.exercises?.count, 2)
        XCTAssertEqual(day1.trainingDetails?.exercises?[0].name, "棒式")
        XCTAssertEqual(day1.trainingDetails?.timeMinutes, 30)
    }

    // MARK: - V3 Cross Training 解碼

    func testV3CrossTrainingDecoding() throws {
        let json = """
        {
          "id": "v3_cross_1", "purpose": "test", "week_of_plan": 1, "total_weeks": 4,
          "total_distance_km": 30, "total_distance_reason": "test", "design_reason": ["test"],
          "days": [
          {"day_index": 1, "category": "cross",
            "primary": {"cross_type": "cycling", "duration_minutes": 45, "distance_km": 20.0, "description": "自行車"},
            "day_target": "交叉訓練", "reason": "test"},
          {"day_index": 2, "category": "cross",
            "primary": {"cross_type": "swimming", "duration_minutes": 40, "description": "游泳"},
            "day_target": "交叉訓練", "reason": "test"},
          {"day_index": 3, "category": "cross",
            "primary": {"cross_type": "yoga", "duration_minutes": 60, "description": "瑜伽"},
            "day_target": "柔軟度", "reason": "test"},
          {"day_index": 4, "category": "cross",
            "primary": {"cross_type": "hiking", "duration_minutes": 90, "description": "健行"},
            "day_target": "戶外活動", "reason": "test"},
          {"day_index": 5, "category": "cross",
            "primary": {"cross_type": "elliptical", "duration_minutes": 30, "description": "橢圓機"},
            "day_target": "有氧", "reason": "test"},
          {"day_index": 6, "category": "cross",
            "primary": {"cross_type": "rowing", "duration_minutes": 30, "description": "划船機"},
            "day_target": "有氧", "reason": "test"},
          {"day_index": 7, "category": "rest", "day_target": "休息", "reason": "恢復"}]
        }
        """.data(using: .utf8)!

        let plan = try JSONDecoder().decode(WeeklyPlan.self, from: json)

        XCTAssertEqual(plan.days[0].trainingType, "cycling")
        XCTAssertEqual(plan.days[0].type, .cycling)
        XCTAssertEqual(plan.days[0].trainingDetails?.distanceKm, 20.0)

        XCTAssertEqual(plan.days[1].trainingType, "swimming")
        XCTAssertEqual(plan.days[1].type, .swimming)

        XCTAssertEqual(plan.days[2].trainingType, "yoga")
        XCTAssertEqual(plan.days[2].type, .yoga)

        XCTAssertEqual(plan.days[3].trainingType, "hiking")
        XCTAssertEqual(plan.days[3].type, .hiking)

        XCTAssertEqual(plan.days[4].trainingType, "elliptical")
        XCTAssertEqual(plan.days[4].type, .elliptical)
        XCTAssertFalse(plan.days[4].type.isRunningActivity)

        XCTAssertEqual(plan.days[5].trainingType, "rowing")
        XCTAssertEqual(plan.days[5].type, .rowing)
        XCTAssertFalse(plan.days[5].type.isRunningActivity)
    }

    // MARK: - V3 Rest 解碼

    func testV3RestDecoding() throws {
        let json = """
        {
          "id": "v3_rest_1", "purpose": "test", "week_of_plan": 1, "total_weeks": 4,
          "total_distance_km": 0, "total_distance_reason": "test", "design_reason": ["test"],
          "days": [
          {"day_index": 1, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 2, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 3, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 4, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 5, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 6, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 7, "category": "rest", "day_target": "休息", "reason": "恢復"}]
        }
        """.data(using: .utf8)!

        let plan = try JSONDecoder().decode(WeeklyPlan.self, from: json)
        let day1 = plan.days[0]

        XCTAssertEqual(day1.trainingType, "rest")
        XCTAssertEqual(day1.type, .rest)
        XCTAssertFalse(day1.isTrainingDay)
        XCTAssertNil(day1.trainingDetails)
    }

    // MARK: - V2 向下相容驗證

    func testV2BackwardCompatibility() throws {
        let json = """
        {
          "id": "v2_compat_1", "purpose": "V2 test", "week_of_plan": 1, "total_weeks": 4,
          "total_distance_km": 30, "total_distance_reason": "test", "design_reason": ["test"],
          "days": [{
            "day_index": "1",
            "training_type": "easy_run",
            "training_details": {
              "distance_km": 8.0,
              "pace": "5:45",
              "heart_rate_range": {"min": 130, "max": 145},
              "description": "輕鬆跑"
            },
            "day_target": "有氧", "reason": "test"
          },
          {"day_index": "2", "training_type": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": "3", "training_type": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": "4", "training_type": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": "5", "training_type": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": "6", "training_type": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": "7", "training_type": "rest", "day_target": "休息", "reason": "恢復"}]
        }
        """.data(using: .utf8)!

        let plan = try JSONDecoder().decode(WeeklyPlan.self, from: json)
        let day1 = plan.days[0]

        XCTAssertEqual(day1.trainingType, "easy_run")
        XCTAssertEqual(day1.type, .easyRun)
        XCTAssertEqual(day1.trainingDetails?.distanceKm, 8.0)
        XCTAssertEqual(day1.trainingDetails?.pace, "5:45")
    }

    func testV3ClimateFieldsBackwardCompatibility() throws {
        let json = """
        {
          "id": "v3_climate_compat_1", "purpose": "V3 climate test", "week_of_plan": 1, "total_weeks": 4,
          "total_distance_km": 30, "total_distance_reason": "test", "design_reason": ["test"],
          "days": [{
            "day_index": 1,
            "category": "run",
            "day_target": "高溫節奏跑",
            "reason": "氣候調整",
            "climate_meta": {
              "feels_like_temp_c": 33.5,
              "heat_pressure_level": "high",
              "pace_adjustment_pct": 6.0,
              "reason_text": "高熱壓力，請放慢配速",
              "long_run_reduction_pct": 25.0
            },
            "warmup": {
              "distance_km": 2.0,
              "pace": "6:30",
              "description": "暖身"
            },
            "primary": {
              "run_type": "tempo",
              "distance_km": 8.0,
              "pace": "5:18",
              "base_pace": "5:00",
              "climate_adjusted_pace": "5:18",
              "climate_meta": {
                "feels_like_temp_c": 33.5,
                "heat_pressure_level": "high",
                "pace_adjustment_pct": 6.0,
                "reason_text": "高熱壓力，請放慢配速"
              },
              "description": "主訓練"
            }
          },
          {"day_index": 2, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 3, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 4, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 5, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 6, "category": "rest", "day_target": "休息", "reason": "恢復"},
          {"day_index": 7, "category": "rest", "day_target": "休息", "reason": "恢復"}]
        }
        """.data(using: .utf8)!

        let plan = try JSONDecoder().decode(WeeklyPlan.self, from: json)
        let day1 = plan.days[0]

        XCTAssertEqual(day1.trainingType, "tempo")
        XCTAssertEqual(day1.type, .tempo)
        XCTAssertEqual(day1.trainingDetails?.distanceKm, 8.0)
        XCTAssertEqual(day1.trainingDetails?.pace, "5:18")
        XCTAssertEqual(day1.reason, "氣候調整")
        XCTAssertEqual(day1.dayTarget, "高溫節奏跑")
        XCTAssertNotNil(day1.trainingDetails?.warmup)
        XCTAssertEqual(day1.trainingDetails?.warmup?.pace, "6:30")
    }
}
