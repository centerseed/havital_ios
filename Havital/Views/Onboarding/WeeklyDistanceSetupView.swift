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
            print("略過週跑量設定，設定為 \(skippedWeeklyDistance) 公里")
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
                header: Text("目前每週跑步量").padding(.top, 10),
                footer: Text("週跑量是指您通常一週內跑步的總公里數。這個數據有助於 Havital 了解您目前的跑步習慣，以便安排合適的訓練強度。如果您不確定，可以先估算一個大概的數字，或者直接「略過」此步驟。")
            ) {
                Text("您的目標距離：\(String(format: "%.1f", viewModel.targetDistance)) 公里")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)
                
                Text("請滑動調整您目前平均每週的跑步總量。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)
                
                // Slider 的最大值可以基於目標距離動態調整，例如目標的1.5倍到2倍，但至少有一個合理的上限
                let sliderMaxDistance = max(viewModel.targetDistance * 1.5, 50.0) // 例如上限50km或目標的1.5倍
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("本週跑量：\(String(format: "%.0f", viewModel.weeklyDistance)) 公里") // 改為顯示整數
                        .fontWeight(.medium)
                    
                    Slider(
                        value: $viewModel.weeklyDistance,
                        in: viewModel.minimumWeeklyDistance...sliderMaxDistance, // 從 ViewModel 取最小跑量
                        step: 1
                    )
                    
                    HStack {
                        Text("\(String(format: "%.0f", viewModel.minimumWeeklyDistance)) 公里")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(String(format: "%.0f", sliderMaxDistance)) 公里")
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
        .navigationTitle("您的週跑量") // 修改標題
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { // 修改為明確的返回按鈕
                Button {
                    dismiss()
                } label: {
                    Text("返回")
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) { // 將略過和下一步放在一起
                Button("略過") {
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
                        Text("下一步")
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
