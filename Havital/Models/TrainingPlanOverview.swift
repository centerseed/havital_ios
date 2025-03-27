import Foundation

struct TrainingStage: Codable {
    let stageName: String
    let stageId: String
    let stageDescription: String
    let trainingFocus: String
    let weekStart: Int
    let weekEnd: Int?
    
    enum CodingKeys: String, CodingKey {
        case stageName = "stage_name"
        case stageId = "stage_id"
        case stageDescription = "stage_description"
        case trainingFocus = "training_focus"
        case weekStart = "week_start"
        case weekEnd = "week_end"
    }
}

struct TrainingPlanOverview: Codable {
    let targetEvaluate: String
    let totalWeeks: Int
    let trainingHighlight: String
    let trainingPlanName: String
    let trainingStageDescription: [TrainingStage]
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case targetEvaluate = "target_evaluate"
        case totalWeeks = "total_weeks"
        case trainingHighlight = "training_hightlight"
        case trainingPlanName = "training_plan_name"
        case trainingStageDescription = "training_stage_discription"
        case createdAt = "created_at"
    }
}
