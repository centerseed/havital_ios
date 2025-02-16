import SwiftUI

struct TrainingItemDetailView: View {
    let itemName: String
    @State private var explanation: TrainingExplanation?
    @State private var displayName: String = ""
    
    var body: some View {
        List {
            if let explanation = explanation {
                Section("目的") {
                    Text(explanation.purpose)
                }
                
                Section("效果") {
                    Text(explanation.benefits)
                }
                
                Section("實行方式") {
                    Text(explanation.method)
                }
                
                Section("注意事項") {
                    Text(explanation.precautions)
                }
            } else {
                Text("無法找到該運動項目的說明")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(displayName)
        .onAppear {
            loadExplanation()
        }
    }
    
    private func loadExplanation() {
        if let explanations = TrainingExplanations.load() {
            // Convert itemName to lowercase and remove spaces for matching
            let key = itemName.lowercased().replacingOccurrences(of: " ", with: "")
            explanation = explanations.explanations[key]
        }
    }
}
