import SwiftUI
import Charts

// VDOT Chart Preview for testing single data point scenario
struct VDOTChartPreview: View {
    
    var body: some View {
        VStack(spacing: 20) {
            Text("VDOT Chart Preview Tests")
                .font(.title2)
                .fontWeight(.bold)
                .padding()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Test 1: Single data point scenario
                    VStack(alignment: .leading) {
                        Text("测试 1: 单个数据点")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        MockVDOTChartView(scenario: .singlePoint)
                            .padding(.horizontal)
                    }
                    
                    // Test 2: Two data points
                    VStack(alignment: .leading) {
                        Text("测试 2: 两个数据点")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        MockVDOTChartView(scenario: .twoPoints)
                            .padding(.horizontal)
                    }
                    
                    // Test 3: Multiple data points (normal scenario)
                    VStack(alignment: .leading) {
                        Text("测试 3: 多个数据点 (正常情况)")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        MockVDOTChartView(scenario: .multiplePoints)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }
}

// Mock VDOT Chart View for testing different scenarios
struct MockVDOTChartView: View {
    let scenario: TestScenario
    @Environment(\.colorScheme) var colorScheme
    
    enum TestScenario {
        case singlePoint
        case twoPoints
        case multiplePoints
    }
    
    private var testData: [VDOTDataPoint] {
        let calendar = Calendar.current
        let today = Date()
        
        switch scenario {
        case .singlePoint:
            return [
                VDOTDataPoint(
                    date: today,
                    value: 34.59,
                    weightVdot: 34.59
                )
            ]
            
        case .twoPoints:
            return [
                VDOTDataPoint(
                    date: calendar.date(byAdding: .day, value: -1, to: today)!,
                    value: 34.2,
                    weightVdot: 34.2
                ),
                VDOTDataPoint(
                    date: today,
                    value: 34.59,
                    weightVdot: 34.59
                )
            ]
            
        case .multiplePoints:
            return (0..<7).map { dayOffset in
                VDOTDataPoint(
                    date: calendar.date(byAdding: .day, value: -dayOffset, to: today)!,
                    value: 34.0 + Double(dayOffset) * 0.1 + Double.random(in: -0.3...0.3),
                    weightVdot: 34.0 + Double(dayOffset) * 0.08 + Double.random(in: -0.2...0.2)
                )
            }.reversed()
        }
    }
    
    // Calculate Y-axis range similar to the real implementation
    private var yAxisRange: ClosedRange<Double> {
        let values = testData.flatMap { [$0.value, $0.weightVdot].compactMap { $0 } }
        guard !values.isEmpty else { return 30...40 }
        
        let minValue = values.min()!
        let maxValue = values.max()!
        let range = maxValue - minValue
        
        if range < 1.0 {
            let center = (minValue + maxValue) / 2
            return (center - 2.0)...(center + 2.0)
        } else {
            let margin = range * 0.3
            return (minValue - margin)...(maxValue + margin)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            HStack {
                Text("动态跑力 (VDOT)")
                    .font(.headline)
                
                Button {
                    // Info button action
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.bottom, 8)
            
            // Chart
            Chart {
                ForEach(testData) { point in
                    // 动态跑力曲线
                    LineMark(
                        x: .value("日期", point.date),
                        y: .value("跑力", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(by: .value("种类", "动态跑力"))
                    
                    // 加权跑力曲线
                    if let weight = point.weightVdot {
                        LineMark(
                            x: .value("日期", point.date),
                            y: .value("跑力", weight)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(by: .value("种类", "加权跑力"))
                    }
                    
                    // 动态跑力点
                    PointMark(
                        x: .value("日期", point.date),
                        y: .value("跑力", point.value)
                    )
                    .foregroundStyle(by: .value("种类", "动态跑力"))
                    
                    // 加权跑力点
                    if let weight = point.weightVdot {
                        PointMark(
                            x: .value("日期", point.date),
                            y: .value("跑力", weight)
                        )
                        .foregroundStyle(by: .value("种类", "加权跑力"))
                    }
                }
            }
            .chartForegroundStyleScale([
                "动态跑力": Color.blue,
                "加权跑力": Color.orange
            ])
            .frame(height: 120) // Updated height
            .chartYScale(domain: yAxisRange)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(String(format: "%.1f", doubleValue))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Stats
            HStack(alignment: .top, spacing: 12) {
                statsBox(
                    title: "加权跑力",
                    value: String(format: "%.2f", testData.last?.weightVdot ?? 0),
                    backgroundColor: Color.blue.opacity(0.15)
                )
                
                statsBox(
                    title: "最新跑力",
                    value: String(format: "%.2f", testData.last?.value ?? 0),
                    backgroundColor: Color.green.opacity(0.15)
                )
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func statsBox(title: String, value: String, backgroundColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(backgroundColor)
        .cornerRadius(8)
    }
}

struct VDOTChartPreview_Previews: PreviewProvider {
    static var previews: some View {
        VDOTChartPreview()
            .previewDisplayName("VDOT Chart Tests")
    }
}