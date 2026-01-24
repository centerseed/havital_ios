import SwiftUI
import HealthKit

// MARK: - Cache Data Structure
private struct CachePoint: Codable {
    let timeInterval: TimeInterval
    let value: Double
}

@MainActor
class HRVChartViewModel: ObservableObject, TaskManageable {
    // MARK: - TaskManageable Properties (Actor-based)
    let taskRegistry = TaskRegistry()
    @Published var hrvData: [(Date, Double)] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedTimeRange: TimeRange = .month
    @Published var diagnosticsText: String? = nil
    @Published var readAuthStatus: HKAuthorizationRequestStatus? = nil
    private let healthKitManager: HealthKitManager

    // MARK: - 智能緩存機制
    private var lastUpdateTime: Date?
    private let cacheKey = "hrv_data_cache"
    private let cacheTimeKey = "hrv_data_cache_time"

    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
        loadCachedData()
    }
    
    deinit {
        cancelAllTasks()
    }
    
    func loadHRVData() async {
        // ✅ 智能緩存檢查：避免頻繁更新
        if !shouldRefreshData() {
            print("📊 [HRVChartViewModel] 使用緩存數據，距離上次更新: \(lastUpdateTime?.description ?? "未知")")
            return
        }

        let taskId = "load_hrv_\(selectedTimeRange.rawValue)"

        guard await executeTask(id: taskId, operation: {
            return try await self.performLoadHRVData()
        }) != nil else {
            return
        }
    }
    
    private func performLoadHRVData() async throws {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            try await healthKitManager.requestAuthorization()
            
            let now = Date()
            let startDate: Date
            
            switch selectedTimeRange {
            case .week:
                startDate = Calendar.current.date(byAdding: .day, value: -7, to: now)!
            case .month:
                startDate = Calendar.current.date(byAdding: .month, value: -1, to: now)!
            case .threeMonths:
                startDate = Calendar.current.date(byAdding: .month, value: -3, to: now)!
            }
            
            let rawData = try await healthKitManager.fetchHRVData(start: startDate, end: now)
            
            // 按日期分組並計算每天凌晨的平均值 - 使用 TimeInterval 作為 key 避免崩潰
            let calendar = Calendar.current
            let groupedData = Dictionary(grouping: rawData) { (date, _) in
                calendar.startOfDay(for: date).timeIntervalSince1970
            }
            
            // 處理每天的數據
            hrvData = groupedData.compactMap { (timeInterval, values) -> (Date, Double)? in
                let date = Date(timeIntervalSince1970: timeInterval)
                // 找出當天凌晨 00:00 到 06:00 的數據
                let morningValues = values.filter { (measurementDate, _) in
                    let hour = calendar.component(.hour, from: measurementDate)
                    return hour >= 0 && hour < 6
                }
                
                // 如果沒有凌晨的數據，跳過這一天
                guard !morningValues.isEmpty else { return nil }
                
                // 計算平均值
                let average = morningValues.reduce(0.0) { $0 + $1.1 } / Double(morningValues.count)
                return (date, average)
            }
            .sorted { $0.0 < $1.0 } // 按日期排序
            
            await MainActor.run {
                isLoading = false
            }

            // ✅ 保存緩存
            saveCachedData()
            lastUpdateTime = Date()
        } catch {
            print("Error loading HRV data: \(error)")
            await MainActor.run {
                self.error = "無法載入心率變異性數據"
                self.isLoading = false
                self.hrvData = []
            }
            throw error
        }
    }
    
    var yAxisRange: ClosedRange<Double> {
        guard !hrvData.isEmpty else { return 0...100 }
        
        let values = hrvData.map { $0.1 }
        let min = values.min() ?? 0
        let max = values.max() ?? 100
        
        // 添加 10% 的 padding
        let padding = (max - min) * 0.1
        return (min - padding)...(max + padding)
    }
    
    /// Diagnostic: fetch HRV authorization, sample count, and sources
    func fetchDiagnostics() async {
        let taskId = "fetch_hrv_diagnostics"
        
        guard await executeTask(id: taskId, operation: {
            return try await self.performFetchDiagnostics()
        }) != nil else {
            return
        }
    }
    
    private func performFetchDiagnostics() async throws {
        await MainActor.run {
            diagnosticsText = nil
        }
        let now = Date()
        // 計算起始日期與 loadHRVData 相同
        let startDate: Date
        switch selectedTimeRange {
        case .week:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        case .month:
            startDate = Calendar.current.date(byAdding: .month, value: -1, to: now)!
        case .threeMonths:
            startDate = Calendar.current.date(byAdding: .month, value: -3, to: now)!
        }
        do {
            // 檢查讀取授權
            let readStatus = try await healthKitManager.checkHRVReadAuthorization()
            // 取得 HRV 診斷
            let diag = try await healthKitManager.fetchHRVDiagnostics(start: startDate, end: now)
            let sources = diag.sources.joined(separator: ", ")
            await MainActor.run {
                diagnosticsText = "讀取授權: \(readStatus); 原始樣本數: \(diag.rawSampleCount); 來源: [\(sources)]"
            }
        } catch {
            await MainActor.run {
                diagnosticsText = "診斷失敗: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    /// 檢查 HRV 讀取授權狀態
    func fetchReadAuthStatus() async {
        let taskId = "fetch_hrv_auth_status"
        
        guard await executeTask(id: taskId, operation: {
            return try await self.performFetchReadAuthStatus()
        }) != nil else {
            return
        }
    }
    
    private func performFetchReadAuthStatus() async throws {
        await MainActor.run {
            readAuthStatus = nil
        }
        do {
            let status = try await healthKitManager.checkHRVReadAuthorization()
            await MainActor.run {
                readAuthStatus = status
            }
        } catch {
            await MainActor.run {
                readAuthStatus = nil
                // 捕捉任意錯誤並存到 error
                self.error = "讀取授權檢查失敗: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    enum TimeRange: String, CaseIterable {
        case week = "一週"
        case month = "一個月"
        case threeMonths = "三個月"
    }

    // MARK: - 智能緩存輔助函數

    /// 檢查是否需要刷新數據
    /// - Returns: true 表示需要刷新，false 表示使用緩存
    private func shouldRefreshData() -> Bool {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)

        // 檢查上次更新時間
        guard let lastUpdate = lastUpdateTime else {
            print("📊 [HRVChartViewModel] 從未更新過，需要刷新")
            return true // 從未更新過
        }

        // 檢查是否超過2小時
        let twoHoursAgo = calendar.date(byAdding: .hour, value: -2, to: now)!
        if lastUpdate < twoHoursAgo {
            // 特殊規則：中午12點到晚上12點只更新一次
            if currentHour >= 12 {
                // 檢查今天12點之後是否已更新過
                let todayNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!
                if lastUpdate >= todayNoon {
                    print("📊 [HRVChartViewModel] 今天12點後已更新過，使用緩存")
                    return false // 今天12點後已更新過，不需要再更新
                }
            }
            print("📊 [HRVChartViewModel] 超過2小時且符合更新條件，需要刷新")
            return true
        }

        print("📊 [HRVChartViewModel] 未超過2小時，使用緩存")
        return false
    }

    /// 從 UserDefaults 載入緩存數據
    private func loadCachedData() {
        guard let timeData = UserDefaults.standard.object(forKey: cacheTimeKey) as? Date else {
            return
        }

        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            let cached = try decoder.decode([CachePoint].self, from: data)
            hrvData = cached.map { (Date(timeIntervalSince1970: $0.timeInterval), $0.value) }
            lastUpdateTime = timeData
            print("📊 [HRVChartViewModel] 成功載入緩存數據: \(hrvData.count) 筆")
        } catch {
            print("📊 [HRVChartViewModel] 載入緩存失敗: \(error)")
        }
    }

    /// 保存數據到 UserDefaults
    private func saveCachedData() {
        let encoder = JSONEncoder()
        // 將 Date 轉換為 TimeInterval 以便序列化
        let serializable = hrvData.map { CachePoint(timeInterval: $0.0.timeIntervalSince1970, value: $0.1) }

        do {
            let data = try encoder.encode(serializable)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheTimeKey)
            print("📊 [HRVChartViewModel] 成功保存緩存數據: \(hrvData.count) 筆")
        } catch {
            print("📊 [HRVChartViewModel] 保存緩存失敗: \(error)")
        }
    }
}
