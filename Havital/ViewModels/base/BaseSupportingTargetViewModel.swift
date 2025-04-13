import Foundation
import SwiftUI

@MainActor
class BaseSupportingTargetViewModel: ObservableObject {
    @Published var raceName = ""
    @Published var raceDate = Date()
    @Published var selectedDistance = "21.0975" // 預設半馬
    @Published var targetHours = 2
    @Published var targetMinutes = 0
    @Published var isLoading = false
    @Published var error: String?
    
    let availableDistances = [
        "3": "3公里",
        "5": "5公里",
        "10": "10公里",
        "15": "15公里",
        "21.0975": "半程馬拉松",
        "42.195": "全程馬拉松"
    ]
    
    var remainingWeeks: Int {
        let calendar = Calendar.current
        let weeks = calendar.dateComponents([.weekOfYear],
                                          from: Date(),
                                          to: raceDate).weekOfYear ?? 0
        return max(weeks, 1) // 至少返回1週
    }
    
    var targetPace: String {
        let totalSeconds = (targetHours * 3600 + targetMinutes * 60)
        let distanceKm = Double(selectedDistance) ?? 21.0975
        let paceSeconds = Int(Double(totalSeconds) / distanceKm)
        let paceMinutes = paceSeconds / 60
        let paceRemainingSeconds = paceSeconds % 60
        return String(format: "%d:%02d", paceMinutes, paceRemainingSeconds)
    }
    
    // 創建目標賽事的基礎 Target 對象
    func createTargetObject(id: String) -> Target {
        return Target(
            id: id,
            type: "race_run",
            name: raceName,
            distanceKm: Int(Double(selectedDistance) ?? 21.0975),
            targetTime: targetHours * 3600 + targetMinutes * 60,
            targetPace: targetPace,
            raceDate: Int(raceDate.timeIntervalSince1970),
            isMainRace: false, // 設為支援賽事
            trainingWeeks: remainingWeeks
        )
    }
}
