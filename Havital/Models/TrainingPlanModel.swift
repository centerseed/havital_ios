// MARK: - Models

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
    var heartRateStats: HeartRateStats?
    
    struct HeartRateStats: Codable {
        struct HeartRateRecord: Codable {
            let timestamp: Date
            let value: Double
            
            init(timestamp: Date, value: Double) {
                self.timestamp = timestamp
                self.value = value
            }
        }
        
        var averageHeartRate: Double
        var heartRates: [HeartRateRecord]
        var goalCompletionRate: Double
        
        init(averageHeartRate: Double, heartRates: [(Date, Double)], goalCompletionRate: Double) {
            self.averageHeartRate = averageHeartRate
            self.heartRates = heartRates.map { HeartRateRecord(timestamp: $0.0, value: $0.1) }
            self.goalCompletionRate = goalCompletionRate
        }
        
        var heartRateTuples: [(Date, Double)] {
            return heartRates.map { ($0.timestamp, $0.value) }
        }
        
        enum CodingKeys: String, CodingKey {
            case averageHeartRate
            case heartRates
            case goalCompletionRate
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            averageHeartRate = try container.decode(Double.self, forKey: .averageHeartRate)
            heartRates = try container.decode([HeartRateRecord].self, forKey: .heartRates)
            goalCompletionRate = try container.decode(Double.self, forKey: .goalCompletionRate)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case startTimestamp = "start_timestamp"
        case purpose
        case isCompleted = "is_completed"
        case tips
        case trainingItems = "training_items"
        case heartRateStats = "heart_rate_stats"
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

struct WeeklyAnalysis: Codable {
    let summary: String
    let training_analysis: String
    let further_suggestion: String
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
            let tips: String?
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
        var workoutDays = Array(userPreference?.workoutDays ?? []).sorted()
        
        // 將訓練日和休息日分開
        let workoutDayInputs = input.days.filter { !($0.training_items.count == 1 && $0.training_items[0].name == "rest") }
        let restDayInput = input.days.first { $0.training_items.count == 1 && $0.training_items[0].name == "rest" }
        
        // 計算需要的訓練日數量
        let requiredWorkoutDays = workoutDayInputs.count
        
        // 如果需要更多訓練日，從休息日中選擇添加
        if requiredWorkoutDays > workoutDays.count {
            let additionalDaysNeeded = requiredWorkoutDays - workoutDays.count
            // 獲取所有可用的休息日，並按照與最近的訓練日的間隔排序
            let restDays = Array(Set(0...6).subtracting(Set(workoutDays))).sorted { day1, day2 in
                // 計算與最近訓練日的間隔
                let gap1 = workoutDays.map { abs($0 - day1) }.min() ?? 7
                let gap2 = workoutDays.map { abs($0 - day2) }.min() ?? 7
                return gap1 > gap2 // 優先選擇間隔較大的日子
            }
            
            // 從休息日中選擇需要的天數
            workoutDays.append(contentsOf: restDays.prefix(additionalDaysNeeded))
            workoutDays.sort()
        }
        
        // 創建訓練日到訓練內容的映射
        var workoutDayToInput: [Int: TrainingPlanInput.DayInput] = [:]
        var currentWorkoutIndex = 0
        
        // 按照原有的訓練日順序分配訓練內容
        for day in workoutDays {
            if currentWorkoutIndex < workoutDayInputs.count {
                workoutDayToInput[day] = workoutDayInputs[currentWorkoutIndex]
                currentWorkoutIndex += 1
            }
        }
        
        // 生成每天的訓練項目
        let days = (0..<7).map { dayOffset -> TrainingDay in
            // 計算當天的時間戳和星期幾
            let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: startDate)!
            let timestamp = Int(dayDate.timeIntervalSince1970)
            
            // 獲取正確的星期幾（1-7，1是星期天）
            let weekday = calendar.component(.weekday, from: dayDate)
            // 調整為 0-6（0是星期天）
            let adjustedWeekday = weekday - 1
            
            // 判斷是否為訓練日
            if let dayInput = workoutDayToInput[adjustedWeekday] {
                // 訓練日
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
                    tips: dayInput.tips ?? "",
                    trainingItems: trainingItems,
                    heartRateStats: nil
                )
            } else {
                // 休息日
                return TrainingDay(
                    id: UUID().uuidString,
                    startTimestamp: timestamp,
                    purpose: restDayInput?.target ?? "休息",
                    isCompleted: false,
                    tips: restDayInput?.tips ?? "今天是休息日",
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
                    ],
                    heartRateStats: nil
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
                "warmup",
                "warmup",
                []
            )
        case "super_slow_run":
            return (
                "super_slow_run",
                "run",
                []
            )
        case "relax":
            return (
                "relax",
                "relax",
                []
            )
        case "rest":
            return (
                "rest",
                "rest",
                []
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
