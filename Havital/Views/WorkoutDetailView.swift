import SwiftUI
import HealthKit
import Charts

struct WorkoutDetailView: View {
    @StateObject private var viewModel: WorkoutDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(workout: HKWorkout, healthKitManager: HealthKitManager, initialHeartRateData: [(Date, Double)]) {
        _viewModel = StateObject(wrappedValue: WorkoutDetailViewModel(
            workout: workout,
            healthKitManager: healthKitManager,
            initialHeartRateData: initialHeartRateData
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                workoutInfoSection
                heartRateChartSection
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
            
            WorkoutDetailView(workout: workout, healthKitManager: HealthKitManager(), initialHeartRateData: [])
        }
    }
}
