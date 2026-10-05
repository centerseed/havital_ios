import Foundation

// MARK: - WeeklyPlanV2 Entity
/// 週課表 V2 - Domain Layer 業務實體
/// ✅ 基於 V1 WeeklyPlan，完整兼容所有欄位
/// ✅ 符合 Codable 以支援本地緩存
struct WeeklyPlanV2: Codable, Equatable {

    // MARK: - V2 新增元數據

    /// 週課表 ID（格式: {overview_id}_{week_number}）
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

    /// 週跑量（公里）。只要任一跑步日缺少日層距離，週量就是未知。
    let totalDistance: Double?

    /// 週跑量顯示值（英制用戶為英里數值，公制用戶為 nil）
    let totalDistanceDisplay: Double?

    /// 週跑量單位（英制用戶為 "miles"，公制用戶為 nil）
    let totalDistanceUnit: String?

    /// 當週跑量決定方式說明
    let totalDistanceReason: String?

    /// 安排理由列表
    let designReason: [String]?

    /// 跑量漸進敘事（免費可見，nil = gate 未命中）
    let mileageProgressionNote: String?

    /// 教練筆記（本週訓練重點 1-2 句總結）
    let coachNote: String?

    /// 訓練日陣列（7 天完整資料）- V2.1+ 使用 DayDetail
    let days: [DayDetail]

    /// 一週七天的氣候資訊（T-0165）。七天恆滿，含休息日與涼爽日。
    ///
    /// Optional 而非 `[]` 預設值：本型別會被序列化進本地快取，舊快取沒有這個 key，
    /// 合成的 `init(from:)` 對非 optional 欄位會直接 throw。nil = 無氣候（用戶關閉 / 預報缺失）。
    ///
    /// `var` 而非 `let`：Swift 只對 optional **var** 在 memberwise init 給 nil 預設值。
    /// 用 `let` 會逼 15 個既有建構點（含測試 fixture）全部補參數。
    var climate: [ClimateDay]?

    /// 七天氣候，缺席時為空陣列。UI 一律用這個，別直接解 optional。
    var climateDays: [ClimateDay] { climate ?? [] }

    /// 該天的氣候 —— **UI 唯一入口**。
    ///
    /// 1. `climate[7]` 有 → 用它（七天恆滿，含休息日與涼爽日）。
    /// 2. `climate[7]` 缺席 → 退回該天的 legacy `climate_meta`（只有 mild+ 跑步日有）。
    ///
    /// 為什麼要退路：後端只對帶 `week_start_date` 錨點的 doc 現算 `climate[7]`，而錨點是
    /// 新管線生成時才寫進去的。上線那一秒，所有現存用戶的當週課表都還是舊 doc → 沒有
    /// `climate[7]`。少了這條退路，熱適應會整個空白到下次課表生成為止。
    func climate(forDayIndex dayIndex: Int) -> ClimateDay? {
        if let fresh = climateDays.forDayIndex(dayIndex) {
            return fresh
        }
        guard let day = days.first(where: { $0.dayIndexInt == dayIndex }),
              let meta = day.effectiveClimateMeta else { return nil }
        return ClimateDay(legacyMeta: meta, dayIndex: dayIndex)
    }

    /// 強度分鐘數分布 - 重用 V1 的 IntensityTotalMinutes
    let intensityTotalMinutes: WeeklyPlan.IntensityTotalMinutes?

    /// 生成此週課表時使用的 VDOT；配速表與編輯建議應優先使用此值
    let currentVdot: Double?

    /// VDOT 來源說明
    let vdotSource: String?

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
