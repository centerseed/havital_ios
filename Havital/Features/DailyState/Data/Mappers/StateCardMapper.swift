import Foundation

// MARK: - StateCardMapper
/// DTO → Entity 轉換。純函式 enum，無狀態。
enum StateCardMapper {
    static func toEntity(from dto: StateCardDTO) -> DailyStateCard {
        DailyStateCard(
            lens: DailyStateCard.Lens(rawValue: dto.lens) ?? .pre,
            source: dto.source ?? "steady",
            headline: dto.headline,
            factType: dto.factType,
            narrativeText: dto.narrativeText,
            chips: dto.chips ?? [],
            causeChips: dto.causeChips ?? [],
            actionLine: actionLine(from: dto.action),
            rizoScenario: dto.action?.rizoHandoff?.scenario ?? dto.divergence?.suggestedRizoScenario,
            divergenceFlagText: (dto.divergence?.present == true) ? dto.divergence?.flagText : nil,
            isPaid: dto.access.isPaid,
            isLocked: dto.access.locked,
            upsellReason: dto.access.upsell?.reason
        )
    }

    private static func actionLine(from action: StateCardDTO.ActionDTO?) -> String? {
        guard let s = action?.sessionRef, let rt = s.runType else { return nil }
        var parts: [String] = []
        if let km = s.distanceKm { parts.append("\(Int(km))K \(rt)") } else { parts.append(rt) }
        if let pace = s.pace { parts.append(pace) }
        return parts.joined(separator: " · ")
    }
}
