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
        // 檢查是否有相同 ID 的任務正在執行
        if activeTasks[id] != nil {
            Logger.firebase("任務已在執行中，跳過重複請求", level: .info, jsonPayload: ["task_id": id])
            return nil
        }
        
        // 創建真正的執行任務
        let task = Task<T?, Never> {
            do {
                let result = try await operation()
                Logger.firebase("任務執行成功", level: .info, jsonPayload: ["task_id": id])
                return result
            } catch is CancellationError {
                Logger.firebase("任務被取消", level: .info, jsonPayload: ["task_id": id])
                return nil
            } catch {
                Logger.firebase("任務執行失敗", level: .error, jsonPayload: [
                    "task_id": id,
                    "error": error.localizedDescription
                ])
                return nil
            }
        }
        
        // 創建 Void 包裝任務以符合 activeTasks 類型
        let voidTask = Task<Void, Never> {
            _ = await task.value
        }
        
        activeTasks[id] = voidTask
        
        // 等待任務完成並清理
        let result = await task.value
        activeTasks.removeValue(forKey: id)
        return result
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