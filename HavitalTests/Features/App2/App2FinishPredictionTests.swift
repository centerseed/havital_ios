import XCTest
@testable import paceriz_dev

/// 能力基準頁（§52）的四距離完賽預估（T-0376；Android 對應 T-0375）。
///
/// 兩層各自鎖住：
/// - **decode**：後端 `race_fitness.finish_time_predictions` 的真實形狀要進得來，
///   而**舊 readiness doc 沒有這個欄位時整包不得炸掉**。
/// - **投影**：排序、標籤在地化、缺值過濾、缺席回空陣列。
final class App2FinishPredictionTests: XCTestCase {

    // MARK: - 素材

    /// 後端 `_build_finish_time_predictions` 的真實形狀
    /// （`race_fitness.py:575-589`）：含 `prediction_confidence: null`、
    /// `limits: []` 這些 iOS 沒有宣告的欄位，以及浮點的 `daniels_base_minutes`。
    private let fullPayload = """
    {
        "score": 72.5,
        "estimated_race_time": "3:41:02",
        "finish_time_predictions": {
            "half_marathon": {
                "distance_label": "Half Marathon",
                "distance_km": 21.0975,
                "estimated_time": "1:45:20",
                "estimated_time_seconds": 6320,
                "prediction_method": "race_projection_v3",
                "parameter_set_id": "race_projection_v3",
                "prediction_confidence": null,
                "daniels_base_minutes": 103.4,
                "correction_ratio": 1.018,
                "prediction_vdot": 46.2,
                "prediction_vdot_source": "capability_baseline",
                "limits": [],
                "status": "ok"
            },
            "five_k": {
                "distance_label": "5K",
                "distance_km": 5.0,
                "estimated_time": "0:22:31",
                "estimated_time_seconds": 1351,
                "prediction_method": "race_projection_v3",
                "parameter_set_id": "race_projection_v3",
                "prediction_confidence": null,
                "daniels_base_minutes": 22.1,
                "correction_ratio": 1.019,
                "prediction_vdot": 46.2,
                "prediction_vdot_source": "capability_baseline",
                "limits": [],
                "status": "ok"
            },
            "full_marathon": {
                "distance_label": "Marathon",
                "distance_km": 42.195,
                "estimated_time": "3:41:02",
                "estimated_time_seconds": 13262,
                "prediction_method": "race_projection_v3",
                "parameter_set_id": "race_projection_v3",
                "prediction_confidence": null,
                "daniels_base_minutes": 215.7,
                "correction_ratio": 1.024,
                "prediction_vdot": 46.2,
                "prediction_vdot_source": "capability_baseline",
                "limits": [],
                "status": "ok"
            },
            "ten_k": {
                "distance_label": "10K",
                "distance_km": 10.0,
                "estimated_time": "0:46:48",
                "estimated_time_seconds": 2808,
                "prediction_method": "race_projection_v3",
                "parameter_set_id": "race_projection_v3",
                "prediction_confidence": null,
                "daniels_base_minutes": 46.0,
                "correction_ratio": 1.017,
                "prediction_vdot": 46.2,
                "prediction_vdot_source": "capability_baseline",
                "limits": [],
                "status": "ok"
            }
        }
    }
    """

    private func metric(_ json: String) throws -> RaceFitnessMetric {
        try JSONDecoder().decode(RaceFitnessMetric.self, from: Data(json.utf8))
    }

    // MARK: - decode

    /// 四個距離都要進得來，欄位對得上。
    func test_decodesAllFourFinishPredictions() throws {
        let dto = try metric(fullPayload)
        let predictions = try XCTUnwrap(dto.finishTimePredictions)

        XCTAssertEqual(Set(predictions.keys),
                       ["five_k", "ten_k", "half_marathon", "full_marathon"])

        let half = try XCTUnwrap(predictions["half_marathon"])
        XCTAssertEqual(half.distanceLabel, "Half Marathon")
        XCTAssertEqual(half.distanceKm, 21.0975)
        XCTAssertEqual(half.estimatedTime, "1:45:20")
        XCTAssertEqual(half.estimatedTimeSeconds, 6320)
        XCTAssertEqual(half.status, "ok")

        // `estimated_race_time` 是**目標賽事那一個距離**，與這四筆不是同一件事。
        XCTAssertEqual(dto.estimatedRaceTime, "3:41:02")
    }

    /// 舊 readiness doc 沒有這個欄位 —— 整包必須照常 decode。
    ///
    /// 這條鎖的是 2026-08-26 `resting_heart_rate` 宣告成 `Int?` 而後端給 `51.0`、
    /// 整包 payload 炸掉的同一個形狀：一個新欄位宣告錯，壞的是整個 readiness。
    func test_missingFinishPredictionsDecodesToNil() throws {
        let dto = try metric("""
        {
            "score": 65.0,
            "estimated_race_time": "4:02:11",
            "vdot_source": "training"
        }
        """)
        XCTAssertNil(dto.finishTimePredictions)
        XCTAssertEqual(dto.score, 65.0)
        XCTAssertEqual(dto.estimatedRaceTime, "4:02:11")
        XCTAssertEqual(dto.vdotSource, "training")
    }

    /// 子欄位缺席也不得炸（後端對某些距離可能不給 `status`／`distance_km`）。
    func test_partialFieldsDecodeToNil() throws {
        let dto = try metric("""
        {
            "score": 50.0,
            "finish_time_predictions": {
                "five_k": { "estimated_time": "0:25:00" }
            }
        }
        """)
        let five = try XCTUnwrap(dto.finishTimePredictions?["five_k"])
        XCTAssertEqual(five.estimatedTime, "0:25:00")
        XCTAssertNil(five.distanceKm)
        XCTAssertNil(five.distanceLabel)
        XCTAssertNil(five.status)
    }

    // MARK: - 投影

    /// 四列、由近到遠。**`[String: T]` 沒有順序**，所以這條鎖的是「排序不是靠
    /// dict 迭代」——輸入的 JSON 故意把 half 放第一個、full 放第三個。
    func test_rowsAreOrderedByDistance() throws {
        let rows = App2MetricDetailProjection.finishPredictions(from: try metric(fullPayload))

        XCTAssertEqual(rows.map(\.id), ["five_k", "ten_k", "half_marathon", "full_marathon"])
        XCTAssertEqual(rows.map(\.time), ["0:22:31", "0:46:48", "1:45:20", "3:41:02"])
    }

    /// 標籤走 App 自己的三語 `race_filter.*`，**不印 payload 的英文
    /// `distance_label`**。
    func test_labelsUseLocalizedRaceNames() throws {
        let rows = App2MetricDetailProjection.finishPredictions(from: try metric(fullPayload))
        let byId = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.label) })

        XCTAssertEqual(byId["five_k"], NSLocalizedString("race_filter.5k", comment: ""))
        XCTAssertEqual(byId["ten_k"], NSLocalizedString("race_filter.10k", comment: ""))
        XCTAssertEqual(byId["half_marathon"],
                       NSLocalizedString("race_filter.half_marathon", comment: ""))
        XCTAssertEqual(byId["full_marathon"],
                       NSLocalizedString("race_filter.full_marathon", comment: ""))

        // 認得的 key 一律用在地化字串，不是 payload 的英文標籤。
        // 不能直接比對 "Marathon"：en 的 `race_filter.full_marathon` 恰好也叫
        // "Marathon"，那樣的斷言在英文測試環境恆紅。改塞哨兵標籤驗證。
        let sentinel = try metric(
            fullPayload.replacingOccurrences(of: "Marathon", with: "PAYLOAD_LABEL")
        )
        let sentinelRows = App2MetricDetailProjection.finishPredictions(from: sentinel)
        XCTAssertEqual(sentinelRows.count, rows.count)
        XCTAssertFalse(
            sentinelRows.contains { $0.label.contains("PAYLOAD_LABEL") },
            "標籤不得印 payload 的 distance_label"
        )
    }

    /// 只有兩個距離投影得出來 → 兩列，順序仍是近的在前。
    func test_partialSetKeepsOrder() throws {
        let rows = App2MetricDetailProjection.finishPredictions(from: try metric("""
        {
            "score": 55.0,
            "finish_time_predictions": {
                "full_marathon": {
                    "distance_label": "Marathon", "distance_km": 42.195,
                    "estimated_time": "4:10:00", "estimated_time_seconds": 15000
                },
                "five_k": {
                    "distance_label": "5K", "distance_km": 5.0,
                    "estimated_time": "0:26:00", "estimated_time_seconds": 1560
                }
            }
        }
        """))

        XCTAssertEqual(rows.map(\.id), ["five_k", "full_marathon"])
    }

    /// 沒有 `estimated_time` 的那一筆整列丟掉 —— 不畫「–」佔位。
    func test_rowsWithoutTimeAreDropped() throws {
        let rows = App2MetricDetailProjection.finishPredictions(from: try metric("""
        {
            "score": 55.0,
            "finish_time_predictions": {
                "five_k": {
                    "distance_km": 5.0, "estimated_time": "0:26:00"
                },
                "ten_k": {
                    "distance_km": 10.0, "estimated_time": null
                },
                "half_marathon": {
                    "distance_km": 21.0975, "estimated_time": ""
                }
            }
        }
        """))

        XCTAssertEqual(rows.map(\.id), ["five_k"])
    }

    /// 缺席的四種形態都回空陣列 → 呼叫端整區不畫。
    func test_absentPredictionsProduceNoRows() throws {
        XCTAssertTrue(App2MetricDetailProjection.finishPredictions(from: nil).isEmpty)

        XCTAssertTrue(App2MetricDetailProjection.finishPredictions(from: try metric("""
        { "score": 40.0 }
        """)).isEmpty)

        XCTAssertTrue(App2MetricDetailProjection.finishPredictions(from: try metric("""
        { "score": 40.0, "finish_time_predictions": {} }
        """)).isEmpty)

        // 有 key 但每一筆都沒有時間 —— 一樣是整區不畫。
        XCTAssertTrue(App2MetricDetailProjection.finishPredictions(from: try metric("""
        {
            "score": 40.0,
            "finish_time_predictions": {
                "five_k": { "distance_km": 5.0, "estimated_time": null }
            }
        }
        """)).isEmpty)
    }

    /// 認不得的 key 才退回 payload 的 `distance_label`，並依 `distance_km` 排進位置
    /// （與 T-0375 Android 同規則）。猜一個譯名比原樣顯示更糟。
    func test_unknownKeyFallsBackToPayloadLabel() throws {
        let rows = App2MetricDetailProjection.finishPredictions(from: try metric("""
        {
            "score": 55.0,
            "finish_time_predictions": {
                "full_marathon": {
                    "distance_label": "Marathon", "distance_km": 42.195,
                    "estimated_time": "4:10:00"
                },
                "fifteen_k": {
                    "distance_label": "15K", "distance_km": 15.0,
                    "estimated_time": "1:12:00"
                },
                "five_k": {
                    "distance_label": "5K", "distance_km": 5.0,
                    "estimated_time": "0:26:00"
                }
            }
        }
        """))

        XCTAssertEqual(rows.map(\.id), ["five_k", "fifteen_k", "full_marathon"])
        XCTAssertEqual(rows[1].label, "15K")
    }

    /// `distance_km` 缺席時用該 key 的已知距離定序，不掉到最後。
    func test_missingDistanceKmFallsBackToKnownDistance() throws {
        let rows = App2MetricDetailProjection.finishPredictions(from: try metric("""
        {
            "score": 55.0,
            "finish_time_predictions": {
                "full_marathon": { "estimated_time": "4:10:00" },
                "five_k": { "estimated_time": "0:26:00" },
                "half_marathon": { "estimated_time": "1:55:00" },
                "ten_k": { "estimated_time": "0:54:00" }
            }
        }
        """))

        XCTAssertEqual(rows.map(\.id), ["five_k", "ten_k", "half_marathon", "full_marathon"])
    }
}
