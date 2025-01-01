import SwiftUI

struct TrainingItemStyle {
    static func icon(for name: String) -> String {
        switch name.lowercased() {
        case "warmup":
            return "figure.walk"
        case "super_slow_run":
            return "figure.run"
        case "running":
            return "figure.run"
        case "cooldown":
            return "figure.cooldown"
        case "rest":
            return "bed.double"
        case "jump_rope":
            return "figure.jumprope"
        case "hiit":
            return "figure.highintensity.intervaltraining"
        case "strength_training":
            return "figure.strengthtraining.traditional"
        case "breath_training":
            return "lungs"
        case "yoga":
            return "figure.yoga"
        default:
            return "figure.mixed.cardio"
        }
    }
    
    static func color(for name: String) -> Color {
        switch name.lowercased() {
        case "warmup":
            return .orange
        case "running":
            return .purple
        case "super_slow_run":
            return .blue
        case "cooldown":
            return .green
        case "rest":
            return .gray
        case "jump_rope":
            return .purple
        case "hiit":
            return .red
        case "strength_training":
            return .orange
        case "breath_training":
            return .cyan
        case "yoga":
            return .mint
        default:
            return .primary
        }
    }
}
