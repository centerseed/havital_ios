import SwiftUI
import HealthKit

// MARK: - ViewModel

/// TrainingCalendarViewModel
/// 負責 TrainingCalendarView 的數據邏輯
@MainActor
class TrainingCalendarViewModel: ObservableObject {
    @Published var workouts: [WorkoutV2] = []
    @Published var isLoading = false
    
    private let repository: WorkoutRepository
    
    init(repository: WorkoutRepository = DependencyContainer.shared.resolve()) {
        self.repository = repository
        
        // 初始載入緩存數據
        Task {
            await loadCachedWorkouts()
        }
    }
    
    private func loadCachedWorkouts() async {
        // 嘗試獲取緩存數據顯示初始狀態
        let cached = await repository.getAllWorkoutsAsync()
        if !cached.isEmpty {
            self.workouts = cached
        }
    }
    
    func loadWorkoutsForMonth(month: Date) async {
        isLoading = true
        let calendar = Calendar.current
        
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            isLoading = false
            return
        }
        
        // 擴大範圍以確保覆蓋（或者可以使用 getAllWorkoutsAsync 然後過濾）
        // 這裡我們直接獲取所有緩存並過濾，因为日曆通常需要快速響應
        // Repository 的 getWorkoutsInDateRangeAsync 是基於本地緩存的，所以很快
        let monthWorkouts = await repository.getWorkoutsInDateRangeAsync(startDate: startOfMonth, endDate: endOfMonth)
        
        self.workouts = monthWorkouts
        self.isLoading = false
    }
}

/// 訓練日曆視圖 - 顯示每月訓練記錄（從緩存讀取）
struct TrainingCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject private var viewModel = TrainingCalendarViewModel()

    @State private var selectedMonth = Date()
    @State private var workoutsByDate: [Date: DayWorkoutInfo] = [:]  // 日期 -> 訓練資訊

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        formatter.locale = Locale.current
        return formatter.string(from: selectedMonth)
    }

    /// 只計算跑步類型的月總里程
    private var totalMonthDistance: Double {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return 0
        }

        // 從 ViewModel 獲取該月的跑步記錄
        let runningWorkouts = viewModel.workouts.filter { workout in
            // 注意：viewModel.workouts 已經是該月的數據（如果是通過 loadWorkoutsForMonth 加載的）
            // 但為了安全起見，再次過濾日期（因為初始加載可能是所有數據）
            let workoutDate = workout.startDate
            let isInMonth = workoutDate >= startOfMonth && workoutDate <= calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfMonth) ?? endOfMonth
            let isRunning = workout.activityType == "running"
            return isInMonth && isRunning
        }

        // 只計算跑步的總距離（轉換為公里）
        return runningWorkouts.reduce(0.0) { $0 + (($1.distance ?? 0) / 1000.0) }
    }

    private var averagePace: String {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return "--:--"
        }

        // ✅ 只計算跑步類型的訓練記錄
        let runningWorkouts = viewModel.workouts.filter { workout in
            let workoutDate = workout.startDate
            let isInMonth = workoutDate >= startOfMonth && workoutDate <= calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfMonth) ?? endOfMonth
            let isRunning = workout.activityType == "running"
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
        .navigationTitle(NSLocalizedString("training_plan.training_calendar", comment: "Training Calendar"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(NSLocalizedString("common.close", comment: "Close")) {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadWorkoutsForMonth()
        }
        .onChange(of: viewModel.workouts) { _ in
            processWorkoutsForDisplay()
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
                Text(NSLocalizedString("training_plan.monthly_total_distance", comment: "Monthly Total Distance"))
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
                Text(NSLocalizedString("training_plan.average_pace", comment: "Average Pace"))
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

    // MARK: - 數據加載

    private func loadWorkoutsForMonth() {
        // 使用 Task 調用異步方法
        Task {
            await viewModel.loadWorkoutsForMonth(month: selectedMonth)
        }
    }
    
    private func processWorkoutsForDisplay() {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return
        }
        
        // 這些數據已經是該月的了，但我們還是過濾一下確保安全
        let allWorkouts = viewModel.workouts

        // 過濾當月的訓練記錄（排除 rest 類型）
        let monthWorkouts = allWorkouts.filter { workout in
            let workoutDate = workout.startDate
            let isInMonth = workoutDate >= startOfMonth && workoutDate <= calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfMonth) ?? endOfMonth
            // 排除 "rest" 類型，這不是實際的運動記錄
            let isNotRest = workout.activityType.lowercased() != "rest"
            return isInMonth && isNotRest
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

        print("📅 日曆數據處理完成：\(selectedMonth) 共 \(monthWorkouts.count) 筆記錄")
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
            return .mint
        case "cycling", "cycle", "bike":
            return .blue
        case "strength", "weight", "gym", "strength_training":
            return .purple
        case "swimming", "swim":
            return .cyan
        case "yoga":
            return .pink
        case "hiking", "hike":
            return .orange
        case "walking", "walk":
            return .green
        case "rowing", "row":
            return .teal
        case "elliptical":
            return .indigo
        case "rest":
            return .gray
        default:
            // 未知類型使用灰色，避免誤認為跑步
            return .gray
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
        case "strength", "weight", "gym", "strength_training":
            return "dumbbell.fill"
        case "swimming", "swim":
            return "figure.pool.swim"
        case "yoga":
            return "figure.mind.and.body"
        case "hiking", "hike":
            return "figure.hiking"
        case "walking", "walk":
            return "figure.walk"
        case "rowing", "row":
            return "figure.rower"
        case "elliptical":
            return "figure.elliptical"
        case "rest":
            return "bed.double.fill"
        case "rest_day":
            return "bed.double.fill"
        default:
            // 未知類型使用通用圖標，避免誤認為跑步
            return "figure.mixed.cardio"
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
                // 只有在距離 > 0 時才顯示距離數值
                if info.totalDistance > 0 {
                    Text(String(format: "%.1f", info.totalDistance))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(workoutColor)
                }

                Image(systemName: workoutIcon)
                    .font(.system(size: 11))
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
