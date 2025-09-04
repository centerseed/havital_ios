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
    
    var availableDistances: [String: String] {
        [
            "5": NSLocalizedString("distance.5k", comment: "5K"),
            "10": NSLocalizedString("distance.10k", comment: "10K"),
            "21.0975": NSLocalizedString("distance.half_marathon", comment: "Half Marathon"),
            "42.195": NSLocalizedString("distance.full_marathon", comment: "Full Marathon")
        ]
    }
    
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
                name: raceName.isEmpty ? NSLocalizedString("onboarding.my_training_goal", comment: "My Training Goal") : raceName, // 如果名稱為空，給一個預設值
                distanceKm: Int(Double(selectedDistance) ?? 42.195),
                targetTime: targetHours * 3600 + targetMinutes * 60,
                targetPace: targetPace,
                raceDate: Int(raceDate.timeIntervalSince1970),
                isMainRace: true,
                trainingWeeks: remainingWeeks
            )
            
            try await UserService.shared.createTarget(target)
            print(NSLocalizedString("onboarding.target_created", comment: "Training goal created"))
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
        VStack {
            Form {
                Section(header: Text(NSLocalizedString("onboarding.your_running_goal", comment: "Your Running Goal")), footer: Text(NSLocalizedString("onboarding.goal_description", comment: "Goal description"))) {
                    TextField(NSLocalizedString("onboarding.target_race_example", comment: "Target race example"), text: $viewModel.raceName)
                        .textContentType(.name)
                    
                    DatePicker(NSLocalizedString("onboarding.goal_date", comment: "Goal Date"),
                              selection: $viewModel.raceDate,
                              in: Date()...,
                              displayedComponents: .date)
                    
                    Text(String(format: NSLocalizedString("onboarding.weeks_until_race", comment: "Weeks until race"), viewModel.remainingWeeks))
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text(NSLocalizedString("onboarding.race_distance", comment: "Race Distance"))) {
                    Picker(NSLocalizedString("onboarding.select_distance", comment: "Select Distance"), selection: $viewModel.selectedDistance) {
                        ForEach(Array(viewModel.availableDistances.keys.sorted()), id: \.self) { key in
                            Text(viewModel.availableDistances[key] ?? key)
                                .tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text(NSLocalizedString("onboarding.target_finish_time", comment: "Target Finish Time")), footer: Text(NSLocalizedString("onboarding.target_time_description", comment: "Target time description"))) {
                    HStack {
                        Picker(L10n.Onboarding.hoursLabel.localized, selection: $viewModel.targetHours) {
                            ForEach(0...6, id: \.self) { hour in
                                Text("\(hour)")
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        
                        Text(NSLocalizedString("onboarding.hours", comment: "hours"))
                        
                        Picker(L10n.Onboarding.minutesLabel.localized, selection: $viewModel.targetMinutes) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text("\(minute)")
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        
                        Text(NSLocalizedString("onboarding.minutes", comment: "minutes"))
                    }
                    .padding(.vertical, 8)
                    
                    Text(String(format: NSLocalizedString("onboarding.average_pace", comment: "Average pace"), viewModel.targetPace))
                        .foregroundColor(.secondary)
                }
                
                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // 底部按鈕
            VStack {
                Button(action: {
                    Task {
                        if await viewModel.createTarget() {
                            showPersonalBest = true
                        }
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(NSLocalizedString("onboarding.next_step", comment: "Next Step"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isLoading)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            
            NavigationLink(destination: PersonalBestView(targetDistance: Double(viewModel.selectedDistance) ?? 42.195)
                .navigationBarBackButtonHidden(true),
                           isActive: $showPersonalBest) {
                EmptyView()
            }
        }
        .navigationTitle(NSLocalizedString("onboarding.set_training_goal", comment: "Set Training Goal"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(NSLocalizedString("onboarding.back", comment: "Back")) {
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
                        Text(NSLocalizedString("onboarding.next_step", comment: "Next Step"))
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
