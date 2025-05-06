import SwiftUI
import Charts

// Chart View
struct VDOTChartView: View {
    @StateObject private var viewModel = VDOTChartViewModel()
    @State private var selectedPoint: VDOTDataPoint? = nil
    @State private var showingHeartRateZoneEditor = false
    @State private var showingInfo = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            HStack {
                Text("動態跑力 (VDOT)")
                    .font(.headline)
                
                Button {
                    showingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .alert("什麼是動態跑力？", isPresented: $showingInfo) {
                    Button("了解", role: .cancel) {}
                } message: {
                    Text("動態跑力是根據您的跑步表現和心率數據綜合計算的指標，反映您的真實跑步能力。\n\n動態跑力會依據訓練的類型，氣溫是度以及當天身體狀況而有起伏。隨著訓練的進行，動態跑力會因您的體能上升而有上升的趨勢。\n\n加權跑力會參考您的目標賽事距離，做出適當的加權來計算一段時間內的動態跑力的加權平均值，更能反映當下對於目標賽事的跑力評估喔！")
                }
                
                Spacer()
            }
            .padding(.bottom, 8)
            
            // Heart Rate Zone Update Banner
            if viewModel.needUpdatedHrRange {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        
                        Text("請設定您的心率區間以獲得更準確的訓練強度指導")
                            .font(.subheadline)
                        
                        Spacer()
                    }
                    
                    Button("設定心率區間") {
                        showingHeartRateZoneEditor = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .padding(.bottom, 8)
            }
            
            if viewModel.isLoading {
                VStack {
                    ProgressView("載入中...")
                        .foregroundColor(.secondary)
                }
                .frame(height: 80)
                .frame(maxWidth: .infinity)
            } else if let error = viewModel.error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("重試") {
                        Task {
                            await viewModel.fetchVDOTData()
                        }
                    }
                    .padding(.top)
                    .foregroundColor(.blue)
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)
            } else if viewModel.vdotPoints.isEmpty {
                VStack {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("暫無跑力數據")
                        .foregroundColor(.secondary)
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)
            } else {
                // 顯示圖表內容
                vdotContent
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .task {
            await viewModel.fetchVDOTData()
        }
        .sheet(isPresented: $showingHeartRateZoneEditor, onDismiss: {
            viewModel.needUpdatedHrRange = false
            UserDefaults.standard.set(false, forKey: "vdot_need_update_hr_range")
        }) {
            HRRHeartRateZoneEditorView()
        }
        .refreshable {
            await viewModel.refreshVDOTData()
        }
    }
    
    private var vdotContent: some View {
        Group {
            // Selected point info (if any)
            if let point = selectedPoint {
                HStack {
                    VStack(alignment: .leading) {
                        Text("日期: \(dateFormatter.string(from: point.date))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("動態跑力: \(String(format: "%.2f", point.value))")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        if let weight = point.weightVdot {
                            Text("加權跑力: \(String(format: "%.2f", weight))")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                    Spacer()
                    Button {
                        selectedPoint = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(8)
                .padding(.bottom, 8)
            }
            
            // Chart
            Chart {
                ForEach(viewModel.vdotPoints) { point in
                    // 動態跑力曲線
                    LineMark(
                        x: .value("日期", point.date),
                        y: .value("跑力", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(by: .value("種類", "動態跑力"))
                    
                    // 加權跑力曲線
                    if let weight = point.weightVdot {
                        LineMark(
                            x: .value("日期", point.date),
                            y: .value("跑力", weight)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(by: .value("種類", "加權跑力"))
                    }
                    
                    // 動態跑力點
                    PointMark(
                        x: .value("日期", point.date),
                        y: .value("跑力", point.value)
                    )
                    .foregroundStyle(by: .value("種類", "動態跑力"))
                    
                    // 加權跑力點
                    if let weight = point.weightVdot {
                        PointMark(
                            x: .value("日期", point.date),
                            y: .value("跑力", weight)
                        )
                        .foregroundStyle(by: .value("種類", "加權跑力"))
                    }
                }
            }
            .chartForegroundStyleScale([
                "動態跑力": Color.blue,
                "加權跑力": Color.orange
            ])
            .frame(height: 80)
            .chartYScale(domain: viewModel.yAxisRange)
            .chartXAxis(.hidden) // Hide X-axis
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
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // Find the closest point
                                    var minDistance = Double.infinity
                                    var closestPoint: VDOTDataPoint? = nil
                                    
                                    for point in viewModel.vdotPoints {
                                        // Get the position for this point
                                        let pointX = proxy.position(forX: point.date) ?? 0
                                        let pointY = proxy.position(forY: point.value) ?? 0
                                        
                                        // Calculate distance to touch point (within the plot area)
                                        let touchX = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                        let touchY = value.location.y - geometry[proxy.plotAreaFrame].origin.y
                                        
                                        let distance = sqrt(pow(touchX - pointX, 2) + pow(touchY - pointY, 2))
                                        if distance < minDistance {
                                            minDistance = distance
                                            closestPoint = point
                                        }
                                    }
                                    
                                    // If within reasonable distance (30 points)
                                    if minDistance < 30, let point = closestPoint {
                                        selectedPoint = point
                                    }
                                }
                        )
                }
            }
            
            // Stats
            HStack(alignment: .top, spacing: 12) {
                statsBox(
                    title: "加權跑力",
                    value: String(format: "%.2f", viewModel.averageVdot),
                    backgroundColor: Color.blue.opacity(0.15)
                )
                
                statsBox(
                    title: "最新跑力",
                    value: String(format: "%.2f", viewModel.latestVdot),
                    backgroundColor: Color.green.opacity(0.15)
                )
            }
            .padding(.top, 8)
        }
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
    
    // Date formatter for display
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }
}

#Preview {
    VStack {
        VDOTChartView()
            .padding()
    }
}
