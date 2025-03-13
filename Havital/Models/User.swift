import Foundation

struct User: Codable {
    let data: UserProfileData
}

struct UserProfileData: Codable {
    let activeTrainingId: String?
    let activeWeeklyPlanId: String?
    let authProvider: String
    let displayName: String
    let email: String
    let lastLogin: String
    let maxHr: Int
    let photoUrl: String?
    let preferWeekDays: [Int]
    let preferWeekDaysLongrun: [Int]
    let relaxingHr: Int
    let updatedAt: String
    let weekOfTraining: Int
    let personalBest: [String: [RaceBest]]?
    
    enum CodingKeys: String, CodingKey {
        case activeTrainingId = "active_training_id"
        case activeWeeklyPlanId = "active_weekly_plan_id"
        case authProvider = "auth_provider"
        case displayName = "display_name"
        case email
        case lastLogin = "last_login"
        case maxHr = "max_hr"
        case photoUrl = "photo_url"
        case preferWeekDays = "prefer_week_days"
        case preferWeekDaysLongrun = "prefer_week_days_longrun"
        case relaxingHr = "relaxing_hr"
        case updatedAt = "updated_at"
        case weekOfTraining = "week_of_training"
        case personalBest = "personal_best"
    }
}

struct RaceBest: Codable {
    // Add the properties for race best records if needed
    // This is a placeholder since we don't have the exact structure
    let distance: Double?
    let time: Double?
    let date: String?
}

// For Google login
struct GoogleLoginRequest: Codable {
    let idToken: String
}

