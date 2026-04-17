import Foundation

struct Announcement: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    let imageUrl: String?
    let ctaLabel: String?
    let ctaUrl: String?
    let publishedAt: Date
    let expiresAt: Date?
    let isSeen: Bool
}
