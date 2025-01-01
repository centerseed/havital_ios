import SwiftUI

struct UserFeedback: Codable {
    let feeling: Int
    let difficul_adjust: String
    let training_day_adjust: String
    let training_item_adjust: String
}

struct NextWeekPlanningView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feelingRating: Int = 3
    @State private var difficultyAdjustment: DifficultyAdjustment = .keepTheSame
    @State private var daysAdjustment: DaysAdjustment = .keepTheSame
    @State private var trainingItemAdjustment: TrainingItemAdjustment = .keepTheSame
    @State private var isGenerating = false
    @State private var showLoadingView = false
    
    enum DifficultyAdjustment: String, CaseIterable {
        case decrease = "減少"
        case keepTheSame = "維持不變"
        case increase = "增加"
        
        var jsonValue: String {
            switch self {
            case .decrease: return "decrease_difficulty"
            case .keepTheSame: return "keep_the_same"
            case .increase: return "increase_difficulty"
            }
        }
    }

    enum DaysAdjustment: String, CaseIterable {
        case decrease = "減少"
        case keepTheSame = "維持不變"
        case increase = "增加"
        
        var jsonValue: String {
            switch self {
            case .decrease: return "decrease_1_day"
            case .keepTheSame: return "keep_the_same"
            case .increase: return "increase_1_day"
            }
        }
    }

    enum TrainingItemAdjustment: String, CaseIterable {
        case decrease = "減少"
        case keepTheSame = "維持不變"
        case increase = "增加"
        
        var jsonValue: String {
            switch self {
            case .decrease: return "decrease_1_different_training_type"
            case .keepTheSame: return "keep_the_same"
            case .increase: return "increase_1_different_training_type"
            }
        }
    }
    
    var onGenerate: (Int, DifficultyAdjustment, DaysAdjustment, TrainingItemAdjustment, @escaping () -> Void) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    Section(header: Text("本週訓練感受（0-最差，5-最佳）")) {
                        Stepper(value: $feelingRating, in: 1...5) {
                            HStack {
                                Text("整體感受：")
                                Text(String(repeating: "⭐️", count: feelingRating))
                            }
                        }
                    }
                    
                    Text("對於下週的訓練期望，Vita會依據實際情況做出調整，也可以自由的編輯新產生的運動計畫")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Section(header: Text("難度調整")) {
                        Picker("難度", selection: $difficultyAdjustment) {
                            ForEach(DifficultyAdjustment.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Section(header: Text("運動天數調整")) {
                        Picker("運動天數", selection: $daysAdjustment) {
                            ForEach(DaysAdjustment.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Section(header: Text("運動項目變化調整")) {
                        Picker("運動項目", selection: $trainingItemAdjustment) {
                            ForEach(TrainingItemAdjustment.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Section {
                        Button(action: {
                            showLoadingView = true
                            onGenerate(feelingRating, difficultyAdjustment, daysAdjustment, trainingItemAdjustment) {
                                showLoadingView = false
                            }
                        }) {
                            if showLoadingView {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("開始產生下次計劃")
                            }
                        }
                        .disabled(showLoadingView)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
                .blur(radius: showLoadingView ? 3 : 0)
                
                if showLoadingView {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Vita 正在為你產生訓練計劃...")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("請稍候")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.9))
                }
            }
            .navigationTitle("下週計劃設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(showLoadingView)
                }
            }
            .interactiveDismissDisabled(showLoadingView)
        }
    }
}

#Preview {
    NextWeekPlanningView { feeling, difficulty, days, trainingItem, completion in
        print("Feeling: \(feeling), Difficulty: \(difficulty), Days: \(days), Training Item: \(trainingItem)")
        completion()
    }
}
