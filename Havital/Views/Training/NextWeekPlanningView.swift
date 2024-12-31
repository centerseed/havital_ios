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
    @State private var difficultyAdjustment: AdjustmentType = .noChange
    @State private var daysAdjustment: AdjustmentType = .noChange
    @State private var trainingItemAdjustment: AdjustmentType = .noChange
    @State private var isGenerating = false
    
    enum AdjustmentType: String, CaseIterable {
        case decrease = "減少"
        case noChange = "不變"
        case increase = "增加"
        
        var jsonValue: String {
            switch self {
            case .decrease: return "decrease"
            case .noChange: return "keep_the_same"
            case .increase: return "increase"
            }
        }
    }
    
    var onGenerate: (Int, AdjustmentType, AdjustmentType, AdjustmentType, @escaping () -> Void) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    Section(header: Text("本週訓練感受（0-最差，5-最佳）")) {
                        Picker("訓練感受評分", selection: $feelingRating) {
                            ForEach(0...5, id: \.self) { rating in
                                Text("\(rating)")
                                    .tag(rating)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Section(header: Text("難度調整")) {
                        Picker("難度", selection: $difficultyAdjustment) {
                            ForEach(AdjustmentType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Section(header: Text("運動天數調整")) {
                        Picker("運動天數", selection: $daysAdjustment) {
                            ForEach(AdjustmentType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Section(header: Text("運動項目變化調整")) {
                        Picker("運動項目", selection: $trainingItemAdjustment) {
                            ForEach(AdjustmentType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Section {
                        Button(action: {
                            isGenerating = true
                            onGenerate(feelingRating, difficultyAdjustment, daysAdjustment, trainingItemAdjustment) {
                                dismiss()
                            }
                        }) {
                            HStack {
                                Spacer()
                                Text("開始產生下週計劃")
                                    .bold()
                                Spacer()
                            }
                        }
                        .disabled(isGenerating)
                    }
                }
                .blur(radius: isGenerating ? 3 : 0)
                
                if isGenerating {
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
                    .disabled(isGenerating)
                }
            }
            .interactiveDismissDisabled(isGenerating)
        }
    }
}

#Preview {
    NextWeekPlanningView { feeling, difficulty, days, trainingItem, completion in
        print("Feeling: \(feeling), Difficulty: \(difficulty), Days: \(days), Training Item: \(trainingItem)")
        completion()
    }
}
