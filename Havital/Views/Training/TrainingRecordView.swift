import SwiftUI
import HealthKit

struct TrainingRecordView: View {
    @StateObject private var viewModel = TrainingRecordViewModel()
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var selectedWorkout: HKWorkout?
    @State private var showingWorkoutDetail = false
    @State private var heartRateData: [(Date, Double)] = []
    @State private var paceData: [(Date, Double)] = []
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("載入訓練記錄中...")
                } else {
                    workoutList
                }
            }
            .navigationTitle("訓練記錄")
            .sheet(item: $selectedWorkout) { workout in
                NavigationStack {
                    WorkoutDetailView(
                        workout: workout,
                        healthKitManager: healthKitManager,
                        initialHeartRateData: heartRateData,
                        initialPaceData: paceData
                    )
                }
            }
            .task {
                await viewModel.loadWorkouts(healthKitManager: healthKitManager)
            }
            .refreshable {
                await viewModel.loadWorkouts(healthKitManager: healthKitManager)
            }
        }
    }
    
    private var workoutList: some View {
        List {
            ForEach(viewModel.workouts, id: \.uuid) { workout in
                workoutRow(workout)
            }
        }
        .overlay {
            if viewModel.workouts.isEmpty {
                ContentUnavailableView(
                    "沒有訓練記錄",
                    systemImage: "figure.run",
                    description: Text("過去一個月內沒有訓練記錄")
                )
            }
        }
    }
    
    private func workoutRow(_ workout: HKWorkout) -> some View {
        Button {
            Task {
                // 預先加載心率數據
                do {
                    heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
                } catch {
                    print("Error loading heart rate data: \(error)")
                    heartRateData = []
                }
                selectedWorkout = workout
                
                do {
                    paceData = try await healthKitManager.fetchPaceData(for: workout)
                } catch {
                    print("Error loading pace data: \(error)")
                    paceData = []
                }
            }
        } label: {
            WorkoutRowView(workout: workout)
        }
        .buttonStyle(.plain)
    }
}

class TrainingRecordViewModel: ObservableObject {
    @Published var workouts: [HKWorkout] = []
    @Published var isLoading = false
    
    func loadWorkouts(healthKitManager: HealthKitManager) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            try await healthKitManager.requestAuthorization()
            let now = Date()
            // 改為獲取一個月的數據
            let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now)!
            
            let fetchedWorkouts = try await healthKitManager.fetchWorkoutsForDateRange(start: oneMonthAgo, end: now)
            
            // 在主線程更新 UI
            await MainActor.run {
                self.workouts = fetchedWorkouts.sorted(by: { $0.startDate > $1.startDate }) // 按日期降序排序
                self.isLoading = false
            }
        } catch {
            print("Error loading workouts: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.workouts = []
            }
        }
    }
}

#Preview {
    TrainingRecordView()
        .environmentObject(HealthKitManager())
}
