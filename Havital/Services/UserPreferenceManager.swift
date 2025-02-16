import Foundation

class UserPreferenceManager: ObservableObject {
    static let shared = UserPreferenceManager()
    
    @Published var email: String = UserDefaults.standard.string(forKey: "user_email") ?? "" {
        didSet {
            UserDefaults.standard.set(email, forKey: "user_email")
        }
    }
    
    @Published var name: String? {
        didSet {
            UserDefaults.standard.set(name, forKey: "user_name")
        }
    }
    
    @Published var age: Int? {
        didSet {
            UserDefaults.standard.set(name, forKey: "age")
        }
    }
    
    @Published var maxHeartRate: Int? {
        didSet {
            UserDefaults.standard.set(name, forKey: "max_heart_rate")
        }
    }
    
    @Published var currentPace: String? {
        didSet {
            UserDefaults.standard.set(photoURL, forKey: "current_pace")
        }
    }
    
    @Published var currentDistance: String? {
        didSet {
            UserDefaults.standard.set(photoURL, forKey: "current_distance")
        }
    }
    
    @Published var preferWeekDays: Array<String>? {
        didSet {
            UserDefaults.standard.set(photoURL, forKey: "prefer_week_days")
        }
    }
    
    @Published var preferWeekDaysLongRun: Array<String>? {
        didSet {
            UserDefaults.standard.set(photoURL, forKey: "prefer_week_days_longrun")
        }
    }
    
    @Published var weekOfTraining: Int? {
        didSet {
            UserDefaults.standard.set(name, forKey: "week_of_training")
        }
    }
    
    @Published var photoURL: String? {
        didSet {
            UserDefaults.standard.set(photoURL, forKey: "user_photo_url")
        }
    }
    
    private init() {
        // Load saved values
        self.name = UserDefaults.standard.string(forKey: "user_name")
        self.photoURL = UserDefaults.standard.string(forKey: "user_photo_url")
    }
    
    func clearUserData() {
        email = ""
        name = nil
        photoURL = nil
    }
}
