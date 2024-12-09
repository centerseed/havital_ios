import Foundation

// MARK: - Training Plan Models
struct TrainingPlan: Codable, Identifiable {
    let id: String
    let purpose: String
    let tips: String
    var days: [TrainingDay]
    
    mutating func updateDayCompletion(_ dayId: String, isCompleted: Bool) {
        if let index = days.firstIndex(where: { $0.id == dayId }) {
            days[index].isCompleted = isCompleted
        }
    }
}

struct TrainingDay: Codable, Identifiable {
    var id: String
    let startTimestamp: Int
    let purpose: String
    var isCompleted: Bool
    let tips: String
    var trainingItems: [TrainingItem]
    
    enum CodingKeys: String, CodingKey {
        case id
        case startTimestamp = "start_timestamp"
        case purpose
        case isCompleted = "is_completed"
        case tips
        case trainingItems = "training_items"
    }
}

struct TrainingItem: Codable, Identifiable {
    let id: String
    let type: String
    let name: String
    let resource: String
    let durationMinutes: Int
    let subItems: [SubItem]
    let goals: [Goal]
    var goalCompletionRates: [String: Double]
    
    enum CodingKeys: String, CodingKey {
        case id, type, name, resource
        case durationMinutes = "duration_minutes"
        case subItems = "sub_items"
        case goals
        case goalCompletionRates = "goal_completion_rates"
    }
    
    init(id: String, type: String, name: String, resource: String, durationMinutes: Int, subItems: [SubItem], goals: [Goal], goalCompletionRates: [String: Double] = [:]) {
        self.id = id
        self.type = type
        self.name = name
        self.resource = resource
        self.durationMinutes = durationMinutes
        self.subItems = subItems
        self.goals = goals
        self.goalCompletionRates = goalCompletionRates
    }
}

struct SubItem: Codable, Identifiable {
    let id: String
    let name: String
}

struct Goal: Codable {
    let type: String
    let value: Int
}

// MARK: - Training Plan Generator
class TrainingPlanGenerator {
    static let shared = TrainingPlanGenerator()
    private init() {}
    
    struct TrainingPlanInput: Codable {
        let purpose: String
        let tips: String
        let days: [DayInput]
        
        struct DayInput: Codable {
            let target: String
            let training_items: [TrainingItemInput]
        }
        
        struct TrainingItemInput: Codable {
            let name: String
            let duration_minutes: Int?
            let goals: GoalsInput?
            
            struct GoalsInput: Codable {
                let heart_rate: Int?
                let distance: Int?
                let times: Int?
                
                func toGoals() -> [Goal] {
                    var goals: [Goal] = []
                    if let hr = heart_rate {
                        goals.append(Goal(type: "heart_rate", value: hr))
                    }
                    if let dist = distance {
                        goals.append(Goal(type: "distance", value: dist))
                    }
                    if let times = times {
                        goals.append(Goal(type: "times", value: times))
                    }
                    return goals
                }
            }
        }
    }
    
    func generatePlan(from jsonDict: [String: Any]) throws -> TrainingPlan {
        let jsonData = try JSONSerialization.data(withJSONObject: jsonDict)
        let input = try JSONDecoder().decode(TrainingPlanInput.self, from: jsonData)
        
        // 生成計劃開始時間（從今天開始）
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // 生成每天的訓練項目
        let days = input.days.enumerated().map { (index, dayInput) -> TrainingDay in
            // 計算當天的時間戳
            let dayDate = calendar.date(byAdding: .day, value: index, to: today)!
            let timestamp = Int(dayDate.timeIntervalSince1970)
            
            // 生成訓練項目
            let trainingItems = dayInput.training_items.enumerated().map { (itemIndex, itemInput) -> TrainingItem in
                let (name, type, subItems) = getTrainingItemDetails(itemInput.name)
                
                // 從輸入中獲取 goals
                let goals = itemInput.goals?.toGoals() ?? []
                
                return TrainingItem(
                    id: "\(index)_\(itemIndex)",
                    type: type,
                    name: name,
                    resource: "",
                    durationMinutes: itemInput.duration_minutes ?? 0,
                    subItems: subItems,
                    goals: goals,
                    goalCompletionRates: [:]
                )
            }
            
            return TrainingDay(
                id: "\(index + 1)",
                startTimestamp: timestamp,
                purpose: dayInput.target,
                isCompleted: false,
                tips: getDayTips(for: dayInput.target),
                trainingItems: trainingItems
            )
        }
        
        return TrainingPlan(
            id: UUID().uuidString,
            purpose: input.purpose,
            tips: input.tips,
            days: days
        )
    }
    
    private func getTrainingItemDetails(_ type: String) -> (name: String, type: String, subItems: [SubItem]) {
        switch type {
        case "warmup":
            return (
                "熱身",
                "warmup",
                [
                    SubItem(id: "1", name: "原地慢跑"),
                    SubItem(id: "2", name: "伸展運動"),
                    SubItem(id: "3", name: "關節活動")
                ]
            )
        case "super_slow_run":
            return (
                "超慢跑",
                "run",
                [
                    SubItem(id: "1", name: "保持呼吸平穩"),
                    SubItem(id: "2", name: "注意配速"),
                    SubItem(id: "3", name: "維持正確姿勢")
                ]
            )
        case "relax":
            return (
                "放鬆",
                "relax",
                [
                    SubItem(id: "1", name: "緩步走路"),
                    SubItem(id: "2", name: "深呼吸"),
                    SubItem(id: "3", name: "伸展放鬆")
                ]
            )
        case "rest":
            return (
                "休息",
                "rest",
                [
                    SubItem(id: "1", name: "充分休息"),
                    SubItem(id: "2", name: "補充水分"),
                    SubItem(id: "3", name: "適當伸展")
                ]
            )
        default:
            return (type, type, [])
        }
    }
    
    private func getDayTips(for target: String) -> String {
        switch target {
        case "超慢跑":
            return "保持呼吸平穩，注意配速和姿勢，如果感到不適請立即休息。"
        case "休息":
            return "今天是休息日，讓身體充分恢復。可以進行輕度伸展，但避免劇烈運動。"
        default:
            return ""
        }
    }
}
