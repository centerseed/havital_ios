import Foundation
import WatchKit

/// 訓練分段追蹤器（間歇/組合訓練）
class SegmentTracker: ObservableObject {
    // MARK: - 狀態

    @Published var currentSegmentIndex: Int = 0
    @Published var currentLap: Int = 1
    @Published var currentPhase: IntervalPhase = .work
    @Published var remainingDistance: Double = 0
    @Published var nextSegmentInfo: String = ""

    // MARK: - 配置

    private let trainingDetails: WatchTrainingDetails
    private let workoutMode: TrainingTypeHelper.WorkoutMode

    private var segmentStartDistance: Double = 0
    private var hasPlayedWarning: Bool = false
    private var totalRepeats: Int = 0

    // MARK: - 初始化

    init(trainingDetails: WatchTrainingDetails, workoutMode: TrainingTypeHelper.WorkoutMode) {
        self.trainingDetails = trainingDetails
        self.workoutMode = workoutMode

        if workoutMode == .interval {
            self.totalRepeats = trainingDetails.repeats ?? 0
            self.currentPhase = .work
        } else if workoutMode == .combination {
            self.currentSegmentIndex = 0
        }

        updateNextSegmentInfo()
    }

    // MARK: - 公開方法

    /// 更新進度
    func updateProgress(currentDistance: Double, currentSpeed: Double) {
        switch workoutMode {
        case .interval:
            updateIntervalProgress(currentDistance, currentSpeed)
        case .combination:
            updateCombinationProgress(currentDistance, currentSpeed)
        default:
            break
        }
    }

    /// 獲取當前段的目標距離（米）
    func getCurrentSegmentDistance() -> Double {
        switch workoutMode {
        case .interval:
            return getIntervalSegmentDistance()
        case .combination:
            return getCombinationSegmentDistance()
        default:
            return 0
        }
    }

    /// 獲取當前段的目標配速
    func getCurrentTargetPace() -> String? {
        switch workoutMode {
        case .interval:
            return currentPhase == .work
                ? trainingDetails.work?.pace
                : trainingDetails.recovery?.pace
        case .combination:
            guard let segments = trainingDetails.segments,
                  currentSegmentIndex < segments.count else { return nil }
            return segments[currentSegmentIndex].pace
        default:
            return trainingDetails.pace
        }
    }

    /// 是否已完成所有段落
    func isCompleted() -> Bool {
        switch workoutMode {
        case .interval:
            return currentLap > totalRepeats
        case .combination:
            guard let segments = trainingDetails.segments else { return true }
            return currentSegmentIndex >= segments.count
        default:
            return false
        }
    }

    // MARK: - 間歇訓練邏輯

    private func updateIntervalProgress(_ distance: Double, _ speed: Double) {
        let segmentDistance = getIntervalSegmentDistance()
        let progress = distance - segmentStartDistance
        let remaining = segmentDistance - progress

        remainingDistance = remaining

        // 5 秒倒數警告
        if speed > 0 {
            let estimatedSeconds = remaining / speed
            if estimatedSeconds <= 5 && estimatedSeconds > 0 && !hasPlayedWarning {
                triggerWarning()
                hasPlayedWarning = true
            }
        }

        // 完成當前段
        if progress >= segmentDistance {
            completeSegment(currentDistance: distance)
        }
    }

    private func getIntervalSegmentDistance() -> Double {
        switch currentPhase {
        case .work:
            return (trainingDetails.work?.distanceKm ?? 0) * 1000
                ?? (trainingDetails.work?.distanceM ?? 0)
        case .recovery:
            return (trainingDetails.recovery?.distanceKm ?? 0) * 1000
                ?? (trainingDetails.recovery?.distanceM ?? 0)
        case .rest:
            return 0  // 全休不計距離
        }
    }

    private func completeSegment(currentDistance: Double) {
        playCompletionSound()

        if currentPhase == .work {
            // 工作段完成 → 進入恢復段
            let recoveryType = RecoveryTypeDetector.getRecoveryType(from: trainingDetails.recovery)
            switch recoveryType {
            case .rest:
                currentPhase = .rest
            case .activeRecovery:
                currentPhase = .recovery
            case .none:
                // 沒有恢復段，直接下一組
                currentLap += 1
                currentPhase = .work
            }
        } else {
            // 恢復段完成 → 下一組工作段
            currentLap += 1
            currentPhase = .work
        }

        segmentStartDistance = currentDistance
        hasPlayedWarning = false
        updateNextSegmentInfo()

        playNextSegmentSound()
    }

    // MARK: - 組合跑邏輯

    private func updateCombinationProgress(_ distance: Double, _ speed: Double) {
        guard let segments = trainingDetails.segments,
              currentSegmentIndex < segments.count else { return }

        let segment = segments[currentSegmentIndex]
        let segmentDistance = (segment.distanceKm ?? 0) * 1000
        let progress = distance - segmentStartDistance
        let remaining = segmentDistance - progress

        remainingDistance = remaining

        // 5 秒倒數
        if speed > 0 {
            let estimatedSeconds = remaining / speed
            if estimatedSeconds <= 5 && estimatedSeconds > 0 && !hasPlayedWarning {
                triggerWarning()
                hasPlayedWarning = true
            }
        }

        // 完成當前段
        if progress >= segmentDistance {
            currentSegmentIndex += 1
            segmentStartDistance = distance
            hasPlayedWarning = false
            updateNextSegmentInfo()
            playNextSegmentSound()
        }
    }

    private func getCombinationSegmentDistance() -> Double {
        guard let segments = trainingDetails.segments,
              currentSegmentIndex < segments.count else { return 0 }
        return (segments[currentSegmentIndex].distanceKm ?? 0) * 1000
    }

    // MARK: - 提示音和震動

    private func triggerWarning() {
        WKInterfaceDevice.current().play(.notification)
        WKInterfaceDevice.current().play(.start)
        print("⚠️ SegmentTracker: 5 秒倒數警告")
    }

    private func playCompletionSound() {
        WKInterfaceDevice.current().play(.success)
        print("✅ SegmentTracker: 段落完成")
    }

    private func playNextSegmentSound() {
        WKInterfaceDevice.current().play(.directionUp)
        WKInterfaceDevice.current().play(.click)
        WKInterfaceDevice.current().play(.click)
        print("▶️ SegmentTracker: 進入下一段")
    }

    // MARK: - 輔助方法

    private func updateNextSegmentInfo() {
        switch workoutMode {
        case .interval:
            if currentPhase == .work {
                // 工作段 → 顯示恢復段信息
                let recoveryType = RecoveryTypeDetector.getRecoveryType(from: trainingDetails.recovery)
                switch recoveryType {
                case .rest(let duration):
                    nextSegmentInfo = "下一段: 全休 \(Int(duration / 60))分鐘"
                case .activeRecovery(let distance, let pace):
                    let distanceText = DistanceFormatter.formatMeters(distance)
                    let paceText = pace.map { " " + $0 } ?? ""
                    nextSegmentInfo = "下一段: 恢復跑 \(distanceText)\(paceText)"
                case .none:
                    nextSegmentInfo = ""
                }
            } else {
                // 恢復段 → 顯示下一組工作段
                if let workDistance = trainingDetails.work?.distanceKm ?? trainingDetails.work?.distanceM {
                    let distanceText = trainingDetails.work?.distanceKm != nil
                        ? DistanceFormatter.formatKilometers(workDistance)
                        : DistanceFormatter.formatMeters(workDistance)
                    let paceText = trainingDetails.work?.pace.map { " " + $0 + "/km" } ?? ""
                    nextSegmentInfo = "下一段: 工作段 \(distanceText)\(paceText)"
                } else {
                    nextSegmentInfo = ""
                }
            }

        case .combination:
            guard let segments = trainingDetails.segments else {
                nextSegmentInfo = ""
                return
            }

            let nextIndex = currentSegmentIndex + 1
            if nextIndex < segments.count {
                let nextSegment = segments[nextIndex]
                let distanceText = nextSegment.distanceKm.map { DistanceFormatter.formatKilometers($0) } ?? "-"
                let paceText = nextSegment.pace.map { " " + $0 + "/km" } ?? ""
                let description = nextSegment.description ?? "階段 \(nextIndex + 1)"
                nextSegmentInfo = "下一段: \(description) \(distanceText)\(paceText)"
            } else {
                nextSegmentInfo = "最後一段"
            }

        default:
            nextSegmentInfo = ""
        }
    }

    // MARK: - 段落類型

    enum IntervalPhase {
        case work       // 工作段（衝刺）
        case recovery   // 恢復段（慢跑）
        case rest       // 恢復段（全休）
    }
}
