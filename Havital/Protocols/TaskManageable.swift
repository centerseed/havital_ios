import Foundation

// MARK: - 任務管理協議
protocol TaskManageable: AnyObject {
    var activeTasks: [String: Task<Void, Never>] { get set }
    
    func executeTask<T>(
        id: String,
        operation: @escaping () async throws -> T
    ) async -> T?
    
    func cancelTask(id: String)
    func cancelAllTasks()
}

// MARK: - 預設實現
extension TaskManageable {
    func executeTask<T>(
        id: String,
        operation: @escaping () async throws -> T
    ) async -> T? {
        // 先取消同 ID 的現有任務
        if let existingTask = activeTasks[id] {
            existingTask.cancel()
            activeTasks.removeValue(forKey: id)
        }
        
        // 創建新任務並執行操作
        let task = Task<Void, Never> {
            // 空的 Task 只用於追蹤和取消
        }
        
        activeTasks[id] = task
        
        // 執行操作
        do {
            // 檢查任務是否已被取消
            try Task.checkCancellation()
            
            let result = try await operation()
            activeTasks.removeValue(forKey: id)
            return result
        } catch is CancellationError {
            activeTasks.removeValue(forKey: id)
            Logger.firebase("任務被取消", level: .info, jsonPayload: ["task_id": id])
            return nil
        } catch {
            activeTasks.removeValue(forKey: id)
            Logger.firebase("任務執行失敗", level: .error, jsonPayload: [
                "task_id": id,
                "error": error.localizedDescription
            ])
            return nil
        }
    }
    
    func cancelTask(id: String) {
        if let task = activeTasks[id] {
            task.cancel()
            activeTasks.removeValue(forKey: id)
            Logger.firebase("取消任務", level: .info, jsonPayload: ["task_id": id])
        }
    }
    
    func cancelAllTasks() {
        let cancelledCount = activeTasks.count
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
        Logger.firebase("取消所有任務", level: .info, jsonPayload: ["cancelled_count": cancelledCount])
    }
}