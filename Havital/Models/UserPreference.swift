import Foundation

struct UserPreference: Codable {
    let userId: Int
    let userEmail: String
    let userName: String
    let aerobicsLevel: Int
    let strengthLevel: Int
    let busyLevel: Int
    let proactiveLevel: Int
    let age: Int
    let bodyFat: Double
    let bodyHeight: Double
    let bodyWeight: Double
    let announcement: String
    
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
