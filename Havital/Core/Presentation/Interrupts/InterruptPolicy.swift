import Foundation

enum InterruptPresentationStyle: Equatable {
    case overlay
    case sheet
    case alert
}

enum InterruptPriority: Int, Comparable {
    case otherNudge = 0
    case dataSourceBindingReminder = 10
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

