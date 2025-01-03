import Foundation

struct TrainingExplanation: Codable {
    let purpose: String
    let benefits: String
    let method: String
    let precautions: String
}

struct TrainingExplanations: Codable {
    let explanations: [String: TrainingExplanation]
    
    static func load() -> TrainingExplanations? {
        guard let url = Bundle.main.url(forResource: "training_explanations", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        
        return try? JSONDecoder().decode(TrainingExplanations.self, from: data)
    }
}
