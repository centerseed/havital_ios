import Foundation
import Combine

/// 心率區間管理器 - 基於心率儲備(HRR)方法計算訓練區間
class HeartRateZonesManager {
    static let shared = HeartRateZonesManager()
    
    private let userPreferenceManager = UserPreferenceManager.shared
    
    // 心率區間定義 (百分比)
    struct ZonePercentages {
        // 輕鬆跑 (Easy)
        static let easyLow: Double = 0.59
        static let easyHigh: Double = 0.74
        
        // 馬拉松配速 (Marathon)
        static let marathonLow: Double = 0.74
        static let marathonHigh: Double = 0.84
        
        // 閾值跑 (Threshold)
        static let thresholdLow: Double = 0.84
        static let thresholdHigh: Double = 0.88
        
        // 有氧跑 (Aerobic)
        static let aerobicLow: Double = 0.88
        static let aerobicHigh: Double = 0.95
        
        // 間歇跑 (Interval)
        static let intervalLow: Double = 0.95
        static let intervalHigh: Double = 1.0
    }
    
    /// 心率區間結構 (與 HealthKitManager.HeartRateZone 相容的結構)
    struct HeartRateZone {
        let zone: Int
        let name: String
        let range: ClosedRange<Double>
        let description: String
        var benefit: String = ""
    }
    
    private init() {}
    
    /// 計算心率區間並儲存到 UserPreferenceManager
    func calculateAndSaveHeartRateZones(maxHR: Int, restingHR: Int) {
        let zones = calculateHeartRateZones(maxHR: maxHR, restingHR: restingHR)
        saveHeartRateZones(zones: zones)
    }
    
    /// 計算心率區間 (基於 HRR 心率儲備法)
    func calculateHeartRateZones(maxHR: Int, restingHR: Int) -> [HeartRateZone] {
        let hrr = Double(maxHR - restingHR) // 心率儲備 (Heart Rate Reserve)
        
        // 計算各區間
        let zone1 = HeartRateZone(
            zone: 1,
            name: L10n.Performance.HeartRateZone.zone1Name.localized,
            range: calculateRange(hrr: hrr, restingHR: restingHR, lowPct: ZonePercentages.easyLow, highPct: ZonePercentages.easyHigh),
            description: L10n.Performance.HeartRateZone.zone1Description.localized,
            benefit: L10n.Performance.HeartRateZone.zone1Benefit.localized
        )
        
        let zone2 = HeartRateZone(
            zone: 2,
            name: L10n.Performance.HeartRateZone.zone2Name.localized,
            range: calculateRange(hrr: hrr, restingHR: restingHR, lowPct: ZonePercentages.marathonLow, highPct: ZonePercentages.marathonHigh),
            description: L10n.Performance.HeartRateZone.zone2Description.localized,
            benefit: L10n.Performance.HeartRateZone.zone2Benefit.localized
        )
        
        let zone3 = HeartRateZone(
            zone: 3,
            name: L10n.Performance.HeartRateZone.zone3Name.localized,
            range: calculateRange(hrr: hrr, restingHR: restingHR, lowPct: ZonePercentages.thresholdLow, highPct: ZonePercentages.thresholdHigh),
            description: L10n.Performance.HeartRateZone.zone3Description.localized,
            benefit: L10n.Performance.HeartRateZone.zone3Benefit.localized
        )
        
        let zone4 = HeartRateZone(
            zone: 4,
            name: L10n.Performance.HeartRateZone.zone4Name.localized,
            range: calculateRange(hrr: hrr, restingHR: restingHR, lowPct: ZonePercentages.aerobicLow, highPct: ZonePercentages.aerobicHigh),
            description: L10n.Performance.HeartRateZone.zone4Description.localized,
            benefit: L10n.Performance.HeartRateZone.zone4Benefit.localized
        )
        
        let zone5 = HeartRateZone(
            zone: 5,
            name: L10n.Performance.HeartRateZone.zone5Name.localized,
            range: calculateRange(hrr: hrr, restingHR: restingHR, lowPct: ZonePercentages.intervalLow, highPct: ZonePercentages.intervalHigh),
            description: L10n.Performance.HeartRateZone.zone5Description.localized,
            benefit: L10n.Performance.HeartRateZone.zone5Benefit.localized
        )
        
        return [zone1, zone2, zone3, zone4, zone5]
    }
    
    /// 根據心率儲備百分比計算實際心率範圍
    private func calculateRange(hrr: Double, restingHR: Int, lowPct: Double, highPct: Double) -> ClosedRange<Double> {
        let low = (hrr * lowPct) + Double(restingHR)
        let high = (hrr * highPct) + Double(restingHR)
        return low...high
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
            userPreferenceManager.heartRateZones = jsonData
            print("已成功儲存心率區間")
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
            return zones.last?.zone ?? 5
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
                
                // 保存到 UserPreferenceManager
                userPreferenceManager.maxHeartRate = maxHR
                userPreferenceManager.restingHeartRate = restingHR
                
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
