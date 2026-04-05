import Foundation

// MARK: - WeeklyPreviewV2 Entity
/// 週訓練預覽 - Domain Layer 業務實體
/// 包含每週的訓練骨架：跑量、強度比例、長跑/品質課類型
struct WeeklyPreviewV2: Codable, Equatable {

    /// 預覽 ID（同 overview_id）
    let id: String

    /// 方法論 ID
    let methodologyId: String

    /// 每週預覽列表
    let weeks: [WeekPreview]

    /// 創建時間
    let createdAt: Date?

    /// 更新時間
    let updatedAt: Date?
}

// MARK: - WeekPreview Entity
/// 單週訓練骨架預覽
struct WeekPreview: Codable, Equatable, Identifiable {

    /// 使用 week 作為唯一識別符
    var id: Int { week }

    /// 週次（1-based）
    let week: Int

    /// 訓練階段 ID（base, build, peak, taper）
    let stageId: String

    /// 目標週跑量（公里）
    let targetKm: Double

    /// 目標週跑量顯示值（英制時為 mi，公制時為 nil）
    let targetKmDisplay: Double?

    /// 距離單位（"km" / "mi"，公制時為 nil）
    let distanceUnit: String?

    /// 是否為恢復週
    let isRecovery: Bool

    /// 里程碑參考
    let milestoneRef: String?

    /// 強度分佈比例（低/中/高，加總 1.0）
    let intensityRatio: IntensityDistributionV2?

    /// 品質課類型列表（空陣列表示無品質課）
    let qualityOptions: [String]

    /// 長跑類型（nil 表示無長跑）
    let longRun: String?
}
