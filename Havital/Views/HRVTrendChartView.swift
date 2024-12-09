import SwiftUI
import Charts
import HealthKit

struct HRVTrendChartView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var hrvData: [(Date, Double)] = []
    @State private var isLoading = true
    @State private var selectedPoint: (Date, Double)?
    
    var body: some View {
        VStack(alignment: .leading) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: 200)
            } else if hrvData.isEmpty {
                Text("無可用的 HRV 數據")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: 200)
            } else {
                Chart {
                    ForEach(hrvData, id: \.0) { item in
                        LineMark(
                            x: .value("日期", item.0),
                            y: .value("HRV", item.1)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        
                        if let selected = selectedPoint, selected.0 == item.0 {
                            PointMark(
                                x: .value("日期", item.0),
                                y: .value("HRV", item.1)
                            )
                            .foregroundStyle(.blue)
                            .symbolSize(100)
                            .annotation(position: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.0.formatted(.dateTime.month().day()))
                                        .font(.caption)
                                    Text("\(Int(item.1)) ms")
                                        .font(.caption.bold())
                                }
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemBackground))
                                        .shadow(radius: 2)
                                )
                            }
                        } else {
                            PointMark(
                                x: .value("日期", item.0),
                                y: .value("HRV", item.1)
                            )
                            .foregroundStyle(.blue)
                            .symbolSize(50)
                        }
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date.formatted(.dateTime.month().day()))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let xPosition = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                        guard xPosition >= 0,
                                              xPosition <= geometry[proxy.plotAreaFrame].width else {
                                            return
                                        }
                                        
                                        guard let date = proxy.value(atX: xPosition) as Date? else {
                                            return
                                        }
                                        
                                        // 找到最近的數據點
                                        let closest = hrvData.min { first, second in
                                            abs(first.0.timeIntervalSince(date)) < abs(second.0.timeIntervalSince(date))
                                        }
                                        
                                        withAnimation(.easeInOut(duration: 0.1)) {
                                            selectedPoint = closest
                                        }
                                    }
                                    .onEnded { _ in
                                        withAnimation(.easeInOut(duration: 0.1)) {
                                            selectedPoint = nil
                                        }
                                    }
                            )
                    }
                }
                .padding()
            }
        }
        .onAppear {
            loadHRVData()
        }
    }
    
    private func loadHRVData() {
        isLoading = true
        
        // 先請求授權
        healthKitManager.requestAuthorization { success in
            guard success else {
                print("HealthKit 授權失敗")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            // 授權成功後獲取數據
            Task {
                // 設定日期範圍為最近一個月
                let calendar = Calendar.current
                let now = Date()
                let endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)!
                let startDate = calendar.date(byAdding: .month, value: -1, to: calendar.startOfDay(for: endDate))!
                
                print("開始獲取 HRV 數據，時間範圍：\(startDate) 到 \(endDate)")
                let data = await healthKitManager.fetchHRVData(start: startDate, end: endDate)
                print("獲取到 \(data.count) 條 HRV 數據")
                
                // 按日期分組並計算每日平均值
                let groupedData = Dictionary(grouping: data) { item in
                    calendar.startOfDay(for: item.0)
                }
                
                let dailyAverages = groupedData.map { (date, values) in
                    let average = values.map { $0.1 }.reduce(0, +) / Double(values.count)
                    return (date, average)
                }.sorted { $0.0 < $1.0 }
                
                print("處理後得到 \(dailyAverages.count) 天的 HRV 平均值")
                
                await MainActor.run {
                    self.hrvData = dailyAverages
                    self.isLoading = false
                }
            }
        }
    }
}
