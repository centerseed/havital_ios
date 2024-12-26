import SwiftUI
import Charts

struct HRVTrendChartView: View {
    @StateObject private var viewModel: HRVChartViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: HRVChartViewModel(healthKitManager: HealthKitManager()))
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("載入中...")
            } else if viewModel.hrvData.isEmpty {
                ContentUnavailableView(
                    "沒有 HRV 數據",
                    systemImage: "waveform.path.ecg",
                    description: Text("無法獲取心率變異性數據")
                )
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("時間範圍", selection: $viewModel.selectedTimeRange) {
                        ForEach(HRVChartViewModel.TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Chart {
                        ForEach(viewModel.hrvData, id: \.0) { item in
                            LineMark(
                                x: .value("日期", item.0),
                                y: .value("HRV", item.1)
                            )
                            .foregroundStyle(.blue)
                            
                            PointMark(
                                x: .value("日期", item.0),
                                y: .value("HRV", item.1)
                            )
                            .foregroundStyle(.blue)
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
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                Text("\(value.as(Double.self)?.formatted() ?? "")")
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: viewModel.selectedTimeRange) { _ in
            Task {
                await viewModel.loadHRVData()
            }
        }
        .task {
            await viewModel.loadHRVData()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

#Preview {
    HRVTrendChartView()
        .frame(height: 300)
        .padding()
}
