import Foundation
import Combine

/// 橋接 HeartRateZonesManager 和 HealthKitManager 的心率區間功能
class HeartRateZonesBridge {
    static let shared = HeartRateZonesBridge()
    
    private let zonesManager = HeartRateZonesManager.shared
    private let userPreferenceManager = UserPreferenceManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    /// 同步用戶心率數據並計算心率區間
    func syncHeartRateZones() async {
        // 檢查是否已有有效的心率數據
        if userPreferenceManager.hasHeartRateData() {
            print("已有有效的心率數據，計算心率區間")
            zonesManager.calculateAndSaveHeartRateZones(
                maxHR: userPreferenceManager.maxHeartRate!,
                restingHR: userPreferenceManager.restingHeartRate!
            )
            return
        }
        
        print("嘗試從用戶資料同步心率數據")
        do {
            // 修正第二個錯誤：使用正確的方式處理異步操作
            let userProfile = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<User, Error>) in
                UserService.shared.getUserProfile()
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { user in
                            continuation.resume(returning: user)
                        }
                    )
                    .store(in: &cancellables)
            }
            
            // 獲取心率數據
            if userProfile.data.maxHr > 0 {
                userPreferenceManager.maxHeartRate = userProfile.data.maxHr
                print("從用戶資料獲取最大心率: \(userProfile.data.maxHr)")
            }
            
            if userProfile.data.relaxingHr > 0 {
                userPreferenceManager.restingHeartRate = userProfile.data.relaxingHr
                print("從用戶資料獲取靜息心率: \(userProfile.data.relaxingHr)")
            }
            
            // 如果現在有有效的心率數據，計算心率區間
            if userPreferenceManager.hasHeartRateData() {
                print("已同步心率數據，計算心率區間")
                zonesManager.calculateAndSaveHeartRateZones(
                    maxHR: userPreferenceManager.maxHeartRate!,
                    restingHR: userPreferenceManager.restingHeartRate!
                )
            } else {
                print("用戶資料中沒有有效的心率數據，使用默認值")
                userPreferenceManager.maxHeartRate = 180 // 設置默認值
                userPreferenceManager.restingHeartRate = 60 // 設置默認值
                zonesManager.calculateAndSaveHeartRateZones(maxHR: 180, restingHR: 60)
            }
        } catch {
            print("同步心率數據時發生錯誤: \(error)")
            // 使用默認值
            userPreferenceManager.maxHeartRate = 180
            userPreferenceManager.restingHeartRate = 60
            zonesManager.calculateAndSaveHeartRateZones(maxHR: 180, restingHR: 60)
        }
    }
    
    /// 將 HeartRateZonesManager.HeartRateZone 轉換為 HealthKitManager.HeartRateZone
    func convertToHealthKitManagerZones(_ zones: [HeartRateZonesManager.HeartRateZone]) -> [HealthKitManager.HeartRateZone] {
        zones.map { zone in
            HealthKitManager.HeartRateZone(
                id: zone.zone,
                zone: zone.zone,
                range: zone.range,
                description: zone.description,
                benefit: zone.benefit
            )
        }
    }
    
    /// 確保心率區間已計算並存儲
    func ensureHeartRateZonesAvailable() async {
        if let _ = userPreferenceManager.heartRateZones {
            // 已有心率區間數據
            return
        }
        
        // 需要計算並儲存心率區間
        await syncHeartRateZones()
    }
}
