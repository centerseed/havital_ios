import Foundation

// MARK: - Rizo Domain Entities
// Domain Layer - 純業務模型，camelCase，**絕不加 Codable**（避免耦合序列化格式）。
// 對應後端 /v2/agent/* 回應，但與 wire 格式解耦：DTO→Entity 的轉換由 RizoMapper 負責。

// MARK: - RizoReply

/// 一次 Rizo 對話回合的回應。
struct RizoReply: Equatable {
    /// AI 回覆內容（已經是 canned 或真實 LLM 輸出，由 safety.canned 區分）。
    let reply: String

    /// 會話 ID，後續同一段對話需回傳給後端維持脈絡。
    let sessionId: String

    /// 配額狀態（freemium gating）。
    let quota: RizoQuota

    /// 安全分層資訊（危險分類 / 是否為罐頭回覆）。
    let safety: RizoSafety

    /// 改課表:此回合若教練提出待確認的課表變更，帶提案；否則 nil。
    let pendingPlanChange: PendingPlanChange?

    /// pendingPlanChange 預設 nil → 既有建構處(無改課表)免改。
    init(reply: String, sessionId: String, quota: RizoQuota, safety: RizoSafety,
         pendingPlanChange: PendingPlanChange? = nil) {
        self.reply = reply
        self.sessionId = sessionId
        self.quota = quota
        self.safety = safety
        self.pendingPlanChange = pendingPlanChange
    }
}

// MARK: - PlanChange diff (structured)

/// 改課表單日 face（domain）。category=="run" 才有 runType/distanceKm。
struct PlanChangeDayFace: Equatable {
    let category: String
    let runType: String?
    let distanceKm: Double?
}

/// 改課表某一日的 from → to 變更。
struct PlanChangeDiffDay: Equatable {
    let dayIndex: Int
    let from: PlanChangeDayFace?
    let to: PlanChangeDayFace?
}

// MARK: - PendingPlanChange

/// 待使用者確認的改課表提案。UI 渲染「接受 / 繼續討論」。
struct PendingPlanChange: Equatable {
    /// 提案 ID，「接受」時回傳給 confirm 端點。
    let proposalId: String

    /// 變更摘要（如 "Day7: lsd 19km -> easy 19km"），給使用者看要改什麼。
    let summary: String?

    /// 風險分層（none / caution / …），UI 可標示風險色。
    let safetyLevel: String?

    /// 是否需訂閱（免費用戶按「接受」會走付費牆）。
    let requiresSubscription: Bool

    /// 結構化變更（在地化卡片用）；舊後端為 nil → fallback summary。
    let diffDays: [PlanChangeDiffDay]?
}

// MARK: - PlanChangeConfirmResult

/// 確認改課表的結果。
struct PlanChangeConfirmResult: Equatable {
    /// 是否已套用。
    let applied: Bool

    /// 後端狀態（如 "applied"）。
    let status: String?
}

// MARK: - RizoQuota

/// Rizo 使用配額狀態。
/// `limit` / `remaining` / `resetsAt` 在無上限（如付費無限）時可能為 nil。
struct RizoQuota: Equatable {
    /// 本次是否允許使用。
    let allowed: Bool

    /// 已使用次數。
    let used: Int

    /// 上限次數（無上限為 nil）。
    let limit: Int?

    /// 剩餘次數（無上限為 nil）。
    let remaining: Int?

    /// 配額重置時間（ISO8601 字串，無重置週期為 nil）。
    let resetsAt: String?

    /// 後端是否已預扣本次配額。
    let reserved: Bool
}

// MARK: - RizoSafety

/// 安全分層資訊。
struct RizoSafety: Equatable {
    /// 危險分類（後端定義的字串分類，如 "none" / "medical" 等）。
    let dangerClass: String

    /// 是否為罐頭（預設安全）回覆而非真實 LLM 生成。
    let canned: Bool
}

// MARK: - RizoPreset

/// 預設快捷選項（情境化按鈕）。
struct RizoPreset: Equatable, Identifiable {
    /// 預設項目唯一 ID。
    let id: String

    /// 分類（用於分組顯示）。
    let category: String

    /// 危險分類。
    let dangerClass: String

    /// 顯示文字。
    let label: String
}

// MARK: - RizoHistoryItem

/// 單一對話輪次（turn 級）。對應後端 history items[] 一筆。
/// 分組成 session 摘要由 RizoConversationSummary.group(from:) 處理。
struct RizoHistoryItem: Equatable {
    /// 所屬對話 session id（分組鍵）。
    let sessionId: String
    /// 情境（body_status / weekly_situation / journal / …）。
    let scenario: String
    /// 使用者輸入（開場輪為空字串）。
    let userInput: String
    /// Rizo 回覆。
    let rizoResponse: String
    /// 輪次時間（ISO8601 UTC 字串）。
    let ts: String?
}
