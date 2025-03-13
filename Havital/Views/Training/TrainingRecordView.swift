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
            .overlay(alignment: .top) {
                if let status = viewModel.uploadStatus {
                    syncStatusView(status)
                }
            }
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
            WorkoutRowView(
                workout: workout,
                isUploaded: viewModel.isWorkoutUploaded(workout),
                uploadTime: viewModel.getWorkoutUploadTime(workout)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func syncStatusView(_ status: String) -> some View {
        HStack {
            if viewModel.isUploading {
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(.trailing, 4)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            
            Text(status)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
        .padding(.top, 8)
    }
}

#Preview {
    TrainingRecordView()
        .environmentObject(HealthKitManager())
}
