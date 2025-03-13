import Foundation
import HealthKit

class WorkoutBackgroundUploader {
    static let shared = WorkoutBackgroundUploader()
    
    private let healthKitManager: HealthKitManager
    private let workoutUploadTracker: WorkoutUploadTracker
    private let workoutService: WorkoutService
    
    private init() {
        self.healthKitManager = HealthKitManager()
        self.workoutUploadTracker = WorkoutUploadTracker.shared
        self.workoutService = WorkoutService.shared
    }
    
    /// Uploads all workouts that haven't been uploaded yet
    func uploadPendingWorkouts(workouts: [HKWorkout]) async {
        print("開始上傳未同步的運動記錄...")
        
        for workout in workouts {
            let workoutId = workout.uuid.uuidString
            
            // Skip if already uploaded
            if workoutUploadTracker.isWorkoutUploaded(workout) {
                continue
            }
            
            do {
                // Fetch heart rate and pace data for the workout
                let heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
                let paceData = try await healthKitManager.fetchPaceData(for: workout)
                
                // Convert to the required DataPoint format
                let heartRates = heartRateData.map { DataPoint(time: $0.0, value: $0.1) }
                let paces = paceData.map { DataPoint(time: $0.0, value: $0.1) }
                
                // Upload the workout data
                try await workoutService.postWorkoutDetails(
                    workout: workout,
                    heartRates: heartRates,
                    paces: paces
                )
                
                // Mark as uploaded
                workoutUploadTracker.markWorkoutAsUploaded(workout)
                print("成功上傳運動記錄: \(workout.workoutActivityType.name), 日期: \(workout.startDate)")
                
            } catch {
                print("上傳運動記錄失敗: \(workoutId), 錯誤: \(error)")
            }
            
            // Add a small delay between uploads to avoid overwhelming the server
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        print("運動記錄上傳完成")
    }
}
