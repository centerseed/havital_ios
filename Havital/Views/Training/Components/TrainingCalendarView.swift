import SwiftUI
import HealthKit

/// 訓練日曆視圖 - 顯示每月訓練記錄（從緩存讀取）
struct TrainingCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedMonth = Date()
    @State private var workoutsByDate: [Date: DayWorkoutInfo] = [:]  // 日期 -> 訓練資訊

    // 使用 UnifiedWorkoutManager 作為數據源（緩存）
    private let unifiedWorkoutManager = UnifiedWorkoutManager.shared

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        formatter.locale = Locale.current
        return formatter.string(from: selectedMonth)
    }

    private var totalMonthDistance: Double {
        workoutsByDate.values.reduce(0) { $0 + $1.totalDistance }
    }

    private var averagePace: String {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return "--:--"
        }

        // ✅ 只計算跑步類型的訓練記錄
        let runningWorkouts = unifiedWorkoutManager.workouts.filter { workout in
            let workoutDate = workout.startDate
            let isInMonth = workoutDate >= startOfMonth && workoutDate <= calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfMonth) ?? endOfMonth
            let isRunning = workout.activityType.lowercased().contains("run")
            return isInMonth && isRunning
        }

        guard !runningWorkouts.isEmpty else { return "--:--" }

        // 計算跑步的總距離和總時長
        let totalDistance = runningWorkouts.reduce(0.0) { $0 + (($1.distance ?? 0) / 1000.0) }  // 轉換為公里
        let totalDuration = runningWorkouts.reduce(0.0) { $0 + $1.duration }

        guard totalDistance > 0 else { return "--:--" }

        // 計算平均配速 (分鐘/公里)
        let paceSeconds = totalDuration / totalDistance
        let minutes = Int(paceSeconds) / 60
        let seconds = Int(paceSeconds) % 60
        return String(format: "%d'%02d\"", minutes, seconds)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 月份選擇器
                monthSelector

                // 統計卡片
                statsCard

                // 日曆視圖
                calendarGrid
            }
            .padding()
        }
        .navigationTitle("訓練日曆")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("關閉") {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadWorkoutsForMonth()
        }
    }

    // MARK: - 月份選擇器

    private var monthSelector: some View {
        HStack {
            Button(action: {
                selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                loadWorkoutsForMonth()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(monthName)
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button(action: {
                let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                if nextMonth <= Date() {
                    selectedMonth = nextMonth
                    loadWorkoutsForMonth()
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(canGoToNextMonth ? .blue : .gray.opacity(0.3))
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoToNextMonth)
        }
    }

    private var canGoToNextMonth: Bool {
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        return nextMonth <= Date()
    }

    // MARK: - 統計卡片

    private var statsCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("月總距離")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", totalMonthDistance))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)

                    Text("km")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("平均配速")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(averagePace)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
        )
    }

    // MARK: - 日曆網格

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            // 星期標題
            weekdayHeader

            // 日期網格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        DayCell(date: date, workoutInfo: workoutsByDate[normalizeDate(date)])
                    } else {
                        EmptyDayCell()
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(white: 0.1) : Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                Text(day)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - 數據加載（從緩存讀取，不調用 API）

    private func loadWorkoutsForMonth() {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return
        }

        // ✅ 從 UnifiedWorkoutManager 緩存讀取，不調用 API
        let allWorkouts = unifiedWorkoutManager.workouts

        // 過濾當月的訓練記錄
        let monthWorkouts = allWorkouts.filter { workout in
            let workoutDate = workout.startDate
            return workoutDate >= startOfMonth && workoutDate <= calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfMonth) ?? endOfMonth
        }

        // 按日期分組並計算總距離和主要運動類型
        var grouped: [Date: DayWorkoutInfo] = [:]
        for workout in monthWorkouts {
            let date = normalizeDate(workout.startDate)
            let distance = (workout.distance ?? 0) / 1000.0  // 轉換為公里
            let duration = workout.duration

            if var existing = grouped[date] {
                existing.totalDistance += distance
                existing.totalDuration += duration
                existing.workoutCount += 1
                // 更新主要類型（選擇距離最長的）
                if distance > (existing.primaryDistance ?? 0) {
                    existing.primaryType = workout.activityType
                    existing.primaryDistance = distance
                }
                grouped[date] = existing
            } else {
                grouped[date] = DayWorkoutInfo(
                    totalDistance: distance,
                    totalDuration: duration,
                    primaryType: workout.activityType,
                    primaryDistance: distance,
                    workoutCount: 1
                )
            }
        }

        workoutsByDate = grouped

        print("📅 日曆載入完成：\(selectedMonth) 共 \(monthWorkouts.count) 筆記錄")
    }

    // MARK: - Helper Functions

    private func normalizeDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.startOfDay(for: date)
    }

    private var daysInMonth: [Date?] {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return []
        }

        var days: [Date?] = []

        // 獲取第一天是星期幾（1=週一，7=週日）
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let offset = (firstWeekday == 1 ? 0 : firstWeekday - 2 + (firstWeekday == 1 ? 7 : 0))

        // 添加前置空白
        for _ in 0..<offset {
            days.append(nil)
        }

        // 添加所有日期
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }

        return days
    }
}

// MARK: - 訓練資訊結構

struct DayWorkoutInfo {
    var totalDistance: Double
    var totalDuration: TimeInterval
    var primaryType: String  // 主要運動類型
    var primaryDistance: Double?
    var workoutCount: Int
}

// MARK: - Day Cell

struct DayCell: View {
    let date: Date
    let workoutInfo: DayWorkoutInfo?
    @Environment(\.colorScheme) var colorScheme

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var workoutColor: Color {
        guard let info = workoutInfo else { return .clear }

        // 根據運動類型返回不同顏色
        switch info.primaryType.lowercased() {
        case "running", "run":
            return .green
        case "cycling", "cycle", "bike":
            return .blue
        case "strength", "weight", "gym":
            return .purple
        case "swimming", "swim":
            return .cyan
        case "yoga":
            return .pink
        case "hiking", "hike":
            return .orange
        default:
            return .green
        }
    }

    private var workoutIcon: String {
        guard let info = workoutInfo else { return "figure.run" }

        // 根據運動類型返回不同圖標
        switch info.primaryType.lowercased() {
        case "running", "run":
            return "figure.run"
        case "cycling", "cycle", "bike":
            return "figure.outdoor.cycle"
        case "strength", "weight", "gym":
            return "dumbbell.fill"
        case "swimming", "swim":
            return "figure.pool.swim"
        case "yoga":
            return "figure.mind.and.body"
        case "hiking", "hike":
            return "figure.hiking"
        default:
            return "figure.run"
        }
    }

    private var backgroundColor: Color {
        if isToday {
            return .blue.opacity(0.15)
        } else if workoutInfo != nil {
            return workoutColor.opacity(0.12)
        } else {
            return colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.97)
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(dayNumber)
                .font(.system(size: 14, weight: isToday ? .bold : .medium))
                .foregroundColor(isToday ? .blue : .primary)

            if let info = workoutInfo {
                Text(String(format: "%.1f", info.totalDistance))
                    .font(.system(size: 12, weight: .bold))  // 增大字體
                    .foregroundColor(workoutColor)

                Image(systemName: workoutIcon)
                    .font(.system(size: 11))  // 增大圖標
                    .foregroundColor(workoutColor.opacity(0.8))

                // 如果有多個訓練，顯示數量
                if info.workoutCount > 1 {
                    Text("×\(info.workoutCount)")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(workoutColor.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)  // 增加高度以容納更大的內容
        .background(backgroundColor)
        .cornerRadius(8)
    }
}

struct EmptyDayCell: View {
    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 70)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        TrainingCalendarView()
    }
}
