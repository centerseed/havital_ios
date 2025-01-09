import Foundation

struct UserPreference: Codable {
    let userId: Int
    let userEmail: String
    let userName: String
    var aerobicsLevel: Int
    var strengthLevel: Int
    var busyLevel: Int
    var proactiveLevel: Int
    var age: Int
    var bodyFat: Double
    var bodyHeight: Double
    var bodyWeight: Double
    var announcement: String
    var workoutDays: Set<Int>
    var preferredWorkout: String
    
    // 新增跑步相關欄位
    var goalType: String  // "小試身手" 或 "挑戰跑步目標"
    var runningExperience: Bool
    var longestDistance: Double  // 最長跑步距離（公里）
    var paceInSeconds: Int  // 配速（秒/公里）
    var targetDistance: String  // 目標距離
    var targetTimeInMinutes: Int  // 目標完賽時間（分鐘）
    var targetPaceInSeconds: Int  // 目標配速（秒/公里）
    var trainingWeeks: Int  // 訓練週數
    var raceDate: Date?  // 比賽日期
    
    // 計劃進度
    var weekOfPlan: Int // 計劃中的第幾周
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case userEmail = "user_email"
        case userName = "user_name"
        case aerobicsLevel = "aerobics_level"
        case strengthLevel = "strength_level"
        case busyLevel = "busy_level"
        case proactiveLevel = "proactive_level"
        case age
        case bodyFat = "body_fat"
        case bodyHeight = "body_height"
        case bodyWeight = "body_weight"
        case announcement
        case workoutDays = "workout_days"
        case preferredWorkout = "preferred_workout"
        case goalType = "goal_type"
        case runningExperience = "running_experience"
        case longestDistance = "longest_distance"
        case paceInSeconds = "pace_in_seconds"
        case targetDistance = "target_distance"
        case targetTimeInMinutes = "target_time_in_minutes"
        case targetPaceInSeconds = "target_pace_in_seconds"
        case trainingWeeks = "training_weeks"
        case raceDate = "race_date"
        case weekOfPlan = "week_of_plan"
    }
    
    init(userId: Int, userEmail: String, userName: String, aerobicsLevel: Int, strengthLevel: Int, busyLevel: Int, proactiveLevel: Int, age: Int, bodyFat: Double, bodyHeight: Double, bodyWeight: Double, announcement: String, workoutDays: Set<Int>, preferredWorkout: String, goalType: String = "", runningExperience: Bool = false, longestDistance: Double = 0.0, paceInSeconds: Int = 0, targetDistance: String = "", targetTimeInMinutes: Int = 0, targetPaceInSeconds: Int = 420, trainingWeeks: Int = 4, raceDate: Date? = nil, weekOfPlan: Int = 1) {
        self.userId = userId
        self.userEmail = userEmail
        self.userName = userName
        self.aerobicsLevel = aerobicsLevel
        self.strengthLevel = strengthLevel
        self.busyLevel = busyLevel
        self.proactiveLevel = proactiveLevel
        self.age = age
        self.bodyFat = bodyFat
        self.bodyHeight = bodyHeight
        self.bodyWeight = bodyWeight
        self.announcement = announcement
        self.workoutDays = workoutDays
        self.preferredWorkout = preferredWorkout
        self.goalType = goalType
        self.runningExperience = runningExperience
        self.longestDistance = longestDistance
        self.paceInSeconds = paceInSeconds
        self.targetDistance = targetDistance
        self.targetTimeInMinutes = targetTimeInMinutes
        self.targetPaceInSeconds = targetPaceInSeconds
        self.trainingWeeks = trainingWeeks
        self.raceDate = raceDate
        self.weekOfPlan = weekOfPlan
    }
}

// UserPreference Manager for handling storage
class UserPreferenceManager: ObservableObject {
    static let shared = UserPreferenceManager()
    @Published var currentPreference: UserPreference?
    
    private init() {
        loadPreference()
    }
    
    func savePreference(_ preference: UserPreference) {
        currentPreference = preference
        if let encoded = try? JSONEncoder().encode(preference) {
            UserDefaults.standard.set(encoded, forKey: "UserPreference")
        }
    }
    
    func loadPreference() {
        if let data = UserDefaults.standard.data(forKey: "UserPreference"),
           let preference = try? JSONDecoder().decode(UserPreference.self, from: data) {
            currentPreference = preference
        }
    }
}
