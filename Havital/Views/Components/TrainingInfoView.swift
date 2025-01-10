import SwiftUI

struct TrainingInfoView: View {
    let type: InfoType
    let plan: TrainingPlan
    let onDismiss: () -> Void
    
    enum InfoType {
        case purpose
        case tips
        
        var title: String {
            switch self {
            case .purpose:
                return "本週目標"
            case .tips:
                return "訓練提示"
            }
        }
        
        func content(from plan: TrainingPlan) -> String {
            switch self {
            case .purpose:
                return plan.purpose
            case .tips:
                return plan.tips
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(type.content(from: plan))
                        .font(.body)
                        .padding()
                }
            }
            .navigationTitle(type.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    TrainingInfoView(
        type: .purpose,
        plan: TrainingPlan(
            id: "test",
            purpose: "測試目標",
            tips: "測試提示",
            days: []
        )
    ) {
        // Dismiss action
    }
}
