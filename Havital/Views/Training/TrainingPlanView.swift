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
        }
        .sheet(isPresented: $showUserProfile) {
            NavigationView {
                UserProfileView()
            }
        }
        /*
        .sheet(isPresented: $showNextWeekPlanningSheet) {
            NextWeekPlanningView { feeling, difficulty, days, trainingItem, completion in
                // 當用戶完成下週計劃設定後的回調
                Task {
                    // 產生下週計劃的邏輯（調用 API 等）
                    await generateNextWeekPlan(
                        feeling: feeling,
                        difficulty: difficulty.jsonValue,
                        days: days.jsonValue,
                        trainingItem: trainingItem.jsonValue,
                        completion: completion
                    )
                }
            }
        }*/
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
                                            .trim(from: 0.0, to: min(CGFloat(currentWeekDistance / plan.totalDistance), currentWeekDistance))
                                            .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                                            .foregroundColor(.blue)
                                            .rotationEffect(Angle(degrees: 270.0))
                                            .animation(.linear, value: currentWeekDistance)
                                        
                                        // 中间的文字
                                        VStack(spacing: 2) {
                                            Text("\(String(format: "%.1f", currentWeekDistance))")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                            
                                            Text("\(formatDistance(max(currentWeekDistance, plan.totalDistance)))")
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
                            
                            // VDOT Circle Progress Bar
                            /*
                            VStack(spacing: 6) {
                                if isLoadingVDOT {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .green))
                                        .scaleEffect(1.0)
                                        .frame(width: 80, height: 80)
                                } else {
                                    ZStack {
                                        // 背景圆环
                                        Circle()
                                            .stroke(lineWidth: 8)
                                            .opacity(0.3)
                                            .foregroundColor(.green)
                                        
                                        // VDOT related
                                        if targetVDOT > 0 {
                                            Circle()
                                                .trim(from: 0.0, to: min(CGFloat(currentVDOT / targetVDOT), 1.0))
                                                .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                                                .foregroundColor(.green)
                                                .rotationEffect(Angle(degrees: 270.0))
                                                .animation(.linear, value: currentVDOT)
                                        }
                                        
                                        // current VDOT
                                        VStack(spacing: 2) {
                                            Text(String(format: "%.1f", currentVDOT))
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                            
                                            if targetVDOT > 0 {
                                                Text("目標:\(String(format: "%.1f", targetVDOT))")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                    .frame(width: 80, height: 80)
                                    .
                                }
                                
                                Text("VDOT")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    
                               
                            }
                            .frame(width: geometry.size.width / 2) */
                        }
                        .frame(width: geometry.size.width)
                        
                    }
                    .frame(height: 100) // 设置一个固定高度以容纳进度条和标签
                    
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
                    
                    // 顯示訓練計劃建立時間
                    /*
                    if let createdDate = plan.createdAt {
                        HStack {
                            Text("建立於：")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(formatDate(createdDate))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 8)
                    }*/
                    
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
                
                ForEach(plan.days) { day in
                    dailyTrainingCard(day)
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
    
    // 加载VDOT数据
    private func loadVDOTData() async {
        isLoadingVDOT = true
        defer { isLoadingVDOT = false }
        
        // 尝试获取用户的当前VDOT和目标VDOT
        do {
            // 从UserDefaults或其他存储中获取
            // 通常这类数据可能在用户完成onboarding或设置跑步目标时保存
            let calculator = VDOTCalculator()
            
            // 模拟从用户偏好设置中获取VDOT数据
            // 实际应用中应该从您的用户数据中获取
            if let preference = UserPreferenceManager.shared.getVDOTData() {
                // 如果有存储的值，使用存储的值
                currentVDOT = preference.currentVDOT ?? 40.0
                targetVDOT = preference.targetVDOT ?? 45.0
            } else {
                // 如果没有存储的值，使用默认值或通过其他方法计算
                // 例如，可以根据最近的跑步表现计算
                // 这里为了演示，暂时使用默认值
                currentVDOT = 40.0
                targetVDOT = 45.0
                
                // 如果有训练历史记录，可以基于最近的跑步计算当前VDOT
                let recentWorkouts = try await fetchRecentRunningWorkouts()
                if let bestWorkout = findBestPerformanceWorkout(workouts: recentWorkouts) {
                    if let distance = bestWorkout.totalDistance?.doubleValue(for: .meter()),
                       distance > 1000 { // 只考虑超过1公里的跑步
                        let timeInSeconds = Int(bestWorkout.duration)
                        let distanceInMeters = Int(distance)
                        // 使用VDOT计算器计算VDOT值
                        currentVDOT = calculator.calculateVDOT(distance: distanceInMeters, time: timeInSeconds)
                    }
                }
            }
            
            // 更新UI
            await MainActor.run {
                self.currentVDOT = max(self.currentVDOT, 1.0) // 确保不为零
                self.targetVDOT = max(self.targetVDOT, self.currentVDOT) // 确保目标不低于当前
            }
            
        } catch {
            print("加载VDOT数据时出错: \(error)")
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
        
        // 如果没有有效的跑步记录，返回nil
        if runningWorkouts.isEmpty {
            return nil
        }
        
        // 找出配速最快的跑步（简单示例）
        // 实际应用中可能需要更复杂的算法来确定"最佳表现"
        return runningWorkouts.min { workoutA, workoutB in
            let paceA = workoutA.duration / (workoutA.totalDistance?.doubleValue(for: .meter()) ?? 1)
            let paceB = workoutB.duration / (workoutB.totalDistance?.doubleValue(for: .meter()) ?? 1)
            return paceA < paceB
        }
    }
    
    private func dailyTrainingCard(_ day: TrainingDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(weekdayName(for: day.dayIndex))
                            .font(.headline)
                            .foregroundColor(.white)
                        if isToday(dayIndex: day.dayIndex, planWeek: weeklyPlan?.weekOfPlan ?? 0) {
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
            }
            
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
        .padding()
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
        .cornerRadius(12)
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
        } catch {
            self.error = error
            print("刷新訓練計劃失敗: \(error)")
        }
    }
    
    private func weekdayName(for index: Int) -> String {
        let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
        return "星期" + weekdays[index - 1]
    }
    
    // 判斷是否應該顯示「今天」標籤
    private func isToday(dayIndex: Int, planWeek: Int) -> Bool {
        guard let date = getDateForDay(dayIndex: dayIndex) else {
            return false
        }
        
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }
    
    // 判斷是否應該顯示產生下週課表按鈕
    private func shouldShowNextWeekButton(plan: WeeklyPlan) -> Bool {
        guard let createdDate = plan.createdAt else {
            return false
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        // 1. 檢查當前是否為計劃週數的所屬週的週日
        // 首先獲取計劃對應週數的週一日期（假設計劃從第1週開始）
        let weeksToAdd = plan.weekOfPlan - 1 // 比如第1週就是加0週，第2週就是加1週
        
        // 查找創建日期那週的週一
        let creationWeekday = calendar.component(.weekday, from: createdDate)
        let daysToSubtract = creationWeekday == 1 ? 6 : creationWeekday - 2
        guard let firstWeekMonday = calendar.date(byAdding: .day, value: -daysToSubtract, to: createdDate) else {
            return false
        }
        
        // 計算當前計劃週數的週一
        guard let currentWeekMonday = calendar.date(byAdding: .weekOfYear, value: weeksToAdd, to: firstWeekMonday) else {
            return false
        }
        
        // 計算當前計劃週數的週日
        guard let currentWeekSunday = calendar.date(byAdding: .day, value: 6, to: currentWeekMonday) else {
            return false
        }
        
        // 當前日期是否是當前計劃週數的週日
        let isCurrentWeekSunday = calendar.isDate(now, inSameDayAs: currentWeekSunday)
        
        // 2. 檢查還有沒有下一週
        let hasNextWeek = plan.weekOfPlan < plan.totalWeeks
        
        // 3. 返回結果：如果是當前週的週日且還有下一週，則顯示按鈕
        return isCurrentWeekSunday && hasNextWeek
    }
    
    // 產生下週計劃的方法
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
                
                // 設置 loading 狀態
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
                            
                            print("成功產生第 \(nextWeek) 週課表並更新 UI")
                        } catch {
                            print("重新載入課表失敗: \(error)")
                            self.error = error
                        }
                    } catch {
                        print("產生下週課表失敗: \(error)")
                        self.error = error
                    }
                    
                    // 確保在所有情況下都會結束 loading 狀態
                    isLoading = false
                }
            }
    private func getDateForDay(dayIndex: Int) -> Date? {
        guard let plan = weeklyPlan, let createdDate = plan.createdAt else {
            return nil
        }
        
        let calendar = Calendar.current
        
        // 找到創建日期所在週的週一
        let creationWeekday = calendar.component(.weekday, from: createdDate)
        let daysToSubtract = creationWeekday == 1 ? 6 : creationWeekday - 2
        guard let firstWeekMonday = calendar.date(byAdding: .day, value: -daysToSubtract, to: createdDate) else {
            return nil
        }
        
        // 計算該計劃週的週一日期（第1週就是創建週的週一，第2週就是往後加一週，依此類推）
        let weeksToAdd = plan.weekOfPlan - 1
        guard let currentWeekMonday = calendar.date(byAdding: .weekOfYear, value: weeksToAdd, to: firstWeekMonday) else {
            return nil
        }
        
        // 計算課表中特定weekday對應的日期
        // dayIndex是1到7，分別代表週一到週日，需要減1來得到要加的天數
        return calendar.date(byAdding: .day, value: dayIndex - 1, to: currentWeekMonday)
    }

    // 格式化為簡短日期格式（僅月份和日期）
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}
