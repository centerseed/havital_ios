import Foundation

// MARK: - TargetTypeV2 Entity
/// 目標類型 V2 - Domain Layer 業務實體
/// 用於 Target Types V2 API 的響應格式
struct TargetTypeV2: Codable, Equatable, Identifiable {

    // MARK: - Properties

    /// 目標類型 ID（race_run, beginner, maintenance）
    let id: String

    /// 目標類型名稱
    let name: String

    /// 目標類型描述
    let description: String

    /// 預設方法論 ID
    let defaultMethodology: String

    /// 可用的方法論 IDs
    let availableMethodologies: [String]

    // MARK: - Computed Properties

    /// 是否為賽事目標
    var isRaceRunTarget: Bool {
        return id == "race_run"
    }

    /// 是否為新手目標
    var isBeginnerTarget: Bool {
        return id == "beginner"
    }

    /// 是否為維持目標
    var isMaintenanceTarget: Bool {
        return id == "maintenance"
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case defaultMethodology = "default_methodology"
        case availableMethodologies = "available_methodologies"
    }
}

// MARK: - TargetTypesResponse
/// 目標類型列表響應
struct TargetTypesResponseV2: Codable {
    let targetTypes: [TargetTypeV2]

    enum CodingKeys: String, CodingKey {
        case targetTypes = "target_types"
    }
}
