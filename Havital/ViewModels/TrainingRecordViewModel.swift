import SwiftUI
import HealthKit

class TrainingRecordViewModel: ObservableObject {
    @Published var workouts: [HKWorkout] = []
    @Published var isLoading = false
    @Published var isUploading = false
    @Published var uploadStatus: String? = nil
    
    private let workoutService = WorkoutService.shared
    
    func loadWorkouts(healthKitManager: HealthKitManager) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            try await healthKitManager.requestAuthorization()
            let now = Date()
            // 改為獲取兩個月的數據
            let monthAgo = Calendar.current.date(byAdding: .month, value: -2, to: now)!
            
            let fetchedWorkouts = try await healthKitManager.fetchWorkoutsForDateRange(start: monthAgo, end: now)
            
            // 在主線程更新 UI
            await MainActor.run {
                self.workouts = fetchedWorkouts.sorted(by: { $0.startDate > $1.startDate }) // 按日期降序排序
                self.isLoading = false
            }
            
            // 開始後台上傳
            await syncWorkouts(healthKitManager: healthKitManager)
            
        } catch {
            print("Error loading workouts: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.workouts = []
            }
        }
    }
    
    func syncWorkouts(healthKitManager: HealthKitManager) async {
        await MainActor.run {
            isUploading = true
            uploadStatus = "正在同步運動數據..."
        }
        
        // 後台上傳尚未同步的運動記錄
        await workoutService.syncPendingWorkouts(workouts: workouts, healthKitManager: healthKitManager)
        
        await MainActor.run {
            isUploading = false
            uploadStatus = "同步完成"
            
            // 短暫顯示上傳完成的訊息，然後隱藏
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                await MainActor.run {
                    self.uploadStatus = nil
                }
            }
        }
    }
    
    /// 檢查特定運動記錄是否已上傳
    func isWorkoutUploaded(_ workout: HKWorkout) -> Bool {
        return workoutService.isWorkoutUploaded(workout)
    }
    
    /// 獲取運動記錄的上傳時間
    func getWorkoutUploadTime(_ workout: HKWorkout) -> Date? {
        return workoutService.getWorkoutUploadTime(workout)
    }
}
