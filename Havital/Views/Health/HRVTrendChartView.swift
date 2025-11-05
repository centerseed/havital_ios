import SwiftUI
import Charts

struct HRVTrendChartView: View {
    @StateObject private var viewModel: HRVChartViewModel
    @StateObject private var userPreferenceManager = UserPreferenceManager.shared
    
    init() {
        _viewModel = StateObject(wrappedValue: HRVChartViewModel(healthKitManager: HealthKitManager()))
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("載入中...")
            } else if viewModel.hrvData.isEmpty {
                VStack(spacing: 16) {
                    EmptyStateView(type: .hrvData)
                    
                    // 診斷按鈕
                    Button("診斷 HRV 問題") {
                        Task { await viewModel.fetchDiagnostics() }
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.blue)
                    .cornerRadius(8)
                    
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
                    // ✅ 優化：移除重複標題（選項卡已顯示「心率變異性 (HRV) 趨勢」）
                    // ✅ 優化：移除重複 Garmin 標籤（父視圖已在頂級顯示）

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
                                Text("\(value.as(Double.self)?.formatted() ?? "")")
                            }
                        }
                    }
                }
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
