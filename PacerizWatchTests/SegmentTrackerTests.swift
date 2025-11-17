import XCTest
@testable import PacerizWatch

/// SegmentTracker 單元測試
class SegmentTrackerTests: XCTestCase {

    // MARK: - 間歇訓練測試

    func testIntervalWorkout_InitialState() {
        // 創建間歇訓練詳情（6×1000m）
        let details = createIntervalTrainingDetails(repeats: 6, workDistance: 1000)
        let tracker = SegmentTracker(trainingDetails: details, workoutMode: .interval)

        // 驗證初始狀態
        XCTAssertEqual(tracker.currentLap, 1)
        XCTAssertEqual(tracker.currentPhase, .work)
        XCTAssertFalse(tracker.isCompleted())
    }

    func testIntervalWorkout_SegmentDistance() {
        let details = createIntervalTrainingDetails(repeats: 6, workDistance: 1000)
        let tracker = SegmentTracker(trainingDetails: details, workoutMode: .interval)

        // 工作段距離應該是 1000m
        XCTAssertEqual(tracker.getCurrentSegmentDistance(), 1000)
    }

    func testIntervalWorkout_TargetPace() {
        let details = createIntervalTrainingDetails(repeats: 6, workDistance: 1000, workPace: "4:00")
        let tracker = SegmentTracker(trainingDetails: details, workoutMode: .interval)

        // 工作段配速
        XCTAssertEqual(tracker.getCurrentTargetPace(), "4:00")
    }

    func testIntervalWorkout_ProgressTracking() {
        let details = createIntervalTrainingDetails(repeats: 6, workDistance: 1000)
        let tracker = SegmentTracker(trainingDetails: details, workoutMode: .interval)

        // 模擬跑了 500m
        tracker.updateProgress(currentDistance: 500, currentSpeed: 3.33) // 3.33 m/s ≈ 5:00/km

        // 剩餘距離應該是 500m
        XCTAssertEqual(tracker.remainingDistance, 500, accuracy: 1)

        // 應該還在第 1 組工作段
        XCTAssertEqual(tracker.currentLap, 1)
        XCTAssertEqual(tracker.currentPhase, .work)
    }

    func testIntervalWorkout_CompletionCheck() {
        let details = createIntervalTrainingDetails(repeats: 6, workDistance: 1000)
        let tracker = SegmentTracker(trainingDetails: details, workoutMode: .interval)

        // 未完成
        XCTAssertFalse(tracker.isCompleted())

        // 手動設置為已完成所有組數
        tracker.currentLap = 7 // 超過 6 組
        XCTAssertTrue(tracker.isCompleted())
    }

    // MARK: - 組合跑測試

    func testCombinationWorkout_InitialState() {
        let details = createCombinationTrainingDetails()
        let tracker = SegmentTracker(trainingDetails: details, workoutMode: .combination)

        // 初始應該在第一個階段
        XCTAssertEqual(tracker.currentSegmentIndex, 0)
        XCTAssertFalse(tracker.isCompleted())
    }

    func testCombinationWorkout_SegmentDistance() {
        let details = createCombinationTrainingDetails()
        let tracker = SegmentTracker(trainingDetails: details, workoutMode: .combination)

        // 第一階段距離應該是 2000m（2.0 km）
        XCTAssertEqual(tracker.getCurrentSegmentDistance(), 2000)
    }

    func testCombinationWorkout_TargetPace() {
        let details = createCombinationTrainingDetails()
        let tracker = SegmentTracker(trainingDetails: details, workoutMode: .combination)

        // 第一階段配速應該是 6:00/km（熱身）
        XCTAssertEqual(tracker.getCurrentTargetPace(), "6:00")
    }

    // MARK: - 輔助方法

    private func createIntervalTrainingDetails(
        repeats: Int,
        workDistance: Double,
        workPace: String = "4:00",
        recoveryDistance: Double = 400,
        recoveryPace: String = "6:00"
    ) -> WatchTrainingDetails {
        let work = WatchWorkoutSegment(
            description: "工作段",
            distanceKm: nil,
            distanceM: workDistance,
            timeMinutes: nil,
            pace: workPace,
            heartRateRange: nil
        )

        let recovery = WatchWorkoutSegment(
            description: "恢復段",
            distanceKm: nil,
            distanceM: recoveryDistance,
            timeMinutes: nil,
            pace: recoveryPace,
            heartRateRange: nil
        )

        return WatchTrainingDetails(
            description: "間歇訓練",
            distanceKm: nil,
            totalDistanceKm: Double(repeats) * (workDistance + recoveryDistance) / 1000,
            timeMinutes: nil,
            pace: nil,
            work: work,
            recovery: recovery,
            repeats: repeats,
            heartRateRange: nil,
            segments: nil
        )
    }

    private func createCombinationTrainingDetails() -> WatchTrainingDetails {
        let segments = [
            WatchProgressionSegment(
                distanceKm: 2.0,
                pace: "6:00",
                description: "熱身",
                heartRateRange: nil
            ),
            WatchProgressionSegment(
                distanceKm: 5.0,
                pace: "4:30",
                description: "節奏跑",
                heartRateRange: nil
            ),
            WatchProgressionSegment(
                distanceKm: 1.0,
                pace: "3:50",
                description: "衝刺",
                heartRateRange: nil
            ),
            WatchProgressionSegment(
                distanceKm: 2.0,
                pace: "6:30",
                description: "緩和",
                heartRateRange: nil
            )
        ]

        return WatchTrainingDetails(
            description: "組合跑",
            distanceKm: nil,
            totalDistanceKm: 10.0,
            timeMinutes: nil,
            pace: nil,
            work: nil,
            recovery: nil,
            repeats: nil,
            heartRateRange: nil,
            segments: segments
        )
    }
}

/// WatchDataManager 測試
class WatchDataManagerTests: XCTestCase {

    var dataManager: WatchDataManager!

    override func setUp() {
        super.setUp()
        dataManager = WatchDataManager()
    }

    override func tearDown() {
        dataManager = nil
        super.tearDown()
    }

    func testGetTrainingForDate() {
        // 創建測試課表
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: today)

        let mockDay = WatchTrainingDay(
            id: "test-1",
            dayIndex: todayString,
            dayTarget: "測試訓練",
            trainingType: "easy",
            trainingDetails: nil
        )

        let mockPlan = WatchWeeklyPlan(
            id: "test-plan",
            weekOfPlan: 1,
            totalWeeks: 12,
            totalDistance: 50,
            days: [mockDay]
        )

        dataManager.weeklyPlan = mockPlan

        // 測試獲取今天的訓練
        let training = dataManager.getTraining(for: today)
        XCTAssertNotNil(training)
        XCTAssertEqual(training?.id, "test-1")
    }

    func testGetTodayTraining() {
        // 測試 getTodayTraining 便利方法
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: today)

        let mockDay = WatchTrainingDay(
            id: "today-1",
            dayIndex: todayString,
            dayTarget: "今天的訓練",
            trainingType: "tempo",
            trainingDetails: nil
        )

        let mockPlan = WatchWeeklyPlan(
            id: "test-plan",
            weekOfPlan: 1,
            totalWeeks: 12,
            totalDistance: 50,
            days: [mockDay]
        )

        dataManager.weeklyPlan = mockPlan

        let todayTraining = dataManager.getTodayTraining()
        XCTAssertNotNil(todayTraining)
        XCTAssertEqual(todayTraining?.dayTarget, "今天的訓練")
    }
}
