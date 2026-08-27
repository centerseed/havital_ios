import Foundation

// MARK: - Treadmill Correction Request Body

/// POST /v2/workouts/{id}/treadmill-correction 的請求 body
private struct TreadmillCorrectionRequest: Encodable {
    let actualDistanceM: Double
    let avgInclinePercent: Double?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case actualDistanceM = "actual_distance_m"
        case avgInclinePercent = "avg_incline_percent"
        case notes
    }
}

// MARK: - Trim Request Body

/// POST /v2/workouts/{id}/trim 的請求 body。
/// keep_start_s / keep_end_s 以「原始 start_time」為基準的秒數。
private struct TrimRequest: Encodable {
    let keepStartS: Double
    let keepEndS: Double

    enum CodingKeys: String, CodingKey {
        case keepStartS = "keep_start_s"
        case keepEndS = "keep_end_s"
    }
}

// MARK: - Workout Remote Data Source
/// 負責從遠端 API 獲取 Workout 數據
/// Data Layer - Remote Data Source
// MARK: - WorkoutStatsDataSourceProtocol
/// 紀錄頁需要的兩條讀取（滾動視窗統計 ＋ 最近訓練清單）。
///
/// 為什麼是「加 protocol」而不是「走 `WorkoutRepository`」：`WorkoutRepository`
/// 沒有 stats 這條語意（它管的是 workout 清單與快取），把 stats 塞進去等於擴張它的
/// 職責；而 ViewModel 直接依賴具體 class 又違反 `.claude/rules/architecture.md`
/// 的「ViewModel depends on repository protocols, never concrete implementations」。
/// 所以在 Data 層對既有實作補一個窄介面 —— **沒有第二份實作**，只是把依賴方向立起來。
protocol WorkoutStatsDataSourceProtocol {
    func fetchWorkoutStats(days: Int, weeks: Int?) async throws -> WorkoutStatsResponse
    func fetchRecentWorkouts(pageSize: Int) async throws -> [WorkoutV2]
    /// 帶游標的分頁（`cursor` nil ＝ 最新一頁）—— 紀錄頁捲到底往更舊載入用。
    func fetchWorkoutsPage(pageSize: Int?, cursor: String?) async throws -> WorkoutListResponse
}

class WorkoutRemoteDataSource: WorkoutStatsDataSourceProtocol {

    // MARK: - Properties

    private let httpClient: any HTTPClient
    private let parser: any APIParser

    // MARK: - Initialization

    init(httpClient: any HTTPClient = DefaultHTTPClient.shared,
         parser: any APIParser = DefaultAPIParser.shared) {
        self.httpClient = httpClient
        self.parser = parser
    }

    // MARK: - Workout List

    /// 獲取訓練列表
    /// - Parameters:
    ///   - pageSize: 每頁數量
    ///   - cursor: 分頁游標
    /// - Returns: 訓練列表
    func fetchWorkouts(pageSize: Int?, cursor: String?) async throws -> [WorkoutV2] {
        try await fetchWorkoutsPage(pageSize: pageSize, cursor: cursor).workouts
    }

    /// 獲取訓練列表「整頁」回應（含後端真實分頁資訊 has_more / next_cursor）。
    /// 與 fetchWorkouts 不同：保留 pagination，供雙軌緩存把分頁狀態一併存起來。
    func fetchWorkoutsPage(pageSize: Int?, cursor: String?) async throws -> WorkoutListResponse {
        // 構建查詢參數
        var queryItems: [URLQueryItem] = []
        if let pageSize = pageSize {
            queryItems.append(URLQueryItem(name: "page_size", value: "\(pageSize)"))
        }
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        let path = URLBuilderHelper.buildPath("/v2/workouts", queryItems: queryItems)

        Logger.debug("[WorkoutRemoteDataSource] fetchWorkoutsPage - path: \(path)")

        let rawData = try await tracked("WorkoutRemoteDataSource: fetchWorkoutsPage") {
            try await httpClient.request(path: path, method: .GET, body: nil)
        }
        return try ResponseProcessor.extractData(WorkoutListResponse.self, from: rawData, using: parser)
    }

    /// 獲取最近的訓練記錄
    /// - Parameter pageSize: 每頁數量
    /// - Returns: 訓練列表
    func fetchRecentWorkouts(pageSize: Int = 20) async throws -> [WorkoutV2] {
        return try await fetchWorkouts(pageSize: pageSize, cursor: nil)
    }

    // MARK: - Single Workout

    /// 獲取單個訓練詳情
    /// - Parameter id: 訓練 ID
    /// - Returns: 訓練詳情
    func fetchWorkout(id: String) async throws -> WorkoutV2 {
        let path = "/v2/workouts/\(id)"

        Logger.debug("[WorkoutRemoteDataSource] fetchWorkout - id: \(id)")

        let rawData = try await tracked("WorkoutRemoteDataSource: fetchWorkout") {
            try await httpClient.request(path: path, method: .GET, body: nil)
        }
        let response = try ResponseProcessor.extractData(WorkoutDetailResponse.self, from: rawData, using: parser)

        // 使用 WorkoutMapper 進行轉換
        return WorkoutMapper.toWorkoutV2(from: response)
    }

    /// 獲取完整訓練詳情（包含時間序列數據）
    /// - Parameter id: 訓練 ID
    /// - Returns: 完整的訓練詳情
    func fetchWorkoutDetail(id: String) async throws -> WorkoutV2Detail {
        let path = "/v2/workouts/\(id)"

        Logger.debug("[WorkoutRemoteDataSource] fetchWorkoutDetail - id: \(id)")

        let rawData = try await tracked("WorkoutRemoteDataSource: fetchWorkoutDetail") {
            try await httpClient.request(path: path, method: .GET, body: nil)
        }
        let response = try ResponseProcessor.extractData(WorkoutV2Detail.self, from: rawData, using: parser)

        return response
    }

    // MARK: - Upload & Sync

    /// 上傳訓練數據
    /// - Parameter request: 上傳請求數據
    /// - Returns: 上傳響應
    func uploadWorkout(_ request: UploadWorkoutRequest) async throws -> UploadWorkoutResponse {
        let path = "/v2/workouts"

        Logger.debug("[WorkoutRemoteDataSource] uploadWorkout - provider: \(request.sourceInfo.name)")

        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(request)

        let rawData = try await tracked("WorkoutRemoteDataSource: uploadWorkout") {
            try await httpClient.request(path: path, method: .POST, body: bodyData)
        }
        let response = try ResponseProcessor.extractData(UploadWorkoutResponse.self, from: rawData, using: parser)

        return response
    }

    func uploadWorkout(_ workoutData: WorkoutData) async throws {
        let path = "/v2/workouts"

        Logger.debug("[WorkoutRemoteDataSource] uploadAppleHealthWorkout - source: \(workoutData.source ?? "unknown")")

        let bodyData = try JSONEncoder().encode(workoutData)
        _ = try await tracked("WorkoutRemoteDataSource: uploadWorkoutData") {
            try await httpClient.request(path: path, method: .POST, body: bodyData)
        }
    }

    func fetchWorkoutSummary(id: String) async throws -> WorkoutSummary {
        let summaryPathPrefix = "/workout/summary/"
        let path = "\(summaryPathPrefix)\(id)"

        Logger.debug("[WorkoutRemoteDataSource] fetchWorkoutSummary - id: \(id)")

        let rawData = try await tracked("WorkoutRemoteDataSource: fetchWorkoutSummary") {
            try await httpClient.request(path: path, method: .GET, body: nil)
        }
        let response = try ResponseProcessor.extractData(WorkoutSummaryResponse.self, from: rawData, using: parser)
        return response.data.workout
    }

    // MARK: - Treadmill Correction

    /// 套用跑步機里程校正
    /// - Parameters:
    ///   - id: 訓練 ID
    ///   - actualDistanceM: 實際距離（公尺），合法範圍 100..100000
    ///   - avgInclinePercent: 平均坡度（%），optional，合法範圍 -10..25
    ///   - notes: 備註，optional，最多 500 字
    /// - Returns: 更新後的 WorkoutV2Detail（含 correction 欄位）
    func applyTreadmillCorrection(
        id: String,
        actualDistanceM: Double,
        avgInclinePercent: Double?,
        notes: String?
    ) async throws -> WorkoutV2Detail {
        let path = "/v2/workouts/\(id)/treadmill-correction"

        Logger.debug("[WorkoutRemoteDataSource] applyTreadmillCorrection - id: \(id)")

        let request = TreadmillCorrectionRequest(
            actualDistanceM: actualDistanceM,
            avgInclinePercent: avgInclinePercent,
            notes: notes
        )
        let bodyData = try JSONEncoder().encode(request)

        let rawData = try await tracked("WorkoutRemoteDataSource: applyTreadmillCorrection") {
            try await self.httpClient.request(path: path, method: .POST, body: bodyData)
        }
        return try ResponseProcessor.extractData(WorkoutV2Detail.self, from: rawData, using: parser)
    }

    // MARK: - Trim

    /// 套用運動紀錄裁剪
    /// - Parameters:
    ///   - id: 訓練 ID
    ///   - keepStartS: 保留起點（相對原始 start_time 的秒數，>= 0）
    ///   - keepEndS: 保留終點（相對原始 start_time 的秒數，> keepStartS；後端要求保留時長 >= 60s）
    /// - Returns: 裁剪後的 WorkoutV2Detail（含 edits 欄位）
    func applyTrim(
        id: String,
        keepStartS: Double,
        keepEndS: Double
    ) async throws -> WorkoutV2Detail {
        let path = "/v2/workouts/\(id)/trim"

        Logger.debug("[WorkoutRemoteDataSource] applyTrim - id: \(id)")

        let request = TrimRequest(keepStartS: keepStartS, keepEndS: keepEndS)
        let bodyData = try JSONEncoder().encode(request)

        let rawData = try await tracked("WorkoutRemoteDataSource: applyTrim") {
            try await self.httpClient.request(path: path, method: .POST, body: bodyData)
        }
        return try ResponseProcessor.extractData(WorkoutV2Detail.self, from: rawData, using: parser)
    }

    // MARK: - Update

    /// 更新訓練數據
    /// - Parameters:
    ///   - id: 訓練 ID
    ///   - body: 更新內容
    func updateWorkout(id: String, body: [String: Any]) async throws {
        let path = "/v2/workouts/\(id)"
        Logger.debug("[WorkoutRemoteDataSource] updateWorkout - id: \(id)")

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        _ = try await tracked("WorkoutRemoteDataSource: updateWorkout") {
            try await httpClient.request(path: path, method: .PATCH, body: bodyData)
        }
    }

    // MARK: - Delete

    /// 刪除訓練記錄
    /// - Parameter id: 訓練 ID
    func deleteWorkout(id: String) async throws {
        let path = "/v2/workouts/\(id)"

        Logger.debug("[WorkoutRemoteDataSource] deleteWorkout - id: \(id)")

        _ = try await tracked("WorkoutRemoteDataSource: deleteWorkout") {
            try await httpClient.request(path: path, method: .DELETE, body: nil)
        }
    }

    // MARK: - Stats

    /// 獲取訓練統計數據
    /// - Parameters:
    ///   - days: 滾動視窗天數
    ///   - weeks: 週跑量序列的週數（T-0304；後端預設 8，1…MAX_STATS_WEEKS）
    /// - Returns: 統計響應
    func fetchWorkoutStats(days: Int = 30, weeks: Int? = nil) async throws -> WorkoutStatsResponse {
        var path = "/v2/workouts/stats?days=\(days)"
        if let weeks {
            path += "&weeks=\(weeks)"
        }

        Logger.debug("[WorkoutRemoteDataSource] fetchWorkoutStats - days: \(days), weeks: \(weeks.map(String.init) ?? "default")")

        let rawData = try await tracked("WorkoutRemoteDataSource: fetchWorkoutStats") {
            try await httpClient.request(path: path, method: .GET, body: nil)
        }
        // Envelope is `{success, data: <stats fields>}` (`success_response(data=stats)`).
        // `WorkoutStatsResponse` itself is `{data: WorkoutStatsData}`; extracting that
        // type double-wraps, so Codable looks for `data.data` and reports missingKey
        // `data` even though the payload is valid (prod 2026-08-27, founder UID).
        let stats = try ResponseProcessor.extractData(WorkoutStatsData.self, from: rawData, using: parser)
        return WorkoutStatsResponse(data: stats)
    }

}
