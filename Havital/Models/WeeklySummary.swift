import Foundation

struct WeeklySummary: Codable {
    let startDate: String
    let endDate: String
    let days: [DaySummary]
    
    struct DaySummary: Codable {
        let date: String
        let name: String
        let duration_minutes: Int
        let actualDuration: Int
        let goals: [GoalSummary]
        
        struct GoalSummary: Codable {
            let type: String
            let target: Int
            let completionRate: Double
            
            enum CodingKeys: String, CodingKey {
                case type
                case target
                case completionRate = "completionRate"
            }
        }
    }
}
