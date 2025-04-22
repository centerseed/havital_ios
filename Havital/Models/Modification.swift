import Foundation

// API for modifications description
struct ModificationDescription: Codable {
    let description: String
}

// Represents a single modification item
struct Modification: Codable {
    let content: String
    private let createdAtString: String
    let expiresAt: String?
    let isOneTime: Bool
    var applied: Bool
    let priority: Int

    // Computed property to parse created_at into Date
    var createdAt: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: createdAtString) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: createdAtString)
    }

    enum CodingKeys: String, CodingKey {
        case content
        case createdAtString = "created_at"
        case expiresAt = "expires_at"
        case isOneTime = "is_one_time"
        case applied
        case priority
    }
}

// Payload for creating a new modification
struct NewModification: Codable {
    let content: String
    let expiresAt: String?
    let isOneTime: Bool
    let priority: Int

    enum CodingKeys: String, CodingKey {
        case content
        case expiresAt = "expires_at"
        case isOneTime = "is_one_time"
        case priority
    }
}

// Payload for bulk updating modifications
struct ModificationsUpdateRequest: Codable {
    let modifications: [Modification]
}
