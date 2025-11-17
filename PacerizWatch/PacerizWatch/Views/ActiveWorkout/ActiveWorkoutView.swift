import SwiftUI

struct ActiveWorkoutView: View {
    let trainingDay: WatchTrainingDay

    @StateObject private var workoutManager: WorkoutManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: WatchDataManager

    @State private var showingEndConfirmation = false

    init(trainingDay: WatchTrainingDay) {
        self.trainingDay = trainingDay
        _workoutManager = StateObject(wrappedValue: WorkoutManager(trainingDay: trainingDay))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 主要指標區域
            mainMetricsView
                .padding(.top, 8)

            Spacer()

            // 次要指標區域
            secondaryMetricsView
                .padding(.bottom, 4)

            // 控制按鈕
            controlButtons
                .padding(.bottom, 8)
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await workoutManager.startWorkout()
        }
        .confirmationDialog("結束訓練？", isPresented: $showingEndConfirmation) {
            Button("結束並保存", role: .destructive) {
                Task {
                    await workoutManager.endWorkout()
                    dismiss()
                }
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - 主要指標視圖

    @ViewBuilder
    private var mainMetricsView: some View {
        let workoutMode = TrainingTypeHelper.getWorkoutMode(trainingDay.trainingType)

        VStack(spacing: 12) {
            // 訓練標題
            Text(trainingDay.type.localizedName)
                .font(.caption)
                .foregroundColor(.secondary)

            // 主要指標（心率或配速）
            if workoutMode == .heartRate || workoutMode == .interval || workoutMode == .combination {
                heartRateView
            } else {
                paceView
            }

            // 分段信息（間歇/組合）
            if let tracker = workoutManager.segmentTracker {
                segmentInfoView(tracker)
            }
        }
    }

    // 心率視圖
    private var heartRateView: some View {
        VStack(spacing: 8) {
            // 當前心率（大數字）
            Text("\(workoutManager.currentHR)")
                .font(.system(size: 52, weight: .bold))
                .monospacedDigit()

            Text("bpm")
                .font(.caption)
                .foregroundColor(.secondary)

            // 心率區間指示器
            if let hrRange = trainingDay.trainingDetails?.heartRateRange,
               hrRange.isValid,
               let zones = dataManager.userProfile?.heartRateZones {
                heartRateZoneIndicator(
                    currentHR: workoutManager.currentHR,
                    targetRange: hrRange,
                    zones: zones
                )
            }
        }
    }

    // 配速視圖
    private var paceView: some View {
        VStack(spacing: 8) {
            // 當前配速（大數字）
            Text(PaceFormatter.secondsToPace(workoutManager.currentPace))
                .font(.system(size: 52, weight: .bold))
                .monospacedDigit()

            Text("/km")
                .font(.caption)
                .foregroundColor(.secondary)

            // 配速區間指示器
            if let targetPace = workoutManager.segmentTracker?.getCurrentTargetPace()
                ?? trainingDay.trainingDetails?.pace {
                paceZoneIndicator(
                    currentPace: workoutManager.currentPace,
                    targetPace: targetPace
                )
            }
        }
    }

    // 心率區間指示器
    private func heartRateZoneIndicator(currentHR: Int, targetRange: WatchHeartRateRange, zones: [WatchHeartRateZone]) -> some View {
        VStack(spacing: 4) {
            // 當前區間名稱
            if let currentZone = HeartRateZoneDetector.detectZone(currentHR: currentHR, zones: zones) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.heartRateZoneColor(zone: currentZone.zone))
                        .frame(width: 8, height: 8)
                    Text(currentZone.name)
                        .font(.caption)
                }
            }

            // 區間指示條（延伸設計）
            if let minHR = targetRange.min, let maxHR = targetRange.max {
                ZStack(alignment: .leading) {
                    // 背景條
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)

                    // 目標區間
                    GeometryReader { geometry in
                        let totalRange = Double(max(maxHR + 20, currentHR + 10) - min(minHR - 20, currentHR - 10))
                        let targetStart = Double(minHR - min(minHR - 20, currentHR - 10)) / totalRange
                        let targetWidth = Double(maxHR - minHR) / totalRange
                        let currentPosition = Double(currentHR - min(minHR - 20, currentHR - 10)) / totalRange

                        // 目標區間底色
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green.opacity(0.3))
                            .frame(width: geometry.size.width * targetWidth, height: 4)
                            .offset(x: geometry.size.width * targetStart)

                        // 當前位置圓點
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .offset(x: geometry.size.width * currentPosition - 4, y: -2)
                    }
                }
                .frame(height: 4)

                // 區間數值
                HStack {
                    Text("\(minHR)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(maxHR)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // 狀態提示
            let status = HeartRateZoneDetector.heartRateStatus(
                currentHR: currentHR,
                targetRange: targetRange
            )
            statusText(for: status)
        }
        .padding(.horizontal)
    }

    // 配速區間指示器
    private func paceZoneIndicator(currentPace: TimeInterval, targetPace: String) -> some View {
        VStack(spacing: 4) {
            Text("目標 \(targetPace)/km")
                .font(.caption)
                .foregroundColor(.secondary)

            // 配速區間（±20秒，慢的在左，快的在右）
            if let range = PaceFormatter.paceRange(targetPace: targetPace) {
                ZStack(alignment: .leading) {
                    // 背景條
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)

                    // 目標區間和當前位置
                    GeometryReader { geometry in
                        let targetSeconds = PaceFormatter.paceToSeconds(targetPace) ?? 0
                        let slowSeconds = PaceFormatter.paceToSeconds(range.min) ?? targetSeconds + 20
                        let fastSeconds = PaceFormatter.paceToSeconds(range.max) ?? targetSeconds - 20

                        let totalRange = slowSeconds - fastSeconds + 40  // 擴展範圍
                        let minValue = fastSeconds - 20
                        let targetStart = (slowSeconds - minValue) / totalRange
                        let targetWidth = (slowSeconds - fastSeconds) / totalRange
                        let currentPosition = max(0, min(1, (slowSeconds - currentPace + 20) / totalRange))

                        // 目標區間底色
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: geometry.size.width * targetWidth, height: 4)
                            .offset(x: geometry.size.width * targetStart)

                        // 當前位置圓點
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .offset(x: geometry.size.width * currentPosition - 4, y: -2)
                    }
                }
                .frame(height: 4)

                // 區間數值（慢的在左，快的在右）
                HStack {
                    Text(range.min)  // 慢速（數字大）
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(range.max)  // 快速（數字小）
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // 狀態提示
            let status = PaceFormatter.isPaceInRange(
                currentPace: currentPace,
                targetPace: targetPace
            )
            paceStatusText(for: status)
        }
        .padding(.horizontal)
    }

    // 分段信息視圖
    private func segmentInfoView(_ tracker: SegmentTracker) -> some View {
        VStack(spacing: 4) {
            // 當前段標題
            if workoutManager.workoutMode == .interval {
                let phaseText: String
                switch tracker.currentPhase {
                case .work:
                    phaseText = "🔴 工作段 \(tracker.currentLap)/\(trainingDay.trainingDetails?.repeats ?? 0)"
                case .recovery:
                    phaseText = "🟢 恢復段 \(tracker.currentLap)/\(trainingDay.trainingDetails?.repeats ?? 0)"
                case .rest:
                    phaseText = "⏸️ 全休 \(tracker.currentLap)/\(trainingDay.trainingDetails?.repeats ?? 0)"
                }
                Text(phaseText)
                    .font(.caption)
                    .fontWeight(.semibold)
            } else if workoutManager.workoutMode == .combination {
                let totalSegments = trainingDay.trainingDetails?.segments?.count ?? 0
                Text("階段 \(tracker.currentSegmentIndex + 1)/\(totalSegments)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            // 剩餘距離
            if tracker.remainingDistance > 0 {
                Text("剩餘 \(DistanceFormatter.formatMeters(tracker.remainingDistance))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // 下一段信息
            if !tracker.nextSegmentInfo.isEmpty {
                Text(tracker.nextSegmentInfo)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.pacerizSurface.opacity(0.5))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    // MARK: - 次要指標視圖

    private var secondaryMetricsView: some View {
        HStack(spacing: 12) {
            metricItem(
                value: DistanceFormatter.formatKilometers(workoutManager.distance / 1000),
                label: "距離"
            )

            Divider()

            metricItem(
                value: DurationFormatter.formatDuration(workoutManager.duration),
                label: "時間"
            )

            Divider()

            metricItem(
                value: String(format: "%.0f", workoutManager.activeCalories),
                label: "卡路里"
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.pacerizSurface.opacity(0.3))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    private func metricItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 控制按鈕

    private var controlButtons: some View {
        HStack(spacing: 16) {
            // 暫停/繼續按鈕
            Button {
                if workoutManager.isPaused {
                    workoutManager.resumeWorkout()
                } else {
                    workoutManager.pauseWorkout()
                }
            } label: {
                Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.pacerizPrimary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // 結束按鈕
            Button {
                showingEndConfirmation = true
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.red)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 輔助方法

    private func statusText(for status: HeartRateZoneDetector.HeartRateStatus) -> some View {
        Group {
            switch status {
            case .inRange:
                Label("✅ 區間內", systemImage: "")
                    .font(.caption2)
                    .foregroundColor(.green)
            case .tooHigh:
                Label("⚠️ 心率過高", systemImage: "")
                    .font(.caption2)
                    .foregroundColor(.red)
            case .tooLow:
                Label("ℹ️ 心率偏低", systemImage: "")
                    .font(.caption2)
                    .foregroundColor(.blue)
            case .unknown:
                EmptyView()
            }
        }
    }

    private func paceStatusText(for status: PaceFormatter.PaceStatus) -> some View {
        Group {
            switch status {
            case .ideal:
                Label("✅ 配速理想", systemImage: "")
                    .font(.caption2)
                    .foregroundColor(.green)
            case .tooFast:
                Label("⚠️ 配速過快", systemImage: "")
                    .font(.caption2)
                    .foregroundColor(.red)
            case .tooSlow:
                Label("⚠️ 配速過慢", systemImage: "")
                    .font(.caption2)
                    .foregroundColor(.orange)
            case .unknown:
                EmptyView()
            }
        }
    }
}
