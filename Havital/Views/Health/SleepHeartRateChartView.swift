import SwiftUI
import Charts

struct SleepHeartRateChartView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @StateObject private var viewModel: SleepHeartRateViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: SleepHeartRateViewModel())
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("載入中...")
            } else if viewModel.heartRateData.isEmpty {
                ContentUnavailableView(
                    "沒有睡眠心率數據",
                    systemImage: "heart.fill",
                    description: Text("無法獲取睡眠心率數據")
                )
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("時間範圍", selection: $viewModel.selectedTimeRange) {
                        ForEach(SleepHeartRateViewModel.TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    
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
                        switch viewModel.selectedTimeRange {
                        case .week:
                            AxisMarks(values: .stride(by: .day)) { value in
                                if let date = value.as(Date.self) {
                                    AxisValueLabel {
                                        Text(formatDate(date))
                                    }
                                }
                            }
                        case .month:
                            AxisMarks(values: .stride(by: .day)) { value in
                                if let date = value.as(Date.self) {
                                    let calendar = Calendar.current
                                    let day = calendar.component(.day, from: date)
                                    if day == 1 || day % 5 == 0 {
                                        AxisValueLabel {
                                            Text(formatDate(date))
                                        }
                                        AxisTick()
                                        AxisGridLine()
                                    }
                                }
                            }
                        case .threeMonths:
                            AxisMarks(values: .stride(by: .day)) { value in
                                if let date = value.as(Date.self) {
                                    let calendar = Calendar.current
                                    let day = calendar.component(.day, from: date)
                                    if day == 1 || day % 5 == 0 {
                                        AxisValueLabel {
                                            Text(formatDate(date))
                                        }
                                        AxisTick()
                                        AxisGridLine()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: viewModel.selectedTimeRange) { _ in
            Task {
                await viewModel.loadHeartRateData()
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
                ContentUnavailableView(
                    "沒有睡眠心率數據",
                    systemImage: "heart.fill",
                    description: Text("無法獲取睡眠心率數據")
                )
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("時間範圍", selection: $viewModel.selectedTimeRange) {
                        ForEach(SleepHeartRateViewModel.TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    
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
                        AxisMarks(values: .stride(by: .day, count: 1)) { value in
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
                        AxisMarks { value in
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
                    .frame(height: 200)
                    
                    if let latestData = viewModel.heartRateData.last {
                        HStack {
                            Text("最新: \(Int(latestData.1)) BPM")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatDate(latestData.0))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .onChange(of: viewModel.selectedTimeRange) { _ in
            Task {
                await viewModel.loadHeartRateData()
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
