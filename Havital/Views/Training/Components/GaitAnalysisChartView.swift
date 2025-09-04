import SwiftUI
import Charts
import Foundation

struct GaitAnalysisChartView: View {
    let stanceTimes: [DataPoint]
    let verticalRatios: [DataPoint] 
    let cadences: [DataPoint]
    let isLoading: Bool
    let error: String?
    let dataProvider: String?
    let deviceModel: String?
    
    @State private var selectedGaitTab: GaitTab = .stanceTime
    
    enum GaitTab: CaseIterable {
        case stanceTime, verticalRatio, cadence
        
        var title: String {
            switch self {
            case .stanceTime: return L10n.GaitAnalysisChart.GaitTab.stanceTime.localized
            case .verticalRatio: return L10n.GaitAnalysisChart.GaitTab.verticalRatio.localized
            case .cadence: return L10n.GaitAnalysisChart.GaitTab.cadence.localized
            }
        }
        
        var color: Color {
            switch self {
            case .stanceTime: return .blue
            case .verticalRatio: return .green
            case .cadence: return .orange
            }
        }
        
        var unit: String {
            switch self {
            case .stanceTime: return "ms"
            case .verticalRatio: return "%"
            case .cadence: return "spm"
            }
        }
        
        var description: String {
            switch self {
            case .stanceTime: return L10n.GaitAnalysisChart.GaitTab.stanceTimeDescription.localized
            case .verticalRatio: return L10n.GaitAnalysisChart.GaitTab.verticalRatioDescription.localized
            case .cadence: return L10n.GaitAnalysisChart.GaitTab.cadenceDescription.localized
            }
        }
    }
    
    init(stanceTimes: [DataPoint], verticalRatios: [DataPoint], cadences: [DataPoint], isLoading: Bool, error: String?, dataProvider: String? = nil, deviceModel: String? = nil) {
        self.stanceTimes = stanceTimes
        self.verticalRatios = verticalRatios
        self.cadences = cadences
        self.isLoading = isLoading
        self.error = error
        self.dataProvider = dataProvider
        self.deviceModel = deviceModel
    }
    
    // MARK: - Data Processing
    
    private var currentData: [DataPoint] {
        switch selectedGaitTab {
        case .stanceTime: return stanceTimes
        case .verticalRatio: return verticalRatios
        case .cadence: return cadences
        }
    }
    
    private var yAxisRange: (min: Double, max: Double) {
        guard !currentData.isEmpty else { return (min: 0, max: 1) }
        let values = currentData.map { $0.value }
        let sortedValues = values.sorted()
        let count = sortedValues.count
        
        // Get basic stats
        let minValue = sortedValues.first ?? 0
        let maxValue = sortedValues.last ?? 1
        let totalRange = maxValue - minValue
        
        // Use different strategies based on metric type
        switch selectedGaitTab {
        case .stanceTime:
            // For stance time, ensure we show reasonable range but accommodate outliers
            let p10Index = max(0, Int(Double(count) * 0.10))
            let p90Index = min(count - 1, Int(Double(count) * 0.90))
            let p10Value = sortedValues[p10Index]
            let p90Value = sortedValues[p90Index]
            
            // Extend range to accommodate outliers but keep reasonable scale
            let rangeMin = max(0, min(p10Value - 20, minValue - 10))
            let rangeMax = max(p90Value + 30, maxValue)
            
            return (min: rangeMin, max: rangeMax)
            
        case .verticalRatio:
            // For vertical ratio, use a more constrained range
            let p5Index = max(0, Int(Double(count) * 0.05))
            let p95Index = min(count - 1, Int(Double(count) * 0.95))
            let p5Value = sortedValues[p5Index]
            let p95Value = sortedValues[p95Index]
            
            let padding = max(1.0, (p95Value - p5Value) * 0.2)
            return (min: max(0, p5Value - padding), max: p95Value + padding)
            
        case .cadence:
            // For cadence, use wider range to show context
            let padding = max(10.0, totalRange * 0.1)
            return (min: max(0, minValue - padding), max: maxValue + padding)
        }
    }
    
    // MARK: - Statistics
    
    private var currentStats: (average: String, min: String, max: String) {
        guard !currentData.isEmpty else { return ("-", "-", "-") }
        
        let values = currentData.map { $0.value }
        let avg = values.reduce(0, +) / Double(values.count)
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 0
        
        switch selectedGaitTab {
        case .stanceTime:
            return (
                String(format: "%.1f ms", avg),
                String(format: "%.1f ms", minVal),
                String(format: "%.1f ms", maxVal)
            )
        case .verticalRatio:
            return (
                String(format: "%.1f%%", avg),
                String(format: "%.1f%%", minVal),
                String(format: "%.1f%%", maxVal)
            )
        case .cadence:
            return (
                String(format: "%.0f spm", avg),
                String(format: "%.0f spm", minVal),
                String(format: "%.0f spm", maxVal)
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.GaitAnalysisChart.title.localized)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Garmin Attribution as required by brand guidelines
                if let dataProvider = dataProvider, dataProvider.lowercased().contains("garmin") {
                    HStack(spacing: 4) {
                        Image("garmin_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 12)
                        
                        if let deviceModel = deviceModel {
                            Text(deviceModel)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            if isLoading {
                VStack {
                    ProgressView(L10n.GaitAnalysisChart.loading.localized)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } else if let error = error {
                ContentUnavailableView(
                    error,
                    systemImage: "figure.run",
                    description: Text(L10n.GaitAnalysisChart.tryAgain.localized)
                )
                .frame(height: 200)
            } else if stanceTimes.isEmpty && verticalRatios.isEmpty && cadences.isEmpty {
                ContentUnavailableView(
                    L10n.GaitAnalysisChart.noData.localized,
                    systemImage: "figure.run",
                    description: Text(L10n.GaitAnalysisChart.unableToGetData.localized)
                )
                .frame(height: 200)
            } else {
                // Debug: 打印數據狀態
                let _ = print("📊 [GaitChart] 觸地時間數據點: \(stanceTimes.count)")
                let _ = print("📊 [GaitChart] 垂直比率數據點: \(verticalRatios.count)")
                let _ = print("📊 [GaitChart] 步頻數據點: \(cadences.count)")
                
                // Tab selector
                let availableTabs = GaitTab.allCases.filter { tab in
                    switch tab {
                    case .stanceTime: return !stanceTimes.isEmpty
                    case .verticalRatio: return !verticalRatios.isEmpty
                    case .cadence: return !cadences.isEmpty
                    }
                }
                
                let _ = print("📊 [GaitChart] 可用標籤頁: \(availableTabs.map { $0.title })")
                
                if availableTabs.count > 1 {
                    Picker("步態指標", selection: $selectedGaitTab) {
                        ForEach(availableTabs, id: \.self) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Current metric description
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedGaitTab.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    // Statistics row
                    HStack(spacing: 24) {
                        StatItem(title: L10n.GaitAnalysisChart.average.localized, value: currentStats.average, color: selectedGaitTab.color)
                        StatItem(title: L10n.GaitAnalysisChart.minimum.localized, value: currentStats.min, color: selectedGaitTab.color)
                        StatItem(title: L10n.GaitAnalysisChart.maximum.localized, value: currentStats.max, color: selectedGaitTab.color)
                        
                        Spacer()
                    }
                }
                .padding(.bottom, 8)

                // Chart
                Chart {
                    ForEach(currentData) { point in
                        // Use PointMark (dots) instead of LineMark for better outlier handling
                        PointMark(
                            x: .value("時間", point.time),
                            y: .value(selectedGaitTab.title, point.value)
                        )
                        .foregroundStyle(pointColor(for: point.value))
                        .symbolSize(pointSize(for: point.value))
                        .opacity(pointOpacity(for: point.value))
                    }
                    
                    // 統計值參考線
                    let values = currentData.map { $0.value }
                    if !values.isEmpty {
                        let avgValue = values.reduce(0, +) / Double(values.count)
                        let minValue = values.min() ?? 0
                        let maxValue = values.max() ?? 0
                        
                        // 平均值線
                        RuleMark(y: .value("平均", avgValue))
                            .foregroundStyle(selectedGaitTab.color.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        
                        // 最大值線 
                        RuleMark(y: .value("最大", maxValue))
                            .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        
                        // 最小值線
                        RuleMark(y: .value("最小", minValue))
                            .foregroundStyle(Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .chartYScale(domain: yAxisRange.min...yAxisRange.max)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .stride(by: yAxisStride)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
                            .foregroundStyle(Color.primary.opacity(0.2))
                        if let yValue = value.as(Double.self) {
                            AxisValueLabel {
                                Text(formatYAxisLabel(yValue))
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
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Helper Methods
    
    private func pointSize(for value: Double) -> CGFloat {
        // Base point size
        let baseSize: CGFloat = 30
        
        // Check if value is an outlier
        if isOutlier(value) {
            return baseSize * 1.3 // Make outliers slightly larger
        } else {
            return baseSize
        }
    }
    
    private func pointOpacity(for value: Double) -> Double {
        // Check if value is an outlier
        if isOutlier(value) {
            return 0.6 // Make outliers more transparent
        } else {
            return 0.8 // Normal opacity
        }
    }
    
    private func isOutlier(_ value: Double) -> Bool {
        guard !currentData.isEmpty else { return false }
        let values = currentData.map { $0.value }
        let sortedValues = values.sorted()
        let count = sortedValues.count
        
        // Use 5th and 95th percentiles to identify outliers
        let p5Index = max(0, Int(Double(count) * 0.05))
        let p95Index = min(count - 1, Int(Double(count) * 0.95))
        
        let p5Value = sortedValues[p5Index]
        let p95Value = sortedValues[p95Index]
        
        return value < p5Value || value > p95Value
    }
    
    private func pointColor(for value: Double) -> Color {
        switch selectedGaitTab {
        case .verticalRatio:
            // 移動效率 (垂直比率) - 藍(優秀) -> 綠(良好) -> 黃(普通) -> 橙(差) -> 紅(很差)
            if value < 3.0 {
                return .blue // 奧運選手級別
            } else if value < 6.1 {
                return .green // 優越
            } else if value < 7.4 {
                return .green.opacity(0.7) // 良好
            } else if value < 8.6 {
                return .yellow // 好
            } else if value < 10.1 {
                return .orange // 普通
            } else {
                return .red // 差
            }
            
        case .stanceTime:
            // 觸地時間 (毫秒) - 藍(菁英) -> 綠(優越) -> 黃(良好) -> 橙(普通) -> 紅(差)
            if value < 170 {
                return .blue // 菁英
            } else if value < 190 {
                return .green // 優越
            } else if value < 210 {
                return .green.opacity(0.7) // 良好
            } else if value < 240 {
                return .yellow // 普通
            } else {
                return .red // 差
            }
            
        case .cadence:
            // 步頻 (spm) - 綠色為理想區間，橙色為次佳，紅色為不理想
            if value >= 170 && value <= 190 {
                return .green // 理想步頻區間
            } else if (value >= 150 && value < 170) || (value > 190 && value <= 200) {
                return .orange // 次佳區間
            } else {
                return .red // 不理想區間 (<150 或 >200)
            }
        }
    }
    
    private var yAxisStride: Double {
        let range = yAxisRange.max - yAxisRange.min
        switch selectedGaitTab {
        case .stanceTime:
            if range < 50 {
                return 10
            } else if range < 100 {
                return 20
            } else if range < 200 {
                return 30
            } else {
                return 50
            }
        case .verticalRatio:
            if range < 2 {
                return 0.5
            } else if range < 5 {
                return 1
            } else {
                return 2
            }
        case .cadence:
            if range < 20 {
                return 5
            } else if range < 50 {
                return 10
            } else {
                return 20
            }
        }
    }
    
    private func formatYAxisLabel(_ value: Double) -> String {
        switch selectedGaitTab {
        case .stanceTime:
            return "\(Int(value))"
        case .verticalRatio:
            return String(format: "%.1f", value)
        case .cadence:
            return "\(Int(value))"
        }
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// MARK: - Previews
#if DEBUG
struct GaitAnalysisChartView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleStanceTimes: [DataPoint] = (0..<60).map { i in
            DataPoint(
                time: Date().addingTimeInterval(TimeInterval(i * 60)),
                value: Double(220 + Int.random(in: -30...30))
            )
        }
        
        let sampleVerticalRatios: [DataPoint] = (0..<60).map { i in
            DataPoint(
                time: Date().addingTimeInterval(TimeInterval(i * 60)),
                value: Double(8.5 + Double.random(in: -1.5...1.5))
            )
        }
        
        let sampleCadences: [DataPoint] = (0..<60).map { i in
            DataPoint(
                time: Date().addingTimeInterval(TimeInterval(i * 60)),
                value: Double(180 + Int.random(in: -20...20))
            )
        }
        
        return Group {
            GaitAnalysisChartView(
                stanceTimes: sampleStanceTimes,
                verticalRatios: sampleVerticalRatios,
                cadences: sampleCadences,
                isLoading: false,
                error: nil,
                dataProvider: "Garmin",
                deviceModel: "Forerunner 965"
            )
            .previewLayout(.sizeThatFits)
            .padding()
            
            GaitAnalysisChartView(
                stanceTimes: [],
                verticalRatios: sampleVerticalRatios,
                cadences: [],
                isLoading: false,
                error: nil
            )
            .previewLayout(.sizeThatFits)
            .padding()
            
            GaitAnalysisChartView(
                stanceTimes: [],
                verticalRatios: [],
                cadences: [],
                isLoading: true,
                error: nil
            )
            .previewLayout(.sizeThatFits)
            .padding()
        }
    }
}
#endif