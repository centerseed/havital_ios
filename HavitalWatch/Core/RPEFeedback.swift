import Foundation

enum RPEFeedback {
    static func text(for rpe: Int) -> String {
        switch rpe {
        case ...3:
            return NSLocalizedString(
                "workout.rpe.feedback.low",
                tableName: nil,
                bundle: .main,
                value: "輕巧地完成 ✓",
                comment: "輕巧地完成 ✓"
            )
        case 4...5:
            return NSLocalizedString(
                "workout.rpe.feedback.medium",
                tableName: nil,
                bundle: .main,
                value: "節奏掌握得不錯 ✓",
                comment: "節奏掌握得不錯 ✓"
            )
        case 6...7:
            return NSLocalizedString(
                "workout.rpe.feedback.high",
                tableName: nil,
                bundle: .main,
                value: "紮實的一次 ✓",
                comment: "紮實的一次 ✓"
            )
        default:
            return NSLocalizedString(
                "workout.rpe.feedback.max",
                tableName: nil,
                bundle: .main,
                value: "硬仗打完了 💪",
                comment: "硬仗打完了 💪"
            )
        }
    }
}
