import Foundation

// MARK: - Rizo DTOs
// Data Layer - 對應後端 /v2/agent/* wire 格式（snake_case + CodingKeys）。
// Response DTO 採用 Codable（ResponseProcessor.extractData 要求 T: Codable），
// 但僅作為 wire 解碼用，業務模型一律用 Domain Entity（見 RizoMapper）。

// MARK: - RizoChatRequest

/// POST /v2/agent/chat 的請求 body。
/// scenario 在訓練日記情境固定為 "journal"。
struct RizoChatRequest: Encodable {
    let scenario: String
    let message: String
    let sessionId: String?
    let workoutId: String?
    let presetSelections: [String]

    enum CodingKeys: String, CodingKey {
        case scenario
        case message
        case sessionId = "session_id"
        case workoutId = "workout_id"
        case presetSelections = "preset_selections"
    }
}

// MARK: - RizoChatResponseDTO

/// POST /v2/agent/chat 回應的 data 物件。
struct RizoChatResponseDTO: Codable {
    let response: String
    let sessionId: String
    let quota: RizoQuotaDTO
    let safety: RizoSafetyDTO

    enum CodingKeys: String, CodingKey {
        case response
        case sessionId = "session_id"
        case quota
        case safety
    }
}

// MARK: - RizoQuotaDTO

struct RizoQuotaDTO: Codable {
    let allowed: Bool
    let used: Int
    let limit: Int?
    let remaining: Int?
    let resetsAt: String?
    let reserved: Bool

    enum CodingKeys: String, CodingKey {
        case allowed
        case used
        case limit
        case remaining
        case resetsAt = "resets_at"
        case reserved
    }
}

// MARK: - RizoSafetyDTO

struct RizoSafetyDTO: Codable {
    let dangerClass: String
    let canned: Bool

    enum CodingKeys: String, CodingKey {
        case dangerClass = "danger_class"
        case canned
    }
}

// MARK: - RizoPresetsResponseDTO

/// GET /v2/agent/presets 回應的 data 物件。
struct RizoPresetsResponseDTO: Codable {
    let scenario: String
    let presets: [RizoPresetDTO]
}

// MARK: - RizoPresetDTO

struct RizoPresetDTO: Codable {
    let id: String
    let category: String
    let dangerClass: String
    let label: String

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case dangerClass = "danger_class"
        case label
    }
}

// MARK: - RizoHistoryResponseDTO

/// GET /v2/agent/history 回應的 data 物件（本批先建骨架）。
struct RizoHistoryResponseDTO: Codable {
    let items: [RizoHistoryItemDTO]
}

// MARK: - RizoHistoryItemDTO

/// 歷史項目 DTO（骨架；欄位待後端 history 契約定版後補齊）。
/// 全部 optional + 寬鬆解碼，避免後端欄位演進時 decode 失敗。
struct RizoHistoryItemDTO: Codable {
    let id: String?
    let scenario: String?
    let message: String?
    let response: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case scenario
        case message
        case response
        case createdAt = "created_at"
    }
}
