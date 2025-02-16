import SwiftUI
import HealthKit
import Charts

struct WorkoutDetailView: View {
    @StateObject private var viewModel: WorkoutDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(workout: HKWorkout, healthKitManager: HealthKitManager, initialHeartRateData: [(Date, Double)], initialPaceData: [(Date, Double)]) {
        _viewModel = StateObject(wrappedValue: WorkoutDetailViewModel(
            workout: workout,
            healthKitManager: healthKitManager,
            initialHeartRateData: initialHeartRateData,
            initialPaceData: initialPaceData
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                workoutInfoSection
                heartRateChartSection
                heartRateZoneSection
            }
            .padding()
        }
        .navigationTitle("訓練詳情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            viewModel.loadHeartRateData()
        }
        .id(viewModel.workoutId) 
    }
    
    private var workoutInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("基本信息")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.workoutType)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Label(viewModel.duration, systemImage: "clock")
                if let calories = viewModel.calories {
                    Label(calories, systemImage: "flame.fill")
                }
                if let distance = viewModel.distance {
                    Label(distance, systemImage: "figure.walk")
                }
                if let pace = viewModel.pace {
                    Label(pace, systemImage: "stopwatch")
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
            
            if viewModel.isLoading {
                VStack {
                    ProgressView("載入心率數據中...")
                }
                .frame(height: 200)
            } else if let error = viewModel.error {
                ContentUnavailableView(
                    error,
                    systemImage: "heart.slash",
                    description: Text("請稍後再試")
                )
                .frame(height: 200)
            } else if viewModel.heartRates.isEmpty {
                ContentUnavailableView(
                    "沒有心率數據",
                    systemImage: "heart.slash",
                    description: Text("無法獲取此次訓練的心率數據")
                )
                .frame(height: 200)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(viewModel.maxHeartRate)
                            .foregroundColor(.red)
                        Spacer()
                        Text(viewModel.minHeartRate)
                            .foregroundColor(.blue)
                    }
                    .font(.caption)
                    
                    Chart {
                        ForEach(viewModel.heartRates) { point in
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
                    .chartYScale(domain: viewModel.yAxisRange.min...viewModel.yAxisRange.max)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .minute, count: 5)) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(date.formatted(.dateTime.hour().minute()))
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
    
    private var heartRateZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("心率區間分佈")
                .font(.headline)
            
            if viewModel.isLoading {
                ProgressView("載入數據中...")
            } else if viewModel.heartRates.isEmpty {
                Text("無心率數據")
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.heartRateZones.sorted(by: { $0.zone < $1.zone })) { zone in
                        let duration = viewModel.zoneDistribution[zone.zone] ?? 0
                        let percentage = viewModel.calculateZonePercentage(duration)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("區間 \(zone.zone)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("(\(Int(zone.range.lowerBound))-\(Int(zone.range.upperBound)) bpm)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(viewModel.formatZoneDuration(duration))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f%%", percentage))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 8)
                                        .cornerRadius(4)
                                    
                                    Rectangle()
                                        .fill(zoneColor(for: zone.zone))
                                        .frame(width: max(geometry.size.width * CGFloat(percentage / 100), 4), height: 8)
                                        .cornerRadius(4)
                                }
                            }
                            .frame(height: 8)
                            
                            Text(zone.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
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
    
    private func zoneColor(for zone: Int) -> Color {
        switch zone {
        case 1: return .blue
        case 2: return .green
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }
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
            
            WorkoutDetailView(workout: workout, healthKitManager: HealthKitManager(), initialHeartRateData: [], initialPaceData: [])
        }
    }
}
