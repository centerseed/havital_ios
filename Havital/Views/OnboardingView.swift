import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
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
    
    let predefinedAnnouncements = [
        "我想感覺到更有精神",
        "我想要有更好的體態",
        "我想要達成難度更高的運動目標"
    ]
    
    let questions = [
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
            description: "一天預計的運動時間，0-5分鐘，7-1小時以上",
            type: .slider,
            range: 0...7
        ),
        OnboardingQuestion(
            title: "想趕快看到身體的進步嗎？",
            description: "請評估您參與運動的主動程度",
            type: .slider,
            range: 0...7
        ),
        OnboardingQuestion(
            title: "你的運動目標",
            description: "請分享你想透過運動達成什麼目標",
            type: .announcement,
            range: nil
        ),
        OnboardingQuestion(
            title: "基本資料",
            description: "請填寫您的基本身體資料",
            type: .bodyInfo,
            range: nil
        )
    ]
    
    var body: some View {
        VStack {
            // Progress indicator
            HStack {
                ForEach(0..<questions.count, id: \.self) { index in
                    Circle()
                        .fill(currentPage >= index ? AppTheme.shared.primaryColor : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.top, 40)
            
            // Question
            Text(questions[currentPage].title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.TextColors.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 40)
            
            Text(questions[currentPage].description)
                .font(.body)
                .foregroundColor(AppTheme.TextColors.secondary)
                .multilineTextAlignment(.center)
                .padding(.vertical)
            
            // Question Content
            Group {
                switch questions[currentPage].type {
                case .announcement:
                    VStack(spacing: 20) {
                        TextField("輸入你的運動目標...", text: $announcement)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                        
                        Text("或選擇以下目標：")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.TextColors.secondary)
                            .padding(.top)
                        
                        ForEach(predefinedAnnouncements, id: \.self) { goal in
                            Button(action: {
                                announcement = goal
                            }) {
                                Text(goal)
                                    .foregroundColor(announcement == goal ? .white : AppTheme.TextColors.primary)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        announcement == goal ? 
                                            AppTheme.shared.primaryColor : 
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
                            .tint(AppTheme.shared.primaryColor)
                            .padding(.horizontal)
                        
                        Text("\(Int(binding(for: currentPage).wrappedValue))")
                            .font(.title)
                            .foregroundColor(AppTheme.shared.primaryColor)
                    }
                    
                case .bodyInfo:
                    VStack(spacing: 20) {
                        HStack {
                            Text("年齡")
                            Spacer()
                            TextField("年齡", value: $age, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .keyboardType(.numberPad)
                        }
                        
                        HStack {
                            Text("體脂率 (%)")
                            Spacer()
                            TextField("體脂率", value: $bodyFat, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .keyboardType(.decimalPad)
                        }
                        
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
                    .foregroundColor(AppTheme.shared.primaryColor)
                    .padding()
                }
                
                Spacer()
                
                if currentPage == questions.count - 1 {
                    Button("完成") {
                        saveUserPreference()
                        hasCompletedOnboarding = true
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(AppTheme.shared.primaryColor)
                    .cornerRadius(10)
                } else {
                    Button("下一步") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(AppTheme.shared.primaryColor)
                    .cornerRadius(10)
                }
            }
            .padding()
        }
        .background(AppTheme.shared.backgroundColor)
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
    
    private func saveUserPreference() {
        let preference = UserPreference(
            userId: 1, // Dummy data
            userEmail: "user@example.com", // Dummy data
            userName: "測試用戶", // Dummy data
            aerobicsLevel: aerobicsLevel,
            strengthLevel: strengthLevel,
            busyLevel: 7 - busyLevel,
            proactiveLevel: proactiveLevel,
            age: age,
            bodyFat: bodyFat,
            bodyHeight: bodyHeight,
            bodyWeight: bodyWeight,
            announcement: announcement
        )
        
        UserPreferenceManager.shared.savePreference(preference)
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
