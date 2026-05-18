import Foundation

enum AchievementAnalyticsPayloadGuard {
    static let allowedKeys: Set<String> = [
        "entry",
        "badge_id",
        "chapter",
        "status",
        "material_type"
    ]

    static let sensitiveKeys: Set<String> = [
        "route",
        "gps",
        "location",
        "coordinate",
        "coordinates",
        "heart",
        "heart_rate",
        "heartrate",
        "sleep",
        "injury",
        "workout_id",
        "workoutid",
        "email",
        "uid",
        "user_id",
        "schedule",
        "plan_detail"
    ]

    static func sanitized(_ params: [String: Any]) -> [String: Any] {
        params.filter { key, _ in
            let normalized = key.lowercased()
            return allowedKeys.contains(normalized) && !sensitiveKeys.contains(normalized)
        }
    }

    static func containsSensitiveKey(_ params: [String: Any]) -> Bool {
        params.keys.contains { key in
            let normalized = key.lowercased()
            return sensitiveKeys.contains { normalized.contains($0) }
        }
    }
}
