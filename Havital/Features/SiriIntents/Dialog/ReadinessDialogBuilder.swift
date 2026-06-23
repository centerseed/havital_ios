import Foundation

// MARK: - ReadinessDialogBuilder

/// 把訓練準備度回應轉成 Siri 念出的口語句子。
/// 純函式，無副作用，無 I/O，可單元測試。
enum ReadinessDialogBuilder {

    /// - Parameter r: `TrainingReadinessResponse`（來自 `GET /plan/readiness/{date}`）
    /// - Returns: zh-TW 口語句子，供 Siri 朗讀
    static func build(from r: TrainingReadinessResponse) -> String {
        switch (r.overallScore, r.overallStatusText) {
        case let (score?, statusText?):
            return String(format: NSLocalizedString("siri.readiness.score_status", comment: ""), Int(score.rounded()), statusText)
        case let (score?, nil):
            return String(format: NSLocalizedString("siri.readiness.score", comment: ""), Int(score.rounded()))
        case let (nil, statusText?):
            return String(format: NSLocalizedString("siri.readiness.no_data_status", comment: ""), statusText)
        case (nil, nil):
            return NSLocalizedString("siri.readiness.no_data", comment: "")
        }
    }
}
