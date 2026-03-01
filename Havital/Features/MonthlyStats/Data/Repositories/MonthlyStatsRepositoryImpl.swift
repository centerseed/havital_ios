import Foundation

// MARK: - MonthlyStats Repository Implementation
/// 月度統計 Repository 實作 - Data Layer
/// 協調 RemoteDataSource 和 LocalDataSource，實現永久 TTL 策略
final class MonthlyStatsRepositoryImpl: MonthlyStatsRepository {

    // MARK: - Singleton

    static let shared = MonthlyStatsRepositoryImpl()

    // MARK: - Properties

    private let remoteDataSource: MonthlyStatsRemoteDataSource
    private let localDataSource: MonthlyStatsLocalDataSource

    // MARK: - Initialization

    init(remoteDataSource: MonthlyStatsRemoteDataSource = MonthlyStatsRemoteDataSource(),
         localDataSource: MonthlyStatsLocalDataSource = MonthlyStatsLocalDataSource()) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource

        Logger.debug("[MonthlyStatsRepositoryImpl] 初始化完成")
    }

    // MARK: - MonthlyStatsRepository Protocol

    /// 獲取指定月份的每日統計數據（永久 TTL 策略）
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份 (1-12)
    /// - Returns: 每日統計數據列表
    /// - Note: ✅ Clean Architecture: 先檢查本地緩存，沒有數據才調用 API
    func getMonthlyStats(year: Int, month: Int) async throws -> [DailyStat] {
        Logger.debug("[MonthlyStatsRepositoryImpl] getMonthlyStats - year: \(year), month: \(month)")

        // ✅ 先從本地緩存讀取數據
        // ⚠️ 重要：只有當緩存有實際數據時才返回，空數組仍需調用 API
        if let cachedStats = localDataSource.getMonthlyStats(year: year, month: month), !cachedStats.isEmpty {
            print("📊 [MonthlyStatsRepo] 從本地緩存返回，\(year)-\(String(format: "%02d", month))，數量: \(cachedStats.count)")
            return cachedStats
        }

        // ✅ 本地沒有數據或數據為空，從 API 獲取
        print("📊 [MonthlyStatsRepo] 🌐 調用 API: /v2/workout/monthly_stats?year=\(year)&month=\(month)")

        do {
            let dto = try await remoteDataSource.fetchMonthlyStats(year: year, month: month)

            // ✅ 轉換 DTO → Entity
            let entities = MonthlyStatsMapper.toDailyStats(from: dto)

            // ✅ 計算統計
            let totalWorkoutCount = entities.reduce(0) { $0 + $1.workoutCount }
            let runningDays = entities.filter { $0.totalDistanceKm > 0 }
            let totalDistance = entities.reduce(0.0) { $0 + $1.totalDistanceKm }
            print("📊 [MonthlyStatsRepo] ✅ API 返回 \(year)-\(String(format: "%02d", month)): \(entities.count) 天, workouts: \(totalWorkoutCount), 跑步 \(runningDays.count) 天, 總距離 \(String(format: "%.1f", totalDistance)) km")

            // ⚠️ 只有當有實際 workout 數據時才緩存
            // 這樣 workout count 為 0 時，下次還會重新調用 API
            if totalWorkoutCount > 0 {
                localDataSource.saveMonthlyStats(entities, year: year, month: month)
                localDataSource.setSyncTimestamp(year: year, month: month)
                print("📊 [MonthlyStatsRepo] 💾 已緩存 \(year)-\(String(format: "%02d", month))")
            } else {
                print("📊 [MonthlyStatsRepo] ⚠️ 無 workout 數據，不緩存（下次會重試）")
            }

            Logger.firebase(
                "月度統計獲取成功",
                level: .info,
                labels: ["module": "MonthlyStatsRepository", "action": "fetch_monthly_stats"],
                jsonPayload: [
                    "year": year,
                    "month": month,
                    "daily_stats_count": entities.count,
                    "running_days": runningDays.count,
                    "total_distance": totalDistance,
                    "cached": totalWorkoutCount > 0
                ]
            )

            return entities

        } catch {
            // ✅ 靜默降級：API 失敗時返回空數組，不拋出錯誤
            Logger.error("[MonthlyStatsRepositoryImpl] 月度數據獲取失敗，靜默降級: \(error.localizedDescription)")

            Logger.firebase(
                "月度統計獲取失敗",
                level: .warn,
                labels: ["module": "MonthlyStatsRepository", "action": "fetch_monthly_stats"],
                jsonPayload: [
                    "year": year,
                    "month": month,
                    "error": error.localizedDescription
                ]
            )

            return []
        }
    }

    /// 檢查指定月份是否已同步過
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份 (1-12)
    /// - Returns: true 表示已同步，false 表示未同步
    func hasSyncedMonth(year: Int, month: Int) async -> Bool {
        return localDataSource.hasSynced(year: year, month: month)
    }

    /// 清除所有月度統計緩存和時間戳（登出時調用）
    /// - Note: ✅ Repository 被動原則：不訂閱事件，只提供此方法供上層調用
    func clearCache() async {
        Logger.debug("[MonthlyStatsRepositoryImpl] clearCache")
        localDataSource.clearAll()

        Logger.firebase(
            "月度統計緩存已清除",
            level: .info,
            labels: ["module": "MonthlyStatsRepository", "action": "clear_cache"]
        )
    }

    // MARK: - Additional Helper Methods

    /// 手動刷新指定月份的數據（清除時間戳後重新獲取）
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份 (1-12)
    /// - Returns: 最新的每日統計數據
    /// - Note: 提供給 UI 層的手動刷新功能
    func refreshMonth(year: Int, month: Int) async throws -> [DailyStat] {
        Logger.debug("[MonthlyStatsRepositoryImpl] refreshMonth - year: \(year), month: \(month)")

        // 清除時間戳
        localDataSource.clearSyncTimestamp(year: year, month: month)

        // 重新獲取
        return try await getMonthlyStats(year: year, month: month)
    }

    /// 獲取所有已同步的月份列表（調試用）
    func getAllSyncedMonths() -> [(year: Int, month: Int, timestamp: Date)] {
        return localDataSource.getAllSyncedMonths()
    }
}

// MARK: - DependencyContainer Registration
extension DependencyContainer {

    /// 註冊 MonthlyStats 模組依賴
    func registerMonthlyStatsModule() {
        Logger.debug("[DI] 🔧 registerMonthlyStatsModule() called")

        // 檢查是否已註冊
        if isRegistered(MonthlyStatsRepository.self) {
            Logger.debug("[DI] ⚠️ MonthlyStats module already registered, skipping")
            return
        }

        Logger.debug("[DI] 📦 Creating MonthlyStatsRepositoryImpl.shared instance")
        // 註冊 Repository
        let repository = MonthlyStatsRepositoryImpl.shared
        Logger.debug("[DI] 📦 Repository instance created: \(String(describing: type(of: repository)))")

        register(repository as MonthlyStatsRepository, forProtocol: MonthlyStatsRepository.self)

        Logger.debug("[DI] ✅ MonthlyStats module registered successfully")

        // 驗證註冊
        let testResolve: MonthlyStatsRepository? = tryResolve()
        Logger.debug("[DI] 🔍 Verification - can resolve: \(testResolve != nil)")
    }
}
