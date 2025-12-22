import Foundation

// MARK: - Personal Best v2 Models

/// Personal Best v2 單筆記錄
struct PersonalBestRecordV2: Codable, Equatable {
    let completeTime: Int          // 完賽時間（秒）
    let pace: String               // 配速 "M:SS"
    let recordedAt: String         // ISO 8601
    let workoutDate: String        // "YYYY-MM-DD"
    let workoutId: String

    enum CodingKeys: String, CodingKey {
        case completeTime = "complete_time"
        case pace
        case recordedAt = "recorded_at"
        case workoutDate = "workout_date"
        case workoutId = "workout_id"
    }

    /// 格式化完賽時間為 HH:MM:SS 或 MM:SS
    func formattedTime() -> String {
        let hours = completeTime / 3600
        let minutes = (completeTime % 3600) / 60
        let seconds = completeTime % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Race Distance Enum

/// 距離枚舉
enum RaceDistanceV2: String, CaseIterable {
    case mile = "1.6"
    case threeK = "3"
    case fiveK = "5"
    case tenK = "10"
    case halfMarathon = "21"
    case fullMarathon = "42"

    var displayName: String {
        switch self {
        case .mile: return L10n.Distance.mile.localized
        case .threeK: return L10n.Distance.threeK.localized
        case .fiveK: return L10n.Distance.fiveK.localized
        case .tenK: return L10n.Distance.tenK.localized
        case .halfMarathon: return L10n.Distance.halfMarathon.localized
        case .fullMarathon: return L10n.Distance.fullMarathon.localized
        }
    }

    var shortName: String {
        switch self {
        case .mile: return "1.6K"
        case .threeK: return "3K"
        case .fiveK: return "5K"
        case .tenK: return "10K"
        case .halfMarathon: return L10n.Distance.halfMarathonShort.localized
        case .fullMarathon: return L10n.Distance.fullMarathonShort.localized
        }
    }

    /// 距離優先級（用於排序和選擇慶祝動畫）
    var priority: Int {
        switch self {
        case .fullMarathon: return 6
        case .halfMarathon: return 5
        case .tenK: return 4
        case .fiveK: return 3
        case .threeK: return 2
        case .mile: return 1
        }
    }
}

// MARK: - Personal Best Update

/// 個人最佳更新記錄（用於慶祝動畫）
struct PersonalBestUpdate: Codable, Equatable {
    let distance: String              // 距離（如 "21"）
    let oldTime: Int                  // 舊紀錄（秒）
    let newTime: Int                  // 新紀錄（秒）
    let improvementSeconds: Int       // 進步秒數
    let workoutDate: String           // 訓練日期
    let detectedAt: Date              // 檢測時間

    /// 距離優先級（用於選擇顯示哪個慶祝動畫）
    var distancePriority: Int {
        RaceDistanceV2(rawValue: distance)?.priority ?? 0
    }

    /// 格式化進步時間
    func formattedImprovement() -> String {
        let minutes = improvementSeconds / 60
        let seconds = improvementSeconds % 60

        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Celebration Cache

/// 慶祝動畫緩存
struct PersonalBestCelebrationCache: Codable {
    var lastDetectedUpdate: PersonalBestUpdate?     // 最後檢測到的更新
    var hasShownCelebration: Bool = false            // 是否已顯示慶祝動畫
    var lastCheckTimestamp: Date?                    // 上次檢查時間
}
