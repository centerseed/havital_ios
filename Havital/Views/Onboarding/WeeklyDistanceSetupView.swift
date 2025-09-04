import SwiftUI

@MainActor
class WeeklyDistanceViewModel: ObservableObject {
    @Published var weeklyDistance: Double
    @Published var isLoading = false
    @Published var error: String?
    @Published var navigateToTrainingDays = false
    
    let targetDistance: Double
    // 調整預設週跑量的上限
    let defaultMaxWeeklyDistanceCap = 30.0 // 預設週跑量上限調整為30公里
    let minimumWeeklyDistance = 0.0 // 允許使用者選擇0公里
    
    init(targetDistance: Double) {
        self.targetDistance = targetDistance
        // 預設週跑量為目標距離的30%，但不超過 defaultMaxWeeklyDistanceCap，最低為0
        let suggestedDistance = targetDistance * 0.3
        self.weeklyDistance = max(minimumWeeklyDistance, min(suggestedDistance, defaultMaxWeeklyDistanceCap))
    }
    
    func saveWeeklyDistance() async {
        isLoading = true
        error = nil
        
        do {
            // 將週跑量轉換為整數
            let weeklyDistanceInt = Int(weeklyDistance.rounded())
            let userData = [
                "current_week_distance": weeklyDistanceInt
            ] as [String: Any]
            
            try await UserService.shared.updateUserData(userData)
            print("週跑量數據 (\(weeklyDistanceInt)km) 上傳成功，準備導航到訓練日設置頁面")
            navigateToTrainingDays = true
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func skipSetup() async {
        isLoading = true
        error = nil
        
        do {
            // 如果略過，將週跑量設為0（整數）
            let skippedWeeklyDistance = 0
            let userData = [
                "current_week_distance": skippedWeeklyDistance
            ] as [String: Any]
            
            try await UserService.shared.updateUserData(userData)
            print("Skipped weekly distance setup, set to \(skippedWeeklyDistance) km")
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
        _viewModel = StateObject(wrappedValue: WeeklyDistanceViewModel(targetDistance: targetDistance))
    }
    
    var body: some View {
        Form {
            Section(
                header: Text(NSLocalizedString("onboarding.current_weekly_distance", comment: "Current Weekly Distance")).padding(.top, 10),
                footer: Text(NSLocalizedString("onboarding.weekly_distance_description", comment: "Weekly Distance Description"))
            ) {
                Text(String(format: NSLocalizedString("onboarding.target_distance_label", comment: "Target Distance Label"), viewModel.targetDistance))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)

                Text(NSLocalizedString("onboarding.adjust_weekly_volume", comment: "Adjust Weekly Volume"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)

                // Slider 的最大值可以基於目標距離動態調整，例如目標的1.5倍到2倍，但至少有一個合理的上限
                let sliderMaxDistance = max(viewModel.targetDistance * 1.5, 50.0) // 例如上限50km或目標的1.5倍

                VStack(alignment: .leading, spacing: 10) {
                    Text(String(format: NSLocalizedString("onboarding.weekly_volume_label", comment: "Weekly Volume Label"), viewModel.weeklyDistance))
                        .fontWeight(.medium)

                    Slider(
                        value: $viewModel.weeklyDistance,
                        in: viewModel.minimumWeeklyDistance...sliderMaxDistance, // 從 ViewModel 取最小跑量
                        step: 1
                    )

                    HStack {
                        Text(String(format: NSLocalizedString("onboarding.km_label", comment: "KM Label"), viewModel.minimumWeeklyDistance))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: NSLocalizedString("onboarding.km_label", comment: "KM Label"), sliderMaxDistance))
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
        .navigationTitle(NSLocalizedString("onboarding.weekly_distance_title", comment: "Weekly Distance Title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { // 修改為明確的返回按鈕
                Button {
                    dismiss()
                } label: {
                    Text(NSLocalizedString("onboarding.back", comment: "Back"))
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) { // 將略過和下一步放在一起
                Button(NSLocalizedString("onboarding.skip", comment: "Skip")) {
                    Task {
                        await viewModel.skipSetup()
                    }
                }
                .disabled(viewModel.isLoading) // 略過按鈕在加載時也禁用

                if viewModel.isLoading {
                    ProgressView()
                        .padding(.leading, 5) // 給 ProgressView 一點空間
                } else {
                    Button(action: {
                        Task {
                            await viewModel.saveWeeklyDistance()
                        }
                    }) {
                        Text(NSLocalizedString("onboarding.next_step", comment: "Next Step"))
                    }
                    .disabled(viewModel.isLoading) // 下一步按鈕在加載時也禁用
                }
            }
        }
        // .disabled(viewModel.isLoading) // Form 層級的 disabled 可以移除，因為按鈕已單獨處理
        .background(
            // 加上 .navigationBarBackButtonHidden(true)
            NavigationLink(destination: TrainingDaysSetupView().navigationBarBackButtonHidden(true), isActive: $viewModel.navigateToTrainingDays) {
                EmptyView()
            }
        )
    }
}

struct WeeklyDistanceSetupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { // 使用 NavigationView 預覽
            WeeklyDistanceSetupView(targetDistance: 21.0975) // 半馬
        }
        NavigationView {
            WeeklyDistanceSetupView(targetDistance: 5) // 5K
        }
    }
}
