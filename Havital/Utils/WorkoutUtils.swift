import Foundation
import HealthKit

enum WorkoutUtils {
    static func workoutTypeString(for workout: HKWorkout) -> String {
        var typeString = ""
        
        // 基本運動類型
        switch workout.workoutActivityType {
        case .running:
            typeString = "跑步"
        case .walking:
            typeString = "走路"
        case .cycling:
            typeString = "騎行"
        case .swimming:
            typeString = "游泳"
        default:
            typeString = "其他運動"
        }
        
        // 添加位置類型
        if let isIndoor = workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool {
            typeString = (isIndoor ? "室內" : "戶外") + typeString
        }
        
        return typeString
    }
    
    static func workoutTypeString(for activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .running:
            return "跑步"
        case .walking:
            return "走路"
        case .cycling:
            return "騎行"
        case .swimming:
            return "游泳"
        default:
            return "其他運動"
        }
    }
    
    static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return String(format: "%d小時%d分鐘", hours, minutes)
        } else {
            return String(format: "%d分鐘", minutes)
        }
    }
    
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
    
    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
