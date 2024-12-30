import Foundation

struct WeeklySummary: Codable {
    let startDate: String
    let endDate: String
    let days: [DaySummary]
    
    struct DaySummary: Codable {
        let name: String
        let date: String
        let plannedDuration: Int
        let actualDuration: Int
        let goals: [GoalSummary]
        
        struct GoalSummary: Codable {
            let type: String
            let target: Int
            let completionRate: Double
        }
    }
}
