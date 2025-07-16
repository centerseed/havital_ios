import Foundation
import Combine

// MARK: - 數據來源類型定義
/// 定義 App 的數據來源類型
enum DataSourceType: String, CaseIterable, Identifiable {
    case unbound = "unbound"
    case appleHealth = "apple_health"
    case garmin = "garmin"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .unbound:
            return "尚未綁定"
        case .appleHealth:
            return "Apple Health"
        case .garmin:
            return "Garmin"
        }
    }
}

class UserPreferenceManager: ObservableObject {
    static let shared = UserPreferenceManager()
    
    private static let dataSourceKey = "data_source_preference"

    // MARK: - 數據來源偏好
    /// 使用者選擇的數據來源
    @Published var dataSourcePreference: DataSourceType {
        didSet {
            // 當值改變時，儲存到 UserDefaults
            UserDefaults.standard.set(dataSourcePreference.rawValue, forKey: Self.dataSourceKey)
            print("數據來源已切換為: \(dataSourcePreference.displayName)")
            
            // 數據源更改通知，讓UI層處理後端同步
            NotificationCenter.default.post(
                name: NSNotification.Name("DataSourceDidChange"), 
                object: dataSourcePreference.rawValue
            )
            
            // 在這裡可以發布通知，觸發全局數據刷新
            // NotificationCenter.default.post(name: .dataSourceDidChange, object: nil)
        }
    }
    
    // 原有屬性
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
            UserDefaults.standard.set(age, forKey: "age")
        }
    }
    
    // MARK: - 心率相關屬性
    
    /// 最大心率
    @Published var maxHeartRate: Int? {
        didSet {
            UserDefaults.standard.set(maxHeartRate, forKey: "max_heart_rate")
        }
    }
    
    /// 靜息心率
    @Published var restingHeartRate: Int? {
        didSet {
            UserDefaults.standard.set(restingHeartRate, forKey: "resting_heart_rate")
        }
    }
    
    /// 心率區間的JSON資料
    @Published var heartRateZones: Data? {
        didSet {
            UserDefaults.standard.set(heartRateZones, forKey: "heart_rate_zones")
        }
    }
    
    @Published var currentPace: String? {
        didSet {
            UserDefaults.standard.set(currentPace, forKey: "current_pace")
        }
    }
    
    @Published var currentDistance: String? {
        didSet {
            UserDefaults.standard.set(currentDistance, forKey: "current_distance")
        }
    }
    
    @Published var preferWeekDays: Array<String>? {
        didSet {
            UserDefaults.standard.set(preferWeekDays, forKey: "prefer_week_days")
        }
    }
    
    @Published var preferWeekDaysLongRun: Array<String>? {
        didSet {
            UserDefaults.standard.set(preferWeekDaysLongRun, forKey: "prefer_week_days_longrun")
        }
    }
    
    @Published var weekOfTraining: Int? {
        didSet {
            UserDefaults.standard.set(weekOfTraining, forKey: "week_of_training")
        }
    }
    
    @Published var photoURL: String? {
        didSet {
            UserDefaults.standard.set(photoURL, forKey: "user_photo_url")
        }
    }
    
    private init() {
        // 載入保存的數據來源偏好，如果未設定，則預設為尚未綁定
        if let savedSource = UserDefaults.standard.string(forKey: Self.dataSourceKey),
           let source = DataSourceType(rawValue: savedSource) {
            self.dataSourcePreference = source
        } else {
            self.dataSourcePreference = .unbound
        }
        
        // 載入保存的值
        self.name = UserDefaults.standard.string(forKey: "user_name")
        self.photoURL = UserDefaults.standard.string(forKey: "user_photo_url")
        self.maxHeartRate = UserDefaults.standard.integer(forKey: "max_heart_rate")
        self.restingHeartRate = UserDefaults.standard.integer(forKey: "resting_heart_rate")
        self.heartRateZones = UserDefaults.standard.data(forKey: "heart_rate_zones")
        
        // 確保心率值有效（如果是0表示未設定）
        if let maxHR = self.maxHeartRate, maxHR == 0 {
            self.maxHeartRate = nil
        }
        
        if let restingHR = self.restingHeartRate, restingHR == 0 {
            self.restingHeartRate = nil
        }
    }
    
    func clearUserData() {
        // 清除基本用戶資訊
        email = ""
        name = nil
        photoURL = nil
        age = nil
        maxHeartRate = nil
        currentPace = nil
        currentDistance = nil
        preferWeekDays = nil
        preferWeekDaysLongRun = nil
        weekOfTraining = nil
        
        // 清除其他相關緩存
        TrainingPlanStorage.shared.clearAll()
        WorkoutUploadTracker.shared.clearUploadedWorkouts()
        
        // 清除用戶偏好相關的 UserDefaults
        let defaults = UserDefaults.standard
        let keysToRemove = [
            "training_plan", "training_plan_overview", "weekly_plan",
            "user_email", "user_name", "age", "max_heart_rate",
            "current_pace", "current_distance", "prefer_week_days",
            "prefer_week_days_longrun", "week_of_training", "user_photo_url",
            // 登出時清除數據來源設定，確保多用戶環境下的數據隔離
            Self.dataSourceKey
        ]
        
        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }
    }
    
    /// 檢查是否有必要的心率數據
    func hasHeartRateData() -> Bool {
        return maxHeartRate != nil &&
               restingHeartRate != nil &&
               maxHeartRate! > restingHeartRate! &&
               maxHeartRate! > 0 &&
               restingHeartRate! > 0
    }
    
    /// 同步心率數據
    func syncHeartRateData(from user: User?) {
        guard let user = user else { return }
        
        // 只有當用戶數據中的值大於0時才更新
        if user.data.maxHr ?? 0 > 0 {
            self.maxHeartRate = user.data.maxHr
        }
        
        if user.data.relaxingHr ?? 0 > 0 {
            self.restingHeartRate = user.data.relaxingHr
        }
        
        // 檢查是否可以計算心率區間
        if hasHeartRateData() {
            HeartRateZonesManager.shared.calculateAndSaveHeartRateZones(
                maxHR: maxHeartRate!,
                restingHR: restingHeartRate!
            )
        }
    }
    
    /// 更新心率數據並計算區間
    func updateHeartRateData(maxHR: Int, restingHR: Int) {
        // 驗證輸入值
        guard maxHR > 0 && restingHR > 0 && maxHR > restingHR else {
            print("無效的心率數據：maxHR = \(maxHR), restingHR = \(restingHR)")
            return
        }
        
        // 更新數據
        self.maxHeartRate = maxHR
        self.restingHeartRate = restingHR
        
        // 計算並保存心率區間
        HeartRateZonesManager.shared.calculateAndSaveHeartRateZones(
            maxHR: maxHR,
            restingHR: restingHR
        )
        
        print("心率數據已更新並計算區間：maxHR = \(maxHR), restingHR = \(restingHR)")
    }
    
    /// 嘗試從API更新心率數據
    /// 嘗試從API更新心率數據
    func fetchHeartRateDataFromAPI() async {
        do {
            let user = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<User, Error>) in
                var cancellable: AnyCancellable?
                cancellable = UserService.shared.getUserProfile().sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { user in
                        continuation.resume(returning: user)
                        cancellable?.cancel()
                    }
                )
            }
            
            syncHeartRateData(from: user)
        } catch {
            print("從API獲取心率數據失敗：\(error)")
        }
    }
    
    /// 獲取心率區間
    func getHeartRateZones() -> [HeartRateZonesManager.HeartRateZone]? {
        // 如果沒有保存的區間數據，返回nil
        guard let _ = heartRateZones else { return nil }
        
        return HeartRateZonesManager.shared.getHeartRateZones()
    }
}

extension UserPreferenceManager {
    // VDOT数据模型
    struct VDOTData {
        let currentVDOT: Double?
        let targetVDOT: Double?
    }
    
    // 获取存储的VDOT数据
    func getVDOTData() -> VDOTData? {
        if let currentVDOT = UserDefaults.standard.object(forKey: "current_vdot") as? Double,
           let targetVDOT = UserDefaults.standard.object(forKey: "target_vdot") as? Double {
            return VDOTData(currentVDOT: currentVDOT, targetVDOT: targetVDOT)
        }
        return nil
    }
    
    // 保存VDOT数据
    func saveVDOTData(currentVDOT: Double, targetVDOT: Double) {
        UserDefaults.standard.set(currentVDOT, forKey: "current_vdot")
        UserDefaults.standard.set(targetVDOT, forKey: "target_vdot")
    }
}

// MARK: - Publisher 擴展，支持 async/await
extension Publisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = self.sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                },
                receiveValue: { value in
                    continuation.resume(returning: value)
                    cancellable?.cancel()
                }
            )
        }
    }
}
