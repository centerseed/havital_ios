import Foundation

/// 訓練負荷數據管理器 - 處理緩存和增量同步
actor TrainingLoadDataManager {
    static let shared = TrainingLoadDataManager()

    private let cacheKey = "training_load_health_data"
    private let lastSyncDateKey = "training_load_last_sync_date"
    private let maxCacheSize = 40
    private let initialLoadDays = 30

    private init() {}

    // MARK: - Public API

    /// 獲取訓練負荷數據（優先使用緩存，背景更新）
    func getTrainingLoadData() async -> [HealthRecord] {
        // 立即返回緩存數據
        let cachedData = loadCachedData()

        // 背景進行增量同步
        Task.detached {
            await self.performIncrementalSync()
        }

        return cachedData
    }

    /// 強制刷新所有數據
    func forceRefreshData() async throws -> [HealthRecord] {
        Logger.debug("[TrainingLoadDataManager] 開始強制刷新數據")

        let response = try await APIClient.shared.fetchHealthDaily(limit: initialLoadDays)
        let freshData = response.healthData

        // 更新緩存
        await saveCachedData(freshData)
        await updateLastSyncDate()

        Logger.debug("[TrainingLoadDataManager] 強制刷新完成，獲得 \(freshData.count) 筆記錄")
        return freshData
    }

    // MARK: - Private Methods

    /// 執行增量同步
    private func performIncrementalSync() async {
        do {
            let daysSinceLastSync = getDaysSinceLastSync()

            // 如果沒有緩存或距離上次同步超過7天，執行完整刷新
            if !hasCachedData() || daysSinceLastSync > 7 {
                Logger.debug("[TrainingLoadDataManager] 執行完整數據刷新")
                _ = try await forceRefreshData()
                return
            }

            // 如果距離上次同步小於1天，跳過更新
            if daysSinceLastSync < 1 {
                Logger.debug("[TrainingLoadDataManager] 距離上次同步不足1天，跳過更新")
                return
            }

            // 執行增量同步
            Logger.debug("[TrainingLoadDataManager] 執行增量同步，獲取最近 \(daysSinceLastSync + 1) 天數據")

            let incrementalLimit = min(daysSinceLastSync + 1, 7) // 最多獲取7天
            let response = try await APIClient.shared.fetchHealthDaily(limit: incrementalLimit)
            let newData = response.healthData

            // 合併數據
            await mergeNewDataWithCache(newData)
            await updateLastSyncDate()

            Logger.debug("[TrainingLoadDataManager] 增量同步完成，新增 \(newData.count) 筆記錄")

        } catch {
            Logger.error("[TrainingLoadDataManager] 增量同步失敗: \(error.localizedDescription)")
        }
    }

    /// 合併新數據與緩存數據
    private func mergeNewDataWithCache(_ newData: [HealthRecord]) async {
        let cachedData = loadCachedData()

        // 創建日期到記錄的映射，避免重複
        var recordMap: [String: HealthRecord] = [:]

        // 先加入舊數據
        for record in cachedData {
            recordMap[record.date] = record
        }

        // 用新數據覆蓋（如果有的話）
        for record in newData {
            recordMap[record.date] = record
        }

        // 按日期排序，取最近40筆
        let mergedData = Array(recordMap.values)
            .sorted { $0.date > $1.date } // 最新的在前
            .prefix(maxCacheSize)
            .map { $0 }

        await saveCachedData(mergedData)

        Logger.debug("[TrainingLoadDataManager] 數據合併完成，總計 \(mergedData.count) 筆記錄")
    }

    /// 計算距離上次同步的天數
    private func getDaysSinceLastSync() -> Int {
        guard let lastSyncDate = UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date else {
            return 999 // 從未同步過
        }

        let daysSince = Calendar.current.dateComponents([.day], from: lastSyncDate, to: Date()).day ?? 999
        return max(0, daysSince)
    }

    /// 更新最後同步時間
    private func updateLastSyncDate() async {
        await MainActor.run {
            UserDefaults.standard.set(Date(), forKey: lastSyncDateKey)
        }
    }

    /// 檢查是否有緩存數據
    private func hasCachedData() -> Bool {
        return UserDefaults.standard.data(forKey: cacheKey) != nil
    }

    /// 加載緩存數據
    private func loadCachedData() -> [HealthRecord] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            Logger.debug("[TrainingLoadDataManager] 沒有緩存數據")
            return []
        }

        do {
            let cachedRecords = try JSONDecoder().decode([HealthRecord].self, from: data)
            Logger.debug("[TrainingLoadDataManager] 加載緩存數據 \(cachedRecords.count) 筆記錄")
            return cachedRecords
        } catch {
            Logger.error("[TrainingLoadDataManager] 緩存數據解析失敗: \(error.localizedDescription)")
            return []
        }
    }

    /// 保存數據到緩存
    private func saveCachedData(_ records: [HealthRecord]) async {
        do {
            let data = try JSONEncoder().encode(records)
            await MainActor.run {
                UserDefaults.standard.set(data, forKey: cacheKey)
            }
            Logger.debug("[TrainingLoadDataManager] 緩存數據已保存，共 \(records.count) 筆記錄")
        } catch {
            Logger.error("[TrainingLoadDataManager] 緩存數據保存失敗: \(error.localizedDescription)")
        }
    }

    /// 清除緩存數據（用於測試或重置）
    func clearCache() async {
        await MainActor.run {
            UserDefaults.standard.removeObject(forKey: cacheKey)
            UserDefaults.standard.removeObject(forKey: lastSyncDateKey)
        }
        Logger.debug("[TrainingLoadDataManager] 緩存已清除")
    }
}