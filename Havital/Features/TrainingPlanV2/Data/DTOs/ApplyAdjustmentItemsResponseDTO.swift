import Foundation

/// Response DTO for POST /v2/summary/weekly/apply-items (data field)
struct ApplyAdjustmentItemsResponseDTO: Codable {
    let appliesToWeek: Int
    let skippedItems: [SkippedAdjustmentItemDTO]

    enum CodingKeys: String, CodingKey {
        case appliesToWeek = "applies_to_week"
        case skippedItems = "skipped_items"
    }
}

struct SkippedAdjustmentItemDTO: Codable {
    let index: Int
    let content: String
}
