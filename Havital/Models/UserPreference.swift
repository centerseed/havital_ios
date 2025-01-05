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
    var preferredWorkouts: Set<String>
    
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
        case preferredWorkouts = "preferred_workouts"
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
