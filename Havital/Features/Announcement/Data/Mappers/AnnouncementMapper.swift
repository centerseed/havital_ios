import Foundation

enum AnnouncementMapper {
    private static let isoFormatterFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoFormatter = ISO8601DateFormatter()

    /// 後端可能回傳帶或不帶 fractional seconds 的 ISO8601，兩種都要能解
    private static func parseISO(_ string: String) -> Date? {
        isoFormatterFractional.date(from: string) ?? isoFormatter.date(from: string)
    }

    static func toDomain(_ dto: AnnouncementDTO) -> Announcement? {
        guard let publishedAtString = dto.publishedAt,
              let publishedAt = parseISO(publishedAtString) else {
            Logger.warn("[AnnouncementMapper] Missing or unparseable publishedAt: \(dto.publishedAt ?? "nil")")
            return nil
        }
        return Announcement(
            id: dto.id,
            title: dto.title,
            body: dto.body,
            imageUrl: dto.imageUrl,
            ctaLabel: dto.ctaLabel,
            ctaUrl: dto.ctaUrl,
            publishedAt: publishedAt,
            expiresAt: dto.expiresAt.flatMap { parseISO($0) },
            isSeen: dto.isSeen ?? false
        )
    }
}
