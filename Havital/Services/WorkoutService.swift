import Foundation
import HealthKit

class WorkoutService {
    static let shared = WorkoutService()
    private let networkService = NetworkService.shared
    
    private init() {}
    
    // Original method for posting a single workout
    func postWorkoutDetails(workout: HKWorkout, heartRates: [DataPoint], paces: [DataPoint]) async throws {
        // Create workout data model
        print("Workout Start Date:", workout.startDate)
        print("Workout End Date:", workout.endDate)
        let workoutData = WorkoutData(
            id: workout.uuid.uuidString,
            name: workout.workoutActivityType.name,
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
    
    // New method for syncing multiple workouts
    func syncPendingWorkouts(workouts: [HKWorkout], healthKitManager: HealthKitManager) async {
        print("開始上傳未同步的運動記錄...")
        let uploadTracker = WorkoutUploadTracker.shared
        
        // 查找尚未上傳的運動記錄
        let pendingWorkouts = workouts.filter {
            !uploadTracker.isWorkoutUploaded($0)
        }
        
        // 僅取最近的30筆需要上傳的運動記錄
        let workoutsToUpload = pendingWorkouts.prefix(30)
        
        print("發現 \(pendingWorkouts.count) 筆未同步運動記錄，將上傳最新的 \(workoutsToUpload.count) 筆")
        
        for workout in workoutsToUpload {
            do {
                // 獲取心率和配速數據
                let heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
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
                
                // 標記為已上傳
                uploadTracker.markWorkoutAsUploaded(workout)
                print("成功上傳運動記錄: \(workout.workoutActivityType.name), 日期: \(workout.startDate)")
                
            } catch {
                print("上傳運動記錄失敗: \(workout.startDate), 錯誤: \(error)")
            }
            
            // 在上傳之間添加小延遲以避免過度使用服務器
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        }
        
        print("運動記錄上傳完成，共上傳 \(workoutsToUpload.count) 筆資料")
    }
    
    // Helper methods for checking upload status
    func isWorkoutUploaded(_ workout: HKWorkout) -> Bool {
        return WorkoutUploadTracker.shared.isWorkoutUploaded(workout)
    }

    func getWorkoutUploadTime(_ workout: HKWorkout) -> Date? {
        return WorkoutUploadTracker.shared.getWorkoutUploadTime(workout)
    }
}

// Data models for API
struct WorkoutData: Codable {
    let id: String
    let name: String
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
