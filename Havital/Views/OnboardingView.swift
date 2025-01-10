import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var trainingPlanVM = TrainingPlanViewModel()
    @State private var isGeneratingPlan = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var planOverview: [String: Any]?
    @State private var showTrainingPlanView = false
    @State private var isGeneratingOverview = false
    
    // User Preference Data
    @State private var aerobicsLevel = 3
    @State private var strengthLevel = 3
    @State private var busyLevel = 3
    @State private var proactiveLevel = 3
    @State private var age = 25
    @State private var bodyFat = 20.0
    @State private var bodyHeight = 170.0
    @State private var bodyWeight = 65.0
    @State private var announcement = ""
    @State private var selectedWeekdays: Set<Int> = []
    @State private var selectedWorkout: String = ""
    @State private var isRequestingHealthKit = false
    @State private var healthKitGranted = false
    
    // 新增運動目標相關的狀態變量
    @State private var selectedGoalType = ""  // "beginner" 或 "running" 或 "custom"
    @State private var hasRunningExperience = false
    @State private var longestDistance = 0.0  // 最長跑步距離
    @State private var paceInSeconds = 420  // 配速（秒/公里），預設 ˙ 分鐘
    @State private var targetDistance = "5KM"  // 預設 5KM
    @State private var targetpaceInSeconds = 420  // 預設 7:00/km
    @State private var targetTimeInMinutes = 35  // 預設 35 分鐘
    @State private var selectedRaceDate = Date().addingTimeInterval(12 * 7 * 24 * 60 * 60)  // 預設 12 週後
    @State private var trainingWeeks = 12  // 訓練週數
    @State private var customGoal = ""
    
    @State private var questions: [OnboardingQuestion] = [
        OnboardingQuestion(
            title: "我是Vita，您的專屬運動顧問",
            description: "建立運動習慣最好的方法，就是設定簡單的目標，然後讓運動融入日常生活中。\n 我會幫您設定合適的運動計畫，並依據您的執行狀況做調整。",
            type: .intro
        ),
        OnboardingQuestion(
            title: "健康資料權限",
            description: "為了提供更好的運動建議和追蹤您的進度，我們需要存取您的健康資料",
            type: .healthKitPermission
        ),
        OnboardingQuestion(
            title: "選擇你的運動目標",
            description: "請選擇你想要達成的運動目標",
            type: .announcement
        )
    ]
      
    let predefinedAnnouncements = [
        "小試身手，先培養運動習慣",
        "挑戰跑步目標"
    ]
    
    var body: some View {
        VStack {
            if isGeneratingPlan {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("正在生成訓練計劃...")
                        .font(.headline)
                }
            } else if let overview = planOverview {
                NavigationLink(destination: TrainingPlanOverviewView(planOverview: overview, selectedGoalType: selectedGoalType, hasCompletedOnboarding: $hasCompletedOnboarding), isActive: $showTrainingPlanView) {
                    EmptyView()
                }
                .hidden()
                
                if !showTrainingPlanView {
                    TrainingPlanOverviewView(planOverview: overview, selectedGoalType: selectedGoalType, hasCompletedOnboarding: $hasCompletedOnboarding)
                }
            } else {
                // Progress indicator
                HStack {
                    ForEach(0..<questions.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage >= index ? Color(UIColor { traitCollection in
                                traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.primaryColor) : UIColor(AppTheme.shared.primaryColor)
                            }) : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 40)
                
                // Question
                Text(questions[currentPage].title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color(UIColor { traitCollection in
                        traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.TextColors.primary) : UIColor(AppTheme.TextColors.primary)
                    }))
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)
                
                Text(questions[currentPage].description)
                    .font(.body)
                    .foregroundColor(Color(UIColor { traitCollection in
                        traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.TextColors.secondary) : UIColor(AppTheme.TextColors.secondary)
                    }))
                    .multilineTextAlignment(.center)
                    .padding(.vertical)
                
                // Question Content
                Group {
                    switch questions[currentPage].type {
                    case .intro:
                        Text("")
                    case .announcement:
                        VStack(spacing: 20) {
                            ForEach(predefinedAnnouncements, id: \.self) { goal in
                                Button(action: {
                                    announcement = goal
                                    addGoalSpecificQuestions()
                                    // 重置相關變量
                                    if goal == "挑戰跑步目標" {
                                        hasRunningExperience = false
                                        longestDistance = 0.0
                                        paceInSeconds = 420
                                        targetDistance = "5KM"
                                        targetTimeInMinutes = 35
                                    } else {
                                        aerobicsLevel = 3
                                        strengthLevel = 3
                                        selectedWorkout = ""
                                    }
                                }) {
                                    Text(goal)
                                        .foregroundColor(announcement == goal ? .white : Color(UIColor { traitCollection in
                                            traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.TextColors.primary) : UIColor(AppTheme.TextColors.primary)
                                        }))
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            announcement == goal ? 
                                                Color(UIColor { traitCollection in
                                                    traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.primaryColor) : UIColor(AppTheme.shared.primaryColor)
                                                }) : 
                                                Color.gray.opacity(0.1)
                                        )
                                        .cornerRadius(10)
                                }
                            }
                            
                            // 自定義目標輸入
                            VStack(alignment: .leading, spacing: 10) {
                                Text("或輸入你的自定義目標")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                TextField("例如：想要完成一場馬拉松", text: $customGoal)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.horizontal)
                                    .onChange(of: customGoal) { newValue in
                                        if !newValue.isEmpty {
                                            announcement = newValue
                                            selectedGoalType = "custom"
                                            // 重置相關變量
                                            aerobicsLevel = 3
                                            strengthLevel = 3
                                            selectedWorkout = ""
                                            addGoalSpecificQuestions()
                                        }
                                    }
                            }
                            .padding(.top)
                        }
                        .padding()
                    
                    case .slider:
                        VStack(spacing: 20) {
                            Slider(value: binding(for: currentPage), in: questions[currentPage].range ?? 0...7, step: 1)
                                .tint(Color(UIColor { traitCollection in
                                    traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.primaryColor) : UIColor(AppTheme.shared.primaryColor)
                                }))
                                .padding(.horizontal)
                            
                            Text("\(Int(binding(for: currentPage).wrappedValue))")
                                .font(.title)
                                .foregroundColor(Color(UIColor { traitCollection in
                                    traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.primaryColor) : UIColor(AppTheme.shared.primaryColor)
                                }))
                        }
                        
                    case .bodyInfo:
                        VStack(spacing: 20) {
                            
                            HStack {
                                Text("身高 (cm)")
                                Spacer()
                                TextField("身高", value: $bodyHeight, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                    .keyboardType(.decimalPad)
                            }
                            
                            HStack {
                                Text("體重 (kg)")
                                Spacer()
                                TextField("體重", value: $bodyWeight, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                    .keyboardType(.decimalPad)
                            }
                            
                            HStack {
                                Text("體脂率 (%)（選填）")
                                Spacer()
                                TextField("體脂率", value: $bodyFat, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                    .keyboardType(.decimalPad)
                            }
                            
                            Text("評估合適的運動強度，和計算最大心率")
                            
                            HStack {
                                Text("年齡")
                                Spacer()
                                TextField("年齡", value: $age, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                    .keyboardType(.numberPad)
                            }
                        }
                        .padding()
                    case .weekdaySelection:
                        VStack(spacing: 20) {
                            Text("請選擇偏好的運動的日期")
                                .font(.subheadline)
                                .foregroundColor(Color(UIColor { traitCollection in
                                    traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.TextColors.secondary) : UIColor(AppTheme.TextColors.secondary)
                                }))
                                .padding(.top)
                            
                            ForEach(0..<7, id: \.self) { weekday in
                                Button(action: {
                                    if selectedWeekdays.contains(weekday) {
                                        selectedWeekdays.remove(weekday)
                                    } else {
                                        selectedWeekdays.insert(weekday)
                                    }
                                }) {
                                    Text(getWeekdayString(weekday: weekday))
                                        .foregroundColor(selectedWeekdays.contains(weekday) ? .white : Color(UIColor { traitCollection in
                                            traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.TextColors.primary) : UIColor(AppTheme.TextColors.primary)
                                        }))
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            selectedWeekdays.contains(weekday) ? 
                                                Color(UIColor { traitCollection in
                                                    traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.primaryColor) : UIColor(AppTheme.shared.primaryColor)
                                                }) : 
                                                Color.gray.opacity(0.1)
                                        )
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .padding()
                    case .healthKitPermission:
                        VStack(spacing: 20) {
                            if isRequestingHealthKit {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("正在請求健康資料權限...")
                                    .font(.headline)
                            } else if healthKitGranted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 50))
                                Text("已獲得健康資料權限")
                                    .font(.headline)
                            } else {
                                Button(action: {
                                    requestHealthKitPermission()
                                }) {
                                    Text("授予健康資料權限")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                }
                            }
                        }
                    case .workoutSelection:
                        VStack(spacing: 20) {
                            ForEach(getAvailableWorkouts(), id: \.name) { workout in
                                Button(action: {
                                    selectedWorkout = workout.name
                                    print("selectedWorkout \(selectedWorkout)")
                                }) {
                                    Text(workout.displayName)
                                        .foregroundColor(selectedWorkout == workout.name ? .white : Color(UIColor { traitCollection in
                                            traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.TextColors.primary) : UIColor(AppTheme.TextColors.primary)
                                        }))
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            selectedWorkout == workout.name ? 
                                                Color(UIColor { traitCollection in
                                                    traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.primaryColor) : UIColor(AppTheme.shared.primaryColor)
                                                }) : 
                                                Color.gray.opacity(0.1)
                                        )
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .padding()
                    case .runningExperience:
                        VStack(spacing: 20) {
                            Text("你有跑步經驗嗎？")
                                .font(.headline)
                                .foregroundColor(Color(UIColor { traitCollection in
                                    traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.TextColors.primary) : UIColor(AppTheme.TextColors.primary)
                                }))
                                .padding(.top)
                            
                            Button(action: {
                                hasRunningExperience = true
                            }) {
                                Text("有")
                                    .foregroundColor(hasRunningExperience ? .white : Color(UIColor { traitCollection in
                                        traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.TextColors.primary) : UIColor(AppTheme.TextColors.primary)
                                    }))
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        hasRunningExperience ? 
                                            Color(UIColor { traitCollection in
                                                traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.primaryColor) : UIColor(AppTheme.shared.primaryColor)
                                            }) : 
                                            Color.gray.opacity(0.1)
                                    )
                                    .cornerRadius(10)
                            }
                            Button(action: {
                                hasRunningExperience = false
                            }) {
                                Text("沒有")
                                    .foregroundColor(!hasRunningExperience ? .white : Color(UIColor { traitCollection in
                                        traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.TextColors.primary) : UIColor(AppTheme.TextColors.primary)
                                    }))
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        !hasRunningExperience ? 
                                            Color(UIColor { traitCollection in
                                                traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.primaryColor) : UIColor(AppTheme.shared.primaryColor)
                                            }) : 
                                            Color.gray.opacity(0.1)
                                    )
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                    case .runningPerformance:
                        VStack(spacing: 20) {
                            // 最長跑步距離輸入
                            VStack(alignment: .leading) {
                                Text("最長跑步距離")
                                    .font(.headline)
                                    .padding(.bottom, 5)
                                
                                HStack {
                                    TextField("", value: $longestDistance, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 100)
                                        .keyboardType(.decimalPad)
                                    Text("公里")
                                }
                            }
                            
                            // 配速輸入
                            VStack(alignment: .leading) {
                                Text("配速")
                                    .font(.headline)
                                    .padding(.bottom, 5)
                                
                                HStack {
                                    let minutes = paceInSeconds / 60
                                    let seconds = paceInSeconds % 60
                                    
                                    Picker("", selection: Binding(
                                        get: { minutes },
                                        set: { newValue in
                                            paceInSeconds = newValue * 60 + (paceInSeconds % 60)
                                        }
                                    )) {
                                        ForEach(3...15, id: \.self) { minute in
                                            Text("\(minute)").tag(minute)
                                        }
                                    }
                                    .frame(width: 80)
                                    .clipped()
                                    
                                    Text("分")
                                        .padding(.trailing, 5)
                                    
                                    Picker("", selection: Binding(
                                        get: { seconds },
                                        set: { newValue in
                                            paceInSeconds = (paceInSeconds / 60) * 60 + newValue
                                        }
                                    )) {
                                        ForEach(0...59, id: \.self) { second in
                                            Text(String(format: "%02d", second)).tag(second)
                                        }
                                    }
                                    .frame(width: 80)
                                    .clipped()
                                    
                                    Text("秒/公里")
                                }
                            }
                        }
                        .padding()
                    
                    case .runningGoals:
                        VStack(spacing: 20) {
                            // 目標距離選擇
                            VStack(alignment: .leading) {
                                Text("目標距離")
                                    .font(.headline)
                                    .padding(.bottom, 5)
                                
                                Menu {
                                    ForEach(["3KM", "5KM", "10KM", "半馬", "全馬"], id: \.self) { distance in
                                        Button(action: {
                                            targetDistance = distance
                                            updateTargetPace()
                                        }) {
                                            HStack {
                                                Text(distance)
                                                if targetDistance == distance {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(targetDistance.isEmpty ? "請選擇目標距離" : targetDistance)
                                            .foregroundColor(targetDistance.isEmpty ? .gray : Color(UIColor { traitCollection in
                                                traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.TextColors.primary) : UIColor(AppTheme.TextColors.primary)
                                            }))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                                }
                            }
                            
                            // 目標完賽時間輸入
                            if !targetDistance.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("完成時間")
                                        .font(.headline)
                                        .padding(.bottom, 5)
                                    
                                    HStack {
                                        let hours = targetTimeInMinutes / 60
                                        let minutes = targetTimeInMinutes % 60
                                        
                                        Picker("", selection: Binding(
                                            get: { hours },
                                            set: { newValue in
                                                targetTimeInMinutes = newValue * 60 + (targetTimeInMinutes % 60)
                                                updateTargetPace()
                                            }
                                        )) {
                                            ForEach(0...6, id: \.self) { hour in
                                                Text("\(hour)").tag(hour)
                                            }
                                        }
                                        .frame(width: 80)
                                        .clipped()
                                        
                                        Text("時")
                                            .padding(.trailing, 5)
                                        
                                        Picker("", selection: Binding(
                                            get: { minutes },
                                            set: { newValue in
                                                targetTimeInMinutes = (targetTimeInMinutes / 60) * 60 + newValue
                                                updateTargetPace()
                                            }
                                        )) {
                                            ForEach(0...59, id: \.self) { minute in
                                                Text(String(format: "%02d", minute)).tag(minute)
                                            }
                                        }
                                        .frame(width: 80)
                                        .clipped()
                                        
                                        Text("分")
                                        
                                        Spacer()
                                    }
                                }
                                
                                // 顯示目標配速
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("目標配速")
                                        .font(.headline)
                                        .padding(.bottom, 5)
                                    
                                    Text("\(targetpaceInSeconds / 60)分\(String(format: "%02d", targetpaceInSeconds % 60))秒/公里")
                                        .font(.system(.body, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                // 比賽日期選擇
                                VStack(alignment: .leading, spacing: 20) {
                                    Text("達成日期")
                                        .font(.headline)
                                        .padding(.top, 10)
                                    
                                    DatePicker(
                                        "",
                                        selection: $selectedRaceDate,
                                        in: Date()...,
                                        displayedComponents: [.date]
                                    )
                                    .onChange(of: selectedRaceDate) { newDate in
                                        // 計算從現在到比賽日期的週數
                                        let calendar = Calendar.current
                                        let components = calendar.dateComponents([.day], from: Date(), to: newDate)
                                        if let days = components.day {
                                            trainingWeeks = max(1, Int(ceil(Double(days) / 7.0)))
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    case .trainingWeeks:
                        VStack(spacing: 20) {
                            Text("選擇訓練計劃週數")
                                .font(.headline)
                                .padding(.bottom, 5)
                            
                            Menu {
                                ForEach([4, 6, 8, 10, 12, 16, 20], id: \.self) { weeks in
                                    Button(action: {
                                        trainingWeeks = weeks
                                    }) {
                                        HStack {
                                            Text("\(weeks)週")
                                            if trainingWeeks == weeks {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text("\(trainingWeeks)週")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 2)
                            }
                            .padding(.horizontal)
                            
                            Text("建議週數：")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• 4-6週：適合短期目標或保持基本運動習慣")
                                    .font(.subheadline)
                                Text("• 8-12週：適合漸進式提升體能或改善體態")
                                    .font(.subheadline)
                                Text("• 16-20週：適合長期目標或準備重大比賽")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        }
                        .padding()
                    }
                }
                
                Spacer()
                
                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        Button("返回") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .foregroundColor(Color(UIColor { traitCollection in
                            traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.primaryColor) : UIColor(AppTheme.shared.primaryColor)
                        }))
                        .padding()
                    }
                    
                    Spacer()
                    
                    // 只有在滿足特定條件時才能進入下一步
                    let canProceed = {
                        switch questions[currentPage].type {
                        case .announcement:
                            return !announcement.isEmpty
                        case .runningExperience:
                            return true // 已經有默認選擇
                        case .runningPerformance:
                            return longestDistance > 0 && paceInSeconds > 0
                        case .runningGoals:
                            if hasRunningExperience {
                                // 如果是跑步表現問題，需要檢查最長距離和配速
                                return longestDistance > 0 && paceInSeconds > 0
                            } else {
                                // 如果是目標設定問題，需要檢查目標距離和時間
                                return !targetDistance.isEmpty && targetTimeInMinutes > 0
                            }
                        case .weekdaySelection:
                            return !selectedWeekdays.isEmpty
                        case .bodyInfo:
                            return bodyHeight > 0 && bodyWeight > 0 && age > 0
                        case .trainingWeeks:
                            return trainingWeeks > 0
                        default:
                            return true
                        }
                    }()
                    
                    if currentPage == questions.count - 1 {
                        Button("完成") {
                            completeOnboarding()
                        }
                        .padding()
                        .foregroundColor(.white)
                        .background(canProceed ? Color(UIColor { traitCollection in
                            traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.primaryColor) : UIColor(AppTheme.shared.primaryColor)
                        }) : Color.gray)
                        .cornerRadius(10)
                        .disabled(!canProceed)
                    } else {
                        Button("下一步") {
                            withAnimation {
                                if questions[currentPage].type == .announcement && !announcement.isEmpty {
                                    // 當選擇了運動目標後，重新計算問題列表並移動到下一個問題
                                    currentPage = 3  // 跳到第一個動態問題
                                } else {
                                    currentPage += 1
                                }
                            }
                        }
                        .padding()
                        .foregroundColor(.white)
                        .background(canProceed ? Color(UIColor { traitCollection in
                            traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.primaryColor) : UIColor(AppTheme.shared.primaryColor)
                        }) : Color.gray)
                        .cornerRadius(10)
                        .disabled(!canProceed)
                    }
                }
                .padding()
            }
        }
        .background(Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.backgroundColor) : UIColor(AppTheme.shared.backgroundColor)
        }))
        .alert("錯誤", isPresented: $showError) {
            Button("確定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func binding(for page: Int) -> Binding<Double> {
        // Find the index of current slider in the questions array
        let sliderQuestions = questions.enumerated().filter { $0.element.type == .slider }
        if let sliderIndex = sliderQuestions.firstIndex(where: { $0.offset == page }) {
            switch sliderIndex {
            case 0: // 有氧運動能力
                return Binding(
                    get: { Double(aerobicsLevel) },
                    set: { aerobicsLevel = Int($0) }
                )
            case 1: // 肌力訓練程度
                return Binding(
                    get: { Double(strengthLevel) },
                    set: { strengthLevel = Int($0) }
                )
            default:
                return .constant(0)
            }
        }
        return .constant(0)
    }
    
    private func addGoalSpecificQuestions() {
        // 保留前三個固定問題，清除之前的接續問題
        questions = Array(questions.prefix(3))
        
        if announcement == "小試身手，先培養運動習慣" {
            selectedGoalType = "beginner"
            questions += [
                OnboardingQuestion(
                    title: "有氧運動能力",
                    description: "0-走路都會喘，7-可以連續跑十公里",
                    type: .slider,
                    range: 0...7
                ),
                OnboardingQuestion(
                    title: "肌力訓練程度",
                    description: "0-上下樓梯要扶東西，7-可以連續深蹲50下",
                    type: .slider,
                    range: 0...7
                ),
                OnboardingQuestion(
                    title: "偏好運動",
                    description: "請選擇你偏好的運動類型",
                    type: .workoutSelection
                )
            ]
        } else if announcement == "挑戰跑步目標" {
            selectedGoalType = "running"
            questions += [
                OnboardingQuestion(
                    title: "跑步經驗",
                    description: "請告訴我們你的跑步經驗",
                    type: .runningExperience
                ),
                OnboardingQuestion(
                    title: "跑步表現",
                    description: "請輸入你的最佳跑步表現",
                    type: .runningPerformance
                ),
                OnboardingQuestion(
                    title: "目標設定",
                    description: "請選擇你想要挑戰的目標",
                    type: .runningGoals
                )
            ]
        } else {
            selectedGoalType = "custom"
            questions += [
                OnboardingQuestion(
                    title: "選擇訓練計劃週數",
                    description: "請選擇你想要的訓練計劃週數",
                    type: .trainingWeeks
                ),
                OnboardingQuestion(
                    title: "有氧運動能力",
                    description: "0-走路都會喘，7-可以連續跑十公里",
                    type: .slider,
                    range: 0...7
                ),
                OnboardingQuestion(
                    title: "肌力訓練程度",
                    description: "0-上下樓梯要扶東西，7-可以連續深蹲50下",
                    type: .slider,
                    range: 0...7
                )
            ]
        }
        
        // 添加共同的問題
        questions += [
            OnboardingQuestion(
                title: "運動時間",
                description: "請選擇一週中可以運動的時間",
                type: .weekdaySelection
            ),
            OnboardingQuestion(
                title: "基本資料",
                description: "請填寫您的基本身體資料",
                type: .bodyInfo
            )
        ]
        
        // 確保當前頁面不會超出範圍
        currentPage = min(currentPage, questions.count - 1)
    }
    
    private func completeOnboarding() {
        isGeneratingPlan = true
        
        // 呼叫 Gemini 生成訓練計劃
        Task {
            do {
                // 保存用戶偏好
                let preference = UserPreference(
                    userId: 0,
                    userEmail: "",
                    userName: "",
                    aerobicsLevel: aerobicsLevel,
                    strengthLevel: strengthLevel,
                    busyLevel: 0,
                    proactiveLevel: 0,
                    age: age,
                    bodyFat: 0,
                    bodyHeight: bodyHeight,
                    bodyWeight: bodyWeight,
                    announcement: announcement,
                    workoutDays: Set(selectedWeekdays),
                    preferredWorkout: selectedWorkout,
                    goalType: selectedGoalType,
                    runningExperience: hasRunningExperience,
                    longestDistance: longestDistance,
                    paceInSeconds: paceInSeconds,
                    targetDistance: targetDistance,
                    targetTimeInMinutes: targetTimeInMinutes,
                    targetPaceInSeconds: targetpaceInSeconds,
                    trainingWeeks: trainingWeeks,
                    raceDate: selectedRaceDate,
                    weekOfPlan: 1
                )
                
                UserPreferenceManager.shared.currentPreference = preference
                UserPreferenceManager.shared.savePreference(preference)

                let promptFile: String
                switch selectedGoalType {
                case "beginner":
                    promptFile = "prompt_encourage_habit_overview"
                case "running":
                    promptFile = "prompt_running_overview"
                default:  // custom
                    promptFile = "prompt_custom_overview"
                }

                let input: [String: Any]
                switch selectedGoalType {
                case "beginner":
                    input = [
                        "user_info": [
                            "age": age,
                            "aerobics_level": aerobicsLevel,
                            "strength_level": strengthLevel,
                            "workout_days": selectedWeekdays.count,
                            "preferred_workout": selectedWorkout,
                            "training_goal": announcement,
                        ]
                    ]
                case "running":
                    input = [
                        "user_info": [
                        "age": age,
                        "running_experience": hasRunningExperience,
                        "longest_distance": longestDistance,
                        "target_distance": targetDistance,
                        "pace_in_seconds": paceInSeconds,
                        "target_pace_in_seconds": targetpaceInSeconds,
                        "training_weeks": trainingWeeks,
                        "workout_days": selectedWeekdays.count,
                        "training_goal": announcement,
                        ]
                    ]
                default:  // custom
                    input = [
                        "user_info": [
                            "age": age,
                            "aerobics_level": aerobicsLevel,
                            "strength_level": strengthLevel,
                            "workout_days": selectedWeekdays.count,
                            "training_weeks": trainingWeeks,
                            "training_goal": announcement,
                        ]
                    ]
                }

                var result = try await GeminiService.shared.generateContent(
                    withPromptFiles: [promptFile],
                    input: input,
                    schema: trainingOverviewSchema
                )
                
                if var userInformation = result["user_information"] as? [String: Any] {
                    userInformation["preferred_workout"] = UserPreferenceManager.shared.currentPreference?.preferredWorkout
                    result["user_information"] = userInformation
                }
                
                print("訓練計劃概覽:\n\(result)")
                
                await MainActor.run {
                    isGeneratingPlan = false
                    self.planOverview = result
                    TrainingPlanStorage.shared.saveTrainingPlanOverview(result)
                }
            } catch {
                await MainActor.run {
                    isGeneratingPlan = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func getWeekdayString(weekday: Int) -> String {
        switch weekday {
        case 0:
            return "星期日"
        case 1:
            return "星期一"
        case 2:
            return "星期二"
        case 3:
            return "星期三"
        case 4:
            return "星期四"
        case 5:
            return "星期五"
        case 6:
            return "星期六"
        default:
            return ""
        }
    }
    
    private func getAvailableWorkouts() -> [(name: String, displayName: String)] {
        let definitions = TrainingDefinitions.load()?.trainingItemDefs ?? []
        let targetWorkouts = ["running", "jump_rope", "super_slow_run", "hiit", "strength_training"]
        
        let availableWorkouts = definitions
            .filter { targetWorkouts.contains($0.name) }
            .map { (name: $0.name, displayName: $0.displayName) }
            .filter { workout in
                if strengthLevel < 3 && workout.name == "hiit" {
                    return false
                }
                return true
            }
        
        return availableWorkouts
    }
    
    private func requestHealthKitPermission() {
        isRequestingHealthKit = true
        
        Task {
            do {
                let healthKitManager = HealthKitManager()
                try await healthKitManager.requestAuthorization()
                await MainActor.run {
                    healthKitGranted = true
                    isRequestingHealthKit = false
                }
            } catch {
                await MainActor.run {
                    isRequestingHealthKit = false
                    errorMessage = "無法獲得健康資料權限：\(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func updateTargetPace() {
        // 根據目標距離和完賽時間計算配速
        let distanceInKm: Double
        switch targetDistance {
        case "3KM":
            distanceInKm = 3
        case "5KM":
            distanceInKm = 5
        case "10KM":
            distanceInKm = 10
        case "半馬":
            distanceInKm = 21.0975
        case "全馬":
            distanceInKm = 42.195
        default:
            return
        }
        
        // 將完賽時間轉換為秒
        let totalSeconds = targetTimeInMinutes * 60

        print("targetDistance: \(targetDistance)")
        
        // 計算每公里秒數
        targetpaceInSeconds = Int(Double(totalSeconds) / distanceInKm)
    }
    
    init() {
        // 初始化時計算預設配速
        _targetDistance = State(initialValue: "5KM")
        _targetTimeInMinutes = State(initialValue: 35)
        _selectedRaceDate = State(initialValue: Date().addingTimeInterval(12 * 7 * 24 * 60 * 60))
        
        // 計算初始配速
        let distanceInKm = 5.0
        let totalSeconds = 35 * 60
        _targetpaceInSeconds = State(initialValue: Int(Double(totalSeconds) / distanceInKm))
        
        // 計算初始訓練週數
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: Date().addingTimeInterval(12 * 7 * 24 * 60 * 60))
        if let days = components.day {
            _trainingWeeks = State(initialValue: max(1, Int(ceil(Double(days) / 7.0))))
        } else {
            _trainingWeeks = State(initialValue: 12)
        }
    }
}

struct OnboardingQuestion {
    let title: String
    let description: String
    let type: QuestionType
    var range: ClosedRange<Double>?
    
    enum QuestionType {
        case slider
        case bodyInfo
        case announcement
        case weekdaySelection
        case workoutSelection
        case healthKitPermission
        case intro
        case runningExperience
        case runningPerformance
        case runningGoals
        case trainingWeeks
    }
    
    init(title: String, description: String, type: QuestionType, range: ClosedRange<Double>? = nil) {
        self.title = title
        self.description = description
        self.type = type
        self.range = range
    }
}

#Preview {
    OnboardingView()
}
