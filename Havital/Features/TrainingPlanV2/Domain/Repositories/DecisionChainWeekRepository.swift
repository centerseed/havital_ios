import Foundation

/// 下週規劃清單的資料存取（窄協定，便於 ViewModel 依賴與測試）。
/// 由 `TrainingPlanV2RepositoryImpl` conform，走的是同一個
/// `TrainingPlanV2RemoteDataSource` 與同一顆 HTTP client——**不另開 network 層**
/// （T-0383 Contract 第 7 條）。窄協定的形狀沿用同檔案旁的
/// `StrengthCompletionRepository`。
///
/// **這一組全部不進本地快取。** 清單上的答案是使用者剛剛按下去的事實，
/// 讀到一份舊的等於把他的選擇丟掉；`TrainingPlanV2LocalDataSource` 的 SWR
/// 策略服務的是課表與 status 那種可以晚一輪的資料。
protocol DecisionChainWeekRepository {

    /// `POST /v2/decision-chain/week/{asOf}/run?week_of_training={week}`。
    /// 真 LLM，數十秒（dev 2026-09-03 實測 43.7s）。`generated`／`already_exists` 都是成功。
    func runDecisionChainWeek(asOf: String, weekOfTraining: Int) async throws -> DecisionChainWeekRun

    /// `GET /v2/decision-chain/week/{asOf}/checklist`。
    /// - Returns: 那一週的清單；**那一週還沒 run 過（404）回 `nil`**——呼叫端據此 fail-open。
    func fetchDecisionChainChecklist(asOf: String) async throws -> DecisionChainChecklist?

    /// `POST /v2/decision-chain/week/{asOf}/checklist/{itemId}`。
    /// - Returns: 表態後的那一條（UI 以它為準，不以本地的樂觀值為準）。
    func recordDecisionChainChecklistStance(
        asOf: String,
        itemId: String,
        status: DecisionChainChecklistItem.Status,
        adjustedValue: DecisionChainValue?
    ) async throws -> DecisionChainChecklistItem

    /// `GET /v2/decision-chain/intent/active`。
    /// - Returns: 清單頂端的唯讀說明；帳本上沒有意圖（`data: null`）回 `nil`。
    func fetchDecisionChainIntentCard() async throws -> DecisionChainIntentCard?
}
