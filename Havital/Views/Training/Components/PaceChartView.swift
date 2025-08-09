import SwiftUI
import Charts

struct PaceChartView: View {
    let paces: [DataPoint]
    let isLoading: Bool
    let error: String?
    let dataProvider: String?
    let deviceModel: String?
    
    init(paces: [DataPoint], isLoading: Bool, error: String?, dataProvider: String? = nil, deviceModel: String? = nil) {
        self.paces = paces
        self.isLoading = isLoading
        self.error = error
        self.dataProvider = dataProvider
        self.deviceModel = deviceModel
    }
    
    private func getMaxPace() -> Double {
        guard !paces.isEmpty else { return 0 }
        // 配速值越小表示越快，所以最大配速實際上是最小值
        return paces.map { $0.value }.min() ?? 0
    }
    
    private func getMinPace() -> Double {
        guard !paces.isEmpty else { return 0 }
        // 配速值越大表示越慢，所以最小配速實際上是最大值
        // 過濾掉異常慢的配速（例如大於1800秒/公里，即30分鐘/公里）
        let filteredPaces = paces.filter { $0.value <= 1800 }
        return filteredPaces.map { $0.value }.max() ?? 0
    }
    
    private func formatPaceFromSeconds(_ secondsPerKm: Double) -> String {
        guard secondsPerKm > 0 else { return "--:--" }
        let minutes = Int(secondsPerKm) / 60
        let seconds = Int(secondsPerKm) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var yAxisTickValues: [Double] {
        let range = paceChartYRange
        let lower = range.lowerBound
        let upper = range.upperBound
        var originalValues: [Double] = []

        if lower < upper {
            let spread = upper - lower
            // 生成5個刻度點
            let numberOfIntervals = 4
            for i in 0...numberOfIntervals {
                originalValues.append(lower + spread * (Double(i) / Double(numberOfIntervals)))
            }
        }
        
        // 轉換為反轉後的 Y 值
        let invertedValues = originalValues.map { invertedPaceValue($0) }
        
        // 過濾掉 NaN 或無限值，並確保唯一性和排序
        return Array(Set(invertedValues.filter { $0.isFinite })).sorted()
    }

    private var paceChartYRange: ClosedRange<Double> {
        // 預設配速範圍 (秒/公里)
        let defaultMinPace: Double = 180  // 3:00 min/km (很快的配速)
        let defaultMaxPace: Double = 600  // 10:00 min/km (慢跑配速)
        let absoluteMinPace: Double = 120 // 2:00 min/km (極快)
        let absoluteMaxPace: Double = 1200 // 20:00 min/km (走路)

        // 1. 處理空數據
        if paces.isEmpty {
            return defaultMinPace...defaultMaxPace
        }

        // 2. 過濾有效配速 (秒/公里)
        let validPaces = paces.map { $0.value }.filter { $0 > 0 && $0 <= absoluteMaxPace }

        guard !validPaces.isEmpty else {
            return defaultMinPace...defaultMaxPace
        }

        // 3. 從數據計算最小和最大配速
        var dataMinPace = validPaces.min() ?? defaultMinPace
        var dataMaxPace = validPaces.max() ?? defaultMaxPace
        
        // 將數據衍生的配速限制在絕對範圍內
        dataMinPace = max(dataMinPace, absoluteMinPace)
        dataMaxPace = min(dataMaxPace, absoluteMaxPace)

        // 如果計算後 min > max，則交換
        if dataMinPace > dataMaxPace {
            swap(&dataMinPace, &dataMaxPace)
        }
        
        // 4. 處理範圍太小的情況
        if dataMaxPace - dataMinPace < 30 { // 如果範圍小於30秒
            let centerPace = (dataMinPace + dataMaxPace) / 2
            dataMinPace = max(absoluteMinPace, centerPace - 30)
            dataMaxPace = min(absoluteMaxPace, centerPace + 30)
        }
        
        // 5. 添加邊距
        let margin = (dataMaxPace - dataMinPace) * 0.1 // 上下各10%邊距
        
        var finalMinPace = dataMinPace - margin
        var finalMaxPace = dataMaxPace + margin
        
        // 再次用絕對限制進行校準
        finalMinPace = max(finalMinPace, absoluteMinPace)
        finalMaxPace = min(finalMaxPace, absoluteMaxPace)

        // 確保最終範圍有效
        if finalMinPace >= finalMaxPace {
            return defaultMinPace...defaultMaxPace
        }
        
        return finalMinPace...finalMaxPace
    }
    
    private func invertedPaceValue(_ pace: Double) -> Double {
        let range = paceChartYRange
        return range.upperBound + range.lowerBound - pace
    }
    
    @ViewBuilder
    private var paceChart: some View {
        Chart {
            // 使用 ForEach 和 LineMark 繪製折線
            ForEach(paces) { point in
                LineMark(
                    x: .value("時間", point.time),
                    y: .value("配速", invertedPaceValue(point.value))
                )
                .foregroundStyle(Color.green.gradient)
                .interpolationMethod(.linear)
            }
            
            // 單獨繪製填色區域
            let lowerBound = paceChartYRange.lowerBound
            ForEach(paces) { point in
                AreaMark(
                    x: .value("時間", point.time),
                    yStart: .value("配速", lowerBound),
                    yEnd: .value("配速", invertedPaceValue(point.value))
                )
                .foregroundStyle(LinearGradient(
                    colors: [.green.opacity(0.3), .green.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .interpolationMethod(.linear)
            }
        }
        .frame(height: 180)
        .chartYAxis {
            AxisMarks(position: .leading, values: yAxisTickValues) { value in
                if let invertedPace = value.as(Double.self), invertedPace > 0 {
                    let originalPace = invertedPaceValue(invertedPace)
                    AxisValueLabel {
                        Text(formatPaceFromSeconds(originalPace))
                            .font(.caption2)
                    }
                }
                AxisTick()
                AxisGridLine()
            }
        }
        .chartYScale(domain: paceChartYRange)
        .chartXAxis {
            AxisMarks(values: .stride(by: .minute, count: 10)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(timeFormatter(date))
                            .font(.caption)
                    }
                }
            }
        }
    }
    
    private func timeFormatter(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let minute = Calendar.current.component(.minute, from: date)
        return String(format: "%d:%02d", hour, minute)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { // Group title and unit
                Text("配速變化")
                    .font(.headline)
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // Garmin Attribution as required by brand guidelines
                    ConditionalGarminAttributionView(
                        dataProvider: dataProvider,
                        deviceModel: deviceModel,
                        displayStyle: .titleLevel
                    )
                    
                    Text("(分鐘/公里)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if isLoading {
                VStack {
                    ProgressView("載入配速數據中...")
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } else if let error = error {
                ContentUnavailableView(
                    error,
                    systemImage: "figure.walk.motion",
                    description: Text("請稍後再試")
                )
                .frame(height: 200)
            } else if paces.isEmpty {
                ContentUnavailableView(
                    "沒有配速數據",
                    systemImage: "figure.walk.motion",
                    description: Text("無法獲取此次訓練的配速數據")
                )
                .frame(height: 200)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    // 配速圖表範圍和標籤
                    HStack {
                        HStack(spacing: 4) {
                            Text("最快:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatPaceFromSeconds(getMaxPace()))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Text("最慢:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatPaceFromSeconds(getMinPace()))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                    }


                    paceChart
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Previews
#if DEBUG
struct PaceChartView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleData: [DataPoint] = (0..<60).map { i in
            DataPoint(
                time: Date().addingTimeInterval(TimeInterval(i * 60)),
                value: 2.5 + Double.random(in: -0.5...0.5) // 大約 6:40-8:00 min/km 的配速
            )
        }
        
        return Group {
            PaceChartView(
                paces: sampleData,
                isLoading: false,
                error: nil
            )
            .previewDisplayName("With Data")
            
            PaceChartView(
                paces: [],
                isLoading: true,
                error: nil
            )
            .previewDisplayName("Loading")
            
            PaceChartView(
                paces: [],
                isLoading: false,
                error: "數據加載失敗"
            )
            .previewDisplayName("Error")
            
            PaceChartView(
                paces: [],
                isLoading: false,
                error: nil
            )
            .previewDisplayName("No Data")
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif
