import SwiftUI

@MainActor
class PersonalBestViewModel: ObservableObject {
    @Published var targetHours = 0
    @Published var targetMinutes = 0
    @Published var targetSeconds = 0
    @Published var isLoading = false
    @Published var error: String?
    @Published var navigateToWeeklyDistance = false
    @Published var selectedDistance = "5" // 預設5公里
    @Published var hasPersonalBest = true // 是否有個人最佳成績
    
    let targetDistance: Double // 從 OnboardingView 傳入的目標賽事距離
    let availableDistances: [String: String] = [
        "3": NSLocalizedString("distance.3k", comment: "3K"),
        "5": NSLocalizedString("distance.5k", comment: "5K"),
        "10": NSLocalizedString("distance.10k", comment: "10K"),
        "21.0975": NSLocalizedString("distance.half_marathon", comment: "Half Marathon"),
        "42.195": NSLocalizedString("distance.full_marathon", comment: "Full Marathon")
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
        let totalSeconds = (targetHours * 3600 + targetMinutes * 60 + targetSeconds)
        // 如果時間未設定 (0時0分0秒)，則不計算配速
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
                guard (targetHours * 3600 + targetMinutes * 60 + targetSeconds) > 0 else {
                    self.error = "請輸入有效的個人最佳時間。"
                    isLoading = false
                    return
                }

                let userData = [
                    "distance_km": Double(selectedDistance) ?? 3.0,
                    "complete_time": targetHours * 3600 + targetMinutes * 60 + targetSeconds
                ] as [String : Any]

                try await UserService.shared.updatePersonalBestData(userData)
                print("個人最佳成績已更新")
            } else {
                // ✅ 跳過 API 調用：使用者選擇沒有個人最佳成績
                // 符合新 onboarding 流程要求，不上傳任何 PB 數據
                print("使用者選擇沒有個人最佳成績，跳過 API 調用。")
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
                    header: Text(NSLocalizedString("onboarding.personal_best_title", comment: "Personal Best Title")).padding(.top, 10),
                    footer: Text(NSLocalizedString("onboarding.personal_best_description", comment: "Personal Best Description"))
                ) {
                    Toggle(NSLocalizedString("onboarding.has_personal_best", comment: "Has Personal Best"), isOn: $viewModel.hasPersonalBest)
                }

                if viewModel.hasPersonalBest {
                    Section(header: Text(NSLocalizedString("onboarding.personal_best_details", comment: "Personal Best Details"))) {
                        Text(NSLocalizedString("onboarding.select_distance_time", comment: "Select Distance and Time"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 5)
                        
                        Picker(NSLocalizedString("onboarding.distance_selection", comment: "Distance Selection"), selection: $viewModel.selectedDistance) {
                            ForEach(Array(viewModel.availableDistances.keys.sorted(by: { Double($0)! < Double($1)! })), id: \.self) { key in
                                Text(viewModel.availableDistances[key] ?? key)
                                    .tag(key)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        HStack {
                            Picker(NSLocalizedString("onboarding.time_hours", comment: "Hours"), selection: $viewModel.targetHours) {
                                ForEach(0...6, id: \.self) { hour in
                                    Text("\(hour)")
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            Text(NSLocalizedString("onboarding.time_hours", comment: "Hours"))

                            Picker(NSLocalizedString("onboarding.time_minutes", comment: "Minutes"), selection: $viewModel.targetMinutes) {
                                ForEach(0...59, id: \.self) { minute in
                                    Text("\(minute)")
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            Text(NSLocalizedString("onboarding.time_minutes", comment: "Minutes"))

                            Picker(NSLocalizedString("onboarding.time_seconds", comment: "Seconds"), selection: $viewModel.targetSeconds) {
                                ForEach(0...59, id: \.self) { second in
                                    Text("\(second)")
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            Text(NSLocalizedString("onboarding.time_seconds", comment: "Seconds"))
                        }
                        .padding(.vertical, 8)
                        
                        if !viewModel.currentPace.isEmpty {
                            HStack {
                                Text(NSLocalizedString("onboarding.average_pace_calculation", comment: "Average Pace"))
                                Spacer()
                                Text("\(viewModel.currentPace) \(NSLocalizedString("onboarding.per_kilometer", comment: "Per Kilometer"))")
                            }
                            .foregroundColor(.secondary)
                        } else if viewModel.hasPersonalBest && (viewModel.targetHours * 3600 + viewModel.targetMinutes * 60 + viewModel.targetSeconds) == 0 {
                            Text(NSLocalizedString("onboarding.enter_valid_time", comment: "Enter Valid Time"))
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    Section(header: Text(NSLocalizedString("onboarding.skip_personal_best", comment: "Skip Personal Best"))) {
                        Text(NSLocalizedString("onboarding.skip_personal_best_message", comment: "Skip Personal Best Message"))
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
            // 新 onboarding 流程中，WeeklyDistanceSetupView 不需要 targetDistance
            NavigationLink(
                destination: WeeklyDistanceSetupView(targetDistance: nil)
                    .navigationBarBackButtonHidden(true),
                isActive: $viewModel.navigateToWeeklyDistance
            ) {
                EmptyView()
            }
            .hidden()
        }
        .navigationTitle(NSLocalizedString("onboarding.personal_best_title_nav", comment: "Personal Best"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { // 返回按鈕
                Button {
                    dismiss()
                } label: {
                    Text(NSLocalizedString("common.back", comment: "Back"))
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
                            Text(NSLocalizedString("onboarding.next", comment: "Next"))
                        }
                    }
                }
                // 更新禁用邏輯
                .disabled(viewModel.isLoading || (viewModel.hasPersonalBest && viewModel.currentPace.isEmpty && (viewModel.targetHours * 3600 + viewModel.targetMinutes * 60 + viewModel.targetSeconds) == 0))
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
