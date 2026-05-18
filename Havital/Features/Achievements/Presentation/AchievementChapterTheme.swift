import SwiftUI

enum AchievementChapterTheme {
    static func primaryColor(for chapter: AchievementChapter) -> Color {
        switch chapter {
        case .start:
            return PacerizTokens.color.brand.secondary
        case .build:
            return PacerizTokens.color.brand.primary
        case .adapt:
            return PacerizTokens.color.brand.accent
        case .prove:
            return PacerizTokens.color.semantic.error
        case .identity:
            return PacerizTokens.color.brand.primary
        case .unknown:
            return PacerizTokens.color.text.secondary
        }
    }
}
