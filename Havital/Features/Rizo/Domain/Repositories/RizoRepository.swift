import Foundation

// MARK: - Rizo Repository Protocol
/// 定義 Rizo（AI 教練）資料存取介面。
/// Domain Layer - 只定義介面，不涉及實作細節。
/// ViewModel（下批）依賴此 protocol，絕不依賴 RizoRepositoryImpl。
protocol RizoRepository {

    /// 送出訓練日記情境的對話訊息。
    /// 對應 POST /v2/agent/chat（scenario 固定為 "journal"）。
    /// - Parameters:
    ///   - workoutId: 關聯的訓練 ID。
    ///   - message: 使用者輸入的訊息。
    ///   - presetSelections: 使用者選取的預設快捷項目 ID 清單。
    ///   - sessionId: 續談會話 ID（AC-TJF-08 Rizo 澄清輪續談）；首回合傳 nil，後續傳上一回合 RizoReply 回的 sessionId。
    /// - Returns: Rizo 回應（含回覆、會話、配額、安全資訊）。
    func sendJournalChat(
        workoutId: String,
        message: String,
        presetSelections: [String],
        sessionId: String?
    ) async throws -> RizoReply

    /// 取得指定情境的預設快捷選項。
    /// 對應 GET /v2/agent/presets?scenario=...
    /// - Parameter scenario: 情境（如 "journal"）。
    /// - Returns: 預設選項清單。
    func getPresets(scenario: String) async throws -> [RizoPreset]

    /// 取得歷史對話清單。
    /// 對應 GET /v2/agent/history。
    /// - Returns: 歷史項目清單。
    func getHistory() async throws -> [RizoHistoryItem]
}

// MARK: - Rizo Repository Convenience Defaults
extension RizoRepository {
    /// 首回合便利多載：sessionId 預設為 nil。
    func sendJournalChat(
        workoutId: String,
        message: String,
        presetSelections: [String]
    ) async throws -> RizoReply {
        try await sendJournalChat(
            workoutId: workoutId,
            message: message,
            presetSelections: presetSelections,
            sessionId: nil
        )
    }
}

// MARK: - Rizo Repository Errors
enum RizoRepositoryError: Error, Equatable {
    /// 資料來源不可用。
    case dataSourceUnavailable

    /// 參數驗證失敗（如 workoutId / message 為空）。
    case invalidInput(String)

    /// 資料格式錯誤。
    case invalidDataFormat(String)
}

// MARK: - RizoRepositoryError to DomainError
extension RizoRepositoryError {
    func toDomainError() -> DomainError {
        switch self {
        case .dataSourceUnavailable:
            return .networkFailure("Rizo data source unavailable")
        case .invalidInput(let message):
            return .validationFailure(message)
        case .invalidDataFormat(let message):
            return .dataCorruption(message)
        }
    }
}
