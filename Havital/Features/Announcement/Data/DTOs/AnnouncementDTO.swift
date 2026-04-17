import Foundation

struct AnnouncementDTO: Codable {
    let id: String
    let title: String
    let body: String
    let imageUrl: String?
    let ctaLabel: String?
    let ctaUrl: String?
    let publishedAt: String?
    let expiresAt: String?
    let isSeen: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, body
        case imageUrl    = "image_url"
        case ctaLabel    = "cta_label"
        case ctaUrl      = "cta_url"
        case publishedAt = "published_at"
        case expiresAt   = "expires_at"
        case isSeen      = "is_seen"
    }
}

struct AnnouncementListResponse: Codable {
    let announcements: [AnnouncementDTO]
}

struct SeenBatchRequest: Codable {
    let announcementIds: [String]

    enum CodingKeys: String, CodingKey {
        case announcementIds = "announcement_ids"
    }
}
