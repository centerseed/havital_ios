import SwiftUI
import HealthKit

struct DataPoint: Identifiable {
    let id = UUID()
    let time: Date
    let value: Double
}

@MainActor
class WorkoutDetailViewModel: ObservableObject {
    @Published var heartRates: [DataPoint] = []
    @Published var paces: [DataPoint] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var zoneDistribution: [Int: TimeInterval] = [:]
    @Published var heartRateZones: [HealthKitManager.HeartRateZone] = []
    
    @Published var isUploaded: Bool = false
    @Published var uploadTime: Date? = nil
    
    private let workout: HKWorkout
    private let healthKitManager: HealthKitManager
    private var loadTask: Task<Void, Never>?
    
    var workoutId: UUID {
        workout.uuid
    }
    
    init(workout: HKWorkout, healthKitManager: HealthKitManager, initialHeartRateData: [(Date, Double)], initialPaceData: [(Date, Double)]) {
        self.workout = workout
        self.healthKitManager = healthKitManager
        
        // 使用初始數據
        // hear rate
        if !initialHeartRateData.isEmpty {
            self.heartRates = initialHeartRateData.map { timeAndValue in
                DataPoint(time: timeAndValue.0, value: timeAndValue.1)
            }
            // pace
            self.paces = initialPaceData.map { timeAndValue in
                DataPoint(time: timeAndValue.0, value: timeAndValue.1)
            }
        } else {
            // 如果沒有初始數據，則自動加載
            loadHeartRateData()
            loadPacesData()
        }
        // delay 2 sences for UI update
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            await postWorkoutData()
        }
    }
    
    deinit {
        loadTask?.cancel()
    }
    
    var workoutType: String {
        WorkoutUtils.workoutTypeString(for: workout.workoutActivityType)
    }
    
    var duration: String {
        WorkoutUtils.formatDuration(workout.duration)
    }
    
    var calories: String? {
        guard let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) else { return nil }
        return String(format: "%.0f kcal", calories)
    }
    
    var distance: String? {
        guard let distance = workout.totalDistance?.doubleValue(for: .meter()) else { return nil }
        if distance >= 1000 {
            return String(format: "%.2f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }
    
    var pace: String? {
        let distance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        let duration = workout.duration
        
        let paceSecondsPerMeter = duration / Double(distance)
        let paceInSecondsPerKm = paceSecondsPerMeter * 1000
        let paceMinutes = Int(paceInSecondsPerKm) / 60
        let paceRemainingSeconds = Int(paceInSecondsPerKm) % 60
        return String(format: "%d:%02d min/km", paceMinutes, paceRemainingSeconds)
    }
    
    var maxHeartRate: String {
        let max = heartRates.map { $0.value }.max() ?? 0
        return String(format: "%.0f bpm", max)
    }
    
    var minHeartRate: String {
        let min = heartRates.map { $0.value }.min() ?? 0
        return String(format: "%.0f bpm", min)
    }
    
    var yAxisRange: (min: Double, max: Double) {
        let values = heartRates.map { $0.value }
        let min = values.min() ?? 0
        let max = values.max() ?? 200
        let padding = (max - min) * 0.1
        return (min - padding, max + padding)
    }

    func loadPacesData() {
        // 取消之前的任務
        loadTask?.cancel()
        
        // 創建新的任務
        loadTask = Task { @MainActor in
            isLoading = true
            error = nil
            
            do {
                let paceData = try await healthKitManager.fetchPaceData(for: workout)
                
                // 檢查任務是否被取消
                if Task.isCancelled { return }
                
                self.paces = paceData.map { timeAndValue in
                    DataPoint(time: timeAndValue.0, value: timeAndValue.1)
                }
        
                self.isLoading = false
            } catch {
                print("Error fetching pace data: \(error)")
                self.error = "獲取配速數據時出錯"
            }
        }
    }
    
    private func postWorkoutData() async {
        do {
            
            try await WorkoutService.shared.postWorkoutDetails(
                workout: workout,
                heartRates: heartRates,
                paces: paces
            )
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func loadHeartRateData() {
        // 取消之前的任務
        loadTask?.cancel()
        
        // 創建新的任務
        loadTask = Task { @MainActor in
            isLoading = true
            error = nil
            
            do {
                let heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
                
                // 檢查任務是否被取消
                if Task.isCancelled { return }
                
                // 將心率數據轉換為圖表點
                let heartRatePoints = heartRateData.map { timeAndValue in
                    DataPoint(time: timeAndValue.0, value: timeAndValue.1)
                }
                
                self.heartRates = heartRatePoints
                
                // 計算心率區間分佈
                self.zoneDistribution = await healthKitManager.calculateZoneDistribution(heartRates: heartRateData)
                self.heartRateZones = await healthKitManager.getHeartRateZones()
                
                self.isLoading = false
            } catch {
                print("Error fetching heart rate data: \(error)")
                self.error = "獲取心率數據時出錯"
                self.isLoading = false
                self.heartRates = []
                self.zoneDistribution = [:]
                self.heartRateZones = []
            }
        }
    }
    
    // 格式化時間區間
    func formatZoneDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // 計算區間百分比
    func calculateZonePercentage(_ duration: TimeInterval) -> Double {
        let totalDuration = zoneDistribution.values.reduce(0, +)
        guard totalDuration > 0 else { return 0 }
        return duration / totalDuration * 100
    }
}
