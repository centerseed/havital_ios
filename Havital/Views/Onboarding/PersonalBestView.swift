import SwiftUI

@MainActor
class PersonalBestViewModel: ObservableObject {
    @Published var targetHours = 0
    @Published var targetMinutes = 0
    @Published var isLoading = false
    @Published var error: String?
    @Published var navigateToWeeklyDistance = false
    @Published var selectedDistance = "5" // 預設5公里
    @Published var hasPersonalBest = true // 是否有個人最佳成績
    
    let targetDistance: Double // 從 OnboardingView 傳入的目標賽事距離
    let availableDistances = [
        "3": "3公里",
        "5": "5公里",
        "10": "10公里",
        "21.0975": "半程馬拉松",
        "42.195": "全程馬拉松"
    ]
    
    init(targetDistance: Double) {
        self.targetDistance = targetDistance
        // 如果目標賽事距離小於等於5K，預設PB距離為3K，否則為5K
        if targetDistance <= 5 {
            self.selectedDistance = "3"
        } else {
            self.selectedDistance = "5"
        }
    }
    
    var currentPace: String {
        guard hasPersonalBest else { return "" } // 如果沒有PB，則不計算配速
        let totalSeconds = (targetHours * 3600 + targetMinutes * 60)
        // 如果時間未設定 (0時0分)，則不計算配速
        guard totalSeconds > 0 else { return "" }
        
        let distanceKm = Double(selectedDistance) ?? 5.0
        let paceSeconds = Int(Double(totalSeconds) / distanceKm)
        let paceMinutes = paceSeconds / 60
        let paceRemainingSeconds = paceSeconds % 60
        return String(format: "%d:%02d", paceMinutes, paceRemainingSeconds)
    }
    
    func updatePersonalBest() async { // 移除參數，直接使用 ViewModel 的屬性
        isLoading = true
        error = nil
        
        do {
            if hasPersonalBest {
                // 確保時間已輸入
                guard (targetHours * 3600 + targetMinutes * 60) > 0 else {
                    self.error = "請輸入有效的個人最佳時間。"
                    isLoading = false
                    return
                }
                
                let userData = [
                    "distance_km": Double(selectedDistance) ?? 3.0,
                    "complete_time": targetHours * 3600 + targetMinutes * 60
                ] as [String : Any]
                
                try await UserService.shared.updatePersonalBestData(userData)
                print("個人最佳成績已更新")
            } else {
                // 如果使用者選擇沒有PB，可以考慮清除已儲存的PB數據或不執行任何操作
                // 目前 UserService 沒有直接清除PB的方法，所以這裡暫不處理清除
                print("使用者選擇沒有個人最佳成績或不確定。")
            }
            navigateToWeeklyDistance = true
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}

struct PersonalBestView: View {
    @StateObject private var viewModel: PersonalBestViewModel
    @Environment(\.dismiss) private var dismiss // 用於返回按鈕
    
    init(targetDistance: Double) {
        _viewModel = StateObject(wrappedValue: PersonalBestViewModel(targetDistance: targetDistance))
    }
    
    var body: some View {
        ZStack {
            Form {
                Section(
                    header: Text("您的跑步經驗").padding(.top, 10),
                    footer: Text("告訴我們您最近或最快的跑步成績，能幫助 Havital 更精準地為您安排初始訓練強度。如果您不確定或沒有相關經驗，可以直接選擇「我不確定我的個人最佳成績」。")
                ) {
                    Toggle("我有個人最佳成績", isOn: $viewModel.hasPersonalBest)
                }

                if viewModel.hasPersonalBest {
                    Section(header: Text("最佳成績詳情")) {
                        Text("請選擇您近期跑出最佳成績的距離與時間。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 5)
                        
                        Picker("選擇距離", selection: $viewModel.selectedDistance) {
                            ForEach(Array(viewModel.availableDistances.keys.sorted(by: { Double($0)! < Double($1)! })), id: \.self) { key in
                                Text(viewModel.availableDistances[key] ?? key)
                                    .tag(key)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        HStack {
                            Picker("時", selection: $viewModel.targetHours) {
                                ForEach(0...6, id: \.self) { hour in
                                    Text("\(hour)")
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            Text("時")
                            
                            Picker("分", selection: $viewModel.targetMinutes) {
                                ForEach(0...59, id: \.self) { minute in
                                    Text("\(minute)")
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            Text("分")
                        }
                        .padding(.vertical, 8)
                        
                        if !viewModel.currentPace.isEmpty {
                            HStack {
                                Text("平均配速")
                                Spacer()
                                Text("\(viewModel.currentPace) /公里")
                            }
                            .foregroundColor(.secondary)
                        } else if viewModel.hasPersonalBest && (viewModel.targetHours * 3600 + viewModel.targetMinutes * 60) == 0 {
                            Text("請輸入有效的時間以計算配速。")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    Section(header: Text("跳過個人最佳成績")) {
                        Text("沒問題！Havital 會根據您的目標和後續設定，提供一個合適的起點。")
                            .foregroundColor(.secondary)
                    }
                }
                
                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // 隱藏導航用的 NavigationLink
            NavigationLink(
                destination: WeeklyDistanceSetupView(targetDistance: viewModel.targetDistance)
                    .navigationBarBackButtonHidden(true),
                isActive: $viewModel.navigateToWeeklyDistance
            ) {
                EmptyView()
            }
            .hidden()
        }
        .navigationTitle("個人最佳成績")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { // 返回按鈕
                Button {
                    dismiss()
                } label: {
                    Text("返回")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await viewModel.updatePersonalBest()
                    }
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("下一步")
                        }
                    }
                }
                // 更新禁用邏輯
                .disabled(viewModel.isLoading || (viewModel.hasPersonalBest && viewModel.currentPace.isEmpty && (viewModel.targetHours * 3600 + viewModel.targetMinutes * 60) == 0))
            }
        }
    }
}

struct PersonalBestView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { // 包在 NavigationView 中以供預覽
            PersonalBestView(targetDistance: 21.0975)
        }
    }
}
