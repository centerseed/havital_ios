import Foundation

extension String {
    /// 獲取運動類型的本地化顯示名稱
    func workoutTypeDisplayName() -> String {
        let type = self.lowercased()
        
        // Direct mapping to localization keys
        switch type {
        case "running", "run":
            return L10n.ActivityType.running.localized
        case "cycling", "bike", "ride":
            return L10n.ActivityType.cycling.localized
        case "swimming", "swim":
            return L10n.ActivityType.swimming.localized
        case "walking", "walk":
            return L10n.ActivityType.walking.localized
        case "hiking", "hike":
            return L10n.ActivityType.hiking.localized
        case "strength_training", "strength", "weight":
            return L10n.ActivityType.strengthTraining.localized
        case "yoga":
            return L10n.ActivityType.yoga.localized
        case "pilates":
            return L10n.ActivityType.pilates.localized
        case "other":
            return L10n.ActivityType.other.localized
        default:
            // Check if it contains specific keywords
            if type.contains("cycl") || type.contains("bike") || type.contains("ride") {
                return L10n.ActivityType.cycling.localized
            } else if type.contains("run") {
                return L10n.ActivityType.running.localized
            } else if type.contains("swim") {
                return L10n.ActivityType.swimming.localized
            } else if type.contains("walk") {
                return L10n.ActivityType.walking.localized
            } else if type.contains("hik") {
                return L10n.ActivityType.hiking.localized
            } else if type.contains("strength") || type.contains("weight") {
                return L10n.ActivityType.strengthTraining.localized
            } else {
                return self.capitalized
            }
        }
    }
}