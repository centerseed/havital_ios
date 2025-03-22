import SwiftUI

@MainActor
class WeeklyDistanceViewModel: ObservableObject {
    @Published var weeklyDistance: Double
    @Published var isLoading = false
    @Published var error: String?
    @Published var navigateToTrainingDays = false
    
    let targetDistance: Double
    let maxSuggestedDistance = 10.0 // 最大建議週跑量為10公里
    
    init(targetDistance: Double) {
        self.targetDistance = targetDistance
        // 預設週跑量為目標距離的一半，但不超過10公里
        self.weeklyDistance = min(targetDistance / 2, maxSuggestedDistance)
    }
    
    func saveWeeklyDistance() async {
        isLoading = true
        error = nil
        
        do {
            let userData = [
                "current_week_distance": weeklyDistance
            ] as [String: Any]
            
            try await UserService.shared.updateUserData(userData)
            print("週跑量數據上傳成功，準備導航到訓練日設置頁面")
            navigateToTrainingDays = true
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func skipSetup() async {
        // 使用預設值並繼續
        isLoading = true
        error = nil
        
        do {
            // 使用預設的週跑量值
            let defaultWeeklyDistance = min(targetDistance / 2, maxSuggestedDistance)
            let userData = [
                "current_week_distance": defaultWeeklyDistance
            ] as [String: Any]
            
            try await UserService.shared.updateUserData(userData)
            print("略過設置: 使用預設週跑量 \(defaultWeeklyDistance) 公里")
            navigateToTrainingDays = true
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}

struct WeeklyDistanceSetupView: View {
    @StateObject private var viewModel: WeeklyDistanceViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(targetDistance: Double) {
        print("初始化WeeklyDistanceSetupView，目標距離: \(targetDistance)公里")
        _viewModel = StateObject(wrappedValue: WeeklyDistanceViewModel(targetDistance: targetDistance))
    }
    
    var body: some View {
        Form {
            Section(header: Text("當前週跑量").padding(.top, 10)) {
                Text("目標賽事距離：\(String(format: "%.1f", viewModel.targetDistance))公里")
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)
                
                Text("請告訴我們您目前每週大約跑多少公里")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)
                
                let maxDistance = viewModel.targetDistance * 3
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("週跑量：\(String(format: "%.1f", viewModel.weeklyDistance)) 公里")
                        .fontWeight(.medium)
                    
                    Slider(
                        value: $viewModel.weeklyDistance,
                        in: 1...max(20, maxDistance),
                        step: 1
                    )
                    .accentColor(.blue)
                    
                    HStack {
                        Text("1 公里")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(max(20, maxDistance))) 公里")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 5)
            }
            
            if let error = viewModel.error {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("週跑量設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Button(action: {
                        Task {
                            await viewModel.saveWeeklyDistance()
                        }
                    }) {
                        Text("下一步")
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button("略過") {
                    Task {
                        await viewModel.skipSetup()
                    }
                }
                .foregroundColor(.secondary)
            }
        }
        .disabled(viewModel.isLoading)
        .background(
            NavigationLink(destination: TrainingDaysSetupView(), isActive: $viewModel.navigateToTrainingDays) {
                EmptyView()
            }
        )
    }
}

#Preview {
    NavigationStack {
        WeeklyDistanceSetupView(targetDistance: 42.195)
    }
}
