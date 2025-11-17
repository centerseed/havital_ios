import Foundation

// MARK: - Training Readiness API Response Models
// All fields are optional to prevent crashes from missing data

/// Main API response wrapper
struct TrainingReadinessAPIResponse: Codable {
    let success: Bool
    let data: TrainingReadinessResponse?
    let error: String?
}

/// Training readiness data response
struct TrainingReadinessResponse: Codable {
    let date: String
    let overallScore: Double?
    let overallStatusText: String?  // ✅ New: Overall status description
    let lastUpdatedTime: String?     // ✅ New: Display time (e.g., "10:30 更新")
    let metrics: TrainingReadinessMetrics?
    let dataSource: String?
    let lastUpdated: String?

    enum CodingKeys: String, CodingKey {
        case date
        case overallScore = "overall_score"
        case overallStatusText = "overall_status_text"
        case lastUpdatedTime = "last_updated_time"
        case metrics
        case dataSource = "data_source"
        case lastUpdated = "last_updated"
    }
}

/// Container for all readiness metrics
struct TrainingReadinessMetrics: Codable {
    let speed: SpeedMetric?
    let endurance: EnduranceMetric?
    let raceFitness: RaceFitnessMetric?
    let trainingLoad: TrainingLoadMetric?
    let recovery: RecoveryMetric?

    enum CodingKeys: String, CodingKey {
        case speed
        case endurance
        case raceFitness = "race_fitness"
        case trainingLoad = "training_load"
        case recovery
    }
}

// MARK: - Trend Data Model

/// Trend chart data (趨勢圖數據)
struct TrendData: Codable {
    let values: [Double]       // 數值陣列 (3-21 個數據點)
    let dates: [String]        // 日期陣列 (格式: MM-DD)
    let direction: String      // 趨勢方向: "up", "down", "stable"

    enum Direction: String {
        case up
        case down
        case stable

        init(from string: String) {
            self = Direction(rawValue: string.lowercased()) ?? .stable
        }
    }

    var directionType: Direction {
        return Direction(from: direction)
    }

    /// Check if trend data is valid
    var isValid: Bool {
        return values.count >= 3 && values.count == dates.count
    }
}

// MARK: - Individual Metric Models

/// Speed metric (速度指標)
struct SpeedMetric: Codable {
    let score: Double
    let achievementRate: Double?
    let statusText: String?           // ✅ New: Two-line status text (separated by \n)
    let description: String?          // ✅ New: Metric description
    let trendData: TrendData?         // ✅ New: Trend chart data
    let recentWorkouts: [WorkoutItem]?
    let trend: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case score
        case achievementRate = "achievement_rate"
        case statusText = "status_text"
        case description
        case trendData = "trend_data"
        case recentWorkouts = "recent_workouts"
        case trend
        case message
    }
}

/// Workout item for recent workouts
struct WorkoutItem: Codable {
    let date: String?
    let type: String?
    let pace: String?
}

/// Endurance metric (耐力指標)
struct EnduranceMetric: Codable {
    let score: Double
    let longRunCompletion: Double?
    let volumeConsistency: Double?
    let statusText: String?           // ✅ New: Two-line status text
    let description: String?          // ✅ New: Metric description
    let trendData: TrendData?         // ✅ New: Trend chart data
    let trend: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case score
        case longRunCompletion = "long_run_completion"
        case volumeConsistency = "volume_consistency"
        case statusText = "status_text"
        case description
        case trendData = "trend_data"
        case trend
        case message
    }
}

/// Race fitness metric (比賽適能指標)
struct RaceFitnessMetric: Codable {
    let score: Double
    let racePaceTrainingQuality: Double?
    let timeToRaceDays: Int?
    let readinessLevel: String?
    let statusText: String?           // ✅ New: Two-line status text
    let description: String?          // ✅ New: Metric description
    let trendData: TrendData?         // ✅ New: Trend chart data
    let estimatedRaceTime: String?    // ✅ New: Estimated race time (e.g., "2:01:32")
    let message: String?

    enum CodingKeys: String, CodingKey {
        case score
        case racePaceTrainingQuality = "race_pace_training_quality"
        case timeToRaceDays = "time_to_race_days"
        case readinessLevel = "readiness_level"
        case statusText = "status_text"
        case description
        case trendData = "trend_data"
        case estimatedRaceTime = "estimated_race_time"
        case message
    }
}

/// Training load metric (訓練負荷指標)
struct TrainingLoadMetric: Codable {
    let score: Double
    let currentTsb: Double?
    let ctl: Double?
    let atl: Double?
    let balanceStatus: String?
    let statusText: String?           // ✅ New: Two-line status text
    let description: String?          // ✅ New: Metric description
    let trendData: TrendData?         // ✅ New: Trend chart data
    let message: String?

    enum CodingKeys: String, CodingKey {
        case score
        case currentTsb = "current_tsb"
        case ctl
        case atl
        case balanceStatus = "balance_status"
        case statusText = "status_text"
        case description
        case trendData = "trend_data"
        case message
    }
}

/// Recovery metric (恢復指標)
struct RecoveryMetric: Codable {
    let score: Double
    let restDaysCount: Int?
    let recoveryQuality: String?
    let fatigueLevel: String?
    let statusText: String?           // ✅ New: Two-line status text
    let trendData: TrendData?         // ✅ New: Trend chart data
    let message: String?

    enum CodingKeys: String, CodingKey {
        case score
        case restDaysCount = "rest_days_count"
        case recoveryQuality = "recovery_quality"
        case fatigueLevel = "fatigue_level"
        case statusText = "status_text"
        case trendData = "trend_data"
        case message
    }
}

// MARK: - Helper Extensions

extension TrainingReadinessResponse {
    /// Check if response has valid data
    var hasData: Bool {
        return metrics != nil
    }

    /// Get readable date
    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: date) {
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        }
        return date
    }
}

extension TrainingReadinessMetrics {
    /// Check if at least one metric is available
    var hasAnyMetric: Bool {
        return speed != nil || endurance != nil || raceFitness != nil || trainingLoad != nil || recovery != nil
    }
}

// MARK: - Trend Interpretation

extension SpeedMetric {
    enum TrendType: String {
        case improving
        case stable
        case declining
        case insufficientData = "insufficient_data"
        case unknown

        init(from string: String?) {
            switch string {
            case "improving": self = .improving
            case "stable": self = .stable
            case "declining": self = .declining
            case "insufficient_data": self = .insufficientData
            default: self = .unknown
            }
        }
    }

    var trendType: TrendType {
        return TrendType(from: trend)
    }
}
