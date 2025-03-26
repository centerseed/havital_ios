import SwiftUI
import HealthKit
import UserNotifications

/// 健身記錄同步調試視圖
struct WorkoutSyncDebugView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var pendingCount = 0
    @State private var statusMessage = "閒置中"
    @State private var isLoading = false
    @State private var uploadedCount = 0
    @State private var logMessages: [String] = []
    @State private var showObserverSetupResult = false
    @State private var observerSetupMessage = ""
    @State private var testWorkoutCreated = false
    @State private var workoutID = ""
    @State private var createdWorkouts: [HKWorkout] = []
    @State private var showDeleteConfirmation = false
    @State private var showDeleteTimeRangeSelection = false
    @State private var selectedTimeRange: TimeRange = .oneDay
    @State private var foundWorkouts: [HKWorkout] = []
    @State private var showFoundWorkouts = false
    
    // 時間範圍選項
    enum TimeRange: String, CaseIterable, Identifiable {
        case oneHour = "最近1小時"
        case sixHours = "最近6小時"
        case oneDay = "最近24小時"
        case threeDays = "最近3天"
        case oneWeek = "最近7天"
        case all = "所有記錄"
        
        var id: String { self.rawValue }
        
        var hours: Int? {
            switch self {
            case .oneHour: return 1
            case .sixHours: return 6
            case .oneDay: return 24
            case .threeDays: return 72
            case .oneWeek: return 168
            case .all: return nil
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 狀態摘要卡片
                statusCard
                
                // 測試功能卡片
                testFunctionsCard
                
                // 測試記錄管理卡片
                testDataManagementCard
                
                // 觀察者設置卡片
                observerSetupCard
                
                // 日誌卡片
                logCard
            }
            .padding()
        }
        .onAppear {
            // 進入視圖時重新整理狀態
            refreshStatus()
        }
        .confirmationDialog(
            "確定要刪除測試數據嗎？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("根據時間範圍刪除") {
                showDeleteTimeRangeSelection = true
            }
            
            Button("只刪除已標記測試記錄", role: .destructive) {
                deleteMarkedTestData()
            }
            
            Button("刪除所有數據", role: .destructive) {
                deleteAllTestData()
            }
            
            Button("取消", role: .cancel) {}
        } message: {
            Text("選擇刪除方式。時間範圍刪除可以刪除指定時間內的所有健身記錄。")
        }
        .sheet(isPresented: $showDeleteTimeRangeSelection) {
            // 時間範圍選擇表單
            TimeRangeSelectionView(
                selectedRange: $selectedTimeRange,
                onConfirm: {
                    findWorkoutsInTimeRange()
                },
                onCancel: {
                    showDeleteTimeRangeSelection = false
                }
            )
        }
        .sheet(isPresented: $showFoundWorkouts) {
            // 顯示找到的健身記錄供確認刪除
            FoundWorkoutsView(
                workouts: $foundWorkouts,
                onConfirmDelete: deleteFoundWorkouts,
                onCancel: { showFoundWorkouts = false }
            )
        }
    }
    
    // 狀態摘要卡片
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("同步狀態")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    statusRow(title: "待上傳健身記錄:", value: "\(pendingCount)")
                    statusRow(title: "已上傳健身記錄:", value: "\(uploadedCount)")
                    statusRow(title: "當前狀態:", value: statusMessage)
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                }
            }
            
            Button("重新整理狀態") {
                refreshStatus()
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // 測試功能卡片
    private var testFunctionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("測試功能")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button(action: createTestWorkout) {
                    VStack {
                        Image(systemName: "figure.run")
                            .font(.title2)
                        Text("創建測試健身記錄")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                
                Button(action: triggerManualUpload) {
                    VStack {
                        Image(systemName: "arrow.up.circle")
                            .font(.title2)
                        Text("手動檢查並上傳")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
            }
            
            HStack(spacing: 12) {
                Button(action: testNotifications) {
                    VStack {
                        Image(systemName: "bell")
                            .font(.title2)
                        Text("測試通知")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
                
                Button(action: clearUploadHistory) {
                    VStack {
                        Image(systemName: "trash")
                            .font(.title2)
                        Text("清除上傳歷史")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(isLoading)
            }
            
            if testWorkoutCreated {
                Text("已創建測試健身記錄 ID: \(workoutID)")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // 測試數據管理卡片
    private var testDataManagementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("測試數據管理")
                .font(.headline)
            
            VStack(spacing: 10) {
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                        Text("刪除測試數據")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    // 直接進入時間範圍選擇
                    showDeleteTimeRangeSelection = true
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue)
                        Text("查找健身記錄")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            Text("刪除功能會移除 HealthKit 中的健身記錄。請謹慎操作，刪除後無法恢復。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // 觀察者設置卡片
    private var observerSetupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HealthKit 觀察者設置")
                .font(.headline)
            
            Button("測試觀察者設置") {
                testObserverSetup()
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)
            
            if showObserverSetupResult {
                Text(observerSetupMessage)
                    .font(.caption)
                    .padding(.top, 4)
                    .foregroundColor(observerSetupMessage.contains("成功") ? .green : .red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // 日誌卡片
    private var logCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("操作日誌")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    logMessages.removeAll()
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(logMessages, id: \.self) { message in
                        Text(message)
                            .font(.caption)
                    }
                }
            }
            .frame(height: 200)
            .padding()
            .background(Color(.systemGray5))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // 狀態行
    private func statusRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.body)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - 測試功能方法
    
    /// 重新整理狀態
    private func refreshStatus() {
        isLoading = true
        addLog("重新整理狀態...")
        
        Task {
            // 獲取待上傳記錄數量
            pendingCount = await WorkoutBackgroundManager.shared.getPendingWorkoutsCount()
            
            // 獲取已上傳記錄數量
            uploadedCount = WorkoutUploadTracker.shared.getUploadedWorkoutsCount()
            
            await MainActor.run {
                statusMessage = "已重新整理"
                isLoading = false
                addLog("狀態重新整理完成：待上傳 \(pendingCount)，已上傳 \(uploadedCount)")
            }
        }
    }
    
    /// 創建測試健身記錄
    private func createTestWorkout() {
        isLoading = true
        statusMessage = "創建測試記錄中..."
        addLog("創建測試健身記錄...")
        testWorkoutCreated = false
        
        Task {
            if let workout = await createMockWorkout() {
                createdWorkouts.append(workout)
            }
            
            await MainActor.run {
                isLoading = false
                statusMessage = "測試記錄已創建"
                testWorkoutCreated = true
                refreshStatus()
            }
        }
    }
    
    /// 創建模擬健身記錄
    private func createMockWorkout() async -> HKWorkout? {
        let healthStore = HKHealthStore()
        
        // 檢查授權
        do {
            try await healthKitManager.requestAuthorization()
            
            // 創建一個跑步記錄
            let startDate = Date().addingTimeInterval(-1800) // 30分鐘前
            let endDate = Date().addingTimeInterval(-300) // 5分鐘前
            
            // 創建健身記錄對象
            let workout = HKWorkout(
                activityType: .running,
                start: startDate,
                end: endDate,
                duration: 1500, // 25分鐘
                totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 200),
                totalDistance: HKQuantity(unit: .meter(), doubleValue: 3000),
                metadata: ["TestWorkout": "true"] // 標記為測試記錄，方便以後刪除
            )
            
            // 儲存到 HealthKit
            do {
                try await healthStore.save(workout)
                workoutID = workout.uuid.uuidString
                addLog("測試健身記錄已創建: ID = \(workoutID)")
                
                // 創建心率數據
                await createHeartRateSamples(for: workout, store: healthStore)
                
                return workout
            } catch {
                addLog("創建測試健身記錄失敗: \(error.localizedDescription)")
                return nil
            }
        } catch {
            addLog("HealthKit 授權失敗: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 創建心率樣本
    private func createHeartRateSamples(for workout: HKWorkout, store: HKHealthStore) async {
        // 確認有心率類型的讀寫權限
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        // 創建一些模擬的心率數據
        let startDate = workout.startDate
        let endDate = workout.endDate
        let duration = endDate.timeIntervalSince(startDate)
        let samples = 20 // 創建20個心率樣本
        
        var heartRateSamples: [HKQuantitySample] = []
        
        for i in 0..<samples {
            let timeOffset = duration * Double(i) / Double(samples)
            let sampleDate = startDate.addingTimeInterval(timeOffset)
            
            // 模擬心率值，從120到160之間變化
            let heartRateValue = 120.0 + 40.0 * sin(Double(i) / Double(samples) * .pi)
            let heartRateQuantity = HKQuantity(unit: HKUnit(from: "count/min"), doubleValue: heartRateValue)
            
            let sample = HKQuantitySample(
                type: heartRateType,
                quantity: heartRateQuantity,
                start: sampleDate,
                end: sampleDate,
                metadata: ["TestSample": "true"] // 標記為測試樣本
            )
            
            heartRateSamples.append(sample)
        }
        
        // 保存心率樣本
        do {
            try await store.save(heartRateSamples)
            addLog("已創建 \(heartRateSamples.count) 個心率樣本")
        } catch {
            addLog("創建心率樣本失敗: \(error.localizedDescription)")
        }
    }
    
    /// 手動觸發上傳過程
    private func triggerManualUpload() {
        isLoading = true
        statusMessage = "正在檢查並上傳..."
        addLog("手動觸發健身記錄上傳...")
        
        Task {
            await WorkoutBackgroundManager.shared.checkAndUploadPendingWorkouts()
            
            await MainActor.run {
                isLoading = false
                statusMessage = "上傳過程完成"
                addLog("手動上傳過程已完成")
                refreshStatus()
            }
        }
    }
    
    /// 測試通知功能
    private func testNotifications() {
        addLog("測試通知功能...")
        
        // 創建一個模擬的 HKWorkout
        let startDate = Date().addingTimeInterval(-3600)
        let endDate = Date()
        let workout = HKWorkout(
            activityType: .running,
            start: startDate,
            end: endDate,
            duration: 3600,
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 300),
            totalDistance: HKQuantity(unit: .meter(), doubleValue: 5000),
            metadata: nil
        )
        
        // 發送通知
        Task {
            // 使用我們自己的方法發送測試通知，而不是 WorkoutBackgroundManager 的方法
            await sendTestNotification(for: workout)
            addLog("測試通知已發送")
        }
    }
    
    /// 發送測試通知
    private func sendTestNotification(for workout: HKWorkout) async {
        // 格式化日期和時間
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dateTimeString = dateFormatter.string(from: workout.startDate)
        
        // 格式化距離（如果有）
        var distanceString = ""
        if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
            if distance >= 1000 {
                distanceString = String(format: "%.2f 公里", distance / 1000)
            } else {
                distanceString = String(format: "%.0f 公尺", distance)
            }
        }
        
        // 創建通知內容
        let content = UNMutableNotificationContent()
        content.title = "測試通知 - 運動資料已同步"
        content.body = "\(workout.workoutActivityType.name) (\(dateTimeString)) \(distanceString) 已成功上傳到雲端"
        content.sound = UNNotificationSound.default
        
        // 設置觸發器（立即顯示）
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // 創建請求
        let request = UNNotificationRequest(
            identifier: "workout-test-notification-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        // 添加通知請求
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("已發送測試通知")
        } catch {
            print("發送測試通知失敗: \(error.localizedDescription)")
        }
    }
    
    /// 測試觀察者設置
    private func testObserverSetup() {
        isLoading = true
        addLog("測試 HealthKit 觀察者設置...")
        
        Task {
            do {
                try await WorkoutBackgroundManager.shared.setupWorkoutObserver()
                
                await MainActor.run {
                    observerSetupMessage = "觀察者設置成功"
                    showObserverSetupResult = true
                    addLog("HealthKit 觀察者設置成功")
                }
            } catch {
                await MainActor.run {
                    observerSetupMessage = "觀察者設置失敗: \(error.localizedDescription)"
                    showObserverSetupResult = true
                    addLog("HealthKit 觀察者設置失敗: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    /// 清除上傳歷史
    private func clearUploadHistory() {
        addLog("清除健身記錄上傳歷史...")
        WorkoutUploadTracker.shared.clearUploadedWorkouts()
        addLog("上傳歷史已清除")
        refreshStatus()
    }
    
    /// 只刪除已標記的測試數據
    private func deleteMarkedTestData() {
        isLoading = true
        statusMessage = "刪除標記的測試記錄..."
        addLog("開始刪除標記的測試健身記錄...")
        
        Task {
            // 從追蹤列表中刪除
            for workout in createdWorkouts {
                await deleteHealthWorkout(workout)
            }
            
            // 嘗試查找並刪除所有標記為測試記錄的健身數據
            await findAndDeleteTestWorkouts()
            
            createdWorkouts.removeAll()
            
            await MainActor.run {
                isLoading = false
                statusMessage = "標記的測試健身記錄已刪除"
                addLog("標記的測試健身記錄已刪除")
                refreshStatus()
            }
        }
    }
    
    /// 查找並刪除所有標記為測試的健身記錄
    private func findAndDeleteTestWorkouts() async {
        let healthStore = HKHealthStore()
        
        do {
            // 創建一個查詢來查找所有標記為測試記錄的健身數據
            let predicate = HKQuery.predicateForObjects(withMetadataKey: "TestWorkout")
            
            // 獲取所有標記的健身記錄
            let workouts = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
                let query = HKSampleQuery(
                    sampleType: HKObjectType.workoutType(),
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    let workouts = samples?.compactMap { $0 as? HKWorkout } ?? []
                    continuation.resume(returning: workouts)
                }
                
                healthStore.execute(query)
            }
            
            // 刪除找到的健身記錄
            addLog("找到 \(workouts.count) 條標記為測試的健身記錄")
            
            for workout in workouts {
                await deleteHealthWorkout(workout)
            }
            
        } catch {
            addLog("查找測試健身記錄時出錯: \(error.localizedDescription)")
        }
    }
    
    /// 根據時間範圍查找健身記錄
    private func findWorkoutsInTimeRange() {
        isLoading = true
        statusMessage = "正在查找健身記錄..."
        addLog("開始按時間範圍查找健身記錄...")
        
        Task {
            let workouts = await findRecentWorkouts(hoursBack: selectedTimeRange.hours)
            
            await MainActor.run {
                foundWorkouts = workouts
                isLoading = false
                
                if workouts.isEmpty {
                    statusMessage = "未找到符合條件的記錄"
                    addLog("未找到符合時間範圍的健身記錄")
                } else {
                    statusMessage = "找到 \(workouts.count) 條記錄"
                    addLog("找到 \(workouts.count) 條健身記錄")
                    showFoundWorkouts = true
                }
                
                showDeleteTimeRangeSelection = false
            }
        }
    }
    
    /// 根據時間範圍查找健身記錄
        private func findRecentWorkouts(hoursBack: Int?) async -> [HKWorkout] {
            let healthStore = HKHealthStore()
            
            do {
                // 如果指定了時間範圍
                if let hours = hoursBack {
                    // 創建時間範圍
                    let now = Date()
                    let startDate = Calendar.current.date(byAdding: .hour, value: -hours, to: now)!
                    
                    // 創建查詢
                    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
                    
                    // 獲取該時間範圍內的所有運動記錄
                    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
                        let query = HKSampleQuery(
                            sampleType: HKObjectType.workoutType(),
                            predicate: predicate,
                            limit: HKObjectQueryNoLimit,
                            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
                        ) { _, samples, error in
                            if let error = error {
                                continuation.resume(throwing: error)
                                return
                            }
                            
                            let workouts = samples?.compactMap { $0 as? HKWorkout } ?? []
                            continuation.resume(returning: workouts)
                        }
                        
                        healthStore.execute(query)
                    }
                } else {
                    // 查詢所有運動記錄
                    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
                        let query = HKSampleQuery(
                            sampleType: HKObjectType.workoutType(),
                            predicate: nil,
                            limit: 100, // 限制數量以避免獲取太多記錄
                            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
                        ) { _, samples, error in
                            if let error = error {
                                continuation.resume(throwing: error)
                                return
                            }
                            
                            let workouts = samples?.compactMap { $0 as? HKWorkout } ?? []
                            continuation.resume(returning: workouts)
                        }
                        
                        healthStore.execute(query)
                    }
                }
            } catch {
                addLog("查找健身記錄時出錯: \(error.localizedDescription)")
                return []
            }
        }
        
        /// 刪除單個健身記錄
        private func deleteHealthWorkout(_ workout: HKWorkout) async {
            let healthStore = HKHealthStore()
            
            do {
                try await healthStore.delete(workout)
                addLog("已刪除健身記錄: \(formatWorkoutInfo(workout))")
            } catch {
                addLog("刪除健身記錄失敗: \(error.localizedDescription)")
            }
        }
        
        /// 格式化健身記錄信息
        private func formatWorkoutInfo(_ workout: HKWorkout) -> String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            
            let dateStr = dateFormatter.string(from: workout.startDate)
            let typeStr = workout.workoutActivityType.name
            
            // 修正的距離格式化代碼
            let distanceStr: String
            if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                if distance >= 1000 {
                    distanceStr = String(format: "%.2f km", distance/1000)
                } else {
                    distanceStr = String(format: "%.0f m", distance)
                }
            } else {
                distanceStr = "無距離"
            }
            
            return "\(typeStr) (\(dateStr)) - \(distanceStr)"
        }
        
        /// 刪除已找到的健身記錄
        private func deleteFoundWorkouts() {
            guard !foundWorkouts.isEmpty else { return }
            
            isLoading = true
            statusMessage = "正在刪除所選記錄..."
            addLog("開始刪除所選的 \(foundWorkouts.count) 條健身記錄...")
            
            Task {
                var deletedCount = 0
                
                for workout in foundWorkouts {
                    do {
                        let healthStore = HKHealthStore()
                        try await healthStore.delete(workout)
                        deletedCount += 1
                        addLog("已刪除: \(formatWorkoutInfo(workout))")
                    } catch {
                        addLog("刪除失敗: \(error.localizedDescription)")
                    }
                }
                
                await MainActor.run {
                    foundWorkouts.removeAll()
                    isLoading = false
                    statusMessage = "已刪除 \(deletedCount) 條記錄"
                    addLog("刪除操作完成，共刪除 \(deletedCount) 條記錄")
                    refreshStatus()
                    
                    showFoundWorkouts = false
                }
            }
        }
        
        /// 刪除所有測試數據（包括健身記錄和上傳歷史）
        private func deleteAllTestData() {
            isLoading = true
            statusMessage = "刪除所有測試數據..."
            addLog("開始刪除所有測試數據...")
            
            Task {
                // 刪除測試健身記錄
                await deleteMarkedTestData()
                
                // 清除上傳歷史
                clearUploadHistory()
                
                await MainActor.run {
                    isLoading = false
                    statusMessage = "所有測試數據已刪除"
                    addLog("所有測試數據已刪除完成")
                }
            }
        }
        
        /// 添加日誌
        private func addLog(_ message: String) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let timestamp = formatter.string(from: Date())
            
            DispatchQueue.main.async {
                self.logMessages.insert("[\(timestamp)] \(message)", at: 0)
                
                // 限制日誌數量
                if self.logMessages.count > 100 {
                    self.logMessages = Array(self.logMessages.prefix(100))
                }
            }
        }
    }

    // MARK: - 時間範圍選擇視圖
    struct TimeRangeSelectionView: View {
        @Binding var selectedRange: WorkoutSyncDebugView.TimeRange
        var onConfirm: () -> Void
        var onCancel: () -> Void
        
        var body: some View {
            NavigationView {
                Form {
                    Section(header: Text("選擇時間範圍")) {
                        ForEach(WorkoutSyncDebugView.TimeRange.allCases) { range in
                            Button {
                                selectedRange = range
                            } label: {
                                HStack {
                                    Text(range.rawValue)
                                    Spacer()
                                    if selectedRange == range {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    
                    Section {
                        Button("查找健身記錄") {
                            onConfirm()
                        }
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    }
                }
                .navigationTitle("選擇時間範圍")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            onCancel()
                        }
                    }
                }
            }
        }
    }

    // MARK: - 找到的健身記錄視圖
    struct FoundWorkoutsView: View {
        @Binding var workouts: [HKWorkout]
        var onConfirmDelete: () -> Void
        var onCancel: () -> Void
        @State private var showDeleteConfirmation = false
        
        var body: some View {
            NavigationView {
                VStack {
                    if workouts.isEmpty {
                        ContentUnavailableView(
                            "沒有找到健身記錄",
                            systemImage: "figure.run.circle.slash",
                            description: Text("所選時間範圍內沒有健身記錄")
                        )
                    } else {
                        List {
                            ForEach(workouts, id: \.uuid) { workout in
                                WorkoutInfoRow(workout: workout)
                            }
                        }
                        
                        VStack(spacing: 12) {
                            Button(action: {
                                showDeleteConfirmation = true
                            }) {
                                Text("刪除所有記錄 (\(workouts.count))")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            
                            Text("警告：此操作將從您的健康數據中永久刪除這些健身記錄")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                }
                .navigationTitle("找到的健身記錄")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            onCancel()
                        }
                    }
                }
                .confirmationDialog(
                    "確定要刪除這些健身記錄嗎？",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("確定刪除", role: .destructive) {
                        onConfirmDelete()
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("這將從您的 HealthKit 數據中永久刪除 \(workouts.count) 條健身記錄。此操作無法撤銷。")
                }
            }
        }
    }

    // MARK: - 健身記錄信息行
    struct WorkoutInfoRow: View {
        let workout: HKWorkout
        
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(workout.workoutActivityType.name)
                        .font(.headline)
                    Spacer()
                    Text(formattedDuration)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let distance = workout.totalDistance?.doubleValue(for: .meter()), distance > 0 {
                    HStack {
                        Image(systemName: "figure.walk")
                        Text(formattedDistance(distance))
                        
                        Spacer()
                        
                        if let pace = calculatePace(distance: distance, duration: workout.duration) {
                            Image(systemName: "stopwatch")
                            Text(pace)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        
        private var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: workout.startDate)
        }
        
        private var formattedDuration: String {
            let minutes = Int(workout.duration) / 60
            let seconds = Int(workout.duration) % 60
            
            return String(format: "%d:%02d", minutes, seconds)
        }
        
        private func formattedDistance(_ distance: Double) -> String {
            if distance >= 1000 {
                return String(format: "%.2f 公里", distance / 1000)
            } else {
                return String(format: "%.0f 公尺", distance)
            }
        }
        
        private func calculatePace(distance: Double, duration: Double) -> String? {
            guard distance > 0 else { return nil }
            
            let paceInSecondsPerKm = duration / (distance / 1000)
            let minutes = Int(paceInSecondsPerKm) / 60
            let seconds = Int(paceInSecondsPerKm) % 60
            
            return String(format: "%d'%02d\"/km", minutes, seconds)
        }
    }
   
