import Foundation

// MARK: - WeeklyPlanV2DTO
/// Weekly Plan V2 DTO - Data Layer
/// 與 API JSON 結構一一對應，使用 snake_case 命名
struct WeeklyPlanV2DTO: Codable {

    // MARK: - Properties

    let id: String
    let uid: String
    let activeTrainingId: String
    let weekOfTraining: Int
    let targetType: String
    let methodologyId: String
    let plan: [String: AnyCodableValue]
    let createdAt: String?
    let updatedAt: String?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case uid
        case activeTrainingId = "active_training_id"
        case weekOfTraining = "week_of_training"
        case targetType = "target_type"
        case methodologyId = "methodology_id"
        case plan
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - API Response Wrapper
/// API 響應包裝器
struct WeeklyPlanV2Response: Codable {
    let success: Bool
    let message: String?
    let data: WeeklyPlanV2DTO
}
