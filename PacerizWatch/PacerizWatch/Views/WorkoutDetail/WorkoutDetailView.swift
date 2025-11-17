import SwiftUI

struct WorkoutDetailView: View {
    let trainingDay: WatchTrainingDay

    @State private var showingWorkout = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 訓練類型標題
                trainingTypeHeader

                // 訓練詳情
                if let details = trainingDay.trainingDetails {
                    detailsContent(details)
                } else {
                    Text("今天休息")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .padding()
                }

                // 開始訓練按鈕
                if trainingDay.isTrainingDay {
                    Button {
                        showingWorkout = true
                    } label: {
                        Label("開始訓練", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.pacerizPrimary)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(trainingDay.type.localizedName)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingWorkout) {
            ActiveWorkoutView(trainingDay: trainingDay)
        }
    }

    private var trainingTypeHeader: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color.trainingTypeColor(type: trainingDay.type))
                .frame(width: 24, height: 24)

            Text(trainingDay.dayTarget)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func detailsContent(_ details: WatchTrainingDetails) -> some View {
        if TrainingTypeHelper.isIntervalWorkout(trainingDay.trainingType) {
            intervalDetails(details)
        } else if TrainingTypeHelper.isCombinationWorkout(trainingDay.trainingType) {
            combinationDetails(details)
        } else {
            simpleDetails(details)
        }
    }

    // MARK: - 簡單訓練詳情

    @ViewBuilder
    private func simpleDetails(_ details: WatchTrainingDetails) -> some View {
        VStack(spacing: 12) {
            // 目標卡片
            VStack(spacing: 8) {
                if let distance = details.distanceKm {
                    metricRow(icon: "figure.run", label: "距離", value: DistanceFormatter.formatKilometers(distance))
                }

                if let time = details.timeMinutes {
                    metricRow(icon: "timer", label: "時間", value: DurationFormatter.formatShort(time * 60))
                }

                if let hrRange = details.heartRateRange, hrRange.isValid {
                    metricRow(icon: "heart.fill", label: "心率", value: hrRange.displayText ?? "-")
                } else if let pace = details.pace {
                    metricRow(icon: "gauge", label: "配速", value: pace + "/km")
                }
            }
            .padding()
            .background(Color.pacerizSurface)
            .cornerRadius(12)
            .padding(.horizontal)

            // 訓練說明
            if let description = details.description {
                VStack(alignment: .leading, spacing: 8) {
                    Text("訓練說明")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(description)
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.pacerizSurface)
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - 間歇訓練詳情

    @ViewBuilder
    private func intervalDetails(_ details: WatchTrainingDetails) -> some View {
        VStack(spacing: 12) {
            // 總覽
            if let repeats = details.repeats {
                Text("\(repeats) 組")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.pacerizPrimary)
            }

            // 工作段
            if let work = details.work {
                segmentCard(
                    title: "工作段",
                    icon: "bolt.fill",
                    color: .red,
                    segment: work
                )
            }

            // 恢復段
            if let recovery = details.recovery {
                let recoveryType = RecoveryTypeDetector.getRecoveryType(from: recovery)
                let title: String
                let icon: String

                switch recoveryType {
                case .rest:
                    title = "全休"
                    icon = "pause.fill"
                case .activeRecovery:
                    title = "恢復段"
                    icon = "figure.walk"
                case .none:
                    title = "恢復段"
                    icon = "figure.walk"
                }

                segmentCard(
                    title: title,
                    icon: icon,
                    color: .green,
                    segment: recovery
                )
            }

            // 總距離
            if let totalDistance = details.totalDistanceKm {
                Text("總距離: \(DistanceFormatter.formatKilometers(totalDistance))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - 組合跑詳情

    @ViewBuilder
    private func combinationDetails(_ details: WatchTrainingDetails) -> some View {
        VStack(spacing: 12) {
            if let segments = details.segments, !segments.is

Empty {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    progressionSegmentCard(
                        title: "階段 \(index + 1)",
                        segment: segment
                    )
                }

                // 總距離
                if let totalDistance = details.totalDistanceKm {
                    Text("總距離: \(DistanceFormatter.formatKilometers(totalDistance))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - 輔助視圖

    private func metricRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    private func segmentCard(title: String, icon: String, color: Color, segment: WatchWorkoutSegment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                if let distance = segment.distanceKm ?? (segment.distanceM.map { $0 / 1000 }) {
                    HStack {
                        Text("距離")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(DistanceFormatter.formatKilometers(distance))
                    }
                    .font(.caption)
                }

                if let pace = segment.pace {
                    HStack {
                        Text("配速")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(pace + "/km")
                    }
                    .font(.caption)
                }

                if let time = segment.timeMinutes {
                    HStack {
                        Text("時間")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(DurationFormatter.formatShort(time * 60))
                    }
                    .font(.caption)
                }

                if let hrRange = segment.heartRateRange, hrRange.isValid {
                    HStack {
                        Text("心率")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(hrRange.displayText ?? "-")
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.pacerizSurface)
        .cornerRadius(12)
    }

    private func progressionSegmentCard(title: String, segment: WatchProgressionSegment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            if let description = segment.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                if let distance = segment.distanceKm {
                    HStack {
                        Text("距離")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(DistanceFormatter.formatKilometers(distance))
                    }
                    .font(.caption)
                }

                if let pace = segment.pace {
                    HStack {
                        Text("配速")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(pace + "/km")
                    }
                    .font(.caption)
                }

                if let hrRange = segment.heartRateRange, hrRange.isValid {
                    HStack {
                        Text("心率")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(hrRange.displayText ?? "-")
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.pacerizSurface)
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(
            trainingDay: WatchTrainingDay(
                id: "1",
                dayIndex: "2025-11-17",
                dayTarget: "輕鬆跑 8 公里",
                trainingType: "easy",
                trainingDetails: WatchTrainingDetails(
                    description: "保持輕鬆配速，感覺舒適為主",
                    distanceKm: 8.0,
                    totalDistanceKm: nil,
                    timeMinutes: 44,
                    pace: "5:30",
                    work: nil,
                    recovery: nil,
                    repeats: nil,
                    heartRateRange: WatchHeartRateRange(min: 120, max: 145),
                    segments: nil
                )
            )
        )
    }
}
