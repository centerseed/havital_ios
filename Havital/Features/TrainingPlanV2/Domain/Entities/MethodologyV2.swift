import Foundation

// MARK: - MethodologyV2 Entity
/// 方法論 V2 - Domain Layer 業務實體
/// 用於 Methodologies V2 API 的響應格式
struct MethodologyV2: Codable, Equatable, Identifiable {

    // MARK: - Properties

    /// 方法論 ID（paceriz, polarized, hansons, norwegian, complete_10k, balanced_fitness, aerobic_endurance）
    let id: String

    /// 方法論名稱
    let name: String

    /// 方法論描述
    let description: String

    /// 適用的目標類型
    let targetTypes: [String]

    /// 訓練階段
    let phases: [String]

    /// 是否啟用交叉訓練
    let crossTrainingEnabled: Bool

    // MARK: - Computed Properties

    /// 是否適用於賽事目標
    var supportsRaceRun: Bool {
        return targetTypes.contains("race_run")
    }

    /// 是否適用於新手目標
    var supportsBeginner: Bool {
        return targetTypes.contains("beginner")
    }

    /// 是否適用於維持目標
    var supportsMaintenance: Bool {
        return targetTypes.contains("maintenance")
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case targetTypes = "target_types"
        case phases
        case crossTrainingEnabled = "cross_training_enabled"
    }
}

// MARK: - MethodologiesResponse
/// 方法論列表響應
struct MethodologiesResponseV2: Codable {
    let methodologies: [MethodologyV2]
}
