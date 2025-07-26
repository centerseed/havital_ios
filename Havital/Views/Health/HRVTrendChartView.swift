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
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "沒有 HRV 數據",
                        systemImage: "waveform.path.ecg",
                        description: Text("無法獲取心率變異性數據")
                    )
                    // 診斷按鈕
                    Button("診斷 HRV 問題") {
                        Task { await viewModel.fetchDiagnostics() }
                    }
                    // 顯示診斷結果
                    if let diag = viewModel.diagnosticsText {
                        Text(diag)
                            .font(.caption)
                            .padding()
                            .multilineTextAlignment(.leading)
                    }
                }
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
                        AxisMarks(values: .automatic(desiredCount: 5)) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(formatDate(date))
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
