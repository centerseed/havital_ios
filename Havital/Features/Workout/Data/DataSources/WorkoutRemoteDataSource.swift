import Foundation

// MARK: - Workout Remote Data Source
/// 負責從遠端 API 獲取 Workout 數據
/// Data Layer - Remote Data Source
class WorkoutRemoteDataSource {

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
        // 構建查詢參數
        var queryItems: [URLQueryItem] = []
        if let pageSize = pageSize {
            queryItems.append(URLQueryItem(name: "page_size", value: "\(pageSize)"))
        }
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        let path = URLBuilderHelper.buildPath("/v2/workouts", queryItems: queryItems)

        Logger.debug("[WorkoutRemoteDataSource] fetchWorkouts - path: \(path)")

        let rawData = try await httpClient.request(path: path, method: .GET, body: nil)
        let response = try ResponseProcessor.extractData(WorkoutListResponse.self, from: rawData, using: parser)

        return response.workouts
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

        let rawData = try await httpClient.request(path: path, method: .GET, body: nil)
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

        let rawData = try await httpClient.request(path: path, method: .GET, body: nil)
        let response = try ResponseProcessor.extractData(WorkoutV2Detail.self, from: rawData, using: parser)

        return response
    }

    // MARK: - Upload & Sync

    /// 上傳訓練數據
    /// - Parameter request: 上傳請求數據
    /// - Returns: 上傳響應
    func uploadWorkout(_ request: UploadWorkoutRequest) async throws -> UploadWorkoutResponse {
        let path = "/v2/workouts/upload"

        Logger.debug("[WorkoutRemoteDataSource] uploadWorkout - provider: \(request.sourceInfo.name)")

        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(request)

        let rawData = try await httpClient.request(path: path, method: .POST, body: bodyData)
        let response = try ResponseProcessor.extractData(UploadWorkoutResponse.self, from: rawData, using: parser)

        return response
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
        _ = try await httpClient.request(path: path, method: .PATCH, body: bodyData)
    }

    // MARK: - Delete

    /// 刪除訓練記錄
    /// - Parameter id: 訓練 ID
    func deleteWorkout(id: String) async throws {
        let path = "/v2/workouts/\(id)"

        Logger.debug("[WorkoutRemoteDataSource] deleteWorkout - id: \(id)")

        _ = try await httpClient.request(path: path, method: .DELETE, body: nil)
    }

    // MARK: - Stats

    /// 獲取訓練統計數據
    /// - Parameter days: 統計天數
    /// - Returns: 統計響應
    func fetchWorkoutStats(days: Int = 30) async throws -> WorkoutStatsResponse {
        let path = "/v2/workouts/stats?days=\(days)"

        Logger.debug("[WorkoutRemoteDataSource] fetchWorkoutStats - days: \(days)")

        let rawData = try await httpClient.request(path: path, method: .GET, body: nil)
        let response = try ResponseProcessor.extractData(WorkoutStatsResponse.self, from: rawData, using: parser)

        return response
    }

}
