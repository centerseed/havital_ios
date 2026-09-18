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
            safety: toSafety(from: dto.safety),
            pendingPlanChange: dto.pendingPlanChange.map(toPendingPlanChange(from:)),
            planChangeApplied: dto.planChangeApplied == true
        )
    }

    /// PendingPlanChangeDTO → PendingPlanChange
    static func toPendingPlanChange(from dto: PendingPlanChangeDTO) -> PendingPlanChange {
        return PendingPlanChange(
            proposalId: dto.proposalId,
            summary: dto.summary,
            safetyLevel: dto.safetyLevel,
            requiresSubscription: dto.requiresSubscription,
            diffDays: dto.diffDays?.map(toDiffDay(from:))
        )
    }

    private static func toDiffDay(from dto: PlanChangeDiffDayDTO) -> PlanChangeDiffDay {
        return PlanChangeDiffDay(
            dayIndex: dto.dayIndex,
            from: dto.from.map(toDayFace(from:)),
            to: dto.to.map(toDayFace(from:))
        )
    }

    private static func toDayFace(from dto: PlanChangeDayFaceDTO) -> PlanChangeDayFace {
        return PlanChangeDayFace(
            category: dto.category,
            runType: dto.runType,
            distanceKm: dto.distanceKm
        )
    }

    /// PlanChangeConfirmResponseDTO → PlanChangeConfirmResult
    static func toConfirmResult(from dto: PlanChangeConfirmResponseDTO) -> PlanChangeConfirmResult {
        return PlanChangeConfirmResult(
            applied: dto.applied ?? (dto.status == "applied"),
            status: dto.status
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
    /// 缺 session_id 的項目視為無效並過濾（無分組鍵）。
    static func toHistory(from dto: RizoHistoryResponseDTO) -> [RizoHistoryItem] {
        return dto.items.compactMap(toHistoryItem(from:))
    }

    /// session_id → 還沒處理的提案。省略或空 map 都是沒有待確認按鈕。
    static func toPendingPlanChanges(
        from dto: RizoHistoryResponseDTO
    ) -> [String: PendingPlanChange] {
        (dto.pendingPlanChanges ?? [:]).mapValues(toPendingPlanChange(from:))
    }

    static func toHistoryItem(from dto: RizoHistoryItemDTO) -> RizoHistoryItem? {
        guard let sessionId = dto.sessionId, !sessionId.isEmpty else { return nil }
        return RizoHistoryItem(
            sessionId: sessionId,
            scenario: dto.scenario ?? "",
            userInput: dto.userInput ?? "",
            rizoResponse: dto.rizoResponse ?? "",
            ts: dto.ts
        )
    }

    static func toHistoryFork(from dto: RizoHistoryForkResponseDTO) -> RizoHistoryFork {
        RizoHistoryFork(
            sessionId: dto.sessionId,
            scenario: dto.scenario,
            turns: dto.turns.compactMap(toHistoryItem(from:))
        )
    }
}
