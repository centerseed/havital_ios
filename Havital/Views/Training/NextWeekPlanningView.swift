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
        case decrease
        case keepTheSame
        case increase

        var localizedString: String {
            switch self {
            case .decrease: return L10n.NextWeekPlanning.Adjustment.decrease.localized
            case .keepTheSame: return L10n.NextWeekPlanning.Adjustment.keepSame.localized
            case .increase: return L10n.NextWeekPlanning.Adjustment.increase.localized
            }
        }
        
        var jsonValue: String {
            switch self {
            case .decrease: return "decrease_difficulty"
            case .keepTheSame: return "keep_the_same"
            case .increase: return "increase_difficulty"
            }
        }
    }

    enum DaysAdjustment: String, CaseIterable {
        case decrease
        case keepTheSame
        case increase

        var localizedString: String {
            switch self {
            case .decrease: return L10n.NextWeekPlanning.Adjustment.decrease.localized
            case .keepTheSame: return L10n.NextWeekPlanning.Adjustment.keepSame.localized
            case .increase: return L10n.NextWeekPlanning.Adjustment.increase.localized
            }
        }
        
        var jsonValue: String {
            switch self {
            case .decrease: return "decrease_1_day"
            case .keepTheSame: return "keep_the_same"
            case .increase: return "increase_1_day"
            }
        }
    }

    enum TrainingItemAdjustment: String, CaseIterable {
        case decrease
        case keepTheSame
        case increase

        var localizedString: String {
            switch self {
            case .decrease: return L10n.NextWeekPlanning.Adjustment.decrease.localized
            case .keepTheSame: return L10n.NextWeekPlanning.Adjustment.keepSame.localized
            case .increase: return L10n.NextWeekPlanning.Adjustment.increase.localized
            }
        }
        
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
                    Section(header: Text(L10n.NextWeekPlanning.weeklyFeeling.localized)) {
                        Stepper(value: $feelingRating, in: 1...5) {
                            HStack {
                                Text(L10n.NextWeekPlanning.overallFeeling.localized)
                                Text(String(repeating: "⭐️", count: feelingRating))
                            }
                        }
                    }
                    
                    Text(L10n.NextWeekPlanning.trainingExpectation.localized)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Section(header: Text(L10n.NextWeekPlanning.difficultyAdjustment.localized)) {
                        Picker(L10n.NextWeekPlanning.difficultyAdjustment.localized, selection: $difficultyAdjustment) {
                            ForEach(DifficultyAdjustment.allCases, id: \.self) { type in
                                Text(type.localizedString).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Section(header: Text(L10n.NextWeekPlanning.daysAdjustment.localized)) {
                        Picker(L10n.NextWeekPlanning.daysAdjustment.localized, selection: $daysAdjustment) {
                            ForEach(DaysAdjustment.allCases, id: \.self) { type in
                                Text(type.localizedString).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Section(header: Text(L10n.NextWeekPlanning.trainingItemAdjustment.localized)) {
                        Picker(L10n.NextWeekPlanning.trainingItemAdjustment.localized, selection: $trainingItemAdjustment) {
                            ForEach(TrainingItemAdjustment.allCases, id: \.self) { type in
                                Text(type.localizedString).tag(type)
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
                                Text(L10n.NextWeekPlanning.startGenerating.localized)
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
                        
                        Text(L10n.NextWeekPlanning.generatingPlan.localized)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(L10n.NextWeekPlanning.pleaseWait.localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.9))
                }
            }
            .navigationTitle(L10n.NextWeekPlanning.title.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.NextWeekPlanning.cancel.localized) {
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
