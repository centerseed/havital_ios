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
                NavigationStack {
                    WorkoutDetailViewV2(workout: workout)
                }
            }
            .task {
                await viewModel.loadWorkouts(healthKitManager: healthKitManager)
            }
            .refreshable {
                await viewModel.refreshWorkouts(healthKitManager: healthKitManager)
            }
        }
    }
    
    private var workoutList: some View {
        List {
            ForEach(viewModel.workouts, id: \.id) { workout in
                workoutRowWithPagination(workout)
            }
            
            loadMoreIndicator
        }
        .overlay {
            emptyStateView
        }
        .alert("載入錯誤", isPresented: errorBinding) {
            Button("確定") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    @ViewBuilder
    private func workoutRowWithPagination(_ workout: WorkoutV2) -> some View {
        workoutRow(workout)
            .onAppear {
                checkForLoadMore(workout)
            }
    }
    
    @ViewBuilder
    private var loadMoreIndicator: some View {
        if viewModel.isLoadingMore {
            HStack {
                Spacer()
                ProgressView("載入更多記錄...")
                    .font(.caption)
                    .padding()
                Spacer()
            }
            .listRowSeparator(.hidden)
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        if viewModel.workouts.isEmpty && !viewModel.isLoading {
            ContentUnavailableView(
                "沒有訓練記錄",
                systemImage: "figure.run",
                description: Text("暫無運動記錄，開始運動後會顯示在這裡")
            )
        }
    }
    
    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in }
        )
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
    
    // MARK: - Helper Methods
    
    /// 檢查是否需要載入更多記錄
    private func checkForLoadMore(_ workout: WorkoutV2) {
        // 當顯示到最後一筆記錄時，觸發載入更多
        if workout.id == viewModel.workouts.last?.id {
            loadMoreIfNeeded()
        }
    }
    
    /// 載入更多記錄
    private func loadMoreIfNeeded() {
        // 避免重複載入
        guard !viewModel.isLoadingMore && viewModel.hasMoreData else { return }
        
        Task {
            await viewModel.loadMoreWorkouts()
        }
    }
}

#Preview {
    TrainingRecordView()
        .environmentObject(HealthKitManager())
}