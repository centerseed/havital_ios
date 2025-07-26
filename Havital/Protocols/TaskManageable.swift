import Foundation

// MARK: - 任務管理協議
protocol TaskManageable: AnyObject {
    var activeTasks: [String: Task<Void, Never>] { get set }
    var taskQueue: DispatchQueue { get }
    
    func executeTask<T>(
        id: String,
        operation: @escaping () async throws -> T
    ) async -> T?
    
    func cancelTask(id: String)
    func cancelAllTasks()
}

// MARK: - 預設實現
extension TaskManageable {
    /// 默認使用串行隊列保證線程安全
    var taskQueue: DispatchQueue {
        return DispatchQueue(label: "taskmanager.\(String(describing: type(of: self)))", qos: .userInitiated)
    }
    
    func executeTask<T>(
        id: String,
        operation: @escaping () async throws -> T
    ) async -> T? {
        // 類型安全檢查：確保 id 是字符串且有效
        guard !id.isEmpty else {
            Logger.firebase("執行任務失敗：任務 ID 不能為空", level: .error, jsonPayload: [
                "caller": String(describing: type(of: self))
            ])
            return nil
        }
        
        // 調試日誌：記錄任務 ID 的類型和值
        Logger.firebase("執行任務", level: .debug, jsonPayload: [
            "task_id": id,
            "caller": String(describing: type(of: self)),
            "id_type": String(describing: type(of: id))
        ])
        
        // 使用串行隊列保證 activeTasks 的線程安全
        return await withCheckedContinuation { continuation in
            taskQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // 檢查是否有相同 ID 的任務正在執行
                if self.activeTasks[id] != nil {
                    Logger.firebase("任務已在執行中，跳過重複請求", level: .info, jsonPayload: ["task_id": id])
                    continuation.resume(returning: nil)
                    return
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
                    let result = await task.value
                    // 任務完成後清理
                    self.taskQueue.async {
                        self.activeTasks.removeValue(forKey: id)
                    }
                }
                
                // 線程安全地添加任務
                self.activeTasks[id] = voidTask
                
                // 啟動任務並等待結果
                Task {
                    let result = await task.value
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    func cancelTask(id: String) {
        taskQueue.async { [weak self] in
            guard let self = self else { return }
            if let task = self.activeTasks[id] {
                task.cancel()
                self.activeTasks.removeValue(forKey: id)
                Logger.firebase("取消任務", level: .info, jsonPayload: ["task_id": id])
            }
        }
    }
    
    func cancelAllTasks() {
        taskQueue.async { [weak self] in
            guard let self = self else { return }
            let cancelledCount = self.activeTasks.count
            for (_, task) in self.activeTasks {
                task.cancel()
            }
            self.activeTasks.removeAll()
            Logger.firebase("取消所有任務", level: .info, jsonPayload: ["cancelled_count": cancelledCount])
        }
    }
}
