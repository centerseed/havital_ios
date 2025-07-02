import SwiftUI
import HealthKit

struct TrainingRecordView: View {
    @StateObject private var viewModel = TrainingRecordViewModel()
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var selectedWorkout: WorkoutV2?
    @State private var showingWorkoutDetail = false
    @State private var heartRateData: [(Date, Double)] = []
    @State private var paceData: [(Date, Double)] = []
    @State private var showInfoSheet = false
    
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showInfoSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showInfoSheet) {
                DeviceInfoSheetView()
            }
            .sheet(item: $selectedWorkout) { workout in
                WorkoutDetailViewV2(workout: workout)
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
            ForEach(viewModel.workouts, id: \.id) { workout in
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
    
    private func workoutRow(_ workout: WorkoutV2) -> some View {
        Button {
            // 對於 V2 API 數據，心率數據已經包含在 workout 中
            // 這裡可以根據需要處理數據顯示
            selectedWorkout = workout
        } label: {
            WorkoutV2RowView(
                workout: workout,
                isUploaded: true, // V2 API 數據都已經在後端
                uploadTime: workout.startDate
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TrainingRecordView()
        .environmentObject(HealthKitManager())
}