import SwiftUI
import Charts

struct PaceChartView: View {
    let paces: [DataPoint]
    let isLoading: Bool
    let error: String?
    
    private func getMaxPace() -> Double {
        guard !paces.isEmpty else { return 0 }
        return paces.map { $0.value }.max() ?? 0
    }
    
    private func getMinPace() -> Double {
        guard !paces.isEmpty else { return 0 }
        // 過濾掉過慢的配速（例如小於0.25 m/s 的配速）
        let filteredPaces = paces.filter { $0.value >= 0.25 }
        return filteredPaces.map { $0.value }.min() ?? 0
    }
    
    private func formatPaceFromMetersPerSecond(_ speed: Double) -> String {
        guard speed > 0 else { return "--:--" }
        let secondsPerKm = 1000 / speed
        let minutes = Int(secondsPerKm) / 60
        let seconds = Int(secondsPerKm) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatSlowestPace(_ speed: Double) -> String {
        guard speed > 0 else { return "--:--" }
        let secondsPerKm = 1000 / speed
        let minutes = Int(secondsPerKm) / 60
        let seconds = Int(secondsPerKm) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var yAxisTickValues: [Double] {
        let range = speedChartYRange
        let lower = range.lowerBound
        let upper = range.upperBound
        var values: [Double] = []

        // 預設情況下的速度值，用於 fallback
        let defaultMinSpeed: Double = 1.0
        let defaultMaxSpeed: Double = 5.0

        if lower < upper {
            let spread = upper - lower
            // 避免除以零或極小間距導致的問題，設定一個最小有效間距閾值
            if spread > 1e-7 { // 例如 0.0000001 m/s
                let numberOfIntervals = 4 // 這會產生 5 個刻度點
                for i in 0...numberOfIntervals {
                    values.append(lower + spread * (Double(i) / Double(numberOfIntervals)))
                }
            } else {
                // 如果間距非常小，只顯示中間值或上下限 (如果它們不同)
                values.append(lower)
                if upper != lower { values.append(upper) }
            }
        } else if lower == upper { // 如果範圍是一個單點
            // 產生一個小範圍圍繞該點，例如 +/- 5% 或一個固定值
            let delta = max(lower * 0.05, 0.1) // 至少 +/- 0.1 m/s
            values.append(lower - delta)
            values.append(lower)
            values.append(lower + delta)
        } else { // lower > upper (理論上不應發生，但作為防禦)
            // Fallback 到預設的速度範圍刻度
            let defaultSpread = defaultMaxSpeed - defaultMinSpeed
            let numberOfIntervals = 4
            for i in 0...numberOfIntervals {
                values.append(defaultMinSpeed + defaultSpread * (Double(i) / Double(numberOfIntervals)))
            }
        }
        // 過濾掉 NaN 或無限值，並確保唯一性和排序
        return Array(Set(values.filter { $0.isFinite })).sorted()
    }

    private var speedChartYRange: ClosedRange<Double> {
        // 預設速度範圍 (m/s)
        let defaultMinSpeed: Double = 1.0  // 約 16:40 min/km
        let defaultMaxSpeed: Double = 5.0  // 約 3:20 min/km
        let absoluteMinSpeed: Double = 0.1 // 避免除以零或非常慢的速度
        let absoluteMaxSpeed: Double = 10.0 // 約 1:40 min/km (博爾特衝刺級別)

        // 1. 處理空數據
        // 如果 paces 陣列為空，則返回預設範圍。
        // 否則，即使在預覽模式下，也繼續使用實際數據計算範圍。
        if paces.isEmpty {
            // print("PaceChartView: paces is empty, returning default speed range.") // 可用於調試
            return defaultMinSpeed...defaultMaxSpeed
        }

        // 2. 過濾有效速度 (m/s)
        let validSpeeds = paces.map { $0.value }.filter { $0 >= absoluteMinSpeed }

        guard !validSpeeds.isEmpty else {
            return defaultMinSpeed...defaultMaxSpeed
        }

        // 3. 從數據計算最小和最大速度
        var dataMinSpeed = validSpeeds.min() ?? defaultMinSpeed
        var dataMaxSpeed = validSpeeds.max() ?? defaultMaxSpeed
        
        // 將數據衍生的速度限制在絕對範圍內
        dataMinSpeed = max(dataMinSpeed, absoluteMinSpeed)
        dataMaxSpeed = min(dataMaxSpeed, absoluteMaxSpeed)

        // 如果計算後 min > max (不太可能，除非數據特殊或預設值交叉)，則交換
        if dataMinSpeed > dataMaxSpeed {
            swap(&dataMinSpeed, &dataMaxSpeed)
        }
        
        // 4. 處理最小速度接近或大於最大速度的情況 (例如所有數據點相同)
        if dataMinSpeed >= dataMaxSpeed {
            let centerSpeed = dataMinSpeed
            dataMinSpeed = max(absoluteMinSpeed, centerSpeed * 0.9)
            dataMaxSpeed = min(absoluteMaxSpeed, centerSpeed * 1.1)
            
            if dataMinSpeed >= dataMaxSpeed { // 如果調整後仍然無效，則回退到預設值
                 return defaultMinSpeed...defaultMaxSpeed
            }
        }
        
        // 5. 添加邊距
        let margin = (dataMaxSpeed - dataMinSpeed) * 0.1 // 上下各10%邊距
        
        var finalMinSpeed = dataMinSpeed - margin
        var finalMaxSpeed = dataMaxSpeed + margin
        
        // 再次用絕對限制進行校準
        finalMinSpeed = max(finalMinSpeed, absoluteMinSpeed)
        finalMaxSpeed = min(finalMaxSpeed, absoluteMaxSpeed)

        // 確保最終範圍有效
        if finalMinSpeed >= finalMaxSpeed {
            if dataMinSpeed < dataMaxSpeed { 
                return dataMinSpeed...dataMaxSpeed
            }
            return defaultMinSpeed...defaultMaxSpeed
        }
        
        return finalMinSpeed...finalMaxSpeed
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { // Group title and unit
                Text("配速變化")
                    .font(.headline)
                Spacer()
                Text("(分鐘/公里)")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                            Text(formatPaceFromSeconds(1000 / getMaxPace()))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Text("最慢:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatPaceFromSeconds(1000 / getMinPace()))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                    }


                    Chart {
                        // 使用 ForEach 和 LineMark 繪製折線
                        ForEach(paces) { point in
                            LineMark(
                                x: .value("時間", point.time),
                                y: .value("速度", point.value)
                            )
                            .foregroundStyle(Color.green.gradient)
                            .interpolationMethod(.catmullRom)
                        }
                        
                        // 單獨繪製填色區域，確保底部邊界正確
                        ForEach(Array(paces.enumerated()), id: \.element.id) { index, point in
                            AreaMark(
                                x: .value("時間", point.time),
                                yStart: .value("速度", speedChartYRange.lowerBound), // 使用圖表範圍的下限作為填色底部
                                yEnd: .value("速度", point.value)
                            )
                            .foregroundStyle(LinearGradient(
                                colors: [.green.opacity(0.3), .green.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .frame(height: 180)
                    // .chartYScale(domain: paceChartYRange) // 移除重複的，下方已包含 reversed: true
                    .chartYAxis {
                        // 將Y軸標籤移至左側，並使用計算好的刻度值
                        AxisMarks(position: .leading, values: yAxisTickValues) { value in
                            if let speedInMps = value.as(Double.self), speedInMps > 0 {
                                AxisValueLabel {
                                    Text(formatPaceFromSeconds(1000 / speedInMps)) // 將速度(m/s)轉為配速(s/km)再格式化
                                        .font(.caption2)
                                }
                            } else if let speedInMps = value.as(Double.self), speedInMps == 0 {
                                AxisValueLabel {
                                    Text("∞") // 速度為0時配速為無窮大
                                        .font(.caption2)
                                }
                            }
                            AxisTick()
                            AxisGridLine()
                        }
                    }
                    .chartYScale(domain: speedChartYRange) // 使用速度範圍，不再需要反轉
                    // X軸配置不變
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
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func formatPaceFromSeconds(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
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
