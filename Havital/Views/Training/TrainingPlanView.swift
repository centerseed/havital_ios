import SwiftUI
import HealthKit
import Combine

struct TrainingPlanView: View {
    @State private var weeklyPlan: WeeklyPlan?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showUserProfile = false
    @State private var showOnboardingConfirmation = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentWeekDistance: Double = 0.0
    @State private var isLoadingDistance = false
    @State private var currentVDOT: Double = 0.0
    @State private var targetVDOT: Double = 0.0
    @State private var isLoadingVDOT = false
    @State private var showNextWeekPlanningSheet = false
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    // 新增：追蹤哪些日子被展開的狀態
    @State private var expandedDayIndices = Set<Int>()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Weekly Plan Section
                    Group {
                        if isLoading {
                            ProgressView("載入訓練計劃中...")
                                .foregroundColor(.gray)
                                .frame(height: 200)
                        } else if let plan = weeklyPlan {
                            weeklyPlanContent(plan)
                        } else if let error = error {
                            VStack {
                                Text("載入失敗")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(error.localizedDescription)
                                    .font(.body)
                                    .foregroundColor(.red)
                                Button("重試") {
                                    Task {
                                        await refreshWeeklyPlan()
                                    }
                                }
                                .foregroundColor(.blue)
                                .padding()
                            }
                            .padding()
                            .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .background(Color.black)
            .refreshable {
                await refreshWeeklyPlan()
            }
            .navigationTitle("第\(weeklyPlan?.weekOfPlan ?? 0)週訓練計劃")
            .navigationBarTitleDisplayMode(.inline)
            .foregroundColor(.white)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showUserProfile = true
                        }) {
                            Label("用戶資訊", systemImage: "person.circle")
                        }
                        Button(action: {
                            showOnboardingConfirmation = true
                        }) {
                            Label("重新OnBoarding", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                    }
                }
            }
            .confirmationDialog(
                "確定要重新開始OnBoarding流程嗎？",
                isPresented: $showOnboardingConfirmation,
                titleVisibility: .visible
            ) {
                Button("確定", role: .destructive) {
                    hasCompletedOnboarding = false
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("這將會重置您的所有訓練設置，需要重新設定您的訓練偏好。")
            }
        }
        .task {
            await loadWeeklyPlan()
            await loadVDOTData()
            // 新增：識別當天的訓練，自動展開
            identifyTodayTraining()
        }
        .sheet(isPresented: $showUserProfile) {
            NavigationView {
                UserProfileView()
            }
        }
    }
    
    // 新增：識別並自動展開當天的訓練
    private func identifyTodayTraining() {
        if let plan = weeklyPlan {
            for day in plan.days {
                if isToday(dayIndex: day.dayIndex, planWeek: plan.weekOfPlan) {
                    expandedDayIndices.insert(day.dayIndex)
                    break
                }
            }
        }
    }
    
    @ViewBuilder
    private func weeklyPlanContent(_ plan: WeeklyPlan) -> some View {
        VStack(spacing: 20) {
            // Week Overview Section
            VStack(alignment: .leading, spacing: 16) {
                Text("本週概覽")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                
                VStack(spacing: 16) {
                    // 使用GeometryReader动态计算和分配空间
                    GeometryReader { geometry in
                        HStack(alignment: .center, spacing: 0) {
                            // 训练周期进度
                            VStack(spacing: 6) {
                                CircularProgressView(
                                    progress: Double(plan.weekOfPlan) / Double(plan.totalWeeks),
                                    currentWeek: plan.weekOfPlan,
                                    totalWeeks: plan.totalWeeks
                                )
                                .frame(width: 80, height: 80)
                                
                                Text("訓練進度")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .frame(width: geometry.size.width / 2)
                            
                            // 如果有周跑量目标，显示第二个圆形进度条
                            VStack(spacing: 6) {
                                if isLoadingDistance {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                        .scaleEffect(1.0)
                                        .frame(width: 80, height: 80)
                                } else {
                                    // 周跑量圆形进度条
                                    ZStack {
                                        // 背景圆环
                                        Circle()
                                            .stroke(lineWidth: 8)
                                            .opacity(0.3)
                                            .foregroundColor(.blue)
                                        
                                        // 进度圆环
                                        Circle()
                                            .trim(from: 0.0, to: min(CGFloat(currentWeekDistance / max(plan.totalDistance, 1.0)), 1.0))
                                            .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                                            .foregroundColor(.blue)
                                            .rotationEffect(Angle(degrees: 270.0))
                                            .animation(.linear, value: currentWeekDistance)
                                        
                                        // 中间的文字
                                        VStack(spacing: 2) {
                                            Text("\(String(format: "%.1f", currentWeekDistance))")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                            
                                            Text("\(formatDistance(plan.totalDistance))")
                                                .font(.system(size: 10))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .frame(width: 80, height: 80)
                                }
                                
                                Text("本週跑量")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .frame(width: geometry.size.width / 2)
                        }
                        .frame(width: geometry.size.width)
                    }
                    .frame(height: 100)
                    
                    // 訓練目的
                    VStack(alignment: .leading, spacing: 2) {
                        Text("週目標")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        
                        Text(plan.purpose)
                            .font(.body)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 顯示「產生下週課表」按鈕 (根據新的條件)
                    if shouldShowNextWeekButton(plan: plan) {
                        Button(action: {
                            generateNextWeekPlan()
                        }) {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 16))
                                Text("產生第\(plan.weekOfPlan + 1)週課表")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .padding(.top, 12)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                .cornerRadius(12)
            }
            
            // Daily Training Section
            VStack(alignment: .leading, spacing: 16) {
                Text("每日訓練")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                
                // 新增：先找出今天的訓練
                let todayTrainings = plan.days.filter { day in
                    isToday(dayIndex: day.dayIndex, planWeek: plan.weekOfPlan)
                }
                
                // 新增：顯示今天的訓練（如果有）
                if let todayTraining = todayTrainings.first {
                    dailyTrainingCard(todayTraining, isToday: true)
                        .transition(.opacity)
                }
                
                // 新增：顯示其他天的訓練（非今天）
                ForEach(plan.days.filter { day in
                    !isToday(dayIndex: day.dayIndex, planWeek: plan.weekOfPlan)
                }) { day in
                    dailyTrainingCard(day, isToday: false)
                        .transition(.opacity)
                }
            }
        }
        .task {
            if plan.totalDistance > 0 {
                await loadCurrentWeekDistance()
            }
        }
        .onAppear {
            if currentVDOT == 0 {
                Task {
                    await loadVDOTData()
                }
            }
        }
    }
    
    // 修改：改為根據展開狀態顯示不同內容的訓練卡片
    private func dailyTrainingCard(_ day: TrainingDay, isToday: Bool) -> some View {
        let isExpanded = isToday || expandedDayIndices.contains(day.dayIndex)
        
        return VStack(alignment: .leading, spacing: 12) {
            // 點擊標題欄可切換展開/摺疊狀態
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedDayIndices.contains(day.dayIndex) {
                        expandedDayIndices.remove(day.dayIndex)
                    } else {
                        expandedDayIndices.insert(day.dayIndex)
                    }
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(weekdayName(for: day.dayIndex))
                                .font(.headline)
                                .foregroundColor(.white)
                            if isToday {
                                Text("今天")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .cornerRadius(4)
                            }
                        }
                        
                        // 添加具體日期顯示
                        if let date = getDateForDay(dayIndex: day.dayIndex) {
                            Text(formatShortDate(date))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    if day.isTrainingDay {
                        Text({
                            switch day.type {
                            case .easyRun, .easy: return "輕鬆"
                            case .interval: return "間歇"
                            case .tempo: return "節奏"
                            case .longRun: return "長跑"
                            case .race: return "比賽"
                            case .rest: return "休息"
                            case .crossTraining: return "交叉訓練"
                            }
                        }())
                        .font(.subheadline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundColor({
                            switch day.type {
                            case .easyRun, .easy: return Color.green
                            case .interval, .tempo: return Color.orange
                            case .longRun: return Color.blue
                            case .race: return Color.red
                            case .rest: return Color.gray
                            case .crossTraining: return Color.purple
                            }
                        }())
                        .background({
                            switch day.type {
                            case .easyRun, .easy: return Color.green.opacity(0.2)
                            case .interval, .tempo: return Color.orange.opacity(0.2)
                            case .longRun: return Color.blue.opacity(0.2)
                            case .race: return Color.red.opacity(0.2)
                            case .rest: return Color.gray.opacity(0.2)
                            case .crossTraining: return Color.purple.opacity(0.2)
                            }
                        }())
                        .cornerRadius(8)
                    }
                    
                    // 新增：展開/摺疊指示器
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                        .font(.caption)
                        .padding(.leading, 4)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // 新增：條件性顯示詳細內容
            if isExpanded {
                // 完整顯示
                VStack(alignment: .leading, spacing: 12) {
                    // 分隔線
                    Divider()
                        .background(Color.gray.opacity(0.3))
                        .padding(.vertical, 4)
                    
                    Text(day.dayTarget)
                        .font(.body)
                        .foregroundColor(.white)
                    
                    if day.isTrainingDay, let trainingItems = day.trainingItems {
                        // For interval training, show a special header with repeats info
                        if day.type == .interval, trainingItems.count > 0, let repeats = trainingItems[0].goals.times {
                            HStack {
                                Text("間歇訓練")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                                Spacer()
                                Text("\(repeats) × 重複")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.15))
                                    .cornerRadius(12)
                            }
                            .padding(.top, 4)
                        }
                        
                        // Show each training item
                        ForEach(trainingItems) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.name)
                                        .font(.subheadline)
                                        .fontWeight(day.type == .interval ? .medium : .regular)
                                        .foregroundColor(day.type == .interval ? .orange : .blue)
                                    
                                    if day.type == .interval, let times = item.goals.times {
                                        Text("× \(times)")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                            .padding(.leading, -4)
                                    }
                                    
                                    Spacer()
                                    
                                    // Show the pace and distance in a pill for all training types
                                    HStack(spacing: 2) {
                                        if let pace = item.goals.pace {
                                            Text(pace)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(day.type == .interval ? .orange : .blue)
                                        }
                                        if let distance = item.goals.distanceKm {
                                            Text("/ \(String(format: "%.1f", distance)) km")
                                                .font(.caption)
                                                .foregroundColor(day.type == .interval ? .orange : .blue)
                                        }
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(day.type == .interval ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                                    .cornerRadius(12)
                                    .opacity((item.goals.pace != nil || item.goals.distanceKm != nil) ? 1 : 0)
                                }
                            }
                            
                            Text(item.runDetails)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            } else {
                // 摺疊時只顯示簡短摘要
                Text(day.dayTarget)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(isToday ? Color(red: 0.15, green: 0.2, blue: 0.25) : Color(red: 0.15, green: 0.15, blue: 0.15))
        .cornerRadius(12)
    }
    
    private func loadCurrentWeekDistance() async {
        isLoadingDistance = true
        defer { isLoadingDistance = false }
        
        do {
            try await healthKitManager.requestAuthorization()
            
            // 获取当前周的时间范围（周一到周日）
            let (weekStart, weekEnd) = getCurrentWeekDates()
            
            // 获取指定时间范围内的锻炼
            let workouts = try await healthKitManager.fetchWorkoutsForDateRange(start: weekStart, end: weekEnd)
            
            // 计算跑步距离总和
            var totalDistance = 0.0
            for workout in workouts {
                if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                    totalDistance += distance / 1000 // 转换为千米
                }
            }
            
            // 更新UI
            await MainActor.run {
                self.currentWeekDistance = totalDistance
            }
            
        } catch {
            print("加载本周跑量时出错: \(error)")
        }
    }
    
    // 获取当前周的开始日期（周一）和结束日期（周日）
    private func getCurrentWeekDates() -> (Date, Date) {
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
    
    private func formatDistance(_ distance: Double) -> String {
        return String(format: "%.1f公里", distance)
    }
    
    // 格式化日期時間為本地化格式
    private func formatDate(_ date: Date) -> String {
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .long
        outputFormatter.timeStyle = .short
        outputFormatter.locale = Locale(identifier: "zh_TW")
        
        return outputFormatter.string(from: date)
    }
    
    // 格式化為簡短日期格式（僅月份和日期）
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    // 加载VDOT数据
    private func loadVDOTData() async {
        isLoadingVDOT = true
        defer { isLoadingVDOT = false }
        
        // 簡化處理：使用默認值
        await MainActor.run {
            self.currentVDOT = 40.0
            self.targetVDOT = 45.0
        }
    }
    
    // 获取最近的跑步记录
    private func fetchRecentRunningWorkouts() async throws -> [HKWorkout] {
        let calendar = Calendar.current
        let now = Date()
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now)!
        
        try await healthKitManager.requestAuthorization()
        return try await healthKitManager.fetchWorkoutsForDateRange(start: threeMonthsAgo, end: now)
    }
    
    // 找出最佳表现的跑步
    private func findBestPerformanceWorkout(workouts: [HKWorkout]) -> HKWorkout? {
        // 只考虑跑步类型的锻炼
        let runningWorkouts = workouts.filter { workout in
            workout.workoutActivityType == .running &&
            workout.totalDistance != nil &&
            workout.duration > 0
        }
        
        if runningWorkouts.isEmpty {
            return nil
        }
        
        return runningWorkouts.min { workoutA, workoutB in
            let paceA = workoutA.duration / (workoutA.totalDistance?.doubleValue(for: .meter()) ?? 1)
            let paceB = workoutB.duration / (workoutB.totalDistance?.doubleValue(for: .meter()) ?? 1)
            return paceA < paceB
        }
    }
    
    private func loadWeeklyPlan() async {
        isLoading = true
        defer { isLoading = false }
        
        // 直接从存储加载周计划
        if let savedPlan = TrainingPlanStorage.loadWeeklyPlan() {
            weeklyPlan = savedPlan
            error = nil
        } else {
            error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法載入週訓練計劃"])
        }
    }
    
    private func refreshWeeklyPlan() async {
        do {
            let newPlan = try await TrainingPlanService.shared.getWeeklyPlan()
            weeklyPlan = newPlan
            error = nil
            if newPlan.totalDistance > 0 {
                await loadCurrentWeekDistance()
            }
            await loadVDOTData()
            
            // 識別當天的訓練，自動展開
            identifyTodayTraining()
        } catch {
            self.error = error
            print("刷新訓練計劃失敗: \(error)")
        }
    }
    
    private func weekdayName(for index: Int) -> String {
        let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
        return "星期" + weekdays[index - 1]
    }
    
    // 判斷是否為今天
    private func isToday(dayIndex: Int, planWeek: Int) -> Bool {
        guard let date = getDateForDay(dayIndex: dayIndex) else {
            return false
        }
        
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }
    
    // 獲取特定天的日期
    private func getDateForDay(dayIndex: Int) -> Date? {
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
    
    // 判斷是否應該顯示產生下週課表按鈕
    private func shouldShowNextWeekButton(plan: WeeklyPlan) -> Bool {
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
    
    // 產生下週計劃
    private func generateNextWeekPlan() {
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
        
        Task { @MainActor in
            isLoading = true
            
            do {
                print("開始產生第 \(nextWeek) 週課表...")
                _ = try await TrainingPlanService.shared.createWeeklyPlan(targetWeek: nextWeek)
                
                // 產生成功後重新載入課表
                do {
                    let newPlan = try await TrainingPlanService.shared.getWeeklyPlan()
                    weeklyPlan = newPlan
                    error = nil
                    
                    if newPlan.totalDistance > 0 {
                        await loadCurrentWeekDistance()
                    }
                    
                    // 識別當天的訓練，自動展開
                    identifyTodayTraining()
                    
                    print("成功產生第 \(nextWeek) 週課表並更新 UI")
                } catch {
                    print("重新載入課表失敗: \(error)")
                    self.error = error
                }
            } catch {
                print("產生下週課表失敗: \(error)")
                self.error = error
            }
            
            isLoading = false
        }
    }
}

