import Foundation
import HealthKit

class WorkoutService {
    static let shared = WorkoutService()
    
    private init() {}
    
    // Helper method to determine workout type string
    private func getWorkoutTypeString(_ activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .running, .trackAndField:
            return "run"
        case .walking:
            return "walk"
        case .cycling, .handCycling:
            return "cycling"
        case .swimming, .swimBikeRun:
            return "swim"
        case .highIntensityIntervalTraining:
            return "hiit"
        case .crossTraining:
            return "cross"
        case .mixedCardio:
            return "mixedCardio"
        case .pilates:
            return "pilates"
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return "strength"
        case .yoga, .mindAndBody:
            return "yoga"
        case .hiking:
            return "hiking"
        default:
            return "other"
        }
    }
    
    // 統一組 workoutId 的方法
    func makeWorkoutId(for workout: HKWorkout) -> String {
        let type = getWorkoutTypeString(workout.workoutActivityType)
        let startTs = Int(workout.startDate.timeIntervalSince1970)
        let distM = Int(workout.totalDistance?.doubleValue(for: .meter()) ?? 0)
        return "\(type)_\(startTs)_\(distM)"
    }
    
    func postWorkoutDetails(
        workout: HKWorkout,
        heartRates: [DataPoint],
        speeds: [DataPoint],
        strideLengths: [DataPoint]? = nil,
        cadences: [DataPoint]? = nil,
        groundContactTimes: [DataPoint]? = nil,
        verticalOscillations: [DataPoint]? = nil
    ) async throws {
        // 確保有心率數據
        if heartRates.isEmpty || heartRates.count < 1 {
            Logger.warn("警告: 運動記錄心率數據不足 (\(heartRates.count) 筆)，不上傳")
            throw WorkoutUploadError.missingHeartRateData
        }
        
        Logger.debug("上傳運動記錄 - Workout End Date: \(workout.endDate)")
        Logger.debug("上傳運動記錄 - Heart Rate Data Points: \(heartRates.count)")
        
        // Debug: log original activityType and mapped type
        let workoutType = getWorkoutTypeString(workout.workoutActivityType)
        Logger.debug("原始 activityType：\(workout.workoutActivityType) rawValue: \(workout.workoutActivityType.rawValue) -> mapped to type: \(workoutType)")
        
        // 創建運動數據模型
        let workoutData = WorkoutData(
            id: workout.uuid.uuidString,
            name: workout.workoutActivityType.name,
            type: workoutType,
            startDate: workout.startDate.timeIntervalSince1970,
            endDate: workout.endDate.timeIntervalSince1970,
            duration: workout.duration,
            distance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
            heartRates: heartRates.map { HeartRateData(time: $0.time.timeIntervalSince1970, value: $0.value) },
            speeds: speeds.map { SpeedData(time: $0.time.timeIntervalSince1970, value: $0.value) },
            strideLengths: strideLengths?.map { StrideData(time: $0.time.timeIntervalSince1970, value: $0.value) },
            cadences: cadences?.map { CadenceData(time: $0.time.timeIntervalSince1970, value: $0.value) },
            groundContactTimes: groundContactTimes?.map { GroundContactTimeData(time: $0.time.timeIntervalSince1970, value: $0.value) },
            verticalOscillations: verticalOscillations?.map { VerticalOscillationData(time: $0.time.timeIntervalSince1970, value: $0.value) }
        )
        
        // 使用 APIClient 上傳運動數據
        try await APIClient.shared.requestNoResponse(
            path: "/workout", method: "POST",
            body: try JSONEncoder().encode(workoutData))
        Logger.info("成功上傳運動數據")
        
        // 上傳成功後，嘗試同步拉取並快取動態跑力
        do {
            // 使用統一方法產生 workoutId
            let summaryId = makeWorkoutId(for: workout)
            let summary = try await getWorkoutSummary(workoutId: summaryId)
            saveCachedWorkoutSummary(summary, for: summaryId)
            Logger.info("已快取 WorkoutSummary for \(summaryId)")
        } catch {
            Logger.warn("快取 WorkoutSummary 失敗: \(error)")
        }
    }
    
    // 新增 Workout Summary API 方法
    func getWorkoutSummary(workoutId: String) async throws -> WorkoutSummary {
        let path = "/workout/summary/\(workoutId)"
        let response: WorkoutSummaryResponse = try await APIClient.shared.request(WorkoutSummaryResponse.self,
            path: path, method: "GET")
        return response.data.workout
    }
    
    // MARK: - 快取 WorkoutSummary 方法
    func saveCachedWorkoutSummary(_ summary: WorkoutSummary, for id: String) {
        var dict = UserDefaults.standard.dictionary(forKey: "WorkoutSummaryCache") as? [String: Data] ?? [:]
        if let data = try? JSONEncoder().encode(summary) {
            dict[id] = data
            UserDefaults.standard.set(dict, forKey: "WorkoutSummaryCache")
        }
    }
    
    func getCachedWorkoutSummary(for id: String) -> WorkoutSummary? {
        guard let dict = UserDefaults.standard.dictionary(forKey: "WorkoutSummaryCache") as? [String: Data],
              let data = dict[id],
              let summary = try? JSONDecoder().decode(WorkoutSummary.self, from: data)
        else { return nil }
        return summary
    }

    // MARK: - Clear WorkoutSummaryCache
    /// 清除儲存在 UserDefaults 的 WorkoutSummaryCache
    func clearWorkoutSummaryCache() {
        UserDefaults.standard.removeObject(forKey: "WorkoutSummaryCache")
    }

    // WorkoutService.swift 中添加的方法

    // 添加到 WorkoutService 類中
    func markWorkoutAsUploaded(_ workout: HKWorkout, hasHeartRate: Bool = true) {
        WorkoutUploadTracker.shared.markWorkoutAsUploaded(workout, hasHeartRate: hasHeartRate)
    }

    // 檢查特定運動記錄是否已上傳
    func isWorkoutUploaded(_ workout: HKWorkout) -> Bool {
        return WorkoutUploadTracker.shared.isWorkoutUploaded(workout)
    }

    // 檢查特定運動記錄是否包含心率數據
    func workoutHasHeartRate(_ workout: HKWorkout) -> Bool {
        return WorkoutUploadTracker.shared.workoutHasHeartRate(workout)
    }

    // 獲取運動記錄的上傳時間
    func getWorkoutUploadTime(_ workout: HKWorkout) -> Date? {
        return WorkoutUploadTracker.shared.getWorkoutUploadTime(workout)
    }
}

// Data models for API
struct WorkoutData: Codable {
    let id: String
    let name: String
    let type: String
    let startDate: TimeInterval
    let endDate: TimeInterval
    let duration: TimeInterval
    let distance: Double
    let heartRates: [HeartRateData]
    let speeds: [SpeedData]                  // 改為速度
    let strideLengths: [StrideData]?         // 步幅
    let cadences: [CadenceData]?             // 步頻
    let groundContactTimes: [GroundContactTimeData]? // 觸地時間
    let verticalOscillations: [VerticalOscillationData]? // 垂直振幅
}

struct HeartRateData: Codable {
    let time: TimeInterval
    let value: Double
}

struct SpeedData: Codable {
    let time: TimeInterval
    let value: Double  // 單位：m/s
}

struct StrideData: Codable {
    let time: TimeInterval
    let value: Double  // 單位：m
}

struct CadenceData: Codable {
    let time: TimeInterval
    let value: Double  // 單位：steps/min
}

struct GroundContactTimeData: Codable {
    let time: TimeInterval
    let value: Double  // 單位：ms
}

struct VerticalOscillationData: Codable {
    let time: TimeInterval
    let value: Double  // 單位：m
}

struct EmptyResponse: Codable {}

// Extension to get a name for the workout type
extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running, .trackAndField:
            return "跑步"
        case .cycling, .handCycling:
            return "騎車"
        case .walking:
            return "步行"
        case .swimming, .swimBikeRun:
            return "游泳"
        case .highIntensityIntervalTraining:
            return "高強度間歇訓練"
        case .crossTraining:
            return "交叉訓練"
        case .mixedCardio:
            return "混合有氧"
        case .traditionalStrengthTraining:
            return "重量訓練"
        case .functionalStrengthTraining:
            return "功能性訓練"
        case .yoga, .mindAndBody:
            return "瑜伽"
        case .pilates:
            return "普拉提"
        case .hiking:
            return "健行"
        default:
            return "其他運動"
        }
    }
}
