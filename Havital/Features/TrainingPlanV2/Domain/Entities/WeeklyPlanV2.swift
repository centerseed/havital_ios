import Foundation

// MARK: - WeeklyPlanV2 Entity
/// 週課表 V2 - Domain Layer 業務實體
/// ✅ 基於 V1 WeeklyPlan，完整兼容所有欄位
/// ✅ 符合 Codable 以支援本地緩存
struct WeeklyPlanV2: Codable, Equatable {

    // MARK: - V2 新增元數據

    /// 週課表 ID（格式: {overview_id}_week_{week_number}）
    let planId: String?

    /// 訓練週次（V2 新增）
    let weekOfTraining: Int?

    // MARK: - V1 核心欄位（完整兼容 WeeklyPlan）

    /// 週課表 ID（V1 欄位）
    let id: String

    /// 當週訓練目的
    let purpose: String

    /// 當前週數（V1 欄位）
    let weekOfPlan: Int?

    /// 總訓練週數
    let totalWeeks: Int?

    /// 週跑量（公里）
    let totalDistance: Double

    /// 當週跑量決定方式說明
    let totalDistanceReason: String?

    /// 安排理由列表
    let designReason: [String]?

    /// 訓練日陣列（7 天完整資料）- V2.1+ 使用 DayDetail
    let days: [DayDetail]

    /// 強度分鐘數分布 - 重用 V1 的 IntensityTotalMinutes
    let intensityTotalMinutes: WeeklyPlan.IntensityTotalMinutes?

    // MARK: - 時間戳

    /// 創建時間
    let createdAt: Date?

    /// 更新時間
    let updatedAt: Date?

    // MARK: - V2 預留擴展欄位（v2.1+ 可選）

    /// 訓練負荷分析（v2.1+ 預留，目前為 null）
    let trainingLoadAnalysis: [String: AnyCodableValue]?

    /// 個性化建議（v2.2+ 預留，目前為 null）
    let personalizedRecommendations: [String: AnyCodableValue]?

    /// 實時調整建議（v2.3+ 預留，目前為 null）
    let realTimeAdjustments: [String: AnyCodableValue]?

    /// API 版本（默認 "2.0"）
    let apiVersion: String?

    // MARK: - Computed Properties

    /// 實際的訓練週次（優先使用 weekOfTraining，否則使用 weekOfPlan）
    var effectiveWeek: Int {
        return weekOfTraining ?? weekOfPlan ?? 0
    }

    /// 實際的課表 ID（優先使用 planId，否則使用 id）
    var effectivePlanId: String {
        return planId ?? id
    }
}
