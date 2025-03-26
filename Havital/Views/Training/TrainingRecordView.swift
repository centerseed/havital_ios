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
            .onDisappear {
                // 在視圖消失時停止觀察者
                viewModel.stopWorkoutObserver(healthKitManager: healthKitManager)
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
                    print("加載心率數據時出錯: \(error)")
                    heartRateData = []
                }
                selectedWorkout = workout
                
                do {
                    paceData = try await healthKitManager.fetchPaceData(for: workout)
                } catch {
                    print("加載配速數據時出錯: \(error)")
                    paceData = []
                }
            }
        } label: {
            WorkoutRowView(
                workout: workout,
                isUploaded: viewModel.isWorkoutUploaded(workout),
                uploadTime: viewModel.getWorkoutUploadTime(workout)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TrainingRecordView()
        .environmentObject(HealthKitManager())
}
