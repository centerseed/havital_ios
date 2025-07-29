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
    
    func registerTask(id: TaskID, task: Task<Void, Never>) -> Bool {
        // 檢查是否已存在
        if activeTasks[id] != nil {
            Logger.firebase("任務已在執行中，跳過重複請求", level: LogLevel.info, jsonPayload: ["task_id": id.description])
            return false
        }
        
        activeTasks[id] = task
        Logger.firebase("註冊任務", level: LogLevel.debug, jsonPayload: ["task_id": id.description])
        return true
    }
    
    func removeTask(id: TaskID) {
        if activeTasks.removeValue(forKey: id) != nil {
            Logger.firebase("移除任務", level: LogLevel.debug, jsonPayload: ["task_id": id.description])
        }
    }
    
    func cancelTask(id: TaskID) {
        if let task = activeTasks.removeValue(forKey: id) {
            task.cancel()
            Logger.firebase("取消任務", level: LogLevel.info, jsonPayload: ["task_id": id.description])
        }
    }
    
    func cancelAllTasks() {
        let cancelledCount = activeTasks.count
        let tasksToCancel = Array(activeTasks.values)
        activeTasks.removeAll()
        
        for task in tasksToCancel {
            task.cancel()
        }
        
        Logger.firebase("取消所有任務", level: LogLevel.info, jsonPayload: ["cancelled_count": cancelledCount])
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
        operation: @escaping @Sendable () async throws -> T
    ) async -> T?
    
    func cancelTask(id: TaskID)
    func cancelAllTasks()
}

// MARK: - 預設實現（Actor-based 線程安全）
@available(iOS 13.0, *)
extension TaskManageable {
    
    /// 為字符串 ID 提供便利方法（向後兼容）
    func executeTask<T>(
        id: String,
        operation: @escaping @Sendable () async throws -> T
    ) async -> T? {
        return await executeTask(id: TaskID(id), operation: operation)
    }
    
    /// 取消任務的字符串版本（向後兼容）
    func cancelTask(id: String) {
        Task { await cancelTask(id: TaskID(id)) }
    }
    
    /// TaskRegistry 必須作為存儲屬性實現
    /// 每個遵循 TaskManageable 的類都應該實現：
    /// private let taskRegistry = TaskRegistry()
    
    func executeTask<T>(
        id: TaskID,
        operation: @escaping @Sendable () async throws -> T
    ) async -> T? {
        // 調試日誌：記錄任務執行
        Logger.firebase("執行任務", level: LogLevel.debug, jsonPayload: [
            "task_id": id.description,
            "caller": String(describing: type(of: self))
        ])
        
        // 創建執行任務，不需要捕獲 self，因為 operation 已經是 @Sendable
        let executionTask = Task<T?, Never> {
            do {
                let result = try await operation()
                Logger.firebase("任務執行成功", level: LogLevel.info, jsonPayload: ["task_id": id.description])
                return result
            } catch is CancellationError {
                Logger.firebase("任務被取消", level: LogLevel.info, jsonPayload: ["task_id": id.description])
                return nil
            } catch {
                Logger.firebase("任務執行失敗", level: LogLevel.error, jsonPayload: [
                    "task_id": id.description,
                    "error": String(describing: error)
                ])
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
        
        // 嘗試註冊任務
        let registered = await taskRegistry.registerTask(id: id, task: managementTask)
        
        if !registered {
            // 任務已存在，取消新創建的任務
            executionTask.cancel()
            managementTask.cancel()
            return nil
        }
        
        // 等待執行結果
        return await executionTask.value
    }
    
    func cancelTask(id: TaskID) {
        Task { [weak self] in
            guard let strongSelf = self else { return }
            await strongSelf.taskRegistry.cancelTask(id: id)
        }
    }
    
    func cancelAllTasks() {
        // 在 deinit 中調用時使用 weak 引用避免循環引用
        Task { [weak self] in
            guard let strongSelf = self else { return }
            await strongSelf.taskRegistry.cancelAllTasks()
        }
    }
}
