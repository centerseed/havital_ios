import SwiftUI
import HealthKit

/// 訓練日曆視圖 - 顯示每月訓練記錄
struct TrainingCalendarView: View {
    @ObservedObject var healthKitManager: HealthKitManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedMonth = Date()
    @State private var workoutsByDate: [Date: Double] = [:]  // 日期 -> 總距離 (km)
    @State private var isLoading = false

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        formatter.locale = Locale.current
        return formatter.string(from: selectedMonth)
    }

    private var totalMonthDistance: Double {
        workoutsByDate.values.reduce(0, +)
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
        .task {
            await loadWorkoutsForMonth()
        }
    }

    // MARK: - 月份選擇器

    private var monthSelector: some View {
        HStack {
            Button(action: {
                selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                Task { await loadWorkoutsForMonth() }
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
                    Task { await loadWorkoutsForMonth() }
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
                Text("訓練天數")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(workoutsByDate.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)

                    Text("天")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
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
            if isLoading {
                ProgressView()
                    .frame(height: 300)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(daysInMonth, id: \.self) { date in
                        if let date = date {
                            DayCell(date: date, distance: workoutsByDate[normalizeDate(date)])
                        } else {
                            EmptyDayCell()
                        }
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

    // MARK: - 數據加載

    private func loadWorkoutsForMonth() async {
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return
        }

        do {
            let workouts = try await healthKitManager.fetchWorkoutsForDateRange(
                start: startOfMonth,
                end: calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfMonth) ?? endOfMonth
            )

            // 按日期分組並計算總距離
            var grouped: [Date: Double] = [:]
            for workout in workouts {
                let date = normalizeDate(workout.startDate)
                let distance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
                grouped[date, default: 0] += distance / 1000.0  // 轉換為公里
            }

            await MainActor.run {
                workoutsByDate = grouped
            }
        } catch {
            print("載入訓練記錄失敗: \(error)")
        }
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

// MARK: - Day Cell

struct DayCell: View {
    let date: Date
    let distance: Double?
    @Environment(\.colorScheme) var colorScheme

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var backgroundColor: Color {
        if isToday {
            return .blue.opacity(0.15)
        } else if distance != nil {
            return .green.opacity(0.12)
        } else {
            return colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.97)
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(dayNumber)
                .font(.system(size: 14, weight: isToday ? .bold : .medium))
                .foregroundColor(isToday ? .blue : .primary)

            if let distance = distance {
                Text(String(format: "%.1f", distance))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.green)

                Image(systemName: "figure.run")
                    .font(.system(size: 8))
                    .foregroundColor(.green.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(backgroundColor)
        .cornerRadius(8)
    }
}

struct EmptyDayCell: View {
    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 60)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        TrainingCalendarView(healthKitManager: HealthKitManager())
    }
}
