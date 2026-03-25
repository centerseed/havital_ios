import Foundation

// MARK: - Training Plan V2 Request DTOs
//
// Request DTOs for Training Plan V2 API calls
// Data Layer - Used for API request body serialization
// Follows Clean Architecture: DTOs in Data Layer, snake_case for API compatibility

// MARK: - Plan Overview Requests

/// Request DTO for creating race-based training plan overview
/// POST /v2/plan/overview (race mode)
struct CreateOverviewForRaceRequest: Codable {
    let targetId: String
    let startFromStage: String?
    let methodologyId: String?

    enum CodingKeys: String, CodingKey {
        case targetId = "target_id"
        case startFromStage = "start_from_stage"
        case methodologyId = "methodology_id"
    }
}

/// Request DTO for creating non-race training plan overview
/// POST /v2/plan/overview (non-race mode: beginner, maintenance)
struct CreateOverviewForNonRaceRequest: Codable {
    let targetType: String
    let trainingWeeks: Int
    let availableDays: Int?
    let methodologyId: String?
    let startFromStage: String?

    enum CodingKeys: String, CodingKey {
        case targetType = "target_type"
        case trainingWeeks = "training_weeks"
        case availableDays = "available_days"
        case methodologyId = "methodology_id"
        case startFromStage = "start_from_stage"
    }
}

/// Request DTO for updating plan overview
/// PUT /v2/plan/overview/:id
struct UpdateOverviewRequest: Codable {
    let startFromStage: String?
    let methodologyId: String?

    enum CodingKeys: String, CodingKey {
        case startFromStage = "start_from_stage"
        case methodologyId = "methodology_id"
    }
}

// MARK: - Weekly Plan Requests

/// Request DTO for generating weekly plan
/// POST /v2/plan/weekly
struct GenerateWeeklyPlanRequest: Codable {
    let weekOfTraining: Int
    let forceGenerate: Bool?
    let promptVersion: String?
    let methodology: String?

    enum CodingKeys: String, CodingKey {
        case weekOfTraining = "week_of_training"
        case forceGenerate = "force_generate"
        case promptVersion = "prompt_version"
        case methodology
    }
}

/// Request DTO for updating weekly plan (merge update)
/// PUT /v2/plan/weekly/:plan_id
struct UpdateWeeklyPlanRequest: Codable {
    let days: [DayDetailDTO]?
    let purpose: String?
    let totalDistanceKm: Double?

    enum CodingKeys: String, CodingKey {
        case days
        case purpose
        case totalDistanceKm = "total_distance_km"
    }
}

// MARK: - Weekly Summary Requests

/// Request DTO for generating weekly summary
/// POST /v2/summary/weekly
struct GenerateWeeklySummaryRequest: Codable {
    let weekOfPlan: Int
    let forceUpdate: Bool?

    enum CodingKeys: String, CodingKey {
        case weekOfPlan = "week_of_plan"
        case forceUpdate = "force_update"
    }
}
