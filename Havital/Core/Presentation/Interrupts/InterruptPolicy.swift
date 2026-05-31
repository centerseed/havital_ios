import Foundation

enum InterruptPresentationStyle: Equatable {
    case overlay
    case sheet
    case alert
}

enum InterruptPriority: Int, Comparable {
    case otherNudge = 0
    case dataSourceBindingReminder = 10
    case workoutRecap = 15          // 訓練完成 recap：高於資料源提醒，但讓位給公告/付費/阻斷
    case announcement = 20
    case paywall = 30
    case sessionBlocking = 40

    static func < (lhs: InterruptPriority, rhs: InterruptPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct InterruptPolicy: Equatable {
    let priority: InterruptPriority
    let presentationStyle: InterruptPresentationStyle
}

