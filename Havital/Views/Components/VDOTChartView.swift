import SwiftUI
import Charts

// Chart View
struct VDOTChartView: View {
    @StateObject private var viewModel = VDOTChartViewModel()
    @State private var selectedPoint: VDOTDataPoint? = nil
    @State private var showingHeartRateZoneEditor = false
    @State private var showingInfo = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            HStack {
                Text("動態跑力 (VDOT)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Button {
                                showingInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.secondary)
                            }
                            .alert("什麼是動態跑力？", isPresented: $showingInfo) {
                                Button("了解", role: .cancel) {}
                            } message: {
                                Text("動態跑力是根據您的跑步表現和心率數據綜合計算的指標，反映您的真實跑步能力。\n\n它考慮了配速、距離以及心率保留率(HRR)，相比傳統VDOT值能更加準確地衡量您的訓練狀態。\n\n較高的動態跑力表示在相同配速下，您的心肺負擔較小，即跑步效率更高。隨著訓練的進行，動態跑力上升意味著您的跑步能力有所提升。")
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
                            .foregroundColor(.white)
                        
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
                .background(Color(red: 0.2, green: 0.2, blue: 0.3))
                .cornerRadius(8)
                .padding(.bottom, 8)
            }
            
            if viewModel.isLoading {
                VStack {
                    ProgressView("載入中...")
                        .foregroundColor(.gray)
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
                        .foregroundColor(.gray)
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
                        .foregroundColor(.gray)
                    Text("暫無跑力數據")
                        .foregroundColor(.gray)
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)
            } else {
                // 顯示圖表內容
                vdotContent
            }
        }
        .padding()
        .background(Color.black)
        .cornerRadius(12)
        .task {
            await viewModel.fetchVDOTData()
        }
        .sheet(isPresented: $showingHeartRateZoneEditor) {
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
                            .foregroundColor(.gray)
                        Text("VDOT: \(String(format: "%.2f", point.value))")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button {
                        selectedPoint = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                .cornerRadius(8)
                .padding(.bottom, 8)
            }
            
            // Chart
            Chart {
                ForEach(viewModel.vdotPoints) { point in
                    LineMark(
                        x: .value("日期", point.date),
                        y: .value("跑力", point.value)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("日期", point.date),
                        y: .value("跑力", point.value)
                    )
                    .foregroundStyle(.blue)
                }
            }
            .frame(height: 80)
            .chartYScale(domain: viewModel.yAxisRange)
            .chartXAxis(.hidden) // Hide X-axis
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(String(format: "%.1f", doubleValue))
                                .font(.caption)
                                .foregroundColor(.gray)
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
            .foregroundStyle(.white)
            
            // Stats
            HStack(alignment: .top, spacing: 12) {
                statsBox(
                    title: "平均跑力",
                    value: String(format: "%.2f", viewModel.averageVdot),
                    backgroundColor: Color(red: 0.1, green: 0.2, blue: 0.3)
                )
                
                statsBox(
                    title: "最新跑力",
                    value: String(format: "%.2f", viewModel.latestVdot),
                    backgroundColor: Color(red: 0.1, green: 0.3, blue: 0.2)
                )
            }
            .padding(.top, 8)
        }
    }
    
    private func statsBox(title: String, value: String, backgroundColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
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
    .background(Color.black)
}
