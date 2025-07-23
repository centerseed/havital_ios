import Foundation

extension String {
    /// 獲取運動類型的中文顯示名稱
    func workoutTypeDisplayName() -> String {
        let displayNames: [String: String] = [
            "RUNNING": "跑步",
            "CYCLING": "自行車", 
            "SWIMMING": "游泳",
            "WALKING": "走路",
            "HIKING": "登山健行",
            "STRENGTH_TRAINING": "肌力訓練",
            "YOGA": "瑜珈",
            "PILATES": "皮拉提斯",
            "OTHER": "其他運動",
            
            // Additional common activity types
            "running": "跑步",
            "cycling": "自行車",
            "swimming": "游泳", 
            "walking": "走路",
            "hiking": "登山健行",
            "strength_training": "肌力訓練",
            "yoga": "瑜珈",
            "pilates": "皮拉提斯",
            "other": "其他運動",
            
            // Garmin specific types
            "bike": "自行車",
            "ride": "自行車",
            "run": "跑步",
            "swim": "游泳",
            "walk": "走路",
            "hike": "登山健行"
        ]
        
        // Try exact match first
        if let displayName = displayNames[self] {
            return displayName
        }
        
        // Try lowercase match
        if let displayName = displayNames[self.lowercased()] {
            return displayName
        }
        
        // Try matching with uppercase
        if let displayName = displayNames[self.uppercased()] {
            return displayName
        }
        
        // Check if it contains cycling-related keywords
        let cyclingKeywords = ["cycling", "bike", "ride", "自行車"]
        for keyword in cyclingKeywords {
            if self.lowercased().contains(keyword.lowercased()) {
                return "自行車"
            }
        }
        
        // Check if it contains running-related keywords
        let runningKeywords = ["running", "run", "跑"]
        for keyword in runningKeywords {
            if self.lowercased().contains(keyword.lowercased()) {
                return "跑步"
            }
        }
        
        // Return original if no match found, but capitalized
        return self.capitalized
    }
}