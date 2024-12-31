import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var trainingPlanVM = TrainingPlanViewModel()
    @State private var isGeneratingPlan = false
    @State private var showError = false
    @State private var errorMessage = ""
    
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
    
    let predefinedAnnouncements = [
        "我想感覺到更有精神",
        "我想減重",
        "我想要有更好的體態",
        "我想要達成難度更高的運動目標",
    ]
      
    let questions = [
        OnboardingQuestion(
            title: "我是Vita，您的專屬運動顧問",
            description: "建立運動習慣最好的方法，就是設定簡單的目標，然後讓運動融入日常生活中。\n 我會幫您設定合適的運動計畫，並依據您的執行狀況做調整。",
            type: .intro
        ),
        OnboardingQuestion(
            title: "你的運動目標",
            description: "請分享你想透過運動達成什麼目標",
            type: .announcement,
            range: nil
        ),
        OnboardingQuestion(
            title: "有氧運動能力",
            description: "請評估您的有氧運動能力（跑步、游泳等）",
            type: .slider,
            range: 0...7
        ),
        OnboardingQuestion(
            title: "肌力訓練程度",
            description: "0-無法深蹲，7-可以連續深蹲50下",
            type: .slider,
            range: 0...7
        ),
        OnboardingQuestion(
            title: "可運動時間",
            description: "請選擇一週中可以運動的時間",
            type: .weekdaySelection,
            range: nil
        ),
        /*
        OnboardingQuestion(
            title: "想趕快看到身體的進步嗎？",
            description: "請評估您參與運動的主動程度",
            type: .slider,
            range: 0...7
        ),*/
        
        OnboardingQuestion(
            title: "基本資料",
            description: "請填寫您的基本身體資料",
            type: .bodyInfo,
            range: nil
        ),
        OnboardingQuestion(
            title: "讓我們開始吧",
            description: "依據你的自我評估，Havital推薦以下運動計畫，請選擇一個你最喜歡的運動項目",
            type: .workoutSelection,
            range: nil
        )
    ]
    
    var body: some View {
        VStack {
            if isGeneratingPlan {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Vita 正在為您生成專屬運動計畫...")
                        .font(.headline)
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
                            TextField("輸入你的運動目標...", text: $announcement)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal)
                            
                            Text("或選擇以下目標：")
                                .font(.subheadline)
                                .foregroundColor(Color(UIColor { traitCollection in
                                    traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.TextColors.secondary) : UIColor(AppTheme.TextColors.secondary)
                                }))
                                .padding(.top)
                            
                            ForEach(predefinedAnnouncements, id: \.self) { goal in
                                Button(action: {
                                    announcement = goal
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
                    case .workoutSelection:
                        VStack(spacing: 20) {
                            ForEach(getAvailableWorkouts(), id: \.name) { workout in
                                Button(action: {
                                    selectedWorkout = workout.name
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
                    
                    if currentPage == questions.count - 1 {
                        Button("完成") {
                            completeOnboarding()
                        }
                        .padding()
                        .foregroundColor(.white)
                        .background(Color(UIColor { traitCollection in
                            traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.primaryColor) : UIColor(AppTheme.shared.primaryColor)
                        }))
                        .cornerRadius(10)
                    } else {
                        Button("下一步") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .padding()
                        .foregroundColor(.white)
                        .background(Color(UIColor { traitCollection in
                            traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.primaryColor) : UIColor(AppTheme.shared.primaryColor)
                        }))
                        .cornerRadius(10)
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
        switch page {
        case 0:
            return Binding(
                get: { Double(aerobicsLevel) },
                set: { aerobicsLevel = Int($0) }
            )
        case 1:
            return Binding(
                get: { Double(strengthLevel) },
                set: { strengthLevel = Int($0) }
            )
        case 2:
            return Binding(
                get: { Double(busyLevel) },
                set: { busyLevel = Int($0) }
            )
        case 3:
            return Binding(
                get: { Double(proactiveLevel) },
                set: { proactiveLevel = Int($0) }
            )
        default:
            return .constant(0)
        }
    }
    
    private func completeOnboarding() {
        isGeneratingPlan = true
        
        // 準備 Gemini 輸入數據
        let geminiInput = [
            "user_info": [
                "age": age,
                "aerobics_level": aerobicsLevel,
                "strength_level": strengthLevel,
                "proactive_level": proactiveLevel,
                "workout_days": selectedWeekdays.count,
                "preferred_workout": selectedWorkout
            ]
        ]
        
        // 呼叫 Gemini 生成訓練計劃
        Task {
            do {
                let result = try await GeminiService.shared.generateContent(
                    withPromptFiles: ["prompt_training_plan_base", "prompt_training_plan_onboard"],
                    input: geminiInput,
                    schema: trainingPlanSchema
                )
                
                // 打印完整的 AI 返回結果
                print("=== AI Onboarding Response ===")
                if let jsonData = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
                print("=================")
                
                // 將結果轉換為 JSON 字符串
                let jsonData = try JSONSerialization.data(withJSONObject: result, options: .prettyPrinted)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    // 生成訓練計劃
                    try await trainingPlanVM.generateNewPlan(plan: jsonString)
                }
                
                // 保存用戶偏好
                let preference = UserPreference(
                    userId: 0,
                    userEmail: "test_user_mail",
                    userName: "測試用戶",
                    aerobicsLevel: aerobicsLevel,
                    strengthLevel: strengthLevel,
                    busyLevel: 3,
                    proactiveLevel: proactiveLevel,
                    age: age,
                    bodyFat: 20,
                    bodyHeight: bodyHeight,
                    bodyWeight: bodyWeight,
                    announcement: announcement,
                    workoutDays: selectedWeekdays,
                    preferredWorkouts: [selectedWorkout]
                )
                
                UserPreferenceManager.shared.currentPreference
                UserPreferenceManager.shared.savePreference(preference)
                
                await MainActor.run {
                    isGeneratingPlan = false
                    hasCompletedOnboarding = true
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
        let targetWorkouts = ["runing", "jump_rope", "super_slow_run", "hiit", "strength_training"]
        
        let availableWorkouts = definitions
            .filter { targetWorkouts.contains($0.name) }
            .map { (name: $0.name, displayName: $0.displayName) }
            .filter { workout in
                if age > 55 && (workout.name == "jump_rope" || workout.name == "hiit") {
                    return false
                }
                if strengthLevel < 3 && workout.name == "hiit" {
                    return false
                }
                return true
            }
        
        return availableWorkouts
    }
}

struct OnboardingQuestion {
    let title: String
    let description: String
    let type: QuestionType
    let range: ClosedRange<Double>?
    
    enum QuestionType {
        case slider
        case bodyInfo
        case announcement
        case weekdaySelection
        case workoutSelection
        case intro
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
