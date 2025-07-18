import Foundation

class VDOTStorage {
    static let shared = VDOTStorage()
    private let defaults = UserDefaults.standard
    private let vdotPointsKey = "vdot_points"
    private let vdotNeedUpdateHRRangeKey = "vdot_need_update_hr_range"
    private let vdotLastFetchTimeKey = "vdot_last_fetch_time"

    private init() {}

    func saveVDOTData(points: [VDOTDataPoint], needUpdatedHrRange: Bool) {
        do {
            // 保存資料點
            let encodablePoints = points.map {
                EncodableVDOTDataPoint(
                    date: $0.date.timeIntervalSince1970,
                    value: $0.value,
                    weightVdot: $0.weightVdot
                )
            }
            let encodedData = try JSONEncoder().encode(encodablePoints)
            defaults.set(encodedData, forKey: vdotPointsKey)

            // 保存HR Range更新狀態
            defaults.set(needUpdatedHrRange, forKey: vdotNeedUpdateHRRangeKey)

            // 保存本次獲取數據的時間
            defaults.set(Date().timeIntervalSince1970, forKey: vdotLastFetchTimeKey)

            print("VDOT資料已保存到本地端")
        } catch {
            print("保存VDOT資料時出錯: \(error)")
        }
    }

    func loadVDOTData() -> ([VDOTDataPoint], Bool) {
        // 讀取資料點
        guard let data = defaults.data(forKey: vdotPointsKey) else {
            return ([], defaults.bool(forKey: vdotNeedUpdateHRRangeKey))
        }

        do {
            let decodedPoints = try JSONDecoder().decode([EncodableVDOTDataPoint].self, from: data)
            let vdotPoints = decodedPoints.map {
                VDOTDataPoint(
                    date: Date(timeIntervalSince1970: $0.date),
                    value: $0.value,
                    weightVdot: $0.weightVdot
                )
            }

            // 讀取HR Range更新狀態
            let needUpdateHrRange = defaults.bool(forKey: vdotNeedUpdateHRRangeKey)

            print("成功從本地端載入\(vdotPoints.count)筆VDOT資料")
            return (vdotPoints, needUpdateHrRange)
        } catch {
            print("讀取VDOT資料時出錯: \(error)")
            return ([], defaults.bool(forKey: vdotNeedUpdateHRRangeKey))
        }
    }

    func getLastFetchTime() -> Date? {
        let timestamp = defaults.double(forKey: vdotLastFetchTimeKey)
        if timestamp > 0 {
            return Date(timeIntervalSince1970: timestamp)
        }
        return nil
    }

    func shouldRefreshData(cacheTimeInSeconds: Double = 1800) -> Bool {
        guard let lastFetchTime = getLastFetchTime() else {
            // 如果沒有上次獲取時間，應該刷新
            return true
        }

        let currentTime = Date()
        let timeSinceLastFetch = currentTime.timeIntervalSince(lastFetchTime)

        // 如果距離上次獲取時間超過指定秒數，應該刷新
        return timeSinceLastFetch > cacheTimeInSeconds
    }

    func clearVDOTData() {
        defaults.removeObject(forKey: vdotPointsKey)
        defaults.removeObject(forKey: vdotNeedUpdateHRRangeKey)
        defaults.removeObject(forKey: vdotLastFetchTimeKey)
    }
}

// 用於編碼/解碼的輔助結構
private struct EncodableVDOTDataPoint: Codable {
    let date: TimeInterval
    let value: Double
    let weightVdot: Double?
}
