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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("心率變化")
                .font(.headline)

            if isLoading {
                VStack {
                    ProgressView("載入心率數據中...")
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } else if let error = error {
                ContentUnavailableView(
                    error,
                    systemImage: "heart.slash",
                    description: Text("請稍後再試")
                )
                .frame(height: 200)
            } else if heartRates.isEmpty {
                ContentUnavailableView(
                    "沒有心率數據",
                    systemImage: "heart.slash",
                    description: Text("無法獲取此次訓練的心率數據")
                )
                .frame(height: 200)
            } else {
                // 心率範圍信息區塊
                HStack(spacing: 16) {
                    // 最高心率
                    VStack(alignment: .center, spacing: 4) {
                        Text("最高心率")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text(maxHeartRate.replacingOccurrences(of: " bpm", with: ""))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.red)

                            Text("bpm")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)


                    // 平均心率 (可選)
                    if let avgHR = averageHeartRate {
                        VStack(alignment: .center, spacing: 4) {
                            Text("平均心率")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(Int(avgHR))")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.purple)

                                Text("bpm")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                    }

                    // 最低心率
                    VStack(alignment: .center, spacing: 4) {
                        Text("最低心率")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text(minHeartRate.replacingOccurrences(of: " bpm", with: ""))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)

                            Text("bpm")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

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
                            y: .value("心率", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.red.opacity(0.1), Color.red.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYScale(domain: yAxisRange.min...(yAxisRange.max))
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        ZStack {
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
                .chartYScale(domain: yAxisRange.min...yAxisRange.max)
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
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic) { value in
                        if let heartRate = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(heartRate))")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartYScale(domain: yAxisRange.min...(yAxisRange.max + 10))
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
                error: nil
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
