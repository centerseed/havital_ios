import SwiftUI
import HealthKit
import Charts

struct WorkoutDetailView: View {
    let workout: HKWorkout
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var heartRates: [HeartRatePoint] = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 基本信息
                workoutInfoSection
                
                // 心率圖表
                heartRateChartSection
            }
            .padding()
        }
        .navigationTitle("訓練詳情")
        .onAppear {
            loadHeartRateData()
        }
    }
    
    private var workoutInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("基本信息")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(WorkoutUtils.workoutTypeString(for: workout))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Label(WorkoutUtils.formatDuration(workout.duration), systemImage: "clock")
                if let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                    Label(String(format: "%.0f kcal", calories), systemImage: "flame.fill")
                }
                if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                    Label(String(format: "%.2f km", distance / 1000), systemImage: "figure.walk")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 1)
    }
    
    private var heartRateChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("心率變化")
                .font(.headline)
            
            if heartRates.isEmpty {
                ProgressView()
                    .frame(height: 200)
            } else {
                let maxHeartRate = heartRates.max(by: { $0.value < $1.value })?.value ?? 0
                let minHeartRate = heartRates.min(by: { $0.value < $1.value })?.value ?? 0
                let yAxisMax = maxHeartRate * 1.1
                let yAxisMin = max(minHeartRate * 0.9, 0)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("最高心率: \(Int(maxHeartRate))")
                        Spacer()
                        Text("最低心率: \(Int(minHeartRate))")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Chart {
                        ForEach(heartRates) { point in
                            LineMark(
                                x: .value("時間", point.time),
                                y: .value("心率", point.value)
                            )
                            .foregroundStyle(Color.red.gradient)
                            
                            AreaMark(
                                x: .value("時間", point.time),
                                y: .value("心率", point.value)
                            )
                            .foregroundStyle(Color.red.opacity(0.1))
                        }
                    }
                    .frame(height: 200)
                    .chartYScale(domain: yAxisMin...yAxisMax)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .minute, count: 5)) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(WorkoutUtils.formatTime(date))
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            if let heartRate = value.as(Double.self) {
                                AxisValueLabel {
                                    Text("\(Int(heartRate))")
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 1)
    }
    
    private func loadHeartRateData() {
        healthKitManager.fetchHeartRateData(for: workout) { heartRateData in
            heartRates = heartRateData.map { date, value in
                HeartRatePoint(time: date, value: value)
            }
        }
    }
}

struct HeartRatePoint: Identifiable {
    let id = UUID()
    let time: Date
    let value: Double
}

struct WorkoutDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            let workout = try! HKWorkout(
                activityType: .running,
                start: Date().addingTimeInterval(-3600),
                end: Date(),
                duration: 3600,
                totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 300),
                totalDistance: HKQuantity(unit: .meter(), doubleValue: 5000),
                metadata: nil
            )
            
            WorkoutDetailView(workout: workout)
        }
    }
}
