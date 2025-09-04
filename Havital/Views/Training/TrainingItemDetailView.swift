import SwiftUI

struct TrainingItemDetailView: View {
    let itemName: String
    @State private var explanation: TrainingExplanation?
    @State private var displayName: String = ""
    
    var body: some View {
        List {
            if let explanation = explanation {
                Section(L10n.TrainingItemDetail.purpose.localized) {
                    Text(explanation.purpose)
                }

                Section(L10n.TrainingItemDetail.benefits.localized) {
                    Text(explanation.benefits)
                }

                Section(L10n.TrainingItemDetail.method.localized) {
                    Text(explanation.method)
                }

                Section(L10n.TrainingItemDetail.precautions.localized) {
                    Text(explanation.precautions)
                }
            } else {
                Text(L10n.TrainingItemDetail.notFound.localized)
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
