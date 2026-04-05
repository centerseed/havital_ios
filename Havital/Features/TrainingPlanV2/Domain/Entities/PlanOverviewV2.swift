import Foundation

// MARK: - PlanOverviewV2 Entity
/// 訓練計畫概覽 V2 - Domain Layer 業務實體
/// 支援多種目標類型（race_run, beginner, maintenance）
/// ✅ 符合 Codable 以支援本地緩存
struct PlanOverviewV2: Codable, Equatable {

    // MARK: - 基礎資訊

    /// 計畫 ID
    let id: String

    /// 目標 ID（引用 targets collection，race_run 必填）
    let targetId: String?

    /// 目標類型（race_run, beginner, maintenance）
    let targetType: String

    /// 目標描述（用於無賽事目標的計劃）
    let targetDescription: String?

    /// 方法論 ID（paceriz, complete_10k...）
    let methodologyId: String?

    /// 總訓練週數
    let totalWeeks: Int

    /// 計畫開始階段（conversion, base, build, peak, taper）
    let startFromStage: String?

    // MARK: - 嵌入的 Target 核心字段

    /// 比賽日期（UTC timestamp）
    let raceDate: Int?

    /// 賽事距離（公里）
    let distanceKm: Double?

    /// 賽事距離顯示值（英制時為 mi，公制時為 nil）
    let distanceKmDisplay: Double?

    /// 距離單位（"km" / "mi"，公制時為 nil）
    let distanceUnit: String?

    /// 目標配速（MM:SS 格式）
    let targetPace: String?

    /// 目標時間（秒）
    let targetTime: Int?

    /// 是否為主要賽事
    let isMainRace: Bool?

    /// 目標/賽事名稱
    let targetName: String?

    // MARK: - 方法論概覽

    /// 方法論概覽資訊
    let methodologyOverview: MethodologyOverviewV2?

    // MARK: - 評估與概要

    /// 對目標的評估
    let targetEvaluate: String?

    /// 如何達到目標的概要描述（150字內）
    let approachSummary: String?

    // MARK: - 訓練結構

    /// 訓練階段列表
    let trainingStages: [TrainingStageV2]

    /// 里程碑列表
    let milestones: [MilestoneV2]

    // MARK: - Metadata

    /// 創建時間
    let createdAt: Date?

    /// 方法論版本
    let methodologyVersion: String?

    /// 里程碑計算依據（"intended_race_distance" / "prior_target" / "no_prior_target"）
    let milestoneBasis: String?

    // MARK: - Computed Properties

    /// 比賽日期（Date 對象）
    var raceDateValue: Date? {
        guard let timestamp = raceDate else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    /// 是否為賽事目標
    var isRaceRunTarget: Bool {
        return targetType == "race_run"
    }

    /// 是否為初心者目標
    var isBeginnerTarget: Bool {
        return targetType == "beginner"
    }

    /// 是否為維持目標
    var isMaintenanceTarget: Bool {
        return targetType == "maintenance"
    }

    /// 計畫持續天數
    var totalDays: Int {
        return totalWeeks * 7
    }
}

// MARK: - MethodologyOverviewV2 Entity
/// 方法論概覽 - 讓用戶理解訓練方法論的核心理念
struct MethodologyOverviewV2: Codable, Equatable {

    /// 方法論名稱
    let name: String

    /// 訓練哲學
    let philosophy: String

    /// 強度風格（balanced, polarized, threshold）
    let intensityStyle: String

    /// 強度分配描述（如 "75% 低強度 / 20% 中強度 / 5% 高強度"）
    let intensityDescription: String
}

// MARK: - TrainingStageV2 Entity
/// 訓練階段
struct TrainingStageV2: Codable, Equatable {

    /// 階段 ID（統一定義）
    let stageId: String

    /// 階段顯示名稱
    let stageName: String

    /// 階段描述
    let stageDescription: String

    /// 階段開始週數
    let weekStart: Int

    /// 階段結束週數
    let weekEnd: Int

    /// 訓練重點
    let trainingFocus: String

    /// 該階段週跑量目標範圍
    let targetWeeklyKmRange: TargetWeeklyKmRangeV2

    /// 該階段週跑量顯示範圍（英制時有值，公制時為 nil）
    let targetWeeklyKmRangeDisplay: TargetWeeklyKmRangeDisplayV2?

    /// 強度分佈比例（來自方法論）
    let intensityRatio: IntensityDistributionV2?

    /// 該階段關鍵訓練類型
    let keyWorkouts: [String]?

    // MARK: - Computed Properties

    /// 階段持續週數
    var durationWeeks: Int {
        return weekEnd - weekStart + 1
    }

    /// 是否包含指定週數
    func contains(week: Int) -> Bool {
        return week >= weekStart && week <= weekEnd
    }
}

// MARK: - TargetWeeklyKmRangeV2 Entity
/// 階段週跑量目標範圍
struct TargetWeeklyKmRangeV2: Codable, Equatable {

    /// 週跑量低標（公里）
    let low: Double

    /// 週跑量高標（公里）
    let high: Double

    // MARK: - Computed Properties

    /// 平均跑量
    var average: Double {
        return (low + high) / 2
    }

    /// 範圍寬度
    var range: Double {
        return high - low
    }
}

// MARK: - IntensityDistributionV2 Entity
/// 強度分佈
struct IntensityDistributionV2: Codable, Equatable {

    /// 低強度比例（0-1）
    let low: Double

    /// 中強度比例（0-1）
    let medium: Double

    /// 高強度比例（0-1）
    let high: Double

    // MARK: - Computed Properties

    /// 總比例（應該等於 1.0）
    var total: Double {
        return low + medium + high
    }

    /// 格式化為百分比字串
    var formattedString: String {
        let lowPercent = Int(low * 100)
        let mediumPercent = Int(medium * 100)
        let highPercent = Int(high * 100)
        return "\(lowPercent)% 低強度 / \(mediumPercent)% 中強度 / \(highPercent)% 高強度"
    }
}

// MARK: - MilestoneV2 Entity
/// 里程碑 - 用於標記訓練計畫中的重要事件
struct MilestoneV2: Codable, Equatable {

    /// 哪一週
    let week: Int

    /// 里程碑類型
    let milestoneType: String

    /// 顯示標題
    let title: String

    /// 描述
    let description: String

    /// 是否為關鍵里程碑
    let isKeyMilestone: Bool
}

// MARK: - TargetWeeklyKmRangeDisplayV2 Entity
/// 英制用戶的週跑量顯示範圍
struct TargetWeeklyKmRangeDisplayV2: Codable, Equatable {

    /// 週跑量低標顯示值（已轉換為用戶單位）
    let lowDisplay: Double

    /// 週跑量高標顯示值（已轉換為用戶單位）
    let highDisplay: Double

    /// 距離單位（"mi"）
    let distanceUnit: String
}
