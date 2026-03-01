import Foundation
@testable import paceriz_dev

struct UserProfileTestFixtures {
    
    static var testUser: User {
        let json = """
        {
            "display_name": "Test User",
            "email": "test@example.com",
            "max_hr": 190,
            "relaxing_hr": 60,
            "current_week_distance": 25,
            "data_source": "apple_health",
            "personal_best_v2": {
                "race_run": {
                    "5": [
                        {
                            "complete_time": 1500,
                            "pace": "5:00",
                            "recorded_at": "2023-01-01T12:00:00Z",
                            "workout_date": "2023-01-01",
                            "workout_id": "workout_123"
                        }
                    ]
                }
            }
        }
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(User.self, from: json)
    }
    
    static var testHeartRateZones: [HeartRateZone] {
        return HeartRateZone.calculateZones(maxHR: 190, restingHR: 60)
    }
    
    static var testTargets: [Target] {
        return [
            Target(id: "target_1", type: "race_run", name: "Taipei Marathon", distanceKm: 42, targetTime: 14400, targetPace: "5:41", raceDate: 1734220800, isMainRace: true, trainingWeeks: 12),
            Target(id: "target_2", type: "race_run", name: "Sun Moon Lake Run", distanceKm: 29, targetTime: 10800, targetPace: "6:12", raceDate: 1730000000, isMainRace: false, trainingWeeks: 8)
        ]
    }
    
    static var testPreferences: UserPreferences {
        return UserPreferences(
            language: "zh-TW",
            timezone: "Asia/Taipei",
            supportedLanguages: ["zh-TW", "en-US", "ja-JP"],
            languageNames: ["zh-TW": "繁體中文", "en-US": "English", "ja-JP": "日本語"],
            dataSourcePreference: .appleHealth,
            email: "test@example.com",
            name: "Test User",
            maxHeartRate: 190,
            restingHeartRate: 60
        )
    }
    
    static func userResponseData(name: String = "Test User") -> Data {
        return """
        {
            "status": "success",
            "data": {
                "display_name": "\(name)",
                "email": "test@example.com",
                "max_hr": 190,
                "relaxing_hr": 60,
                "current_week_distance": 25
            }
        }
        """.data(using: .utf8)!
    }
}
