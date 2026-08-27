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
    /// T-0241 收合卡融合理由句(建議＋因為＋真實數字);免費/護欄 fallback → nil。
    let collapsedReason: String?
    let chips: [String]?
    let causeChips: [String]?
    let mileageProgression: String?
    let action: ActionDTO?
    let divergence: DivergenceDTO?
    let access: AccessDTO
    /// T-0142 指標跑當日即時校準卡(偵測到今天合格全力跑才有值,否則 nil)。
    /// ⚠️ 不給預設值:`let + 預設值` 會讓 synthesized Decodable 不 decode 此 key(永遠 nil)。
    /// Optional 本身即 decodeIfPresent(缺 → nil、有 → decode),測試手動建構需明給 nil。
    let benchmarkCalibration: BenchmarkCalibrationDTO?
    /// 已評級的指標列(`label`／`arrow`／`verdict`／`change`／`evidence`／`dot`／`status`)。
    /// 這條就是 2.0 指標膠囊列要的東西——`/v2/athlete-state/metrics` 依規格只交
    /// envelope、不評級(ME-INV-05),所以綁那一條的畫面永遠是灰的。
    let insights: [InsightDTO]?

    enum CodingKeys: String, CodingKey {
        case lens, source, headline, chips, action, divergence, access, insights
        case factType = "fact_type"
        case narrativeText = "narrative_text"
        case collapsedReason = "collapsed_reason"
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

    /// `insights[]` 的一列。後端已做完評級與在地化,app 端不再自己推導文案。
    struct InsightDTO: Codable {
        let key: String
        let label: String?
        let valueText: String?
        let arrow: String?
        let verdict: String?
        let change: String?
        let evidence: String?
        let dot: String?
        /// `graded`／`not_computed`。
        let status: String?

        enum CodingKeys: String, CodingKey {
            case key, label, arrow, verdict, change, evidence, dot, status
            case valueText = "value_text"
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
