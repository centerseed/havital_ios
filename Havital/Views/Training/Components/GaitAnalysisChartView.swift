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
            case .stanceTime: return "觸地時間"
            case .verticalRatio: return "移動效率"
            case .cadence: return "步頻"
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
            case .stanceTime: return "腳部接觸地面的時間，越短代表跑姿越有效率"
            case .verticalRatio: return "垂直移動與總移動距離的比率，越低代表移動效率越好"
            case .cadence: return "每分鐘步數，理想範圍約180左右"
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
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = maxValue - minValue
        let padding = range * 0.1 // 10% padding
        
        return (min: max(0, minValue - padding), max: maxValue + padding)
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
                Text("步態分析")
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
                    ProgressView("載入步態數據中...")
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } else if let error = error {
                ContentUnavailableView(
                    error,
                    systemImage: "figure.run",
                    description: Text("請稍後再試")
                )
                .frame(height: 200)
            } else if stanceTimes.isEmpty && verticalRatios.isEmpty && cadences.isEmpty {
                ContentUnavailableView(
                    "沒有步態數據",
                    systemImage: "figure.run",
                    description: Text("無法獲取此次訓練的步態分析數據")
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
                        StatItem(title: "平均值", value: currentStats.average, color: selectedGaitTab.color)
                        StatItem(title: "最小值", value: currentStats.min, color: selectedGaitTab.color)
                        StatItem(title: "最大值", value: currentStats.max, color: selectedGaitTab.color)
                        
                        Spacer()
                    }
                }
                .padding(.bottom, 8)

                // Chart
                Chart {
                    ForEach(currentData) { point in
                        LineMark(
                            x: .value("時間", point.time),
                            y: .value(selectedGaitTab.title, point.value)
                        )
                        .foregroundStyle(selectedGaitTab.color.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("時間", point.time),
                            yStart: .value(selectedGaitTab.title, yAxisRange.min),
                            yEnd: .value(selectedGaitTab.title, point.value)
                        )
                        .foregroundStyle(selectedGaitTab.color.opacity(0.1))
                        .interpolationMethod(.catmullRom)
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
    
    private var yAxisStride: Double {
        let range = yAxisRange.max - yAxisRange.min
        switch selectedGaitTab {
        case .stanceTime:
            return range < 50 ? 10 : 20
        case .verticalRatio:
            return range < 2 ? 0.5 : 1
        case .cadence:
            return range < 20 ? 5 : 10
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