import Foundation
import HealthKit
import CoreLocation
import Combine

/// watchOS 訓練管理器
@MainActor
class WorkoutManager: NSObject, ObservableObject {
    // MARK: - Published 狀態

    @Published var isActive: Bool = false
    @Published var isPaused: Bool = false

    // 實時數據
    @Published var distance: Double = 0          // 米
    @Published var duration: TimeInterval = 0    // 秒
    @Published var currentPace: TimeInterval = 0 // 秒/公里
    @Published var currentSpeed: Double = 0      // 米/秒
    @Published var currentHR: Int = 0            // bpm
    @Published var activeCalories: Double = 0    // kcal

    // GPS 數據
    @Published var locations: [CLLocation] = []

    // 分段追蹤器（間歇/組合訓練）
    @Published var segmentTracker: SegmentTracker?

    // MARK: - 私有屬性

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private let locationManager = CLLocationManager()

    private var startDate: Date?
    private var trainingDay: WatchTrainingDay
    private var workoutMode: TrainingTypeHelper.WorkoutMode

    // 心率和速度數據採樣
    private var heartRateSamples: [(timestamp: TimeInterval, bpm: Int)] = []
    private var speedSamples: [(timestamp: TimeInterval, speed: Double)] = []

    // MARK: - 初始化

    init(trainingDay: WatchTrainingDay) {
        self.trainingDay = trainingDay
        self.workoutMode = TrainingTypeHelper.getWorkoutMode(trainingDay.trainingType)

        super.init()

        // 設置位置管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness

        // 如果是分段訓練，創建 SegmentTracker
        if let details = trainingDay.trainingDetails,
           workoutMode == .interval || workoutMode == .combination {
            segmentTracker = SegmentTracker(
                trainingDetails: details,
                workoutMode: workoutMode
            )
        }
    }

    // MARK: - 公開 API

    /// 開始訓練
    func startWorkout() async {
        // 請求 HealthKit 權限
        await requestHealthKitPermissions()

        // 創建訓練配置
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()

            session?.delegate = self
            builder?.delegate = self

            // 設置數據源
            builder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            // 開始會話
            let start Date = Date()
            session?.startActivity(with: startDate)
            await builder?.beginCollection(withStart: startDate) { success, error in
                if let error = error {
                    print("❌ WorkoutManager: 開始採集失敗 - \(error.localizedDescription)")
                }
            }

            // 開始 GPS
            locationManager.startUpdatingLocation()

            self.startDate = startDate
            isActive = true

            print("✅ WorkoutManager: 訓練已開始")
        } catch {
            print("❌ WorkoutManager: 啟動失敗 - \(error.localizedDescription)")
        }
    }

    /// 暫停訓練
    func pauseWorkout() {
        session?.pause()
        locationManager.stopUpdatingLocation()
        isPaused = true
        print("⏸️ WorkoutManager: 訓練已暫停")
    }

    /// 繼續訓練
    func resumeWorkout() {
        session?.resume()
        locationManager.startUpdatingLocation()
        isPaused = false
        print("▶️ WorkoutManager: 訓練已繼續")
    }

    /// 結束訓練
    func endWorkout() async {
        session?.end()
        locationManager.stopUpdatingLocation()

        // 保存訓練
        await saveWorkout()

        isActive = false
        print("🏁 WorkoutManager: 訓練已結束")
    }

    // MARK: - 私有方法

    private func requestHealthKitPermissions() async {
        let typesToRead: Set = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .runningSpeed)!
        ]

        let typesToWrite: Set = [
            HKObjectType.workoutType()
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            print("✅ WorkoutManager: HealthKit 權限已授予")
        } catch {
            print("❌ WorkoutManager: HealthKit 權限失敗 - \(error.localizedDescription)")
        }
    }

    private func updateMetrics(_ statistics: HKStatistics) {
        switch statistics.quantityType {
        case HKQuantityType.quantityType(forIdentifier: .heartRate):
            if let heartRate = statistics.mostRecentQuantity() {
                let bpm = Int(heartRate.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
                currentHR = bpm

                // 記錄心率樣本
                if let start = startDate {
                    let timestamp = Date().timeIntervalSince(start)
                    heartRateSamples.append((timestamp: timestamp, bpm: bpm))
                }
            }

        case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
            if let distance = statistics.sumQuantity() {
                self.distance = distance.doubleValue(for: .meter())
            }

        case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
            if let energy = statistics.sumQuantity() {
                activeCalories = energy.doubleValue(for: .kilocalorie())
            }

        case HKQuantityType.quantityType(forIdentifier: .runningSpeed):
            if let speed = statistics.mostRecentQuantity() {
                currentSpeed = speed.doubleValue(for: HKUnit.meter().unitDivided(by: .second()))

                // 計算配速（秒/公里）
                if currentSpeed > 0 {
                    currentPace = 1000.0 / currentSpeed  // 秒/公里
                }

                // 記錄速度樣本
                if let start = startDate {
                    let timestamp = Date().timeIntervalSince(start)
                    speedSamples.append((timestamp: timestamp, speed: currentSpeed))
                }

                // 更新分段追蹤器
                segmentTracker?.updateProgress(currentDistance: distance, currentSpeed: currentSpeed)
            }

        default:
            break
        }
    }

    private func saveWorkout() async {
        guard let builder = builder, let startDate = startDate else { return }

        do {
            let workout = try await builder.endCollection(withEnd: Date())

            // TODO: 將數據上傳到後端（透過 iPhone）
            print("✅ WorkoutManager: 訓練已保存到 HealthKit")
            print("   - 距離: \(distance)m")
            print("   - 時長: \(duration)s")
            print("   - 心率樣本數: \(heartRateSamples.count)")
            print("   - GPS 點數: \(locations.count)")
        } catch {
            print("❌ WorkoutManager: 保存失敗 - \(error.localizedDescription)")
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                   didChangeTo toState: HKWorkoutSessionState,
                                   from fromState: HKWorkoutSessionState,
                                   date: Date) {
        Task { @MainActor in
            switch toState {
            case .running:
                print("▶️ WorkoutSession: Running")
            case .paused:
                print("⏸️ WorkoutSession: Paused")
            case .ended:
                print("🏁 WorkoutSession: Ended")
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("❌ WorkoutSession: 錯誤 - \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType else { continue }

                if let statistics = workoutBuilder.statistics(for: quantityType) {
                    updateMetrics(statistics)
                }
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // 處理訓練事件
    }
}

// MARK: - CLLocationManagerDelegate

extension WorkoutManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.locations.append(contentsOf: locations)

            // 計算總距離（使用 GPS）
            if self.locations.count >= 2 {
                var totalDistance: Double = 0
                for i in 1..<self.locations.count {
                    totalDistance += self.locations[i].distance(from: self.locations[i - 1])
                }
                // self.distance = totalDistance  // 可選：使用 GPS 距離而非 HealthKit
            }

            // 更新時長
            if let start = startDate {
                duration = Date().timeIntervalSince(start)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ LocationManager: GPS 錯誤 - \(error.localizedDescription)")
    }
}
