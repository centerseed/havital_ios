import SwiftUI
import Charts

struct SleepHeartRateChartView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var isLoading = true
    @State private var heartRatePoints: [(Date, Double)] = []
    @State private var selectedPoint: (Date, Double)?
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("睡眠靜息心率")
                .font(.headline)
                .padding(.horizontal)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: 200)
            } else {
                if heartRatePoints.isEmpty {
                    Text("無睡眠心率數據")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, maxHeight: 200)
                } else {
                    Chart {
                        ForEach(heartRatePoints, id: \.0) { point in
                            LineMark(
                                x: .value("日期", point.0),
                                y: .value("心率", point.1)
                            )
                            .foregroundStyle(Color.purple.gradient)
                            
                            PointMark(
                                x: .value("日期", point.0),
                                y: .value("心率", point.1)
                            )
                            .foregroundStyle(.purple)
                        }
                        
                        if let selected = selectedPoint {
                            RuleMark(
                                x: .value("Selected", selected.0)
                            )
                            .foregroundStyle(Color.gray.opacity(0.3))
                            .annotation(position: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(selected.0.formatted(.dateTime.month().day()))
                                        .font(.caption)
                                    Text("\(Int(selected.1))次/分鐘")
                                        .font(.caption.bold())
                                }
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemBackground))
                                        .shadow(radius: 2)
                                )
                            }
                        }
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(date.formatted(.dateTime.month().day()))
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let xPosition = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                            guard xPosition >= 0,
                                                  xPosition <= geometry[proxy.plotAreaFrame].width else {
                                                return
                                            }
                                            
                                            guard let date = proxy.value(atX: xPosition) as Date? else {
                                                return
                                            }
                                            
                                            // 找到最近的數據點
                                            let closest = heartRatePoints.min { first, second in
                                                abs(first.0.timeIntervalSince(date)) < abs(second.0.timeIntervalSince(date))
                                            }
                                            
                                            withAnimation(.easeInOut(duration: 0.1)) {
                                                selectedPoint = closest
                                            }
                                        }
                                        .onEnded { _ in
                                            withAnimation(.easeInOut(duration: 0.1)) {
                                                selectedPoint = nil
                                            }
                                        }
                                )
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            print("開始加載睡眠心率數據")
            await loadSleepHeartRates()
        }
    }
    
    private func loadSleepHeartRates() async {
        isLoading = true
        defer { isLoading = false }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate)!
        
        print("正在獲取從 \(startDate) 到 \(endDate) 的睡眠心率數據")
        
        var currentDate = startDate
        var points: [(Date, Double)] = []
        
        while currentDate <= endDate {
            do {
                if let heartRate = try await healthKitManager.fetchSleepHeartRateAverage(for: currentDate) {
                    print("獲取到 \(currentDate.formatted()) 的睡眠心率: \(heartRate)")
                    points.append((currentDate, heartRate))
                } else {
                    print("未找到 \(currentDate.formatted()) 的睡眠心率數據")
                }
            } catch {
                print("獲取 \(currentDate.formatted()) 的睡眠心率時發生錯誤: \(error.localizedDescription)")
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        print("總共獲取到 \(points.count) 個數據點")
        
        await MainActor.run {
            self.heartRatePoints = points
        }
    }
}

#Preview {
    SleepHeartRateChartView()
        .environmentObject(HealthKitManager())
}
