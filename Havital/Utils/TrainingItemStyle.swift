import SwiftUI

struct TrainingItemStyle {
    static func icon(for name: String) -> String {
        switch name {
        case "熱身":
            return "figure.walk"
        case "超慢跑":
            return "figure.run"
        case "放鬆":
            return "figure.cooldown"
        case "休息":
            return "bed.double"
        default:
            return "figure.mixed.cardio"
        }
    }
    
    static func color(for name: String) -> Color {
        switch name {
        case "熱身":
            return .orange
        case "超慢跑":
            return .blue
        case "放鬆":
            return .green
        case "休息":
            return .gray
        default:
            return .primary
        }
    }
}
