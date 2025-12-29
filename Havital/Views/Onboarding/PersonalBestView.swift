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
    @Published var availablePersonalBests: [String: [PersonalBestRecordV2]] = [:] // 從 API 載入的 PB v2 列表
    @Published var selectedPersonalBestKey: String? // 選擇的 PB 對應的 key (e.g., "5" for 5K)
    @Published var showPersonalBestList = false // 顯示 PB 列表

    let targetDistance: Double // 從 OnboardingView 傳入的目標賽事距離
    // 注意：個人最佳成績從 3km 開始，不包含 1.6km
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

    /// 從後端載入用戶已有的 PersonalBestV2 列表
    func loadPersonalBests() async {
        do {
            let user = try await UserService.shared.getUserProfileAsync()
            if let personalBestV2 = user.personalBestV2,
               let raceRunData = personalBestV2["race_run"] {
                // raceRunData 結構: { "5": [...], "10": [...], etc. }
                await MainActor.run {
                    self.availablePersonalBests = raceRunData
                    print("[PersonalBestViewModel] 成功載入 \(raceRunData.count) 種距離的 PB")
                }
            }
        } catch {
            print("[PersonalBestViewModel] 載入 PB 失敗: \(error.localizedDescription)")
            // 不顯示錯誤，因為新用戶可能沒有 PB
        }
    }

    /// 當用戶選擇已有的 PB 時
    func selectPersonalBest(distanceKey: String) {
        guard let recordsList = availablePersonalBests[distanceKey],
              let bestRecord = recordsList.first else {
            return
        }

        // 標準化距離值以匹配 availableDistances 中的 key
        let normalizedDistance = normalizeDistanceKey(distanceKey)
        selectedDistance = normalizedDistance
        selectedPersonalBestKey = distanceKey

        // 將已有的 PB 時間填入
        let totalSeconds = bestRecord.completeTime
        targetHours = totalSeconds / 3600
        targetMinutes = (totalSeconds % 3600) / 60
        targetSeconds = totalSeconds % 60

        print("[PersonalBestViewModel] 選擇已有 PB: \(distanceKey)km, 時間: \(bestRecord.formattedTime())")
        showPersonalBestList = false
    }

    /// 標準化距離 key：將 API 返回的值對應到 availableDistances 中的 key
    /// 例如: "21" -> "21.0975", "42" -> "42.195"
    private func normalizeDistanceKey(_ key: String) -> String {
        switch key {
        case "21": return "21.0975"
        case "42": return "42.195"
        default: return key
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

    /// 標準化距離值：將 21 轉換為 21.0975，42 轉換為 42.195
    private func normalizeDistance(_ distanceStr: String) -> Double {
        let distance = Double(distanceStr) ?? 0.0

        // 半馬：21 → 21.0975
        if distance == 21 {
            return 21.0975
        }

        // 全馬：42 → 42.195
        if distance == 42 {
            return 42.195
        }

        // 其他距離保持原值
        return distance
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
                    print("[PersonalBestViewModel] ❌ 時間未輸入")
                    return
                }

                // 距離標準化：將 21 轉換為 21.0975，42 轉換為 42.195
                let normalizedDistance = normalizeDistance(selectedDistance)

                let userData = [
                    "distance_km": normalizedDistance,
                    "complete_time": targetHours * 3600 + targetMinutes * 60 + targetSeconds
                ] as [String : Any]

                print("[PersonalBestViewModel] 正在更新 PB: \(userData)")
                try await UserService.shared.updatePersonalBestData(userData)

                // 如果是選擇已有的 PB，記錄一下
                if let pbKey = selectedPersonalBestKey {
                    print("✅ 使用者選擇已有的 PB: \(pbKey)km")
                } else {
                    print("✅ 個人最佳成績已更新")
                }
            } else {
                // ✅ 跳過 API 調用：使用者選擇沒有個人最佳成績
                // 符合新 onboarding 流程要求，不上傳任何 PB 數據
                print("使用者選擇沒有個人最佳成績，跳過 API 調用。")
            }

            // 保存 hasPersonalBest 狀態，供 WeeklyDistanceSetupView 判斷導航邏輯使用
            UserDefaults.standard.set(hasPersonalBest, forKey: "onboarding_hasPersonalBest")

            print("[PersonalBestViewModel] ✅ 更新成功，準備導航")
            navigateToWeeklyDistance = true
        } catch {
            self.error = error.localizedDescription
            print("[PersonalBestViewModel] ❌ 更新失敗: \(error.localizedDescription)")
        }

        isLoading = false
    }
}

struct PersonalBestView: View {
    @StateObject private var viewModel: PersonalBestViewModel
    @ObservedObject private var coordinator = OnboardingCoordinator.shared
    
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

                    // 如果有已存的 PB 紀錄，顯示快速選擇列表
                    if viewModel.hasPersonalBest && !viewModel.availablePersonalBests.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("或選擇已有的個人最佳成績")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.availablePersonalBests.keys.sorted { a, b in
                                        Double(a) ?? 0 < Double(b) ?? 0
                                    }, id: \.self) { distanceKey in
                                        if let records = viewModel.availablePersonalBests[distanceKey],
                                           let bestRecord = records.first {
                                            Button(action: {
                                                viewModel.selectPersonalBest(distanceKey: distanceKey)
                                            }) {
                                                VStack(spacing: 4) {
                                                    Text("\(distanceKey)km")
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                    Text(bestRecord.formattedTime())
                                                        .font(.caption2)
                                                }
                                                .frame(maxWidth: .infinity)
                                                .padding(8)
                                                .background(viewModel.selectedPersonalBestKey == distanceKey ? Color.accentColor : Color(.systemGray5))
                                                .foregroundColor(viewModel.selectedPersonalBestKey == distanceKey ? .white : .primary)
                                                .cornerRadius(8)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 8)
                    }
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
        }
        .navigationTitle(NSLocalizedString("onboarding.personal_best_title_nav", comment: "Personal Best"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if coordinator.isReonboarding && coordinator.navigationPath.isEmpty {
                    // Re-onboarding 根視圖：顯示關閉按鈕
                    Button {
                        AuthenticationService.shared.cancelReonboarding()
                    } label: {
                        Image(systemName: "xmark")
                    }
                } else if !coordinator.navigationPath.isEmpty {
                    // 有導航路徑時：顯示返回按鈕
                    Button {
                        coordinator.goBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text(NSLocalizedString("common.back", comment: "Back"))
                        }
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await viewModel.updatePersonalBest()
                        // 只要沒有錯誤，就導航到下一步
                        if viewModel.error == nil {
                            coordinator.navigate(to: .weeklyDistance)
                        }
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
                // 更新禁用邏輯：只在載入中或有 PB 但未輸入時間時禁用
                .disabled(viewModel.isLoading || (viewModel.hasPersonalBest && (viewModel.targetHours * 3600 + viewModel.targetMinutes * 60 + viewModel.targetSeconds) == 0))
            }
        }
        .task {
            // 載入用戶已有的 PersonalBestV2 列表
            await viewModel.loadPersonalBests()
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
