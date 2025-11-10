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
                Text(L10n.Performance.VDOT.vdotTitle.localized)
                    .font(.headline)
                
                Button {
                    showingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .alert(L10n.Performance.VDOT.whatIsVdot.localized, isPresented: $showingInfo) {
                    Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) {}
                } message: {
                    Text(L10n.Performance.VDOT.vdotDescription.localized)
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
                        
                        Text(L10n.Performance.VDOT.heartRateZonePrompt.localized)
                            .font(.subheadline)
                        
                        Spacer()
                    }
                    
                    Button(L10n.Performance.VDOT.setHeartRateZones.localized) {
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
                    ProgressView(L10n.Performance.Chart.loading.localized)
                        .foregroundColor(.secondary)
                }
                .frame(height: 80)
                .frame(maxWidth: .infinity)
            } else if let error = viewModel.error {
                EmptyStateView(
                    type: .loadingFailed,
                    customMessage: error,
                    showRetryButton: true
                ) {
                    Task {
                        await viewModel.fetchVDOTData()
                    }
                }
            } else if viewModel.vdotPoints.isEmpty {
                EmptyStateView(type: .vdotData)
            } else {
                // 顯示圖表內容
                vdotContent
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .task {
            await TrackedTask("VDOTChartView: fetchVDOTData") {
                await viewModel.fetchVDOTData()
            }.value
        }
        .sheet(isPresented: $showingHeartRateZoneEditor, onDismiss: {
            viewModel.needUpdatedHrRange = false
            UserDefaults.standard.set(false, forKey: "vdot_need_update_hr_range")
        }) {
            HRRHeartRateZoneEditorView()
        }
        .refreshable {
            await TrackedTask("VDOTChartView: refreshVDOTData") {
                await viewModel.refreshVDOTData()
            }.value
        }
    }
    
    private var vdotContent: some View {
        Group {
            // Selected point info (if any)
            if let point = selectedPoint {
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(L10n.Performance.Chart.date.localized): \(dateFormatter.string(from: point.date))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(L10n.Performance.VDOT.dynamicVdot.localized): \(String(format: "%.2f", point.value))")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        if let weight = point.weightVdot {
                            Text("\(L10n.Performance.VDOT.weightedVdot.localized): \(String(format: "%.2f", weight))")
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
                        x: .value(L10n.Performance.Chart.date.localized, point.date),
                        y: .value(L10n.Performance.Chart.vdotValue.localized, point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(by: .value("種類", L10n.Performance.VDOT.dynamicVdot.localized))
                    
                    // 加權跑力曲線
                    if let weight = point.weightVdot {
                        LineMark(
                            x: .value(L10n.Performance.Chart.date.localized, point.date),
                            y: .value(L10n.Performance.Chart.vdotValue.localized, weight)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(by: .value("種類", L10n.Performance.VDOT.weightedVdot.localized))
                    }
                    
                    // 動態跑力點
                    PointMark(
                        x: .value(L10n.Performance.Chart.date.localized, point.date),
                        y: .value(L10n.Performance.Chart.vdotValue.localized, point.value)
                    )
                    .foregroundStyle(by: .value("種類", L10n.Performance.VDOT.dynamicVdot.localized))
                    
                    // 加權跑力點
                    if let weight = point.weightVdot {
                        PointMark(
                            x: .value(L10n.Performance.Chart.date.localized, point.date),
                            y: .value(L10n.Performance.Chart.vdotValue.localized, weight)
                        )
                        .foregroundStyle(by: .value("種類", L10n.Performance.VDOT.weightedVdot.localized))
                    }
                }
            }
            .chartForegroundStyleScale([
                L10n.Performance.VDOT.dynamicVdot.localized: Color.blue,
                L10n.Performance.VDOT.weightedVdot.localized: Color.orange
            ])
            .frame(height: 120)
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
                    title: L10n.Performance.VDOT.weightedVdot.localized,
                    value: String(format: "%.2f", viewModel.averageVdot),
                    backgroundColor: Color.blue.opacity(0.15)
                )
                
                statsBox(
                    title: L10n.Performance.VDOT.latestVdot.localized,
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
