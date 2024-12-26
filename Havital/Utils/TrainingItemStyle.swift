import SwiftUI

struct TrainingItemStyle {
    static func icon(for name: String) -> String {
        switch name.lowercased() {
        case "熱身", "warmup":
            return "figure.walk"
        case "超慢跑", "super_slow_run":
            return "figure.run"
        case "放鬆", "cooldown":
            return "figure.cooldown"
        case "休息", "rest":
            return "bed.double"
        default:
            return "figure.mixed.cardio"
        }
    }
    
    static func color(for name: String) -> Color {
        switch name.lowercased() {
        case "熱身", "warmup":
            return .orange
        case "超慢跑", "super_slow_run":
            return .blue
        case "放鬆", "cooldown":
            return .green
        case "休息", "rest":
            return .gray
        default:
            return .primary
        }
    }
}
