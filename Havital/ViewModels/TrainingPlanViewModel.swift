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
    @Published var trainingOverview: TrainingPlanOverview? // 訓練計劃概覽
    
    // 重用 TrainingRecordViewModel 的功能
    private let workoutService = WorkoutService.shared
    private let trainingRecordVM = TrainingRecordViewModel()
    
    // 追蹤哪些日子被展開的狀態
    @Published var expandedDayIndices = Set<Int>()
    
    // 添加屬性來追蹤當前計劃的週數，用於檢測計劃變更
    private var currentPlanWeek: Int?
    
    // === 集中式日期處理部分 ===
    private struct WeekDateInfo {
        let startDate: Date  // 週一凌晨00:00:00
        let endDate: Date    // 週日晚上23:59:59
        let daysMap: [Int: Date] // 日期索引映射（1-7 對應週一到週日）
        
        func getDateForDayIndex(_ dayIndex: Int) -> Date? {
            return daysMap[dayIndex]
        }
    }
    
    // 儲存當前計算好的週日期資訊
    private var currentWeekDateInfo: WeekDateInfo?
    
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
            // 儲存當前計劃的週數，用於後續檢測計劃變更
            currentPlanWeek = savedPlan.weekOfPlan
            
            // 計算週日期資訊
            calculateWeekDateInfo(for: savedPlan)
            
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
    
    // 集中處理日期邏輯的核心方法
    private func calculateWeekDateInfo(for plan: WeeklyPlan) {
        let calendar = Calendar.current
        
        // 如果沒有創建日期，無法計算
        guard let createdAt = plan.createdAt else {
            print("計劃沒有創建日期，無法計算週日期範圍")
            currentWeekDateInfo = nil
            return
        }
        
        // 調試輸出
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        print("計劃創建日期: \(formatter.string(from: createdAt))")
        
        // 步驟1: 確定創建日期是星期幾 (1=週一, 7=週日)
        let creationWeekday = calendar.component(.weekday, from: createdAt)
        // 將1-7(週日-週六)轉換為1-7(週一-週日)
        let adjustedCreationWeekday = creationWeekday == 1 ? 7 : creationWeekday - 1
        print("創建日期是週 \(adjustedCreationWeekday)")
        
        // 步驟2: 決定要使用的週一日期
        let isCreatedOnSunday = adjustedCreationWeekday == 7
        
        var targetWeekMonday: Date
        
        if isCreatedOnSunday {
            // 如果是週日創建的，計算下一週的週一 (創建日期+1天)
            print("週日產生的計劃，日期範圍從下週開始")
            guard let nextMonday = calendar.date(byAdding: .day, value: 1, to: createdAt) else {
                print("無法計算下週一日期")
                currentWeekDateInfo = nil
                return
            }
            targetWeekMonday = nextMonday
        } else {
            // 如果是週一到週六創建的，找到當週的週一
            print("非週日產生的計劃，日期範圍從當週開始")
            let daysToSubtract = adjustedCreationWeekday - 1 // 週一不需要減
            guard let currentMonday = calendar.date(byAdding: .day, value: -daysToSubtract, to: createdAt) else {
                print("無法計算當週一日期")
                currentWeekDateInfo = nil
                return
            }
            targetWeekMonday = currentMonday
        }
        
        // 設置當天的開始時間為凌晨00:00:00
        let startOfMonday = calendar.startOfDay(for: targetWeekMonday)
        
        // 步驟3: 計算該週的週日日期和結束時間
        guard let weekSunday = calendar.date(byAdding: .day, value: 6, to: startOfMonday),
              let endOfSunday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: weekSunday) else {
            print("無法計算週日日期")
            currentWeekDateInfo = nil
            return
        }
        
        // 步驟4: 生成所有日期的映射 (1-7 對應週一到週日)
        var daysMap: [Int: Date] = [:]
        for dayIndex in 1...7 {
            if let date = calendar.date(byAdding: .day, value: dayIndex - 1, to: startOfMonday) {
                daysMap[dayIndex] = date
            }
        }
        
        // 創建週日期信息對象
        let weekDateInfo = WeekDateInfo(
            startDate: startOfMonday,
            endDate: endOfSunday,
            daysMap: daysMap
        )
        
        // 更新當前週日期信息
        self.currentWeekDateInfo = weekDateInfo
        
        // 輸出計算結果供除錯
        print("計算的週日期範圍 - 開始: \(formatter.string(from: startOfMonday)), 結束: \(formatter.string(from: endOfSunday))")
        
        // 額外檢查每天的日期
        print("計算的日期映射:")
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "MM/dd (E)"
        for (dayIndex, date) in daysMap {
            print("  星期\(["一", "二", "三", "四", "五", "六", "日"][dayIndex-1]): \(shortFormatter.string(from: date))")
        }
    }
    
    // 獲取當前週的日期範圍 (用於獲取訓練記錄)
    func getCurrentWeekDates() -> (Date, Date) {
        // 如果已經計算過週日期信息，直接使用
        if let dateInfo = currentWeekDateInfo {
            return (dateInfo.startDate, dateInfo.endDate)
        }
        
        // 如果有課表但還沒計算過，重新計算
        if let plan = weeklyPlan {
            calculateWeekDateInfo(for: plan)
            if let dateInfo = currentWeekDateInfo {
                return (dateInfo.startDate, dateInfo.endDate)
            }
        }
        
        // 默認情況：返回當前自然週的範圍
        let calendar = Calendar.current
        let today = Date()
        
        // 找到本週的週一
        let weekday = calendar.component(.weekday, from: today)
        let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
        let daysToSubtract = adjustedWeekday - 1
        
        // 週一日期
        let startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: calendar.startOfDay(for: today))!
        
        // 週日日期 (週一加6天)
        let endDate = calendar.date(byAdding: .day, value: 6, to: startDate)!
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate)!
        
        print("使用當前自然週範圍: \(startDate) - \(endOfDay)")
        
        return (startDate, endOfDay)
    }
    
    // 獲取特定課表日的日期
    func getDateForDay(dayIndex: Int) -> Date? {
        // 如果已經計算過週日期信息，直接從映射中獲取
        if let dateInfo = currentWeekDateInfo {
            return dateInfo.getDateForDayIndex(dayIndex)
        }
        
        // 如果有課表但還沒計算過，重新計算
        if let plan = weeklyPlan {
            calculateWeekDateInfo(for: plan)
            return currentWeekDateInfo?.getDateForDayIndex(dayIndex)
        }
        
        return nil
    }
    
    // 判斷特定課表日是否為今天
    func isToday(dayIndex: Int, planWeek: Int) -> Bool {
        guard let date = getDateForDay(dayIndex: dayIndex) else {
            return false
        }
        
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }
    
    // 修正的 loadTrainingOverview 方法
    func loadTrainingOverview() async {
        print("開始載入訓練計劃概覽")
        
        // 將概覽加載任務隔離，避免影響其他操作
        do {
            // 直接嘗試從 API 獲取最新數據
            let overview = try await TrainingPlanService.shared.getTrainingPlanOverview()
            
            // 成功獲取後更新 UI
            await MainActor.run {
                self.trainingOverview = overview
            }
            
            print("成功載入訓練計劃概覽")
        } catch {
            print("載入訓練計劃概覽失敗: \(error)")
            
            // 如果 API 獲取失敗，嘗試從本地存儲加載
            let savedOverview = TrainingPlanStorage.loadTrainingPlanOverview()
            if !savedOverview.trainingPlanName.isEmpty {
                print("從本地存儲載入訓練計劃概覽")
                await MainActor.run {
                    self.trainingOverview = savedOverview
                }
            }
        }
    }

    // 用於 TrainingPlanView 中展示訓練計劃名稱
    var trainingPlanName: String {
        if let overview = trainingOverview, !overview.trainingPlanName.isEmpty {
            return overview.trainingPlanName
        }
        return "第\(weeklyPlan?.weekOfPlan ?? 0)週訓練計劃"
    }

    // 在產生新週計劃時更新概覽
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
                
                // 檢查計劃週數是否變更
                let planWeekChanged = currentPlanWeek != newPlan.weekOfPlan
                
                // 更新當前計劃週數
                currentPlanWeek = newPlan.weekOfPlan
                
                // 重新計算週日期信息
                calculateWeekDateInfo(for: newPlan)
                
                await MainActor.run {
                    weeklyPlan = newPlan
                    error = nil
                    
                    // 如果計劃週數已變更，清除舊的訓練記錄和展開狀態
                    if planWeekChanged {
                        print("產生新週課表後，清除舊的訓練記錄")
                        workoutsByDay.removeAll()
                        expandedDayIndices.removeAll()
                    }
                }
                
                // 重新載入訓練計劃概覽，確保獲取最新資訊
                print("重新載入訓練計劃概覽")
                await loadTrainingOverview()
                
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
    
    func refreshWeeklyPlan(healthKitManager: HealthKitManager) async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        let maxRetries = 3
        var currentRetry = 0
        
        while currentRetry < maxRetries {
            do {
                print("開始更新計劃 (嘗試 \(currentRetry + 1)/\(maxRetries))")
                let newPlan = try await TrainingPlanService.shared.getWeeklyPlan()
                
                // 檢查計劃週數是否變更
                let planWeekChanged = currentPlanWeek != nil && currentPlanWeek != newPlan.weekOfPlan
                
                // 更新當前計劃週數
                currentPlanWeek = newPlan.weekOfPlan
                
                // 重新計算週日期信息
                calculateWeekDateInfo(for: newPlan)
                
                await MainActor.run {
                    weeklyPlan = newPlan
                    error = nil
                    
                    // 如果計劃週數已變更，清除舊的訓練記錄和展開狀態
                    if planWeekChanged {
                        print("偵測到計劃週數變更，清除舊的訓練記錄")
                        workoutsByDay.removeAll()
                        expandedDayIndices.removeAll()
                    }
                }
                print("完成更新計劃")
                
                // 更新訓練計劃概覽
                await loadTrainingOverview()
                
                if newPlan.totalDistance > 0 {
                    await loadCurrentWeekDistance(healthKitManager: healthKitManager)
                }
                
                await loadVDOTData()
                
                // 重新載入訓練記錄
                await loadWorkoutsForCurrentWeek(healthKitManager: healthKitManager)
                await identifyTodayTraining()
                
                break // 成功後跳出重試迴圈
            } catch {
                currentRetry += 1
                if currentRetry >= maxRetries {
                    await MainActor.run {
                        self.error = error
                        print("刷新訓練計劃失敗 (已重試 \(maxRetries) 次): \(error)")
                    }
                } else {
                    print("刷新訓練計劃失敗，準備重試: \(error)")
                    try? await Task.sleep(nanoseconds: UInt64(1_000_000_000)) // 等待1秒後重試
                }
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    // 修正的載入當前週訓練記錄方法
    func loadWorkoutsForCurrentWeek(healthKitManager: HealthKitManager) async {
        await MainActor.run {
            isLoadingWorkouts = true
        }
        
        do {
            // 獲取當前週的時間範圍
            let (weekStart, weekEnd) = getCurrentWeekDates()
            
            print("載入週訓練記錄 - 週開始: \(formatDebugDate(weekStart)), 週結束: \(formatDebugDate(weekEnd))")
            
            try await healthKitManager.requestAuthorization()
            let workouts = try await healthKitManager.fetchWorkoutsForDateRange(start: weekStart, end: weekEnd)
            
            print("獲取到 \(workouts.count) 條訓練記錄")
            for (index, workout) in workouts.enumerated() {
                print("記錄 \(index+1): 日期 \(formatDebugDate(workout.startDate)), 類型: \(workout.workoutActivityType.rawValue)")
            }
            
            // 按日期分組
            let groupedWorkouts = groupWorkoutsByDay(workouts)
            
            print("分組後的訓練記錄:")
            for (day, dayWorkouts) in groupedWorkouts {
                print("星期\(["一", "二", "三", "四", "五", "六", "日"][day-1]): \(dayWorkouts.count) 條記錄")
            }
            
            // 檢查今天的運動記錄
            let calendar = Calendar.current
            let today = Date()
            let todayWeekday = calendar.component(.weekday, from: today)
            let todayIndex = todayWeekday == 1 ? 7 : todayWeekday - 1  // 轉換為1-7代表週一到週日
            
            if let todayWorkouts = groupedWorkouts[todayIndex], !todayWorkouts.isEmpty {
                print("今天(星期\(["一", "二", "三", "四", "五", "六", "日"][todayIndex-1]))有 \(todayWorkouts.count) 條訓練記錄")
            } else {
                print("今天沒有訓練記錄")
            }
            
            // 更新 UI
            await MainActor.run {
                self.workoutsByDay = groupedWorkouts
                self.isLoadingWorkouts = false
            }
            
        } catch {
            print("載入訓練記錄時出錯: \(error)")
            
            await MainActor.run {
                self.isLoadingWorkouts = false
            }
        }
    }

    // 改進的按日期分組方法
    private func groupWorkoutsByDay(_ workouts: [HKWorkout]) -> [Int: [HKWorkout]] {
        let calendar = Calendar.current
        var grouped: [Int: [HKWorkout]] = [:]
        
        // 定義跑步相關的活動類型
        let runningActivityTypes: [HKWorkoutActivityType] = [
            .running,
            .walking,
            .hiking,
            .trackAndField,
            .crossTraining
        ]
        
        for workout in workouts {
            // 只處理跑步相關的鍛煉
            guard runningActivityTypes.contains(workout.workoutActivityType) else {
                continue
            }
            
            let weekday = calendar.component(.weekday, from: workout.startDate)
            // 轉換 weekday 為 1-7（週一到週日）
            let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
            
            if grouped[adjustedWeekday] == nil {
                grouped[adjustedWeekday] = []
            }
            grouped[adjustedWeekday]?.append(workout)
        }
        
        // 對每天的運動記錄按日期排序（最新的在前面）
        for (day, dayWorkouts) in grouped {
            grouped[day] = dayWorkouts.sorted { $0.startDate > $1.startDate }
        }
        
        return grouped
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
            
            // 獲取當前週的時間範圍
            let (weekStart, weekEnd) = getCurrentWeekDates()
            
            // 獲取指定時間範圍內的鍛煉
            let workouts = try await healthKitManager.fetchWorkoutsForDateRange(start: weekStart, end: weekEnd)
            
            // 計算跑步距離總和
            let totalDistance = calculateTotalDistance(workouts)
            
            // 更新UI
            await MainActor.run {
                self.currentWeekDistance = totalDistance
            }
            
        } catch {
            print("加載本週跑量時出錯: \(error)")
        }
        
        await MainActor.run {
            isLoadingDistance = false
        }
    }
    
    // 加載VDOT數據
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
    
    
    // 判斷是否應該顯示產生下週課表按鈕
    func shouldShowNextWeekButton(plan: WeeklyPlan) -> Bool {
        // 獲取當前週的日期範圍
        let (_, weekEnd) = getCurrentWeekDates()
        
        let calendar = Calendar.current
        let now = Date()
        
        // 當前日期是否是當前計劃週數的週日
        let isCurrentWeekSunday = calendar.isDate(now, equalTo: weekEnd, toGranularity: .day)
        
        // 檢查還有沒有下一週
        let hasNextWeek = plan.weekOfPlan < plan.totalWeeks
        
        return isCurrentWeekSunday && hasNextWeek
    }
    
    // 輔助方法
    private func calculateTotalDistance(_ workouts: [HKWorkout]) -> Double {
        var total = 0.0
        for workout in workouts {
            if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                total += distance / 1000 // 轉換為公里
            }
        }
        return total
    }
    
    // 格式化工具方法
    func formatDistance(_ distance: Double) -> String {
        return String(format: "%.2f km", distance)
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
    
    // 用於除錯的日期格式化工具
    private func formatDebugDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
