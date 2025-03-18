import SwiftUI
import HealthKit
import Combine

class TrainingPlanViewModel: ObservableObject {
    @Published var weeklyPlan: WeeklyPlan?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var currentWeekDistance: Double = 0.0
    @Published var isLoadingDistance = false
    @Published var currentVDOT: Double = 0.0
    @Published var targetVDOT: Double = 0.0
    @Published var isLoadingVDOT = false
    @Published var workoutsByDay: [Int: [HKWorkout]] = [:]
    @Published var isLoadingWorkouts = false
    
    // 重用 TrainingRecordViewModel 的功能
    private let workoutService = WorkoutService.shared
    private let trainingRecordVM = TrainingRecordViewModel()
    
    // 追蹤哪些日子被展開的狀態
    @Published var expandedDayIndices = Set<Int>()
    
    // 從 TrainingRecordViewModel 重用的方法
    func isWorkoutUploaded(_ workout: HKWorkout) -> Bool {
        return workoutService.isWorkoutUploaded(workout)
    }
    
    func getWorkoutUploadTime(_ workout: HKWorkout) -> Date? {
        return workoutService.getWorkoutUploadTime(workout)
    }
    
    func loadWeeklyPlan() async {
        await MainActor.run {
            isLoading = true
        }
        
        if let savedPlan = TrainingPlanStorage.loadWeeklyPlan() {
            await MainActor.run {
                weeklyPlan = savedPlan
                error = nil
                isLoading = false
            }
        } else {
            await MainActor.run {
                error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法載入週訓練計劃"])
                isLoading = false
            }
        }
    }
    
    func refreshWeeklyPlan(healthKitManager: HealthKitManager) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let newPlan = try await TrainingPlanService.shared.getWeeklyPlan()
            await MainActor.run {
                weeklyPlan = newPlan
                error = nil
            }
            
            if newPlan.totalDistance > 0 {
                await loadCurrentWeekDistance(healthKitManager: healthKitManager)
            }
            
            await loadVDOTData()
            await loadWorkoutsForCurrentWeek(healthKitManager: healthKitManager)
            await identifyTodayTraining()
        } catch {
            await MainActor.run {
                self.error = error
                print("刷新訓練計劃失敗: \(error)")
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    // 加載當前週的訓練記錄
    func loadWorkoutsForCurrentWeek(healthKitManager: HealthKitManager) async {
        guard let plan = weeklyPlan, let createdAt = plan.createdAt else {
            return
        }
        
        await MainActor.run {
            isLoadingWorkouts = true
        }
        
        do {
            // 獲取當前週的時間範圍
            let (weekStart, weekEnd) = getWeekDates(for: plan)
            
            try await healthKitManager.requestAuthorization()
            let workouts = try await healthKitManager.fetchWorkoutsForDateRange(start: weekStart, end: weekEnd)
            
            // 按日期分組
            let groupedWorkouts = groupWorkoutsByDay(workouts)
            
            // 更新 UI
            await MainActor.run {
                self.workoutsByDay = groupedWorkouts
            }
            
        } catch {
            print("加載訓練紀錄時出錯: \(error)")
        }
        
        await MainActor.run {
            isLoadingWorkouts = false
        }
    }
    
    // 識別並自動展開當天的訓練
    func identifyTodayTraining() async {
        if let plan = weeklyPlan {
            await MainActor.run {
                for day in plan.days where isToday(dayIndex: day.dayIndex, planWeek: plan.weekOfPlan) {
                    expandedDayIndices.insert(day.dayIndex)
                    break
                }
            }
        }
    }
    
    func loadCurrentWeekDistance(healthKitManager: HealthKitManager) async {
        await MainActor.run {
            isLoadingDistance = true
        }
        
        do {
            try await healthKitManager.requestAuthorization()
            
            // 获取当前周的时间范围（周一到周日）
            let (weekStart, weekEnd) = getCurrentWeekDates()
            
            // 获取指定时间范围内的锻炼
            let workouts = try await healthKitManager.fetchWorkoutsForDateRange(start: weekStart, end: weekEnd)
            
            // 计算跑步距离总和
            let totalDistance = calculateTotalDistance(workouts)
            
            // 更新UI
            await MainActor.run {
                self.currentWeekDistance = totalDistance
            }
            
        } catch {
            print("加载本周跑量时出错: \(error)")
        }
        
        await MainActor.run {
            isLoadingDistance = false
        }
    }
    
    // 加载VDOT数据
    func loadVDOTData() async {
        await MainActor.run {
            isLoadingVDOT = true
        }
        
        // 簡化處理：使用默認值
        await MainActor.run {
            self.currentVDOT = 40.0
            self.targetVDOT = 45.0
            self.isLoadingVDOT = false
        }
    }
    
    // 产生下週计划
    func generateNextWeekPlan() async {
        guard let currentPlan = weeklyPlan else {
            print("無法產生下週課表：當前課表不存在")
            return
        }
        
        // 計算下一週的週數
        let nextWeek = currentPlan.weekOfPlan + 1
        
        // 確保下一週不超過總週數
        guard nextWeek <= currentPlan.totalWeeks else {
            print("已經是最後一週，無法產生下週課表")
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            print("開始產生第 \(nextWeek) 週課表...")
            _ = try await TrainingPlanService.shared.createWeeklyPlan(targetWeek: nextWeek)
            
            // 產生成功後重新載入課表
            do {
                let newPlan = try await TrainingPlanService.shared.getWeeklyPlan()
                
                await MainActor.run {
                    weeklyPlan = newPlan
                    error = nil
                }
                
                print("成功產生第 \(nextWeek) 週課表並更新 UI")
            } catch {
                print("重新載入課表失敗: \(error)")
                
                await MainActor.run {
                    self.error = error
                }
            }
        } catch {
            print("產生下週課表失敗: \(error)")
            
            await MainActor.run {
                self.error = error
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    // 判斷是否應該顯示產生下週課表按鈕
    func shouldShowNextWeekButton(plan: WeeklyPlan) -> Bool {
        guard let createdAt = plan.createdAt else {
            return false
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        // 計算當前計劃週數的週一
        let creationWeekday = calendar.component(.weekday, from: createdAt)
        let daysToSubtract = creationWeekday == 1 ? 6 : creationWeekday - 2
        guard let firstWeekMonday = calendar.date(byAdding: .day, value: -daysToSubtract, to: createdAt) else {
            return false
        }
        
        // 計算週數與日期
        let weeksToAdd = plan.weekOfPlan - 1
        guard let currentWeekMonday = calendar.date(byAdding: .weekOfYear, value: weeksToAdd, to: firstWeekMonday) else {
            return false
        }
        
        guard let currentWeekSunday = calendar.date(byAdding: .day, value: 6, to: currentWeekMonday) else {
            return false
        }
        
        // 當前日期是否是當前計劃週數的週日
        let isCurrentWeekSunday = calendar.isDate(now, inSameDayAs: currentWeekSunday)
        
        // 檢查還有沒有下一週
        let hasNextWeek = plan.weekOfPlan < plan.totalWeeks
        
        return isCurrentWeekSunday && hasNextWeek
    }
    
    // 輔助方法
    private func calculateTotalDistance(_ workouts: [HKWorkout]) -> Double {
        var total = 0.0
        for workout in workouts {
            if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                total += distance / 1000 // 转换为千米
            }
        }
        return total
    }
    
    private func groupWorkoutsByDay(_ workouts: [HKWorkout]) -> [Int: [HKWorkout]] {
        let calendar = Calendar.current
        var grouped: [Int: [HKWorkout]] = [:]
        
        for workout in workouts {
            let weekday = calendar.component(.weekday, from: workout.startDate)
            // 轉換 weekday 為 1-7（週一到週日）
            let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
            
            if grouped[adjustedWeekday] == nil {
                grouped[adjustedWeekday] = []
            }
            grouped[adjustedWeekday]?.append(workout)
        }
        
        return grouped
    }
    
    private func getWeekDates(for plan: WeeklyPlan) -> (Date, Date) {
        let calendar = Calendar.current
        
        // 計算週開始和結束日期
        let creationWeekday = calendar.component(.weekday, from: plan.createdAt ?? Date())
        let daysToSubtract = creationWeekday == 1 ? 6 : creationWeekday - 2
        guard let firstWeekMonday = calendar.date(byAdding: .day, value: -daysToSubtract, to: plan.createdAt ?? Date()) else {
            return (Date(), Date())
        }
        
        let weeksToAdd = plan.weekOfPlan - 1
        guard let currentWeekMonday = calendar.date(byAdding: .weekOfYear, value: weeksToAdd, to: firstWeekMonday) else {
            return (Date(), Date())
        }
        
        guard let currentWeekSunday = calendar.date(byAdding: .day, value: 6, to: currentWeekMonday) else {
            return (Date(), Date())
        }
        
        guard let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: currentWeekSunday) else {
            return (Date(), Date())
        }
        
        return (currentWeekMonday, endOfDay)
    }
    
    // 获取当前周的开始日期（周一）和结束日期（周日）
    func getCurrentWeekDates() -> (Date, Date) {
        let calendar = Calendar.current
        let today = Date()
        
        // 找到本周的周一
        var weekdayComponents = calendar.dateComponents([.weekday], from: today)
        let weekday = weekdayComponents.weekday ?? 1 // 默认为周日(1)
        
        // 由于Calendar.current.firstWeekday通常是1(周日)，但我们需要从周一开始计算
        // 计算距离周一的天数
        let daysToMonday = (weekday + 5) % 7 // 转换为周一为第一天(周一=0, 周二=1, ..., 周日=6)
        
        // 周一日期
        let startDate = calendar.date(byAdding: .day, value: -daysToMonday, to: calendar.startOfDay(for: today))!
        
        // 周日日期 (周一加6天)
        let endDate = calendar.date(byAdding: .day, value: 6, to: startDate)!
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate)!
        
        return (startDate, endOfDay)
    }
    
    // 格式化工具方法
    func formatDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            return String(format: "%.2f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }
    
    func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    func formatPace(_ paceInSeconds: Double) -> String {
        let minutes = Int(paceInSeconds) / 60
        let seconds = Int(paceInSeconds) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
    
    func weekdayName(for index: Int) -> String {
        let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
        return "星期" + weekdays[index - 1]
    }
    
    // 輔助判斷方法
    func isToday(dayIndex: Int, planWeek: Int) -> Bool {
        guard let date = getDateForDay(dayIndex: dayIndex) else {
            return false
        }
        
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }
    
    func getDateForDay(dayIndex: Int) -> Date? {
        guard let plan = weeklyPlan, let createdAt = plan.createdAt else {
            return nil
        }
        
        let calendar = Calendar.current
        
        // 找到創建日期所在週的週一
        let creationWeekday = calendar.component(.weekday, from: createdAt)
        let daysToSubtract = creationWeekday == 1 ? 6 : creationWeekday - 2
        guard let firstWeekMonday = calendar.date(byAdding: .day, value: -daysToSubtract, to: createdAt) else {
            return nil
        }
        
        // 計算該計劃週的週一日期
        let weeksToAdd = plan.weekOfPlan - 1
        guard let currentWeekMonday = calendar.date(byAdding: .weekOfYear, value: weeksToAdd, to: firstWeekMonday) else {
            return nil
        }
        
        // 計算課表中特定weekday對應的日期
        return calendar.date(byAdding: .day, value: dayIndex - 1, to: currentWeekMonday)
    }
}
