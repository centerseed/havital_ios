// Havital/Models/BackfillModels.swift
import Foundation

// MARK: - Backfill Response Models

/// Backfill 觸發回應
struct BackfillResponse: Codable {
    let data: BackfillData

    struct BackfillData: Codable {
        let backfillId: String
        let status: String
        let message: String

        enum CodingKeys: String, CodingKey {
            case backfillId = "backfill_id"
            case status
            case message
        }
    }

    var backfillId: String { data.backfillId }
    var status: String { data.status }
    var message: String { data.message }
}

/// Backfill 狀態查詢回應
struct BackfillStatusResponse: Codable {
    let data: BackfillStatusData

    struct BackfillStatusData: Codable {
        let backfillId: String
        let status: String
        let provider: String
        let timeRange: TimeRange
        let progress: Progress
        let timestamps: Timestamps
        let completionReason: String?
        let error: String?

        struct TimeRange: Codable {
            let startDate: String
            let endDate: String
            let days: Int

            enum CodingKeys: String, CodingKey {
                case startDate = "start_date"
                case endDate = "end_date"
                case days
            }
        }

        struct Progress: Codable {
            let initialWorkoutCount: Int
            let currentWorkoutCount: Int
            let newWorkouts: Int

            enum CodingKeys: String, CodingKey {
                case initialWorkoutCount = "initial_workout_count"
                case currentWorkoutCount = "current_workout_count"
                case newWorkouts = "new_workouts"
            }
        }

        struct Timestamps: Codable {
            let triggeredAt: String
            let lastCheckedAt: String?
            let lastWorkoutReceivedAt: String?
            let completedAt: String?

            enum CodingKeys: String, CodingKey {
                case triggeredAt = "triggered_at"
                case lastCheckedAt = "last_checked_at"
                case lastWorkoutReceivedAt = "last_workout_received_at"
                case completedAt = "completed_at"
            }
        }

        enum CodingKeys: String, CodingKey {
            case backfillId = "backfill_id"
            case status
            case provider
            case timeRange = "time_range"
            case progress
            case timestamps
            case completionReason = "completion_reason"
            case error
        }
    }

    var status: String { data.status }
    var progress: BackfillStatusData.Progress { data.progress }
    var completionReason: String? { data.completionReason }
    var error: String? { data.error }
}

/// Backfill 進度（UI 使用）
struct BackfillProgress {
    let newWorkouts: Int
    let currentWorkoutCount: Int
}
