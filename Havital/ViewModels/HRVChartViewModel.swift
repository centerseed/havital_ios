import SwiftUI
import HealthKit

class HRVChartViewModel: ObservableObject, TaskManageable {
    // MARK: - TaskManageable Properties (Actor-based)
    let taskRegistry = TaskRegistry()
    @Published var hrvData: [(Date, Double)] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedTimeRange: TimeRange = .week
    @Published var diagnosticsText: String? = nil
    @Published var readAuthStatus: HKAuthorizationRequestStatus? = nil
    private let healthKitManager: HealthKitManager
    
    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
    }
    
    deinit {
        cancelAllTasks()
    }
    
    func loadHRVData() async {
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
}
