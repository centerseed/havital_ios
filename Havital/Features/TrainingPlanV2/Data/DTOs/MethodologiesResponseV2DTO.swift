import Foundation

// MARK: - MethodologyV2DTO
/// 方法論 V2 - Data Layer DTO
/// 對應 /v2/methodologies API 回應格式
struct MethodologyV2DTO: Codable {

    let id: String
    let name: String
    let description: String
    let targetTypes: [String]
    let phases: [String]
    let crossTrainingEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case targetTypes = "target_types"
        case phases
        case crossTrainingEnabled = "cross_training_enabled"
    }
}

// MARK: - MethodologiesResponseV2DTO
/// 方法論列表響應 - Data Layer DTO
struct MethodologiesResponseV2DTO: Codable {
    let methodologies: [MethodologyV2DTO]
}
