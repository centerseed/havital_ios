import Foundation

// MARK: - WeeklyPlanV2DTO
/// Weekly Plan V2 DTO - Data Layer
/// 與 API JSON 結構一一對應，使用 snake_case 命名
/// ✅ 基於 V1 WeeklyTrainingPlan，完整兼容所有欄位
struct WeeklyPlanV2DTO: Codable {

    // MARK: - V2 新增元數據

    /// 週課表 ID（格式: {overview_id}_{week_number}）
    let planId: String?

    /// Overview ID（後端回傳，用於組合 planId）
    let overviewId: String?

    /// 訓練週次（V2 新增，與 weekOfPlan 可能重複）
    let weekOfTraining: Int?

    // MARK: - V1 核心欄位（完整兼容 WeeklyTrainingPlan）

    /// 週課表 ID（V1 欄位，部分 API 可能不回傳）
    let id: String?

    /// 當週訓練目的
    let purpose: String

    /// 當前週數（V1 欄位）
    let weekOfPlan: Int?

    /// 總訓練週數
    let totalWeeks: Int?

    /// 週跑量（公里）
    let totalDistance: Double

    /// 週跑量顯示值（英制用戶為英里數值，公制用戶為 nil）
    let totalDistanceDisplay: Double?

    /// 週跑量單位（英制用戶為 "miles"，公制用戶為 nil）
    let totalDistanceUnit: String?

    /// 當週跑量決定方式說明
    let totalDistanceReason: String?

    /// 安排理由列表
    let designReason: [String]?

    /// 訓練日陣列（7 天完整資料）- V2.1+ 使用 DayDetailDTO
    let days: [DayDetailDTO]

    /// 強度分鐘數分布 {low, medium, high}
    let intensityTotalMinutes: WeeklyPlan.IntensityTotalMinutes?

    // MARK: - 時間戳

    /// 創建時間
    let createdAt: String?

    /// 更新時間
    let updatedAt: String?

    // MARK: - V2 預留擴展欄位（v2.1+ 可選）

    /// 訓練負荷分析（v2.1+ 預留，目前為 null）
    let trainingLoadAnalysis: [String: AnyCodableValue]?

    /// 個性化建議（v2.2+ 預留，目前為 null）
    let personalizedRecommendations: [String: AnyCodableValue]?

    /// 實時調整建議（v2.3+ 預留，目前為 null）
    let realTimeAdjustments: [String: AnyCodableValue]?

    /// 階段 ID
    let stageId: String?

    /// 方法論 ID
    let methodologyId: String?

    /// 資料版本
    let dataVersion: String?

    /// API 版本（默認 "2.0"）
    let apiVersion: String?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case overviewId = "overview_id"
        case weekOfTraining = "week_of_training"
        case id
        case purpose
        case weekOfPlan = "week_of_plan"
        case totalWeeks = "total_weeks"
        case totalDistance = "total_distance_km"
        case totalDistanceDisplay = "total_distance_display"
        case totalDistanceUnit = "total_distance_unit"
        case totalDistanceReason = "total_distance_reason"
        case designReason = "design_reason"
        case days
        case intensityTotalMinutes = "intensity_total_minutes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case trainingLoadAnalysis = "training_load_analysis"
        case personalizedRecommendations = "personalized_recommendations"
        case realTimeAdjustments = "real_time_adjustments"
        case stageId = "stage_id"
        case methodologyId = "methodology_id"
        case dataVersion = "data_version"
        case apiVersion = "api_version"
    }
}

// MARK: - API Response Wrapper
/// API 響應包裝器已由 ResponseProcessor 自動處理
/// 後端返回格式：{"success": true, "data": {...}}
/// 前端使用 WeeklyPlanV2DTO 即可，ResponseProcessor 會自動解析
