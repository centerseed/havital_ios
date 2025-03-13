import SwiftUI
import Charts

// VDOT Data Models
struct VDOTDataPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct VDOTResponse: Codable {
    let data: VDOTData
}

struct VDOTData: Codable {
    let needUpdatedHrRange: Bool
    let vdots: [VDOTEntry]
    
    enum CodingKeys: String, CodingKey {
        case needUpdatedHrRange = "need_updated_hr_range"
        case vdots
    }
}

struct VDOTEntry: Codable {
    let datetime: TimeInterval
    let dynamicVdot: Double
    
    enum CodingKeys: String, CodingKey {
        case datetime
        case dynamicVdot = "dynamic_vdot"
    }
}

// View Model
class VDOTViewModel: ObservableObject {
    @Published var vdotPoints: [VDOTDataPoint] = []
    @Published var averageVdot: Double = 0
    @Published var latestVdot: Double = 0
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var yAxisRange: ClosedRange<Double> = 30...40
    @Published var needUpdatedHrRange: Bool = false
    
    private let networkService = NetworkService.shared
    
    func fetchVDOTData(limit: Int = 30) async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let endpoint = try Endpoint(
                path: "/workout/vdots",
                method: .get,
                requiresAuth: true,
                queryItems: [URLQueryItem(name: "limit", value: String(limit))]
            )
            
            let response: VDOTResponse = try await networkService.request(endpoint)
            
            let vdotEntries = response.data.vdots
            let points = vdotEntries.map { entry in
                VDOTDataPoint(
                    date: Date(timeIntervalSince1970: entry.datetime),
                    value: entry.dynamicVdot
                )
            }.sorted { $0.date < $1.date }
            
            // Calculate average VDOT
            let calculatedAverage = vdotEntries.reduce(0.0) { $0 + $1.dynamicVdot } / Double(vdotEntries.count)
            
            // Get the latest VDOT (from the most recent timestamp)
            let latestEntry = vdotEntries.max(by: { $0.datetime < $1.datetime })
            let calculatedLatest = latestEntry?.dynamicVdot ?? 0.0
            
            // Calculate appropriate Y-axis range based on data
            let values = points.map { $0.value }
            if let minValue = values.min(), let maxValue = values.max() {
                // Add 5% padding on each side
                let padding = (maxValue - minValue) * 0.05
                let yMin = Swift.max(minValue - padding, 0) // Ensure we don't go below 0
                let yMax = maxValue + padding
                
                // If the range is too small, expand it
                let minimumRange = 5.0 // Minimum range of 5 units
                let range = yMax - yMin
                if range < minimumRange {
                    let additionalPadding = (minimumRange - range) / 2
                    let newYMin = Swift.max(yMin - additionalPadding, 0)
                    let newYMax = yMax + additionalPadding
                    await MainActor.run {
                        self.yAxisRange = newYMin...newYMax
                    }
                } else {
                    await MainActor.run {
                        self.yAxisRange = yMin...yMax
                    }
                }
            }
            
            await MainActor.run {
                self.vdotPoints = points
                self.averageVdot = calculatedAverage
                self.latestVdot = calculatedLatest
                self.needUpdatedHrRange = response.data.needUpdatedHrRange
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = "無法載入跑力數據: \(error.localizedDescription)"
                print(error.localizedDescription)
                self.isLoading = false
            }
        }
    }
}

// Chart View
struct VDOTChartView: View {
    @StateObject private var viewModel = VDOTViewModel()
    @State private var selectedPoint: VDOTDataPoint? = nil
    @State private var showingHeartRateZoneEditor = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            HStack {
                Text("動態跑力 (VDOT)")
                    .font(.headline)
                    .foregroundColor(.white)
                
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
        .padding()
        .background(Color.black)
        .cornerRadius(12)
        .task {
            await viewModel.fetchVDOTData()
        }
        .sheet(isPresented: $showingHeartRateZoneEditor) {
            HRRHeartRateZoneEditorView()
        }
    }
    
    private func statsBox(title: String, value: String, backgroundColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.title)
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

// Preview
struct VDOTChartView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VDOTChartView()
                    .padding()
            }
        }
    }
}
