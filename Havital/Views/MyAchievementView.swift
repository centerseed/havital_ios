import SwiftUI
import Charts
import HealthKit

struct SectionTitleWithInfo: View {
    let title: String
    let explanation: String
    @State private var showingInfo = false
    var useSheet: Bool = false
    var sheetContent: (() -> AnyView)? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Button {
                showingInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .if(!useSheet) { view in
                view.alert(title, isPresented: $showingInfo) {
                    Button("了解", role: .cancel) {}
                } message: {
                    Text(explanation)
                }
            }
            .if(useSheet && sheetContent != nil) { view in
                view.sheet(isPresented: $showingInfo) {
                    sheetContent?()
                }
            }
            
            Spacer()
        }
    }
}

// Extension to support conditional modifiers
extension View {
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct MyAchievementView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    
    // 當前數據源設定
    private var dataSourcePreference: DataSourceType {
        UserPreferenceManager.shared.dataSourcePreference
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // VDOT Chart Section - 所有數據源都顯示（從 API 獲取）
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitleWithInfo(
                            title: "VDOT 趨勢",
                            explanation: "VDOT 是根據您的跑步表現所計算出的有氧能力指標。隨著訓練進度的增加，您的 VDOT 值會逐漸提升。"
                        )
                        .padding(.horizontal)
                        
                        VDOTChartView()
                            .padding()
                    }
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                    .padding(.horizontal)
                    
                    // HRV 趨勢圖 - 根據數據源選擇顯示方式
                    HRVChartSection()
                        .environmentObject(healthKitManager)
                    
                    // 睡眠靜息心率圖 - 根據數據源選擇顯示方式
                    RestingHeartRateChartSection()
                        .environmentObject(healthKitManager)
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("表現數據")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - HRV Chart Section
struct HRVChartSection: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    
    // 當前數據源設定
    private var dataSourcePreference: DataSourceType {
        UserPreferenceManager.shared.dataSourcePreference
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitleWithInfo(
                title: "心率變異性 (HRV) 趨勢",
                explanation: "心率變異性（HRV）是衡量身體恢復能力和壓力水平的重要指標。較高的HRV通常表示更好的恢復能力和較低的壓力水平。"
            )
            .padding(.horizontal)
            
            switch dataSourcePreference {
            case .appleHealth:
                // Apple Health: 優先使用 API，失敗時回退到 HealthKit
                APIBasedHRVChartView(fallbackToHealthKit: true)
                    .environmentObject(healthKitManager)
                    .padding()
                
            case .garmin:
                // Garmin: 僅使用 API 數據
                APIBasedHRVChartView(fallbackToHealthKit: false)
                    .environmentObject(healthKitManager)
                    .padding()
                
            case .unbound:
                // 未綁定數據源
                EmptyDataSourceView(message: "請選擇數據來源以查看 HRV 趨勢")
                    .padding()
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        .padding(.horizontal)
    }
}

// MARK: - Resting Heart Rate Chart Section
struct RestingHeartRateChartSection: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    
    // 當前數據源設定
    private var dataSourcePreference: DataSourceType {
        UserPreferenceManager.shared.dataSourcePreference
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitleWithInfo(
                title: "睡眠靜息心率",
                explanation: "睡眠靜息心率是評估心臟健康和整體健康狀況的重要指標。較低的靜息心率通常表示更好的心臟功能和更高體能水平。"
            )
            .padding(.horizontal)
            
            switch dataSourcePreference {
            case .appleHealth:
                // Apple Health: 使用現有的 HealthKit 數據
                SleepHeartRateChartView()
                    .environmentObject(healthKitManager)
                    .padding()
                
            case .garmin:
                // Garmin: 使用 API 數據（待實現）
                APIBasedRestingHeartRateChartView()
                    .padding()
                
            case .unbound:
                // 未綁定數據源
                EmptyDataSourceView(message: "請選擇數據來源以查看靜息心率趨勢")
                    .padding()
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        .padding(.horizontal)
    }
}

// MARK: - API Based Chart Views with Fallback
struct APIBasedHRVChartView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    let fallbackToHealthKit: Bool
    
    @State private var healthData: [HealthRecord] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var usingFallback = false
    
    // 簡單的 task 取消追蹤
    @State private var loadTask: Task<Void, Never>?
    
    init(fallbackToHealthKit: Bool = true) {
        self.fallbackToHealthKit = fallbackToHealthKit
    }
    
    // 計算 HRV Y 軸範圍
    private var hrvYAxisDomain: ClosedRange<Double> {
        let hrvValues = healthData.compactMap { $0.hrvLastNightAvg }
        guard !hrvValues.isEmpty else { return 0...100 }
        
        let minValue = hrvValues.min() ?? 0
        let maxValue = hrvValues.max() ?? 100
        let range = maxValue - minValue
        
        // 如果數據範圍太小，手動擴展範圍來顯示變化
        if range < 10 {
            let center = (minValue + maxValue) / 2
            return (center - 15)...(center + 15)
        } else {
            // 增加 20% 的邊距
            let margin = range * 0.2
            return (minValue - margin)...(maxValue + margin)
        }
    }
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("載入 HRV 數據中...")
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let error = error, !usingFallback {
                if fallbackToHealthKit {
                    // 顯示 API 失敗，使用本地數據的提示
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "wifi.exclamationmark")
                                .foregroundColor(.orange)
                            Text("使用本地數據")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // 使用 HealthKit 的 HRV 圖表作為回退
                        HRVTrendChartView()
                            .environmentObject(healthKitManager)
                    }
                } else {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("載入失敗")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                }
            } else if healthData.isEmpty {
                VStack {
                    Image(systemName: "heart.text.square")
                        .foregroundColor(.gray)
                    Text("無 HRV 數據")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                VStack {
                    if usingFallback {
                        HStack {
                            Image(systemName: "wifi.exclamationmark")
                                .foregroundColor(.orange)
                            Text("使用本地數據")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    
                    Chart {
                        ForEach(healthData.indices, id: \.self) { index in
                            let record = healthData[index]
                            if let hrv = record.hrvLastNightAvg {
                                LineMark(
                                    x: .value("日期", formatDateForChart(record.date)),
                                    y: .value("HRV", hrv)
                                )
                                .foregroundStyle(.blue)
                                .symbol(Circle())
                            }
                        }
                    }
                    .frame(height: 150)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartYScale(domain: hrvYAxisDomain)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                }
            }
        }
        .task {
            loadTask?.cancel()
            loadTask = Task {
                await loadHealthData()
            }
        }
        .onDisappear {
            loadTask?.cancel()
        }
    }
    
    private func loadHealthData() async {
        isLoading = true
        usingFallback = false
        
        // 優先嘗試從 API 獲取數據
        healthData = await HealthDataUploadManager.shared.getHealthData(days: 14)
        error = nil
        
        isLoading = false
    }
    
    private func getLocalHRVData() async -> [HealthRecord] {
        // 從 HealthKit 獲取本地 HRV 數據作為回退
        var records: [HealthRecord] = []
        let calendar = Calendar.current
        
        for i in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            
            do {
                // 獲取該日期的 HRV 數據
                let startOfDay = Calendar.current.startOfDay(for: date)
                let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? date
                
                let hrvDataPoints = try await healthKitManager.fetchHRVData(start: startOfDay, end: endOfDay)
                let avgHRV = hrvDataPoints.isEmpty ? nil : hrvDataPoints.map { $0.1 }.reduce(0, +) / Double(hrvDataPoints.count)
                
                let record = HealthRecord(
                    date: ISO8601DateFormatter().string(from: date),
                    dailyCalories: nil,
                    hrvLastNightAvg: avgHRV,
                    restingHeartRate: nil
                )
                records.append(record)
            } catch {
                // 單日數據失敗，跳過
                continue
            }
        }
        
        return records.reversed() // 時間順序排列
    }
    
    private func formatDateForChart(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString) ?? Date()
    }
}

struct APIBasedRestingHeartRateChartView: View {
    @State private var healthData: [HealthRecord] = []
    @State private var isLoading = true
    @State private var error: String?
    
    // 簡單的 task 取消追蹤
    @State private var loadTask: Task<Void, Never>?
    
    // 計算靜息心率 Y 軸範圍
    private var restingHRYAxisDomain: ClosedRange<Double> {
        let hrValues = healthData.compactMap { $0.restingHeartRate }.map { Double($0) }
        guard !hrValues.isEmpty else { return 40...100 }
        
        let minValue = hrValues.min() ?? 40
        let maxValue = hrValues.max() ?? 100
        let range = maxValue - minValue
        
        // 如果數據範圍太小，手動擴展範圍來顯示變化
        if range < 5 {
            let center = (minValue + maxValue) / 2
            return (center - 10)...(center + 10)
        } else {
            // 增加 20% 的邊距
            let margin = range * 0.2
            return (minValue - margin)...(maxValue + margin)
        }
    }
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("載入靜息心率數據中...")
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("載入失敗")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else if healthData.isEmpty {
                VStack {
                    Image(systemName: "heart")
                        .foregroundColor(.gray)
                    Text("無靜息心率數據")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                Chart {
                    ForEach(healthData.indices, id: \.self) { index in
                        let record = healthData[index]
                        if let rhr = record.restingHeartRate {
                            LineMark(
                                x: .value("日期", formatDateForChart(record.date)),
                                y: .value("靜息心率", rhr)
                            )
                            .foregroundStyle(.red)
                        }
                    }
                }
                .frame(height: 150)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartYScale(domain: restingHRYAxisDomain)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
            }
        }
        .task {
            loadTask?.cancel()
            loadTask = Task {
                await loadHealthData()
            }
        }
        .onDisappear {
            loadTask?.cancel()
        }
    }
    
    private func loadHealthData() async {
        isLoading = true
        
        healthData = await HealthDataUploadManager.shared.getHealthData(days: 14)
        error = nil
        
        isLoading = false
    }
    
    private func formatDateForChart(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString) ?? Date()
    }
}

// MARK: - Empty Data Source View
struct EmptyDataSourceView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }
}

// MARK: - Health Data Models are now in APIClient.swift

#Preview {
    MyAchievementView()
        .environmentObject(HealthKitManager())
}
