import Foundation
import HealthKit

class WorkoutService {
    static let shared = WorkoutService()
    private let networkService = NetworkService.shared
    
    private init() {}
    
    // Helper method to determine workout type string
    private func getWorkoutTypeString(_ activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .running, .walking, .trackAndField:
            return "run"
        case .cycling:
            return "cycling"
        case .swimming, .swimBikeRun:
            return "swim"
        case .highIntensityIntervalTraining, .crossTraining, .functionalStrengthTraining:
            return "hiit"
        case .traditionalStrengthTraining:
            return "strength"
        case .yoga, .mindAndBody:
            return "yoga"
        default:
            return "other"
        }
    }
    
    // 上傳單個運動記錄
    func postWorkoutDetails(workout: HKWorkout, heartRates: [DataPoint], paces: [DataPoint]) async throws {
        // 確保有心率數據
        if heartRates.isEmpty || heartRates.count < 5 {
            print("警告: 運動記錄心率數據不足 (\(heartRates.count) 筆)，不上傳")
            throw WorkoutUploadError.missingHeartRateData
        }
        
        print("上傳運動記錄 - Workout Start Date:", workout.startDate)
        print("上傳運動記錄 - Workout End Date:", workout.endDate)
        print("上傳運動記錄 - Heart Rate Data Points:", heartRates.count)
        
        // 創建運動數據模型
        let workoutData = WorkoutData(
            id: workout.uuid.uuidString,
            name: workout.workoutActivityType.name,
            type: getWorkoutTypeString(workout.workoutActivityType),
            startDate: workout.startDate.timeIntervalSince1970,
            endDate: workout.endDate.timeIntervalSince1970,
            duration: workout.duration,
            distance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
            heartRates: heartRates.map { HeartRateData(time: $0.time.timeIntervalSince1970, value: $0.value) },
            paces: paces.map { PaceData(time: $0.time.timeIntervalSince1970, value: $0.value) }
        )
        
        let endpoint = try Endpoint(
            path: "/workout",
            method: .post,
            requiresAuth: true,
            body: workoutData
        )
        
        do {
            let _: EmptyResponse = try await networkService.request(endpoint)
            print("成功上傳運動數據")
        } catch {
            print("上傳運動數據失敗: \(error)")
            throw error
        }
    }
    
    // 同步多個待上傳的運動記錄
    func syncPendingWorkouts(workouts: [HKWorkout], healthKitManager: HealthKitManager) async {
        print("開始上傳未同步的運動記錄...")
        let uploadTracker = WorkoutUploadTracker.shared
        
        // 查找需要同步的運動記錄
        let pendingWorkouts = workouts.filter { workout in
            // 如果未上傳或已上傳但無心率數據且超過嘗試時間，則需要同步
            if !uploadTracker.isWorkoutUploaded(workout) {
                return true
            }
            
            if !uploadTracker.workoutHasHeartRate(workout) {
                if let uploadTime = uploadTracker.getWorkoutUploadTime(workout) {
                    let timeElapsed = Date().timeIntervalSince(uploadTime)
                    return timeElapsed >= 3600 // 1小時後重試
                }
                return true
            }
            
            return false
        }
        
        // 僅取最近的30筆需要上傳的運動記錄
        let workoutsToUpload = pendingWorkouts.prefix(30)
        
        print("發現 \(pendingWorkouts.count) 筆需同步運動記錄，將處理最新的 \(workoutsToUpload.count) 筆")
        
        for workout in workoutsToUpload {
            do {
                // 獲取心率數據
                let heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
                
                // 檢查心率數據是否充足
                if heartRateData.isEmpty || heartRateData.count < 5 {
                    print("運動記錄 \(workout.uuid) 心率數據不足 (\(heartRateData.count) 筆)，暫不上傳")
                    
                    // 標記為已嘗試但無心率資料
                    if !uploadTracker.isWorkoutUploaded(workout) {
                        uploadTracker.markWorkoutAsUploaded(workout, hasHeartRate: false)
                    }
                    continue
                }
                
                // 獲取配速數據
                let paceData = try await healthKitManager.fetchPaceData(for: workout)
                
                // 轉換為所需的 DataPoint 格式
                let heartRates = heartRateData.map { DataPoint(time: $0.0, value: $0.1) }
                let paces = paceData.map { DataPoint(time: $0.0, value: $0.1) }
                
                // 上傳運動數據
                try await postWorkoutDetails(
                    workout: workout,
                    heartRates: heartRates,
                    paces: paces
                )
                
                // 標記為已上傳且有心率數據
                uploadTracker.markWorkoutAsUploaded(workout, hasHeartRate: true)
                print("成功上傳運動記錄: \(workout.workoutActivityType.name), 日期: \(workout.startDate), 心率數據: \(heartRates.count) 筆")
                
            } catch WorkoutUploadError.missingHeartRateData {
                print("運動記錄 \(workout.uuid) 缺少心率數據，標記為待稍後處理")
                if !uploadTracker.isWorkoutUploaded(workout) {
                    uploadTracker.markWorkoutAsUploaded(workout, hasHeartRate: false)
                }
            } catch {
                print("上傳運動記錄失敗: \(workout.startDate), 錯誤: \(error)")
                // 如果是首次嘗試，標記為已嘗試但失敗
                if !uploadTracker.isWorkoutUploaded(workout) {
                    uploadTracker.markWorkoutAsUploaded(workout, hasHeartRate: false)
                }
            }
            
            // 在上傳之間添加小延遲以避免過度使用服務器
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        }
        
        print("運動記錄同步完成，共處理 \(workoutsToUpload.count) 筆資料")
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

// 運動上傳相關錯誤
enum WorkoutUploadError: Error {
    case missingHeartRateData
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
    let paces: [PaceData]
}

struct HeartRateData: Codable {
    let time: TimeInterval
    let value: Double
}

struct PaceData: Codable {
    let time: TimeInterval
    let value: Double
}

struct EmptyResponse: Codable {}

// Extension to get a name for the workout type
extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running:
            return "跑步"
        case .cycling:
            return "騎車"
        case .walking:
            return "步行"
        case .swimming:
            return "游泳"
        case .highIntensityIntervalTraining:
            return "高強度間歇訓練"
        case .traditionalStrengthTraining:
            return "重量訓練"
        case .functionalStrengthTraining:
            return "功能性訓練"
        case .crossTraining:
            return "交叉訓練"
        case .mixedCardio:
            return "混合有氧"
        case .yoga:
            return "瑜伽"
        case .pilates:
            return "普拉提"
        default:
            return "其他運動"
        }
    }
}
