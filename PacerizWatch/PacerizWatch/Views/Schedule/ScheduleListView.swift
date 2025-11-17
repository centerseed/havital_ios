import SwiftUI

struct ScheduleListView: View {
    @EnvironmentObject var dataManager: WatchDataManager
    @State private var isRefreshing = false

    var body: some View {
        Group {
            if let weeklyPlan = dataManager.weeklyPlan {
                content(weeklyPlan)
            } else if dataManager.isLoading {
                loadingView
            } else {
                emptyView
            }
        }
        .navigationTitle("本週課表")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await refresh()
        }
    }

    @ViewBuilder
    private func content(_ plan: WatchWeeklyPlan) -> some View {
        VStack(spacing: 0) {
            // 週數標題
            HStack {
                Text("第 \(plan.weekOfPlan)/\(plan.totalWeeks) 週")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let syncTime = dataManager.lastSyncTime {
                    Text(syncTimeText(syncTime))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // 課表列表
            List {
                ForEach(plan.days) { day in
                    NavigationLink(destination: WorkoutDetailView(trainingDay: day)) {
                        TrainingDayRow(day: day)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("載入中...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("尚無課表")
                .font(.title3)

            Text("請在 iPhone 上打開 Paceriz 同步課表")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("手動同步") {
                Task {
                    await refresh()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.pacerizPrimary)
        }
        .padding()
    }

    private func refresh() async {
        isRefreshing = true
        await dataManager.requestSync()
        isRefreshing = false
    }

    private func syncTimeText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - 課表行視圖

struct TrainingDayRow: View {
    let day: WatchTrainingDay

    private var isToday: Bool {
        Calendar.current.isDateInToday(day.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 日期和訓練類型
            HStack {
                Text(dayText)
                    .font(isToday ? .headline : .body)
                    .foregroundColor(isToday ? .pacerizPrimary : .primary)

                Spacer()

                if isToday {
                    Text("今天")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.pacerizPrimary.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            // 訓練類型圓點和名稱
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.trainingTypeColor(type: day.type))
                    .frame(width: 10, height: 10)

                Text(day.type.localizedName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // 訓練詳情
            if let details = day.trainingDetails {
                HStack(spacing: 12) {
                    if let distance = details.distanceKm {
                        Label(DistanceFormatter.formatKilometers(distance), systemImage: "figure.run")
                            .font(.caption)
                    }

                    if let pace = details.pace {
                        Label(pace + "/km", systemImage: "timer")
                            .font(.caption)
                    }

                    // 間歇訓練顯示組數
                    if TrainingTypeHelper.isIntervalWorkout(day.trainingType),
                       let repeats = details.repeats,
                       let workDistance = details.work?.distanceKm ?? details.work?.distanceM {
                        let distanceText = details.work?.distanceKm != nil
                            ? String(format: "%.0fm", workDistance * 1000)
                            : String(format: "%.0fm", workDistance)
                        Text("\(repeats)×\(distanceText)")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var dayText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d (E)"
        return formatter.string(from: day.date)
    }
}

#Preview {
    NavigationStack {
        ScheduleListView()
            .environmentObject(WatchDataManager.shared)
    }
}
