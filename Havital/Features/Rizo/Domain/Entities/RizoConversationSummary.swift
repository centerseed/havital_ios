import Foundation

// MARK: - RizoConversationSummary
/// 一段 Rizo 對話（同 session_id 的所有輪次分組後的顯示摘要）。
/// Domain Entity — 無 Codable、無 UIKit/i18n/時區依賴。分組為純函式，可單測。
struct RizoConversationSummary: Identifiable, Equatable {
    /// 標題種子截斷長度（字元數）。
    private static let titleSeedMaxLength = 20

    var id: String { sessionId }
    let sessionId: String
    let scenario: String
    /// 最早輪次時間（ISO8601）。
    let startedAt: String?
    /// 最晚輪次時間（ISO8601）；清單排序 + 日期顯示用。
    let updatedAt: String?
    let turnCount: Int
    /// 標題種子 = 第一個非空用戶輸入（截斷 20 字）；純開場 session 為 nil，由 UI 套 fallback。
    let titleSeed: String?
    /// 清單預覽 = 最後一輪非空 Rizo 回覆（UI 再截斷單行）。
    let lastResponse: String
    /// 該 session 全部輪次（依 ts 升冪）。
    let turns: [RizoHistoryItem]

    /// 攤平的跨 session turn 清單 → 依 session 分組的對話摘要清單。
    /// - 同 session 內 turns 依 ts 升冪。
    /// - session 之間依最晚 ts 降冪（最新在上）。
    /// - ISO8601 UTC 字串等長同格式，字典序即時間序。nil ts 視為 ""。
    static func group(from items: [RizoHistoryItem]) -> [RizoConversationSummary] {
        var order: [String] = []
        var buckets: [String: [RizoHistoryItem]] = [:]
        for item in items {
            if buckets[item.sessionId] == nil {
                buckets[item.sessionId] = []
                order.append(item.sessionId)
            }
            buckets[item.sessionId]?.append(item)
        }

        let summaries: [RizoConversationSummary] = order.compactMap { sid in
            // 不變式:order 內每個 sid 建立 bucket 當下即 append 一筆,故此處不可能 nil/空;保留為防禦。
            guard let raw = buckets[sid], !raw.isEmpty else { return nil }
            let sorted = raw.sorted { ($0.ts ?? "") < ($1.ts ?? "") }
            let scenario = sorted.first(where: { !$0.scenario.isEmpty })?.scenario ?? ""
            let titleSeed = sorted
                .first(where: { !$0.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                .map { String($0.userInput.trimmingCharacters(in: .whitespacesAndNewlines).prefix(titleSeedMaxLength)) }
            let lastResponse = sorted
                .last(where: { !$0.rizoResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                .map { $0.rizoResponse.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
            return RizoConversationSummary(
                sessionId: sid,
                scenario: scenario,
                startedAt: sorted.first?.ts,
                updatedAt: sorted.last?.ts,
                turnCount: sorted.count,
                titleSeed: titleSeed,
                lastResponse: lastResponse,
                turns: sorted
            )
        }

        return summaries.sorted { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") }
    }
}
