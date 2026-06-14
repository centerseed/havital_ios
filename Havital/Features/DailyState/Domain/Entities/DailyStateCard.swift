import Foundation

// MARK: - DailyStateCard
/// Domain Entity — 今日狀態卡片。camelCase，無 Codable（不耦合序列化格式）。
struct DailyStateCard: Equatable {
    enum Lens: String { case pre, post }

    let lens: Lens
    let source: String
    let headline: String
    let factType: String?
    let narrativeText: String?        // nil = 鎖/無
    let chips: [String]               // 佐證(已格式化,可空)
    let causeChips: [String]          // 可能因素(質性)
    let mileageProgression: String?   // 跑量漸進行（免費可見）
    let actionLine: String?           // 「12K easy · 6:45」
    let rizoScenario: String?         // 交棒 scenario(本版僅記錄,不導航)
    let divergenceFlagText: String?
    let isPaid: Bool
    let isLocked: Bool
    let upsellReason: String?

    var hasChip: Bool { !chips.isEmpty }
}
