import Foundation

// MARK: - TargetTypeV2DTO
/// 目標類型 V2 - Data Layer DTO
/// 對應 /v2/target/types API 回應格式
struct TargetTypeV2DTO: Codable {

    let id: String
    let name: String
    let description: String
    let defaultMethodology: String
    let availableMethodologies: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case defaultMethodology = "default_methodology"
        case availableMethodologies = "available_methodologies"
    }
}

// MARK: - TargetTypesResponseV2DTO
/// 目標類型列表響應 - Data Layer DTO
struct TargetTypesResponseV2DTO: Codable {
    let targetTypes: [TargetTypeV2DTO]

    enum CodingKeys: String, CodingKey {
        case targetTypes = "target_types"
    }
}
