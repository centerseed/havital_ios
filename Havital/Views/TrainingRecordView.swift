import SwiftUI
import HealthKit

struct TrainingRecordView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var workouts: [HKWorkout] = []
    
    var body: some View {
        NavigationStack {
            List(workouts, id: \.uuid) { workout in
                NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                    WorkoutRowView(workout: workout)
                }
            }
            .navigationTitle("訓練紀錄")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: PerformanceChartView()) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                    }
                }
            }
            .onAppear {
                healthKitManager.requestAuthorization { success in
                    if success {
                        healthKitManager.fetchWorkouts { fetchedWorkouts in
                            workouts = fetchedWorkouts
                        }
                    }
                }
            }
        }
    }
}

struct WorkoutRowView: View {
    let workout: HKWorkout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(WorkoutUtils.workoutTypeString(for: workout))
                    .font(.headline)
                Spacer()
                Text(WorkoutUtils.formatDate(workout.startDate))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("\(WorkoutUtils.formatDuration(workout.duration))", systemImage: "clock")
                Spacer()
                if let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                    Label(String(format: "%.0f kcal", calories), systemImage: "flame.fill")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                Text(String(format: "距離: %.2f km", distance / 1000))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TrainingRecordView()
}
