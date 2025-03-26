import SwiftUI

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var raceName = ""
    @Published var raceDate = Date()
    @Published var selectedDistance = "42.195" // 預設全馬
    @Published var targetHours = 4
    @Published var targetMinutes = 0
    @Published var isLoading = false
    @Published var error: String?
    @Published var navigateToTrainingDays = false
    
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
    func createTarget() async {
        isLoading = true
        error = nil
        
        do {
            let target = Target(
                type: "race_run",
                name: raceName,
                distanceKm: Int(Double(selectedDistance) ?? 42.195),
                targetTime: targetHours * 3600 + targetMinutes * 60,
                targetPace: targetPace,
                raceDate: Int(raceDate.timeIntervalSince1970),
                isMainRace: true,
                trainingWeeks: remainingWeeks
            )
            
            try await UserService.shared.createTarget(target)
            print("賽事目標已建立")
            navigateToTrainingDays = true
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showPersonalBest = false
    @StateObject private var authService = AuthenticationService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    Section(header: Text("賽事資訊")) {
                        TextField("賽事名稱", text: $viewModel.raceName)
                            .textContentType(.name)
                        
                        DatePicker("賽事日期",
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
                    
                    Section(header: Text("目標完賽時間")) {
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
                .navigationTitle("設定賽事目標")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            // 離開 Onboarding 流程
                            // 但不標記為已完成，以便下次仍可進入
                            if let window = UIApplication.shared.windows.first {
                                window.rootViewController?.dismiss(animated: true, completion: nil)
                            }
                        }) {
                            Text("離開")
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            print("按下下一步按鈕")
                            Task {
                                print("開始執行 createTarget")
                                do {
                                    await viewModel.createTarget()
                                    print("完成執行 createTarget，準備導航")
                                    await MainActor.run {
                                        showPersonalBest = true
                                        print("已設置 showPersonalBest = true")
                                    }
                                } catch {
                                    print("執行 createTarget 時發生錯誤: \(error)")
                                }
                            }
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text("下一步")
                            }
                        }
                        .disabled(viewModel.raceName.isEmpty || viewModel.isLoading)
                    }
                }
                NavigationLink(destination: PersonalBestView(targetDistance: Double(viewModel.selectedDistance) ?? 42.195), isActive: $showPersonalBest) {
                    EmptyView()
                }
            }
        }
    }
}
