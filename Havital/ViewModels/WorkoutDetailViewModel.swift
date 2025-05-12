import SwiftUI
import HealthKit

class WorkoutDetailViewModel: ObservableObject {
    @Published var heartRates: [DataPoint] = []
    @Published var paces: [DataPoint] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var zoneDistribution: [Int: TimeInterval] = [:]
    @Published var heartRateZones: [HealthKitManager.HeartRateZone] = []
    
    // 心率統計數據
    @Published var averageHeartRate: Double?
    // 訓練負荷
    @Published var trainingLoad: Double?
    
    // HRR 心率區間相關
    @Published var hrrZones: [HeartRateZonesManager.HeartRateZone] = []
    @Published var hrrZoneDistribution: [Int: TimeInterval] = [:]
    @Published var isLoadingHRRZones = false
    
    @Published var isUploaded: Bool = false
    @Published var uploadTime: Date? = nil
    
    let workout: HKWorkout
    let healthKitManager: HealthKitManager
    private var loadTask: Task<Void, Never>?
    
    var workoutId: UUID {
        workout.uuid
    }
    
    init(workout: HKWorkout, healthKitManager: HealthKitManager, initialHeartRateData: [(Date, Double)], initialPaceData: [(Date, Double)]) {
        self.workout = workout
        self.healthKitManager = healthKitManager
        
        // 使用初始數據
        if !initialHeartRateData.isEmpty {
            self.heartRates = initialHeartRateData.map { timeAndValue in
                DataPoint(time: timeAndValue.0, value: timeAndValue.1)
            }
            // pace
            self.paces = initialPaceData.map { timeAndValue in
                DataPoint(time: timeAndValue.0, value: timeAndValue.1)
            }
            
            // 檢查是否已上傳
            checkUploadStatus()
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
        guard let distance = workout.totalDistance?.doubleValue(for: .meter()), distance > 0 else { return nil }
        
        let paceSecondsPerMeter = workout.duration / distance
        let paceInSecondsPerKm = paceSecondsPerMeter * 1000
        let paceMinutes = Int(paceInSecondsPerKm) / 60
        let paceRemainingSeconds = Int(paceInSecondsPerKm) % 60
        return String(format: "%d:%02d/km", paceMinutes, paceRemainingSeconds)
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
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 200
        let padding = (maxVal - minVal) * 0.1
        return (min: minVal - padding, max: maxVal + padding)
    }

    func loadPacesData() {
        // 檢查是否已有配速數據
        if !paces.isEmpty {
            return
        }
        
        // 取消之前的任務
        loadTask?.cancel()
        
        // 創建新的任務
        loadTask = Task { @MainActor in
            isLoading = true
            
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
    
    // 檢查上傳狀態
    func checkUploadStatus() {
        isUploaded = WorkoutService.shared.isWorkoutUploaded(workout)
        uploadTime = WorkoutService.shared.getWorkoutUploadTime(workout)
    }
    
    func loadHeartRateData() {
        // 如果已經有心率數據, 但沒有心率區間分佈, 直接計算區間分佈
        if !heartRates.isEmpty && zoneDistribution.isEmpty {
            calculateHRRZoneDistribution()
            return
        }
        
        // 如果已經有心率數據和區間分佈，直接返回
        if !heartRates.isEmpty && !zoneDistribution.isEmpty {
            return
        }
        
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
                
                // 計算平均心率
                let sum = heartRatePoints.reduce(0.0) { $0 + $1.value }
                self.averageHeartRate = heartRatePoints.isEmpty ? nil : sum / Double(heartRatePoints.count)
                
                // 計算HRR心率區間分佈
                calculateHRRZoneDistribution()
                
                // 同時加載配速數據
                if self.paces.isEmpty {
                    let paceData = try await healthKitManager.fetchPaceData(for: workout)
                    self.paces = paceData.map { DataPoint(time: $0.0, value: $0.1) }
                }
                
                // 檢查上傳狀態
                checkUploadStatus()
                
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
    
    // 計算HRR區間分佈
    func calculateHRRZoneDistribution() {
        isLoadingHRRZones = true
        
        // 確保心率區間已計算
        Task {
            await HeartRateZonesBridge.shared.ensureHeartRateZonesAvailable()
        }
        
        do {
            // 獲取HRR心率區間
            self.hrrZones = HeartRateZonesManager.shared.getHeartRateZones()
            
            // 如果已經有心率數據，計算區間分佈
            if !heartRates.isEmpty {
                // 將 DataPoint 轉換為 HealthKitManager 需要的格式
                let heartRateData = heartRates.map { ($0.time, $0.value) }
                
                // 計算心率區間分佈
                Task {
                    self.hrrZoneDistribution = await healthKitManager.calculateHRRZoneDistribution(heartRates: heartRateData)
                }
            }
        } catch {
            print("計算HRR心率區間分佈時出錯: \(error)")
        }
        
        isLoadingHRRZones = false
    }
    
    // 格式化時間區間
    func formatZoneDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    // 計算區間百分比
    func calculateZonePercentage(_ duration: TimeInterval) -> Double {
        let totalDuration = zoneDistribution.values.reduce(0, +)
        guard totalDuration > 0 else { return 0 }
        return duration / totalDuration * 100
    }
    
    // 計算HRR區間百分比
    func calculateHRRZonePercentage(_ duration: TimeInterval) -> Double {
        let totalDuration = hrrZoneDistribution.values.reduce(0, +)
        guard totalDuration > 0 else { return 0 }
        return duration / totalDuration * 100
    }
}
