import Foundation

struct User: Codable {
    let data: UserProfileData
}

struct UserProfileData: Codable {
    let activeTrainingId: String?
    let activeWeeklyPlanId: String?
    /// 顯示名稱可能為空
    let displayName: String?
    let email: String?
    let lastLogin: String?
    let maxHr: Int?
    let photoUrl: String?
    let preferWeekDays: [Int]?
    let preferWeekDaysLongrun: [Int]?
    let relaxingHr: Int?
    let updatedAt: String?
    let weekOfTraining: Int?
    let currentWeekDistance: Int?
    let personalBest: [String: [RaceBest]]?
    let dataSource: String?
    
    // 自定義解碼方法處理可能的型別轉換
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 處理 maxHr
        if let intValue = try? container.decode(Int.self, forKey: .maxHr) {
            maxHr = intValue
        } else if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: .maxHr) {
            maxHr = Int(doubleValue.rounded())
        } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: .maxHr) {
            maxHr = Int(Double(stringValue)?.rounded() ?? 0)
        } else {
            maxHr = nil
        }
        
        // 處理 relaxingHr
        if let intValue = try? container.decode(Int.self, forKey: .relaxingHr) {
            relaxingHr = intValue
        } else if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: .relaxingHr) {
            relaxingHr = Int(doubleValue.rounded())
        } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: .relaxingHr) {
            relaxingHr = Int(Double(stringValue)?.rounded() ?? 0)
        } else {
            relaxingHr = nil
        }
        
        // 處理其他欄位
        activeTrainingId = try container.decodeIfPresent(String.self, forKey: .activeTrainingId)
        activeWeeklyPlanId = try container.decodeIfPresent(String.self, forKey: .activeWeeklyPlanId)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        lastLogin = try container.decodeIfPresent(String.self, forKey: .lastLogin)
        photoUrl = try container.decodeIfPresent(String.self, forKey: .photoUrl)
        preferWeekDays = try container.decodeIfPresent([Int].self, forKey: .preferWeekDays)
        preferWeekDaysLongrun = try container.decodeIfPresent([Int].self, forKey: .preferWeekDaysLongrun)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        weekOfTraining = try container.decodeIfPresent(Int.self, forKey: .weekOfTraining)
        
        // 處理 currentWeekDistance，確保為整數
        if let intValue = try? container.decode(Int.self, forKey: .currentWeekDistance) {
            currentWeekDistance = intValue
        } else if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: .currentWeekDistance) {
            currentWeekDistance = Int(doubleValue.rounded())
        } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: .currentWeekDistance) {
            currentWeekDistance = Int(Double(stringValue)?.rounded() ?? 0)
        } else {
            currentWeekDistance = nil
        }
        
        personalBest = try container.decodeIfPresent([String: [RaceBest]].self, forKey: .personalBest)
        dataSource = try container.decodeIfPresent(String.self, forKey: .dataSource)
    }
    
    enum CodingKeys: String, CodingKey {
        case activeTrainingId = "active_training_id"
        case activeWeeklyPlanId = "active_weekly_plan_id"
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
        case currentWeekDistance = "current_week_distance"
        case dataSource = "data_source"
    }
}

struct RaceBest: Codable {
    let distance: Double?
    let time: Double?
    let date: String?
    
    // 自定義解碼方法處理可能的型別轉換
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 處理 distance 欄位
        if let doubleValue = try? container.decode(Double.self, forKey: .distance) {
            distance = doubleValue
        } else if let intValue = try? container.decodeIfPresent(Int.self, forKey: .distance) {
            distance = Double(intValue)
        } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: .distance) {
            distance = Double(stringValue)
        } else {
            distance = nil
        }
        
        // 處理 time 欄位
        if let doubleValue = try? container.decode(Double.self, forKey: .time) {
            time = doubleValue
        } else if let intValue = try? container.decodeIfPresent(Int.self, forKey: .time) {
            time = Double(intValue)
        } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: .time) {
            time = Double(stringValue)
        } else {
            time = nil
        }
        
        date = try container.decodeIfPresent(String.self, forKey: .date)
    }
    
    private enum CodingKeys: String, CodingKey {
        case distance, time, date
    }
}

// For Google login
struct GoogleLoginRequest: Codable {
    let idToken: String
}
