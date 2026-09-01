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
    let planType: String?            // ✅ V2: plan type ("race_run" | "beginner" | "maintenance")

    enum CodingKeys: String, CodingKey {
        case date
        case overallScore = "overall_score"
        case overallStatusText = "overall_status_text"
        case lastUpdatedTime = "last_updated_time"
        case metrics
        case dataSource = "data_source"
        case lastUpdated = "last_updated"
        case planType = "plan_type"
    }
}

// MARK: - ReadinessPlanType (Domain Layer)

/// Plan type enum for conditional readiness display.
/// Determines which UI components are shown for different training goals.
enum ReadinessPlanType {
    case raceRun
    case beginner
    case maintenance
    case unknown

    init(from string: String?) {
        switch string {
        case "race_run": self = .raceRun
        case "beginner": self = .beginner
        case "maintenance": self = .maintenance
        default: self = .unknown
        }
    }

    /// Show radar chart — true for race_run and unknown (conservative: show all when plan type undetermined)
    var shouldShowRadar: Bool { self == .raceRun || self == .unknown }

    /// Show overall score — true for race_run and unknown
    var shouldShowOverallScore: Bool { self == .raceRun || self == .unknown }

    /// Show estimated race time — true for race_run and unknown
    var shouldShowEstimatedRaceTime: Bool { self == .raceRun || self == .unknown }

    /// Show status text — true for race_run and unknown
    var shouldShowStatusText: Bool { self == .raceRun || self == .unknown }

    /// Show endurance card — true for race_run and unknown
    var shouldShowEndurance: Bool { self == .raceRun || self == .unknown }

    /// Show race fitness card — true for race_run and unknown
    var shouldShowRaceFitness: Bool { self == .raceRun || self == .unknown }

    /// Show recovery card — true for race_run and unknown
    var shouldShowRecovery: Bool { self == .raceRun || self == .unknown }
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
    let values: [Double]       // 數值陣列 (最多 28 個數據點)
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

/// 單一固定距離的完賽預估（`race_fitness.finish_time_predictions` 的一筆）。
///
/// 後端一次給滿 5K／10K／半馬／全馬四筆（producer
/// `domains/readiness/v2/metrics/race_fitness.py:557-590`，距離表 `:84-89`），
/// 投影不出來的距離**不會進 dict**，所以進得來就是有值。
///
/// **每一欄都是 optional**：這個型別是 `Codable`，任一必要欄位缺席會讓**整個
/// readiness response** decode 失敗（2026-08-26 `resting_heart_rate` 宣告成 `Int?`
/// 而後端給 `51.0`，整包 payload 炸掉、HRV/RHR/TSB 全壞的同一個形狀）。
struct RaceFinishPrediction: Codable, Equatable {
    /// 後端的英文標籤（`5K`／`10K`／`Half Marathon`／`Marathon`）。
    /// **認得的 key 一律用 App 自己的三語標籤**，這一欄只在 key 認不得時當退路。
    let distanceLabel: String?
    let distanceKm: Double?
    /// `H:MM:SS`（`race_fitness.py:1093-1098` `_format_time`）。
    let estimatedTime: String?
    let estimatedTimeSeconds: Int?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case distanceLabel = "distance_label"
        case distanceKm = "distance_km"
        case estimatedTime = "estimated_time"
        case estimatedTimeSeconds = "estimated_time_seconds"
        case status
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
    /// 固定距離的完賽預估（key = `five_k`／`ten_k`／`half_marathon`／`full_marathon`）。
    ///
    /// 與 `estimatedRaceTime` 不是同一件事：後者是**目標賽事那一個距離**的投影，
    /// 這一份是四個固定距離的能力對照（T-0376／T-0375）。
    /// **舊 readiness doc 沒有這個欄位 → nil**，不得因此 decode 失敗。
    let finishTimePredictions: [String: RaceFinishPrediction]?
    let message: String?
    /// VDOT 來源："benchmark" 表示由指標跑校準，"training" 表示由訓練資料估算（可選，缺失時不顯示歸因標記）
    let vdotSource: String?
    /// 最近指標跑日期，格式 YYYY-MM-DD（僅 vdotSource == "benchmark" 時有值）
    let benchmarkDate: String?

    enum CodingKeys: String, CodingKey {
        case score
        case racePaceTrainingQuality = "race_pace_training_quality"
        case timeToRaceDays = "time_to_race_days"
        case readinessLevel = "readiness_level"
        case statusText = "status_text"
        case description
        case trendData = "trend_data"
        case estimatedRaceTime = "estimated_race_time"
        case finishTimePredictions = "finish_time_predictions"
        case message
        case vdotSource = "vdot_source"
        case benchmarkDate = "benchmark_date"
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
