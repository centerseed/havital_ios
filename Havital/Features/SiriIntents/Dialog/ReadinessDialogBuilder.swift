import Foundation

// MARK: - ReadinessDialogBuilder

/// 把訓練準備度回應轉成 Siri 念出的口語句子。
/// 純函式，無副作用，無 I/O，可單元測試。
enum ReadinessDialogBuilder {

    /// - Parameter r: `TrainingReadinessResponse`（來自 `GET /plan/readiness/{date}`）
    /// - Returns: zh-TW 口語句子，供 Siri 朗讀
    static func build(from r: TrainingReadinessResponse) -> String {
        // TODO(i18n): localize before non-zh-TW rollout
        switch (r.overallScore, r.overallStatusText) {
        case let (score?, statusText?):
            return "你今天的訓練準備度是 \(Int(score.rounded())) 分，\(statusText)。"
        case let (score?, nil):
            return "你今天的訓練準備度是 \(Int(score.rounded())) 分。"
        case let (nil, statusText?):
            return "你今天的訓練準備度資料尚未取得，\(statusText)。"
        case (nil, nil):
            return "你今天的訓練準備度資料尚未取得。"
        }
    }
}
