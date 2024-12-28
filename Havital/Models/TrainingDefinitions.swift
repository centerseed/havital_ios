import Foundation

struct TrainingType: Codable, Hashable {
    let id: String
    let type: String
}

struct TrainingItemDefinition: Codable, Identifiable, Hashable {
    let name: String
    let hints: [String]
    let resource: String?
    let trainingTypeId: String
    
    var id: String { name }
    
    enum CodingKeys: String, CodingKey {
        case name
        case hints
        case resource
        case trainingTypeId = "training_type_id"
    }
    
    var displayName: String {
        switch name {
        case "runing": return "跑步"
        case "jump_rope": return "跳繩"
        case "super_slow_run": return "超慢跑"
        case "hiit": return "高強度間歇"
        case "strength_training": return "力量訓練"
        case "breath_training": return "呼吸訓練"
        case "rest": return "休息"
        case "warmup": return "熱身"
        case "cooldown": return "放鬆"
        default: return name
        }
    }
    
    // Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    static func == (lhs: TrainingItemDefinition, rhs: TrainingItemDefinition) -> Bool {
        return lhs.name == rhs.name
    }
}

struct TrainingSubItemDefinition: Codable, Hashable {
    let id: String
    let name: String
    let resource: String
}

struct TrainingDefinitions: Codable {
    let trainingTypes: [TrainingType]
    let trainingItemDefs: [TrainingItemDefinition]
    let trainingSubItemDefs: [TrainingSubItemDefinition]
    
    enum CodingKeys: String, CodingKey {
        case trainingTypes = "training_types"
        case trainingItemDefs = "training_item_defs"
        case trainingSubItemDefs = "training_sub_item_defs"
    }
    
    static func load() -> TrainingDefinitions? {
        guard let url = Bundle.main.url(forResource: "training_definitions", withExtension: "json") else {
            print("Error: JSON file not found.")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            print("JSON data loaded successfully.")
            let definitions = try JSONDecoder().decode(TrainingDefinitions.self, from: data)
            return definitions
        } catch {
            print("Error decoding JSON: \(error)")
            return nil
        }
    }
}
