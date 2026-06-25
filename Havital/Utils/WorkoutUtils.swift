import Foundation
import HealthKit

struct WorkoutUtils {
    /// 為運動類型返回本地化的名稱
    // In WorkoutUtils.swift
    static func workoutTypeString(for activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .running:
            return L10n.ActivityType.running.localized
        case .walking:
            return L10n.ActivityType.walking.localized
        case .cycling:
            return L10n.ActivityType.cycling.localized
        case .swimming:
            return L10n.ActivityType.swimming.localized
        case .hiking:
            return L10n.ActivityType.hiking.localized
        case .yoga:
            return L10n.ActivityType.yoga.localized
        case .functionalStrengthTraining:
            return L10n.ActivityType.strengthTraining.localized
        // Add other cases as needed
        default:
            return L10n.ActivityType.other.localized
        }
    }

    /// 格式化運動時長
    static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: NSLocalizedString("workout_format.duration_hm", comment: ""), hours, minutes)
        } else {
            return String(format: NSLocalizedString("workout_format.duration_ms", comment: ""), minutes, seconds)
        }
    }

    static func formatDurationSimple(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    /// 格式化日期顯示
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("workout_format.date_pattern", comment: "")
        return formatter.string(from: date)
    }
    
    /// 格式化距離（依 UnitManager 設定決定單位）
    static func formatDistance(_ distance: Double) -> String {
        return MainActor.assumeIsolated {
            let unit = UnitManager.shared.currentUnitSystem
            switch unit {
            case .metric:
                if distance >= 1000 {
                    return String(format: NSLocalizedString("workout_format.distance_km", comment: ""), distance / 1000)
                } else {
                    return String(format: NSLocalizedString("workout_format.distance_m", comment: ""), distance)
                }
            case .imperial:
                let miles = (distance / 1000) * 0.621371
                if miles >= 0.1 {
                    return String(format: "%.2f mi", miles)
                } else {
                    let feet = distance * 3.28084
                    return String(format: "%.0f ft", feet)
                }
            }
        }
    }

    /// 格式化配速（依 UnitManager 設定決定單位）
    static func formatPace(durationInSeconds: Double, distanceInMeters: Double) -> String {
        guard distanceInMeters > 0 else {
            return NSLocalizedString("pace.unable_to_calculate", comment: "Pace cannot be calculated")
        }
        let paceSecondsPerKm = (durationInSeconds / distanceInMeters) * 1000
        return MainActor.assumeIsolated {
            let unit = UnitManager.shared.currentUnitSystem
            let converted: Double
            switch unit {
            case .metric: converted = paceSecondsPerKm
            case .imperial: converted = paceSecondsPerKm * 1.60934
            }
            let minutes = Int(converted) / 60
            let seconds = Int(converted) % 60
            return String(format: "%d'%02d\"/%@", minutes, seconds, unit.distanceSuffix)
        }
    }
    
    /// 檢查運動是否為有心率數據的類型
    static func isCardioWorkout(_ workout: HKWorkout) -> Bool {
        let cardioTypes: [HKWorkoutActivityType] = [
            .running, .walking, .cycling, .swimming, .hiking,
            .elliptical, .stairClimbing, .highIntensityIntervalTraining,
            .jumpRope, .crossTraining, .mixedCardio
        ]
        
        return cardioTypes.contains(workout.workoutActivityType)
    }
}
