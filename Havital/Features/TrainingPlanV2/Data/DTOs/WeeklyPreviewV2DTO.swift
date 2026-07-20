import Foundation

// MARK: - WeeklyPreviewResponseDTO
/// Weekly Preview Response DTO - Data Layer
/// 與 API JSON 結構一一對應
struct WeeklyPreviewResponseDTO: Codable {
    let planId: String
    let methodologyId: String
    let totalWeeks: Int?
    let weeks: [WeekPreviewDTO]
    let createdAt: String?
    let updatedAt: String?
    /// 週跑量安全上限（km）— backend additive 欄位，舊 response 無此 key
    let safetyCeilingKm: Double?
    /// 賽事距離門檻（km）— backend additive 欄位，舊 response 無此 key
    let raceThresholdKm: Double?

    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case methodologyId = "methodology_id"
        case totalWeeks = "total_weeks"
        case weeks
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case safetyCeilingKm = "safety_ceiling_km"
        case raceThresholdKm = "race_threshold_km"
    }
}

// MARK: - WeekPreviewDTO
/// 單週預覽 DTO
struct WeekPreviewDTO: Codable {
    let week: Int
    let stageId: String
    let targetKm: Double
    let targetKmDisplay: Double?
    let distanceUnit: String?
    let isRecovery: Bool?
    let milestoneRef: String?
    let intensityRatio: IntensityDistributionDTO?
    let qualityOptions: [QualityOptionDTO]?
    let longRun: LongRunDTO?
    let weekInPhase: Int?
    let totalPhaseWeeks: Int?

    enum CodingKeys: String, CodingKey {
        case week
        case stageId = "stage_id"
        case targetKm = "target_km"
        case targetKmDisplay = "target_km_display"
        case distanceUnit = "distance_unit"
        case isRecovery = "is_recovery"
        case milestoneRef = "milestone_ref"
        case intensityRatio = "intensity_ratio"
        case qualityOptions = "quality_options"
        case longRun = "long_run"
        case weekInPhase = "week_in_phase"
        case totalPhaseWeeks = "total_phase_weeks"
    }
}

// MARK: - QualityOptionDTO
/// 品質訓練選項 DTO
struct QualityOptionDTO: Codable {
    let category: String
    let trainingType: String

    enum CodingKeys: String, CodingKey {
        case category
        case trainingType = "training_type"
    }
}

// MARK: - LongRunDTO
/// 長跑訓練 DTO
struct LongRunDTO: Codable {
    let maxKm: Double?
    let trainingType: String

    enum CodingKeys: String, CodingKey {
        case maxKm = "max_km"
        case trainingType = "training_type"
    }
}
