import Foundation
import SwiftUICore

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
    var startTimestamp: Int
    var purpose: String
    var isCompleted: Bool
    var tips: String
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
    var type: String
    var name: String
    var resource: String
    var durationMinutes: Int
    var subItems: [SubItem]
    var goals: [Goal]
    var goalCompletionRates: [String: Double]
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case resource
        case durationMinutes = "duration_minutes"
        case subItems = "sub_items"
        case goals
        case goalCompletionRates = "goal_completion_rates"
    }
    
    var displayName: String {
        let definitions = TrainingDefinitions.load()?.trainingItemDefs ?? []
        if let def = definitions.first(where: { $0.name == name }) {
            return def.displayName
        }
        return name
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
    var id: String
    var name: String
}

struct Goal: Codable {
    var type: String
    var value: Int
}

// MARK: - Training Plan Generator
class TrainingPlanGenerator {
    @StateObject private var userPrefManager = UserPreferenceManager.shared
    static let shared = TrainingPlanGenerator()
    private init() {}
    
    struct TrainingPlanInput: Codable {
        let purpose: String
        let tips: String
        let days: [DayInput]
        let startDate: TimeInterval?
        
        struct DayInput: Codable {
            let target: String
            let training_items: [TrainingItemInput]
            let tips: String
        }
        
        struct TrainingItemInput: Codable {
            let name: String
            let duration_minutes: Int?
            let goals: GoalsInput?
            
            struct GoalsInput: Codable {
                let heart_rate: Int?
                let distance: Int?
                let times: Int?
                let pace: Int?
                
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
                    if let pace = pace {
                        goals.append(Goal(type: "pace", value: pace))
                    }
                    return goals
                }
            }
        }
    }
    
    func generatePlan(from jsonDict: [String: Any]) throws -> TrainingPlan {
        let jsonData = try JSONSerialization.data(withJSONObject: jsonDict)
        let input = try JSONDecoder().decode(TrainingPlanInput.self, from: jsonData)
        
        // 使用指定的開始日期或今天
        let calendar = Calendar.current
        let startDate: Date
        if let timestamp = input.startDate {
            startDate = calendar.startOfDay(for: Date(timeIntervalSince1970: timestamp))
        } else {
            startDate = calendar.startOfDay(for: Date())
        }
        
        // 獲取用戶偏好的訓練日
        let userPreference = userPrefManager.currentPreference
        let workoutDays = userPreference?.workoutDays ?? []
        
        // 將訓練日和休息日分開
        let workoutDayInputs = input.days.filter { !($0.training_items.count == 1 && $0.training_items[0].name == "rest") }
        let restDayInput = input.days.first { $0.training_items.count == 1 && $0.training_items[0].name == "rest" }
        
        var currentWorkoutIndex = 0
        
        // 生成每天的訓練項目
        let days = (0..<7).map { dayOffset -> TrainingDay in
            // 計算當天的時間戳和星期幾
            let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: startDate)!
            let timestamp = Int(dayDate.timeIntervalSince1970)
            
            // 獲取正確的星期幾（1-7，1是星期天）
            let weekday = calendar.component(.weekday, from: dayDate)

            // 調整為 0-6（0是星期天）
            let adjustedWeekday = weekday - 1
            
            print("Date: \(dayDate), \(weekday), \(getWeekdayName(adjustedWeekday)), Workout Days: \(workoutDays.map { getWeekdayName($0) }.joined(separator: ", "))")
            
            // 判斷是否為訓練日
            if workoutDays.contains(adjustedWeekday) && currentWorkoutIndex < workoutDayInputs.count {
                // 訓練日
                let dayInput = workoutDayInputs[currentWorkoutIndex]
                currentWorkoutIndex += 1
                
                // 生成訓練項目
                let trainingItems = dayInput.training_items.enumerated().map { (itemIndex, itemInput) -> TrainingItem in
                    let (name, type, subItems) = getTrainingItemDetails(itemInput.name)
                    
                    return TrainingItem(
                        id: UUID().uuidString,
                        type: type,
                        name: name,
                        resource: "",
                        durationMinutes: itemInput.duration_minutes ?? 0,
                        subItems: subItems,
                        goals: itemInput.goals?.toGoals() ?? []
                    )
                }
                
                return TrainingDay(
                    id: UUID().uuidString,
                    startTimestamp: timestamp,
                    purpose: dayInput.target,
                    isCompleted: false,
                    tips: dayInput.tips,
                    trainingItems: trainingItems
                )
            } else {
                // 休息日
                guard let restDay = restDayInput else {
                    // 如果沒有休息日模板，創建一個默認的
                    return TrainingDay(
                        id: UUID().uuidString,
                        startTimestamp: timestamp,
                        purpose: "休息",
                        isCompleted: false,
                        tips: "",
                        trainingItems: [
                            TrainingItem(
                                id: UUID().uuidString,
                                type: "rest",
                                name: "rest",
                                resource: "",
                                durationMinutes: 0,
                                subItems: [],
                                goals: []
                            )
                        ]
                    )
                }
                
                return TrainingDay(
                    id: UUID().uuidString,
                    startTimestamp: timestamp,
                    purpose: restDay.target,
                    isCompleted: false,
                    tips: restDay.tips,
                    trainingItems: [
                        TrainingItem(
                            id: UUID().uuidString,
                            type: "rest",
                            name: "rest",
                            resource: "",
                            durationMinutes: 0,
                            subItems: [],
                            goals: []
                        )
                    ]
                )
            }
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
                    SubItem(id: "1", name: "伸展運動"),
                    SubItem(id: "2", name: "關節活動")
                ]
            )
        case "super_slow_run":
            return (
                "超慢跑",
                "run",
                [
                    SubItem(id: "1", name: "注意配速"),
                    SubItem(id: "2", name: "維持正確姿勢")
                ]
            )
        case "relax":
            return (
                "放鬆",
                "relax",
                [
                    SubItem(id: "1", name: "伸展放鬆")
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
    
    private func getWeekdayName(_ weekday: Int) -> String {
        let weekdays = ["週日", "週一", "週二", "週三", "週四", "週五", "週六"]
        return String(weekday)
    }
}
