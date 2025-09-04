import SwiftUI
import Charts

struct HeartRateChartView: View {
    let heartRates: [DataPoint]
    let maxHeartRate: String
    let averageHeartRate: Double?
    let minHeartRate: String
    let yAxisRange: (min: Double, max: Double)
    let isLoading: Bool
    let error: String?
    let dataProvider: String?
    let deviceModel: String?
    
    init(heartRates: [DataPoint], maxHeartRate: String, averageHeartRate: Double?, minHeartRate: String, yAxisRange: (min: Double, max: Double), isLoading: Bool, error: String?, dataProvider: String? = nil, deviceModel: String? = nil) {
        self.heartRates = heartRates
        self.maxHeartRate = maxHeartRate
        self.averageHeartRate = averageHeartRate
        self.minHeartRate = minHeartRate
        self.yAxisRange = yAxisRange
        self.isLoading = isLoading
        self.error = error
        self.dataProvider = dataProvider
        self.deviceModel = deviceModel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.HeartRateChart.title.localized)
                    .font(.headline)
                
                Spacer()
                
                // Garmin Attribution as required by brand guidelines
                ConditionalGarminAttributionView(
                    dataProvider: dataProvider,
                    deviceModel: deviceModel,
                    displayStyle: .compact
                )
            }

            if isLoading {
                VStack {
                    ProgressView(L10n.HeartRateChart.loading.localized)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } else if let error = error {
                ContentUnavailableView(
                    error,
                    systemImage: "heart.slash",
                    description: Text(L10n.HeartRateChart.tryAgain.localized)
                )
                .frame(height: 200)
            } else if heartRates.isEmpty {
                ContentUnavailableView(
                    L10n.HeartRateChart.noData.localized,
                    systemImage: "heart.slash",
                    description: Text(L10n.HeartRateChart.unableToGetData.localized)
                )
                .frame(height: 200)
            } else {

                Chart {
                    ForEach(heartRates) { point in
                        LineMark(
                            x: .value("時間", point.time),
                            y: .value("心率", point.value)
                        )
                        .foregroundStyle(Color.red.gradient)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("時間", point.time),
                            yStart: .value("心率", yAxisRange.min),
                            yEnd: .value("心率", point.value)
                        )
                        .foregroundStyle(Color.red.opacity(0.1))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYScale(domain: yAxisRange.min...yAxisRange.max)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        ZStack {
                            // 繪製水平格線
                            ForEach(
                                Array(
                                    stride(
                                        from: yAxisRange.min,
                                        to: yAxisRange.max, by: 20)), id: \.self
                            ) { yValue in
                                if let yPosition = proxy.position(forY: yValue) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 1)
                                        .position(x: geometry.size.width / 2, y: yPosition)
                                        .frame(width: geometry.size.width)
                                }
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .stride(by: 10)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        if let heartRate = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(heartRate))")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .minute, count: 10)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(
                                    "\(Calendar.current.component(.hour, from: date)):\(String(format: "%02d", Calendar.current.component(.minute, from: date)))"
                                )
                                .font(.caption)
                            }
                        }
                    }
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
struct HeartRateChartView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleData: [DataPoint] = (0..<60).map { i in
            DataPoint(
                time: Date().addingTimeInterval(TimeInterval(i * 60)),
                value: Double(60 + Int.random(in: 0...30))
            )
        }
        
        return Group {
            HeartRateChartView(
                heartRates: sampleData,
                maxHeartRate: "180 bpm",
                averageHeartRate: 150,
                minHeartRate: "70 bpm",
                yAxisRange: (min: 50, max: 200),
                isLoading: false,
                error: nil,
                dataProvider: "Garmin",
                deviceModel: "Forerunner 955"
            )
            .previewDisplayName("With Data")
            
            HeartRateChartView(
                heartRates: [],
                maxHeartRate: "--",
                averageHeartRate: nil,
                minHeartRate: "--",
                yAxisRange: (min: 0, max: 200),
                isLoading: true,
                error: nil
            )
            .previewDisplayName("Loading")
            
            HeartRateChartView(
                heartRates: [],
                maxHeartRate: "--",
                averageHeartRate: nil,
                minHeartRate: "--",
                yAxisRange: (min: 0, max: 200),
                isLoading: false,
                error: "數據加載失敗"
            )
            .previewDisplayName("Error")
            
            HeartRateChartView(
                heartRates: [],
                maxHeartRate: "--",
                averageHeartRate: nil,
                minHeartRate: "--",
                yAxisRange: (min: 0, max: 200),
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
