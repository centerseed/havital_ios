import Foundation

// MARK: - StateCardDTO
/// Wire DTO for `GET /v2/state/today` 的 data payload。
/// envelope `{success,data}` 已由 APICallHelper 拆掉，此 DTO 僅代表 data。
/// Data Layer — snake_case 對映 via CodingKeys。
struct StateCardDTO: Codable {
    let lens: String
    let source: String?
    let headline: String
    let factType: String?
    let narrativeText: String?
    let chips: [String]?
    let causeChips: [String]?
    let mileageProgression: String?
    let action: ActionDTO?
    let divergence: DivergenceDTO?
    let access: AccessDTO
    /// T-0142 指標跑當日即時校準卡(偵測到今天合格全力跑才有值,否則 nil)。
    /// 預設 nil:production 走 Codable decode(可缺),測試手動建構可省略此欄。
    let benchmarkCalibration: BenchmarkCalibrationDTO? = nil

    enum CodingKeys: String, CodingKey {
        case lens, source, headline, chips, action, divergence, access
        case factType = "fact_type"
        case narrativeText = "narrative_text"
        case causeChips = "cause_chips"
        case mileageProgression = "mileage_progression"
        case benchmarkCalibration = "benchmark_calibration"
    }

    // MARK: - BenchmarkCalibrationDTO (T-0142)
    /// `benchmark_calibration` payload。calibration_preview 巢狀(對映後端);mapper 攤平成
    /// 既有 BenchmarkCalibrationPayload 給 BenchmarkCalibrationCard 渲染。
    struct BenchmarkCalibrationDTO: Codable {
        let workoutId: String?
        let workoutDate: String?
        let distanceKm: Double?
        let benchmarkDistanceM: Double?
        let benchmarkDurationS: Double?
        let overviewId: String?
        let weekOfTraining: Int?
        let calibrationPreview: PreviewDTO?
        let shouldHedge: Bool?
        let canScheduleNext: Bool?
        enum CodingKeys: String, CodingKey {
            case workoutId = "workout_id"
            case workoutDate = "workout_date"
            case distanceKm = "distance_km"
            case benchmarkDistanceM = "benchmark_distance_m"
            case benchmarkDurationS = "benchmark_duration_s"
            case overviewId = "overview_id"
            case weekOfTraining = "week_of_training"
            case calibrationPreview = "calibration_preview"
            case shouldHedge = "should_hedge"
            case canScheduleNext = "can_schedule_next"
        }
        struct PreviewDTO: Codable {
            let raceTimeBeforeS: Int?
            let raceTimeAfterS: Int?
            let vdotBefore: Double?
            let vdotAfter: Double?
            enum CodingKeys: String, CodingKey {
                case raceTimeBeforeS = "race_time_before_s"
                case raceTimeAfterS = "race_time_after_s"
                case vdotBefore = "vdot_before"
                case vdotAfter = "vdot_after"
            }
        }
    }

    struct ActionDTO: Codable {
        let kind: String
        let sessionRef: SessionRefDTO?
        let rizoHandoff: RizoHandoffDTO?
        enum CodingKeys: String, CodingKey {
            case kind
            case sessionRef = "session_ref"
            case rizoHandoff = "rizo_handoff"
        }
        struct SessionRefDTO: Codable {
            let runType: String?
            let distanceKm: Double?
            let pace: String?
            enum CodingKeys: String, CodingKey {
                case runType = "run_type"
                case distanceKm = "distance_km"
                case pace
            }
        }
        struct RizoHandoffDTO: Codable { let scenario: String? }
    }

    struct DivergenceDTO: Codable {
        let present: Bool
        let flagText: String?
        let suggestedRizoScenario: String?
        enum CodingKeys: String, CodingKey {
            case present
            case flagText = "flag_text"
            case suggestedRizoScenario = "suggested_rizo_scenario"
        }
    }

    struct AccessDTO: Codable {
        let isPaid: Bool
        let locked: Bool
        let upsell: UpsellDTO?
        enum CodingKeys: String, CodingKey {
            case isPaid = "is_paid"
            case locked, upsell
        }
        struct UpsellDTO: Codable { let reason: String? }
    }
}
