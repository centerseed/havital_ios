import Foundation
import HealthKit

struct WorkoutUtils {
    /// 為運動類型返回本地化的名稱
    // In WorkoutUtils.swift
    static func workoutTypeString(for activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .running:
            return "跑步"
        case .walking:
            return "步行"
        case .cycling:
            return "騎行"
        case .swimming:
            return "游泳"
        case .hiking:
            return "遠足"
        case .yoga:
            return "瑜伽"
        case .functionalStrengthTraining:
            return "力量訓練"
        // Add other cases as needed
        default:
            return "其他運動"
        }
    }

    /// 格式化運動時長
    static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d時%02d分", hours, minutes)
        } else {
            return String(format: "%d分%02d秒", minutes, seconds)
        }
    }
    
    /// 格式化日期顯示
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
    
    /// 格式化距離
    static func formatDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            return String(format: "%.2f 公里", distance / 1000)
        } else {
            return String(format: "%.0f 米", distance)
        }
    }
    
    /// 格式化配速 (分:秒/千米)
    static func formatPace(durationInSeconds: Double, distanceInMeters: Double) -> String {
        guard distanceInMeters > 0 else { return "無法計算" }
        
        let paceSecondsPerMeter = durationInSeconds / distanceInMeters
        let paceSecondsPerKm = paceSecondsPerMeter * 1000
        
        let paceMinutes = Int(paceSecondsPerKm) / 60
        let paceSeconds = Int(paceSecondsPerKm) % 60
        
        return String(format: "%d'%02d\"/km", paceMinutes, paceSeconds)
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
