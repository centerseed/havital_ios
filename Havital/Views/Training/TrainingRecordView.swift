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
                if viewModel.isLoading && !viewModel.hasWorkouts {
                    ProgressView(NSLocalizedString("training.loading_records", comment: "Loading training records..."))
                } else {
                    workoutList
                }
            }
            .navigationTitle(NSLocalizedString("record.title", comment: "Training Log"))
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
        .alert(NSLocalizedString("error.load_failed", comment: "Load Error"), isPresented: errorBinding) {
            Button(NSLocalizedString("common.confirm", comment: "Confirm")) {
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
                ProgressView(NSLocalizedString("training.loading_more_records", comment: "Loading more records..."))
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
                NSLocalizedString("record.no_records", comment: "No Training Records"),
                systemImage: "figure.run",
                description: Text(NSLocalizedString("record.no_records_description", comment: "No workout records available, they will appear here after you start exercising"))
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
    
    /// Check if more records need to be loaded
    private func checkForLoadMore(_ workout: WorkoutV2) {
        // When displaying the last record, trigger loading more
        let isLastItem = workout.id == viewModel.workouts.last?.id
        print("🔍 Check pagination loading: Current item \(workout.id), Is last item: \(isLastItem)")
        print("🔍 Total records: \(viewModel.workouts.count), hasMoreData: \(viewModel.hasMoreData), isLoadingMore: \(viewModel.isLoadingMore)")
        
        if isLastItem {
            print("🔍 Reached last item, attempting to load more...")
            loadMoreIfNeeded()
        }
    }
    
    /// Load more records
    private func loadMoreIfNeeded() {
        // Avoid duplicate loading
        print("🚀 loadMoreIfNeeded - isLoadingMore: \(viewModel.isLoadingMore), hasMoreData: \(viewModel.hasMoreData)")
        
        guard !viewModel.isLoadingMore && viewModel.hasMoreData else {
            print("❌ Load more blocked - isLoadingMore: \(viewModel.isLoadingMore), hasMoreData: \(viewModel.hasMoreData)")
            return
        }
        
        print("✅ Starting to load more records...")
        Task {
            await viewModel.loadMoreWorkouts()
        }
    }
}

#Preview {
    TrainingRecordView()
        .environmentObject(HealthKitManager())
}