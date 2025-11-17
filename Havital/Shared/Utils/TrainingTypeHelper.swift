import Foundation

/// 訓練類型輔助工具
struct TrainingTypeHelper {
    /// 判斷是否是「輕鬆課表」（需要顯示心率區間）
    static func isEasyWorkout(_ trainingType: String) -> Bool {
        let type = DayType(rawValue: trainingType) ?? .rest
        return isEasyWorkout(type)
    }

    static func isEasyWorkout(_ type: DayType) -> Bool {
        switch type {
        case .easy, .easyRun, .recovery_run, .lsd:
            return true
        default:
            return false
        }
    }

    /// 判斷是否是間歇訓練
    static func isIntervalWorkout(_ trainingType: String) -> Bool {
        let type = DayType(rawValue: trainingType) ?? .rest
        return type == .interval
    }

    /// 判斷是否是組合跑
    static func isCombinationWorkout(_ trainingType: String) -> Bool {
        let type = DayType(rawValue: trainingType) ?? .rest
        return type == .combination || type == .progression
    }

    /// 判斷是否需要分段追蹤
    static func needsSegmentTracking(_ trainingType: String) -> Bool {
        return isIntervalWorkout(trainingType) || isCombinationWorkout(trainingType)
    }

    /// 判斷是否是休息日
    static func isRestDay(_ trainingType: String) -> Bool {
        let type = DayType(rawValue: trainingType) ?? .rest
        return type == .rest
    }

    /// 獲取訓練模式
    static func getWorkoutMode(_ trainingType: String) -> WorkoutMode {
        if isEasyWorkout(trainingType) {
            return .heartRate
        } else if isIntervalWorkout(trainingType) {
            return .interval
        } else if isCombinationWorkout(trainingType) {
            return .combination
        } else if isRestDay(trainingType) {
            return .rest
        } else {
            return .pace
        }
    }

    /// 訓練模式枚舉
    enum WorkoutMode {
        case heartRate      // 心率模式（輕鬆跑）
        case pace           // 配速模式（節奏跑、閾值跑等）
        case interval       // 間歇模式
        case combination    // 組合跑模式
        case rest           // 休息
    }
}

/// 恢復段類型判斷
struct RecoveryTypeDetector {
    /// 判斷恢復段類型
    static func getRecoveryType(from segment: WatchWorkoutSegment?) -> RecoveryType {
        guard let segment = segment else { return .none }

        // 如果有距離，是主動恢復跑
        if let distance = segment.distanceKm ?? segment.distanceM {
            let distanceInMeters = segment.distanceKm.map { $0 * 1000 } ?? distance
            return .activeRecovery(distanceMeters: distanceInMeters, pace: segment.pace)
        }

        // 如果有時間，是全休
        if let timeMinutes = segment.timeMinutes {
            return .rest(durationSeconds: timeMinutes * 60)
        }

        return .none
    }

    /// 恢復類型
    enum RecoveryType {
        case activeRecovery(distanceMeters: Double, pace: String?)  // 恢復跑
        case rest(durationSeconds: TimeInterval)                    // 全休
        case none                                                    // 無恢復段
    }
}
