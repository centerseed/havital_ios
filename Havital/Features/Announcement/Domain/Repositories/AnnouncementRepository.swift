import Foundation

protocol AnnouncementRepository {
    /// GET /v2/announcements — 回傳後端已過濾的所有有效公告
    func fetchAnnouncements() async throws -> [Announcement]

    /// POST /v2/announcements/{id}/seen — Banner render 後呼叫
    func markSeen(id: String) async throws

    /// POST /v2/announcements/seen-batch — 進入訊息中心時呼叫
    func markSeenBatch(ids: [String]) async throws
}
