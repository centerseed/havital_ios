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

    /// 送出通用情境（無關聯 workout）的對話訊息。
    /// 對應 POST /v2/agent/chat（scenario 由呼叫端指定，如今日卡片情境）。
    /// - Parameters:
    ///   - scenario: 對話情境（如 "weekly_situation" / "body_status"）。
    ///   - message: 使用者輸入的訊息；首回合開場可傳空字串，由後端依 scenario 注入今日狀態生成開場。
    ///   - sessionId: 續談會話 ID；首回合傳 nil，後續傳上一回合 RizoReply 回的 sessionId。
    /// - Returns: Rizo 回應（含回覆、會話、配額、安全資訊）。
    func sendChat(
        scenario: String,
        message: String,
        sessionId: String?
    ) async throws -> RizoReply

    func streamChat(scenario: String, message: String, sessionId: String?) -> AsyncThrowingStream<RizoChatUpdate, Error>
    func streamJournalChat(workoutId: String, message: String, presetSelections: [String], sessionId: String?) -> AsyncThrowingStream<RizoChatUpdate, Error>

    /// 取得指定情境的預設快捷選項。
    /// 對應 GET /v2/agent/presets?scenario=...
    /// - Parameter scenario: 情境（如 "journal"）。
    /// - Returns: 預設選項清單。
    func getPresets(scenario: String) async throws -> [RizoPreset]

    /// 取得歷史對話清單。
    /// 對應 GET /v2/agent/history。
    /// - Returns: 歷史項目清單。
    func getHistory() async throws -> [RizoHistoryItem]

    /// 以來源 session 的第 `throughTurnIndex` 回合（0-based，含該回合）建立新對話。
    func forkHistory(sourceSessionId: String, throughTurnIndex: Int) async throws -> RizoHistoryFork

    /// 確認並套用先前提出的改課表提案（使用者按「接受」）。
    /// 對應 POST /v2/agent/plan-change/confirm。
    /// - Parameter proposalId: chat 回應 `pendingPlanChange.proposalId`。
    /// - Returns: 確認結果（是否已套用）。
    func confirmPlanChange(proposalId: String) async throws -> PlanChangeConfirmResult
}

// MARK: - Rizo Repository Convenience Defaults
extension RizoRepository {
    func forkHistory(sourceSessionId: String, throughTurnIndex: Int) async throws -> RizoHistoryFork {
        throw RizoRepositoryError.dataSourceUnavailable
    }

    func streamJournalChat(workoutId: String, message: String, presetSelections: [String], sessionId: String?) -> AsyncThrowingStream<RizoChatUpdate, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(.final(try await sendJournalChat(workoutId: workoutId, message: message,
                                                                        presetSelections: presetSelections, sessionId: sessionId)))
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    func streamChat(scenario: String, message: String, sessionId: String?) -> AsyncThrowingStream<RizoChatUpdate, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(.final(try await sendChat(scenario: scenario, message: message, sessionId: sessionId)))
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    /// 預設實作:不測改課表的 preview/test 替身免實作(真實 RizoRepositoryImpl 已覆寫)。
    func confirmPlanChange(proposalId: String) async throws -> PlanChangeConfirmResult {
        throw RizoRepositoryError.dataSourceUnavailable
    }

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

enum RizoChatUpdate {
    case partial(String)
    case final(RizoReply)
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
