import SwiftUI
import Charts

struct SleepHeartRateChartView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @StateObject private var viewModel: SleepHeartRateViewModel
    @StateObject private var userPreferenceManager = UserPreferenceManager.shared
    
    init() {
        _viewModel = StateObject(wrappedValue: SleepHeartRateViewModel())
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("載入中...")
            } else if viewModel.heartRateData.isEmpty {
                EmptyStateView(type: .sleepHeartRateData)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    // ✅ 優化：移除重複標題（選項卡已顯示「睡眠靜息心率」）
                    // Garmin Attribution as required by brand guidelines
                    HStack {
                        Spacer()

                        ConditionalGarminAttributionView(
                            dataProvider: userPreferenceManager.dataSourcePreference == .garmin ? "Garmin" : nil,
                            deviceModel: nil,
                            displayStyle: .titleLevel
                        )
                    }

                    Chart {
                        ForEach(viewModel.heartRateData, id: \.0) { item in
                            LineMark(
                                x: .value("日期", item.0),
                                y: .value("心率", item.1)
                            )
                            .foregroundStyle(.purple)
                            
                            PointMark(
                                x: .value("日期", item.0),
                                y: .value("心率", item.1)
                            )
                            .foregroundStyle(.purple)
                        }
                    }
                    .chartYScale(domain: viewModel.yAxisRange)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(formatDate(date))
                                        .font(.caption)
                                }
                                AxisGridLine()
                                AxisTick()
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let heartRate = value.as(Double.self) {
                                    Text("\(Int(heartRate))")
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            // 設定 ViewModel 的管理器
            viewModel.healthKitManager = healthKitManager
            
            // 嘗試從環境中獲取 SharedHealthDataManager（如果有的話）
            // 由於 @EnvironmentObject 無法是可選的，我們需要在 MyAchievementView 中處理這個
        }
        .task {
            await viewModel.loadHeartRateData()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

// MARK: - Garmin 版本的 SleepHeartRateChartView
struct SleepHeartRateChartViewWithGarmin: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @StateObject private var viewModel: SleepHeartRateViewModel
    @StateObject private var userPreferenceManager = UserPreferenceManager.shared
    private let sharedHealthDataManager: SharedHealthDataManager
    
    init() {
        self.sharedHealthDataManager = SharedHealthDataManager.shared
        _viewModel = StateObject(wrappedValue: SleepHeartRateViewModel())
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("載入中...")
            } else if viewModel.heartRateData.isEmpty {
                EmptyStateView(type: .sleepHeartRateData)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    // ✅ 優化：移除重複標題（選項卡已顯示「睡眠靜息心率」）
                    // Garmin Attribution as required by brand guidelines
                    HStack {
                        Spacer()

                        ConditionalGarminAttributionView(
                            dataProvider: userPreferenceManager.dataSourcePreference == .garmin ? "Garmin" : nil,
                            deviceModel: nil,
                            displayStyle: .titleLevel
                        )
                    }

                    Chart {
                        ForEach(viewModel.heartRateData, id: \.0) { item in
                            LineMark(
                                x: .value("日期", item.0),
                                y: .value("心率", item.1)
                            )
                            .foregroundStyle(.purple)
                            
                            PointMark(
                                x: .value("日期", item.0),
                                y: .value("心率", item.1)
                            )
                            .foregroundStyle(.purple)
                            .symbolSize(50)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(formatDate(date))
                                        .font(.caption)
                                }
                                AxisGridLine()
                                AxisTick()
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let heartRate = value.as(Double.self) {
                                    Text("\(Int(heartRate))")
                                        .font(.caption)
                                }
                            }
                            AxisGridLine()
                            AxisTick()
                        }
                    }
                    .chartYScale(domain: viewModel.yAxisRange)
                    .frame(height: 180)
                }
            }
        }
        .onAppear {
            // 設定 ViewModel 的管理器
            viewModel.healthKitManager = healthKitManager
        }
        .task {
            await viewModel.loadHeartRateData()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

#Preview {
    SleepHeartRateChartView()
        .frame(height: 300)
        .padding()
}