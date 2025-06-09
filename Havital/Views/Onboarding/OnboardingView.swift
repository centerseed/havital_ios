import SwiftUI

@MainActor
class OnboardingViewModel: ObservableObject {
    // ... (ViewModel 內容保持不變) ...
    @Published var raceName = ""
    @Published var raceDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()  // 預設為一個月後
    @Published var selectedDistance = "42.195" // 預設全馬
    @Published var targetHours = 4
    @Published var targetMinutes = 0
    @Published var isLoading = false
    @Published var error: String?
    // @Published var navigateToTrainingDays = false // 這個狀態似乎沒有直接在這個 View 中使用來導航，而是 createTarget 成功後，間接觸發 showPersonalBest
    
    let availableDistances = [
        "5": "5公里",
        "10": "10公里",
        "21.0975": "半程馬拉松",
        "42.195": "全程馬拉松"
    ]
    
    var remainingWeeks: Int {
        let calendar = Calendar.current
        let weeks = calendar.dateComponents([.weekOfYear],
                                          from: Date(),
                                          to: raceDate).weekOfYear ?? 0
        return max(weeks, 1) // 至少返回1週
    }
    
    var targetPace: String {
        let totalSeconds = (targetHours * 3600 + targetMinutes * 60)
        let distanceKm = Double(selectedDistance) ?? 42.195
        let paceSeconds = Int(Double(totalSeconds) / distanceKm)
        let paceMinutes = paceSeconds / 60
        let paceRemainingSeconds = paceSeconds % 60
        return String(format: "%d:%02d", paceMinutes, paceRemainingSeconds)
    }
    
    @MainActor
    func createTarget() async -> Bool { // 返回 Bool 表示是否成功
        isLoading = true
        error = nil
        
        do {
            let target = Target(
                id: UUID().uuidString,
                type: "race_run", // 或許可以考慮增加 "personal_goal" 類型
                name: raceName.isEmpty ? "我的訓練目標" : raceName, // 如果名稱為空，給一個預設值
                distanceKm: Int(Double(selectedDistance) ?? 42.195),
                targetTime: targetHours * 3600 + targetMinutes * 60,
                targetPace: targetPace,
                raceDate: Int(raceDate.timeIntervalSince1970),
                isMainRace: true,
                trainingWeeks: remainingWeeks
            )
            
            try await UserService.shared.createTarget(target)
            print("訓練目標已建立")
            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }
}

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showPersonalBest = false
    // @StateObject private var authService = AuthenticationService.shared // authService 在此 View 未直接使用

    var body: some View {
        ZStack(alignment: .bottom) {
                Form {
                    Section(header: Text("您的跑步目標"), footer: Text("如果您沒有特定賽事，可以為自己設定一個挑戰目標，例如「完成第一個5公里」或「提升10公里速度」。")) {
                        TextField("目標名稱 (例如：台北馬拉松 或 我的5K挑戰)", text: $viewModel.raceName)
                            .textContentType(.name)
                        
                        DatePicker("目標日期",
                                  selection: $viewModel.raceDate,
                                  in: Date()...,
                                  displayedComponents: .date)
                        
                        Text("距離比賽還有 \(viewModel.remainingWeeks) 週")
                            .foregroundColor(.secondary)
                    }
                    
                    Section(header: Text("比賽距離")) {
                        Picker("選擇距離", selection: $viewModel.selectedDistance) {
                            ForEach(Array(viewModel.availableDistances.keys.sorted()), id: \.self) { key in
                                Text(viewModel.availableDistances[key] ?? key)
                                    .tag(key)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    Section(header: Text("目標完賽時間"), footer: Text("設定一個您期望達成的時間。")) {
                        HStack {
                            Picker("時", selection: $viewModel.targetHours) {
                                ForEach(0...6, id: \.self) { hour in
                                    Text("\(hour)")
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100)
                            
                            Text("時")
                            
                            Picker("分", selection: $viewModel.targetMinutes) {
                                ForEach(0..<60, id: \.self) { minute in
                                    Text("\(minute)")
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100)
                            
                            Text("分")
                        }
                        .padding(.vertical, 8)
                        
                        Text("平均配速：\(viewModel.targetPace) /公里")
                            .foregroundColor(.secondary)
                    }
                    
                    if let error = viewModel.error {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                }
                // 在表單底部添加固定的按鈕
                Section {
                    Button(action: {
                        Task {
                            if await viewModel.createTarget() {
                                showPersonalBest = true
                            }
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("下一步")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
                
                NavigationLink(destination: PersonalBestView(targetDistance: Double(viewModel.selectedDistance) ?? 42.195)
                    .navigationBarBackButtonHidden(true),
                               isActive: $showPersonalBest) {
                    EmptyView()
                }
            }
            .navigationTitle("設定訓練目標")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
                
                // 右上角「下一步」按鈕
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            if await viewModel.createTarget() {
                                showPersonalBest = true
                            }
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("下一步")
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }

}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        // 若要在預覽中測試，需要包裝在 NavigationView 中
        NavigationView {
            OnboardingView()
        }
    }
}
