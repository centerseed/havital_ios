import Foundation

// MARK: - T-0142 指標跑當日即時校準 動作 DTO
// apply → POST /v2/workouts/benchmark/apply;schedule-next → POST /v2/workouts/benchmark/schedule-next

struct BenchmarkApplyRequestDTO: Codable {
    let workoutId: String
    let workoutDate: String
    let benchmarkDistanceM: Double
    let benchmarkDurationS: Double
    let overviewId: String
    enum CodingKeys: String, CodingKey {
        case workoutId = "workout_id"
        case workoutDate = "workout_date"
        case benchmarkDistanceM = "benchmark_distance_m"
        case benchmarkDurationS = "benchmark_duration_s"
        case overviewId = "overview_id"
    }
}

struct BenchmarkApplyResultDTO: Codable {
    let confirmed: Bool
    let vdot: Double?
    let finishPrediction: FinishDTO?
    enum CodingKeys: String, CodingKey {
        case confirmed, vdot
        case finishPrediction = "finish_prediction"
    }
    struct FinishDTO: Codable {
        let estimatedRaceTimeSeconds: Int?
        enum CodingKeys: String, CodingKey {
            case estimatedRaceTimeSeconds = "estimated_race_time_seconds"
        }
    }
}

struct BenchmarkScheduleRequestDTO: Codable {
    let overviewId: String
    let currentWeek: Int
    enum CodingKeys: String, CodingKey {
        case overviewId = "overview_id"
        case currentWeek = "current_week"
    }
}

struct BenchmarkScheduleResultDTO: Codable {
    let scheduled: Bool
    let scheduledWeek: Int?
    enum CodingKeys: String, CodingKey {
        case scheduled
        case scheduledWeek = "scheduled_week"
    }
}
