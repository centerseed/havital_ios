import Foundation

// MARK: - Rizo Mapper
/// 負責 Rizo wire DTO → Domain Entity 的轉換。
/// Data Layer - Mapper。Domain Entity 不持 Codable，轉換邏輯集中於此。
struct RizoMapper {

    // MARK: - Chat

    /// RizoChatResponseDTO → RizoReply
    static func toReply(from dto: RizoChatResponseDTO) -> RizoReply {
        return RizoReply(
            reply: dto.response,
            sessionId: dto.sessionId,
            quota: toQuota(from: dto.quota),
            safety: toSafety(from: dto.safety)
        )
    }

    static func toQuota(from dto: RizoQuotaDTO) -> RizoQuota {
        return RizoQuota(
            allowed: dto.allowed,
            used: dto.used,
            limit: dto.limit,
            remaining: dto.remaining,
            resetsAt: dto.resetsAt,
            reserved: dto.reserved
        )
    }

    static func toSafety(from dto: RizoSafetyDTO) -> RizoSafety {
        return RizoSafety(
            dangerClass: dto.dangerClass,
            canned: dto.canned
        )
    }

    // MARK: - Presets

    /// RizoPresetsResponseDTO → [RizoPreset]
    static func toPresets(from dto: RizoPresetsResponseDTO) -> [RizoPreset] {
        return dto.presets.map(toPreset(from:))
    }

    static func toPreset(from dto: RizoPresetDTO) -> RizoPreset {
        return RizoPreset(
            id: dto.id,
            category: dto.category,
            dangerClass: dto.dangerClass,
            label: dto.label
        )
    }

    // MARK: - History

    /// RizoHistoryResponseDTO → [RizoHistoryItem]
    /// 缺 id 的項目視為無效並過濾（骨架階段的保守處理）。
    static func toHistory(from dto: RizoHistoryResponseDTO) -> [RizoHistoryItem] {
        return dto.items.compactMap(toHistoryItem(from:))
    }

    static func toHistoryItem(from dto: RizoHistoryItemDTO) -> RizoHistoryItem? {
        guard let id = dto.id else { return nil }
        return RizoHistoryItem(
            id: id,
            scenario: dto.scenario ?? "",
            message: dto.message ?? "",
            response: dto.response ?? "",
            createdAt: dto.createdAt
        )
    }
}
