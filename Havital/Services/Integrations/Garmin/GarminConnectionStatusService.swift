import Foundation

/// Garmin 連線狀態檢查服務
/// Uses APICallHelper for unified error handling
class GarminConnectionStatusService {
    static let shared = GarminConnectionStatusService()

    // MARK: - Dependencies

    private let apiHelper: APICallHelper

    private init(httpClient: HTTPClient = DefaultHTTPClient.shared,
                 parser: APIParser = DefaultAPIParser.shared) {
        self.apiHelper = APICallHelper(
            httpClient: httpClient,
            parser: parser,
            moduleName: "GarminConnectionStatus"
        )
    }

    /// 檢查 Garmin 連線狀態
    /// - Returns: 連線狀態回應
    func checkConnectionStatus() async throws -> GarminConnectionStatusResponse {
        return try await apiHelper.get(
            GarminConnectionStatusResponse.self,
            path: "/connect/garmin/status"
        )
    }
}

// MARK: - Response Models

struct GarminConnectionStatusResponse: Codable {
    let connected: Bool
    let provider: String
    let status: String
    let connectedAt: String?
    let lastUpdated: String?
    let message: String

    // MARK: - 歷史資料權限（T-0438）
    //
    // 後端一律附這三個（`SPEC-provider-connection-lifecycle` §8a 契約邊界）。
    // 全部 optional：舊版後端沒有這些欄位，缺席時的語意是「不知道」＝不提示。

    /// `granted` / `missing` / `unknown`。**事實**，analytics 的 hasHistory 用它。
    let historicalPermission: String?
    /// 最後一次向 Garmin 問權限的時間。
    let historicalPermissionCheckedAt: String?
    /// **判斷**：現在要不要畫「缺歷史資料權限」提示卡。
    /// 後端已經把「權限 missing ＋ 連線 ≤7 天 ＋ 沒成功拿過歷史」三件事判完，
    /// App 只認這一個布林，**不得自己從 `historicalPermission` 推**（會漏掉另外兩個條件）。
    let historyPromptEligible: Bool?

    enum CodingKeys: String, CodingKey {
        case connected, provider, status, message
        case connectedAt = "connected_at"
        case lastUpdated = "last_updated"
        case historicalPermission = "historical_permission"
        case historicalPermissionCheckedAt = "historical_permission_checked_at"
        case historyPromptEligible = "history_prompt_eligible"
    }

    /// Garmin 確認給了歷史資料權限。**只有明確的 `granted` 算數**——`unknown` 是我們沒問到，
    /// 不能當成有（analytics 會因此高估，那正是這次要修的謊）。
    var hasHistoricalPermission: Bool {
        historicalPermission == "granted"
    }

    /// 要不要畫提示卡。欄位缺席或 false 一律不畫（不得誤報，2026-09-05 裁決）。
    var shouldPromptForHistoryPermission: Bool {
        historyPromptEligible == true
    }
    
    /// 檢查連線是否為活躍狀態
    var isActive: Bool {
        // 如果 status 為 "active"，就認為連接是活躍的
        // 不依賴 connected 欄位，因為後端可能沒有正確設置該欄位
        return status == "active"
    }
}