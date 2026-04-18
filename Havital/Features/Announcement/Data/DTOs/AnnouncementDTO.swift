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
    let isSeen: Bool?   // nil when backend omits the field; mapper defaults to false (unread)

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

// MARK: - Lossy list response

struct AnnouncementListResponse: Codable {
    let announcements: [AnnouncementDTO]

    enum CodingKeys: String, CodingKey { case announcements }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let throwables = try container.decode([ThrowableAnnouncementDTO].self, forKey: .announcements)
        var items: [AnnouncementDTO] = []
        items.reserveCapacity(throwables.count)
        for (index, throwable) in throwables.enumerated() {
            switch throwable.result {
            case .success(let dto):
                items.append(dto)
            case .failure(let error):
                Logger.warn("[AnnouncementListResponse] item[\(index)] decode skipped: \(error.localizedDescription)")
            }
        }
        self.announcements = items
    }
}

/// Wrapper that captures a single AnnouncementDTO decode result without propagating failure.
private struct ThrowableAnnouncementDTO: Decodable {
    let result: Result<AnnouncementDTO, Error>

    init(from decoder: Decoder) throws {
        result = Result(catching: { try AnnouncementDTO(from: decoder) })
    }
}

struct SeenBatchRequest: Codable {
    let announcementIds: [String]

    enum CodingKeys: String, CodingKey {
        case announcementIds = "announcement_ids"
    }
}
