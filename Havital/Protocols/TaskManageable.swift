import Foundation

// MARK: - 線程安全的任務標識符
struct TaskID: Hashable, CustomStringConvertible, Sendable {
    private let value: String
    
    init(_ value: String) {
        // 確保 ID 安全：移除特殊字符，限制長度
        let sanitized = value.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        self.value = String(sanitized.prefix(50))
    }
    
    var description: String { value }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
    
    static func == (lhs: TaskID, rhs: TaskID) -> Bool {
        return lhs.value == rhs.value
    }
}

// MARK: - Actor-based Task Registry (完全線程安全)
@available(iOS 13.0, *)
actor TaskRegistry {
    private var activeTasks: [TaskID: Task<Void, Never>] = [:]
    private var lastCompletionTimes: [TaskID: Date] = [:]  // ✅ 記錄任務完成時間

    func registerTask(id: TaskID, task: Task<Void, Never>, cooldownSeconds: TimeInterval = 0) -> Bool {
        // 檢查是否已存在
        if activeTasks[id] != nil {
            // 只記錄本地日誌，不發送到後端
            Logger.trace("[TaskRegistry] 任務已在執行中，跳過重複請求: \(id.description)")
            return false
        }

        // ✅ 檢查冷卻時間
        if cooldownSeconds > 0, let lastTime = lastCompletionTimes[id] {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < cooldownSeconds {
                let remaining = Int(cooldownSeconds - elapsed)
                Logger.trace("[TaskRegistry] 任務在冷卻中，剩餘 \(remaining) 秒: \(id.description)")
                return false
            }
        }

        activeTasks[id] = task
        // 只記錄本地日誌，不發送到後端
        Logger.trace("[TaskRegistry] 註冊任務: \(id.description)")
        return true
    }

    func removeTask(id: TaskID) {
        if activeTasks.removeValue(forKey: id) != nil {
            // ✅ 記錄完成時間
            lastCompletionTimes[id] = Date()
            // 只記錄本地日誌，不發送到後端
            Logger.trace("[TaskRegistry] 移除任務: \(id.description)")
        }
    }
    
    func cancelTask(id: TaskID) {
        if let task = activeTasks.removeValue(forKey: id) {
            task.cancel()
            // 只記錄本地日誌，不發送到後端
            Logger.trace("[TaskRegistry] 取消任務: \(id.description)")
        }
    }
    
    func cancelAllTasks() {
        let cancelledCount = activeTasks.count
        let tasksToCancel = Array(activeTasks.values)
        activeTasks.removeAll()
        
        for task in tasksToCancel {
            task.cancel()
        }
        
        // 只記錄本地日誌，不發送到後端
        if cancelledCount > 0 {
            Logger.trace("[TaskRegistry] 取消所有任務，數量: \(cancelledCount)")
        }
    }
    
    func taskCount() -> Int {
        return activeTasks.count
    }
}

// MARK: - 任務管理協議（使用 Actor 保證線程安全）
@available(iOS 13.0, *)
protocol TaskManageable: AnyObject {
    var taskRegistry: TaskRegistry { get }

    func executeTask<T>(
        id: TaskID,
        cooldownSeconds: TimeInterval,  // ✅ 新增冷卻參數
        operation: @escaping @Sendable () async throws -> T
    ) async -> T?

    func cancelTask(id: TaskID)
    func cancelAllTasks()
}

// MARK: - 預設實現（Actor-based 線程安全）
@available(iOS 13.0, *)
extension TaskManageable {

    /// 為字符串 ID 提供便利方法（向後兼容，無冷卻）
    func executeTask<T>(
        id: String,
        operation: @escaping @Sendable () async throws -> T
    ) async -> T? {
        return await executeTask(id: TaskID(id), cooldownSeconds: 0, operation: operation)
    }

    /// 無冷卻版本（向後兼容）
    func executeTask<T>(
        id: TaskID,
        operation: @escaping @Sendable () async throws -> T
    ) async -> T? {
        return await executeTask(id: id, cooldownSeconds: 0, operation: operation)
    }

    /// 取消任務的字符串版本（向後兼容）
    func cancelTask(id: String) {
        Task { await cancelTask(id: TaskID(id)) }
    }

    /// TaskRegistry 必須作為存儲屬性實現
    /// 每個遵循 TaskManageable 的類都應該實現：
    /// private let taskRegistry = TaskRegistry()

    /// ✅ 核心實現：支援冷卻時間
    func executeTask<T>(
        id: TaskID,
        cooldownSeconds: TimeInterval = 0,
        operation: @escaping @Sendable () async throws -> T
    ) async -> T? {
        // 只記錄本地調試日誌，不發送到後端
        Logger.trace("[TaskManageable] 執行任務: \(id.description) from \(String(describing: type(of: self)))")

        // 創建執行任務，不需要捕獲 self，因為 operation 已經是 @Sendable
        let executionTask = Task<T?, Never> {
            do {
                let result = try await operation()
                // 只記錄本地日誌，不發送到後端
                Logger.trace("[TaskManageable] 任務執行成功: \(id.description)")
                return result
            } catch is CancellationError {
                // 取消事件不需要記錄，避免過多日誌
                return nil
            } catch {
                // TaskManagement 錯誤只記錄在本地，不上傳到雲端
                Logger.trace("[TaskManageable] 任務執行失敗: \(id.description) - \(error.localizedDescription)")
                return nil
            }
        }
        
        // 創建管理任務（用於註冊到 TaskRegistry）
        let managementTask = Task<Void, Never> { [weak self] in
            let result = await executionTask.value
            // 任務完成後從註冊表中移除，使用 weak self 避免循環引用
            guard let strongSelf = self else { return }
            await strongSelf.taskRegistry.removeTask(id: id)
        }
        
        // ✅ 嘗試註冊任務（帶冷卻檢查）
        let registered = await taskRegistry.registerTask(id: id, task: managementTask, cooldownSeconds: cooldownSeconds)

        if !registered {
            // 任務已存在或在冷卻中，取消新創建的任務
            executionTask.cancel()
            managementTask.cancel()
            return nil
        }
        
        // 等待執行結果
        return await executionTask.value
    }
    
    func cancelTask(id: TaskID) {
        // 捕捉 registry（actor，reference type）而非 self：
        // 與 cancelAllTasks 保持一致，確保即使在物件釋放邊緣呼叫也能完成取消。
        let registry = taskRegistry
        Task { await registry.cancelTask(id: id) }
    }

    func cancelAllTasks() {
        // deinit 時 self 已釋放：捕捉 registry（actor）而非 self，
        // 讓 registry 在取消完成前存活，確保 in-flight task 確實被取消。
        let registry = taskRegistry
        Task { await registry.cancelAllTasks() }
    }
}
