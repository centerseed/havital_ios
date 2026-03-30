import Foundation
import Combine

private typealias DomainHeartRateZone = HeartRateZone

/// 心率區間管理器 - 基於心率儲備(HRR)方法計算訓練區間
///
/// ⚠️ DEPRECATED: 此類需要重構為 UseCase 模式
/// 遷移計劃:
/// 1. 創建 CalculateHeartRateZonesUseCase (純計算邏輯)
/// 2. 使用 UserProfileRepository 替代 UserPreferencesManager.shared
/// 3. 移除 Singleton 模式，改用依賴注入
@available(*, deprecated, message: "Needs refactoring to UseCase pattern with UserProfileRepository")
class HeartRateZonesManager {
    static let shared = HeartRateZonesManager()
    
    private let userPreferenceManager = UserPreferencesManager.shared
    
    /// 心率區間結構 (與 HealthKitManager.HeartRateZone 相容的結構)
    struct HeartRateZone {
        let zone: Int
        let name: String
        let range: ClosedRange<Double>
        let description: String
        var benefit: String = ""
    }
    
    private init() {}
    
    /// 計算心率區間並儲存到 UserPreferencesManager
    func calculateAndSaveHeartRateZones(maxHR: Int, restingHR: Int) {
        let zones = calculateHeartRateZones(maxHR: maxHR, restingHR: restingHR)
        saveHeartRateZones(zones: zones)
    }
    
    /// 計算心率區間 (委派給 HeartRateZone.calculateZones，確保與新 6 區間系統一致)
    func calculateHeartRateZones(maxHR: Int, restingHR: Int) -> [HeartRateZone] {
        let domainZones = DomainHeartRateZone.calculateZones(maxHR: maxHR, restingHR: restingHR)
        return domainZones.map { zone in
            HeartRateZone(
                zone: zone.zone,
                name: zone.name,
                range: zone.range,
                description: zone.description,
                benefit: zone.benefit
            )
        }
    }
    
    /// 將計算的心率區間儲存到 UserPreferences
    private func saveHeartRateZones(zones: [HeartRateZone]) {
        // 將心率區間轉換為可儲存格式
        let zonesData = zones.map { zone -> [String: Any] in
            return [
                "zone": zone.zone,
                "name": zone.name,
                "lowBound": zone.range.lowerBound,
                "upperBound": zone.range.upperBound,
                "description": zone.description,
                "benefit": zone.benefit
            ]
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: zonesData)

            // 確保在主線程更新 @Published 屬性
            Task { @MainActor in
                userPreferenceManager.heartRateZones = jsonData
                print("已成功儲存心率區間")
            }
        } catch {
            print("儲存心率區間時發生錯誤: \(error)")
        }
    }
    
    /// 從 UserPreferences 取得心率區間
    func getHeartRateZones() -> [HeartRateZone] {
        guard let data = userPreferenceManager.heartRateZones,
              let zonesArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            print("無法讀取心率區間，將嘗試重新計算")
            return tryCalculateFromUserProfile()
        }
        
        return zonesArray.compactMap { zoneDict -> HeartRateZone? in
            guard let zone = zoneDict["zone"] as? Int,
                  let name = zoneDict["name"] as? String,
                  let lowBound = zoneDict["lowBound"] as? Double,
                  let upperBound = zoneDict["upperBound"] as? Double,
                  let description = zoneDict["description"] as? String else {
                return nil
            }
            
            let benefit = zoneDict["benefit"] as? String ?? ""
            
            return HeartRateZone(
                zone: zone,
                name: name,
                range: lowBound...upperBound,
                description: description,
                benefit: benefit
            )
        }
    }
    
    /// 當沒有儲存的心率區間時，嘗試從用戶資料計算
    private func tryCalculateFromUserProfile() -> [HeartRateZone] {
        guard let maxHR = userPreferenceManager.maxHeartRate,
              let restingHR = userPreferenceManager.restingHeartRate else {
            print("無法從 UserPreferences 取得心率資料，將使用默認值")
            return calculateHeartRateZones(maxHR: 180, restingHR: 60)
        }
        
        let zones = calculateHeartRateZones(maxHR: maxHR, restingHR: restingHR)
        saveHeartRateZones(zones: zones)
        return zones
    }
    
    /// 取得特定心率對應的區間
    func getZoneForHeartRate(_ heartRate: Double) -> Int {
        let zones = getHeartRateZones()
        
        for zone in zones {
            if zone.range.contains(heartRate) {
                return zone.zone
            }
        }
        
        // 如果心率超過最高區間
        if heartRate > zones.last?.range.upperBound ?? 0 {
            return zones.last?.zone ?? 6
        }
        
        // 如果心率低於最低區間
        return zones.first?.zone ?? 1
    }
    
    /// 從用戶資料同步心率資訊
    func syncHeartRateZonesFromUserProfile() async {
        do {
            // 嘗試從 API 獲取用戶資料
            let userProfile = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<User, Error>) in
                var cancellable: AnyCancellable?
                cancellable = UserService.shared.getUserProfile().sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        if let cancellable = cancellable {
                            cancellable.cancel()
                        }
                    },
                    receiveValue: { user in
                        continuation.resume(returning: user)
                        if let cancellable = cancellable {
                            cancellable.cancel()
                        }
                    }
                )
            }
            
            if userProfile.maxHr ?? 0 > 0 && userProfile.relaxingHr ?? 0 > 0 {
                let maxHR = userProfile.maxHr
                let restingHR = userProfile.relaxingHr

                print("從用戶資料同步心率區間 - 最大心率: \(maxHR), 靜息心率: \(restingHR)")

                // 確保在主線程更新 @Published 屬性
                await MainActor.run {
                    // 保存到 UserPreferencesManager
                    userPreferenceManager.maxHeartRate = maxHR
                    userPreferenceManager.restingHeartRate = restingHR
                }

                // 計算並保存心率區間
                calculateAndSaveHeartRateZones(maxHR: maxHR ?? 0, restingHR: restingHR ?? 0)
            }  else {
                print("用戶資料中缺少有效的心率資訊")
            }
        } catch {
            print("從服務器同步用戶心率資訊失敗: \(error)")
        }
    }
}
