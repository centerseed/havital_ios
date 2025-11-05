import SwiftUI
import Charts

/// 統一的睡眠靜息心率圖表視圖
/// ✅ 合併原本的 SleepHeartRateChartView 和 SleepHeartRateChartViewWithGarmin
/// ✅ ViewModel 已根據數據源自動處理數據加載，無需分開兩個視圖
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
                    // ✅ 優化：移除重複 Garmin 標籤（父視圖已在頂級顯示）

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