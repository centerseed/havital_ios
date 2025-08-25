import Foundation
import HealthKit

// MARK: - Workout V2 Error Types

enum WorkoutV2Error: LocalizedError {
    case decodingFailed(String)
    case networkError(String)
    case invalidResponse(String)
    
    var errorDescription: String? {
        switch self {
        case .decodingFailed(let details):
            return "JSON 解析失敗: \(details)"
        case .networkError(let details):
            return "網路錯誤: \(details)"
        case .invalidResponse(let details):
            return "回應無效: \(details)"
        }
    }
}

// MARK: - Error Details Structure

struct DecodingErrorDetail {
    let description: String
    let missingField: String?
    let codingPath: String
    let debugDescription: String
}

// MARK: - Workout V2 Service
class WorkoutV2Service {
    static let shared = WorkoutV2Service()
    
    // MARK: - New Architecture Dependencies
    private let httpClient: any HTTPClient
    private let parser: any APIParser
    
    private init(httpClient: any HTTPClient = DefaultHTTPClient.shared,
                 parser: any APIParser = DefaultAPIParser.shared) {
        self.httpClient = httpClient
        self.parser = parser
    }
    
    // MARK: - Unified API Call Method
    
    /// 統一的 API 調用方法，保留詳細錯誤分析
    private func makeAPICall<T: Codable>(
        _ type: T.Type,
        path: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        operationName: String
    ) async throws -> T {
        // 增強日誌：記錄 API 調用詳情
        Logger.debug("[WorkoutV2Service] \(operationName) - 調用 API: \(method.rawValue) \(path)")
        Logger.debug("[WorkoutV2Service] \(operationName) - 預期解析類型: \(String(describing: type))")
        
        do {
            let rawData = try await httpClient.request(path: path, method: method, body: body)
            Logger.debug("[WorkoutV2Service] \(operationName) - 收到響應，數據大小: \(rawData.count) bytes")
            
            // 先嘗試使用統一解析器
            do {
                let result = try ResponseProcessor.extractData(type, from: rawData, using: parser)
                Logger.debug("[WorkoutV2Service] \(operationName) - 成功解析響應")
                return result
            } catch {
                // 如果統一解析失敗，使用原有的詳細錯誤分析
                Logger.error("[WorkoutV2Service] \(operationName) - 統一解析器失敗: \(error.localizedDescription)")
                throw error
            }
            
        } catch let decodingError as DecodingError {
            // 保留原有的詳細解析錯誤處理邏輯
            let errorDetail = getDecodingErrorDetail(decodingError)
            logDetailedDecodingError(errorDetail, operationName: operationName, type: type)
            
            throw WorkoutV2Error.decodingFailed(errorDetail.description)
            
        } catch let apiError as APIError where apiError.isCancelled {
            Logger.debug("\(operationName) 任務被取消，忽略錯誤")
            throw SystemError.taskCancelled
        } catch {
            Logger.firebase(
                "\(operationName) 請求失敗",
                level: .error,
                labels: [
                    "module": "WorkoutV2Service",
                    "action": operationName.lowercased().replacingOccurrences(of: " ", with: "_"),
                    "error_type": "general_error"
                ],
                jsonPayload: [
                    "error_description": error.localizedDescription,
                    "error_type": String(describing: Swift.type(of: error))
                ]
            )
            throw error
        }
    }
    
    // MARK: - Error Handling Helpers
    
    /// 記錄詳細的解碼錯誤信息
    private func logDetailedDecodingError<T>(_ errorDetail: DecodingErrorDetail, operationName: String, type: T.Type) {
        // 輸出詳細錯誤信息到 console 以便 debug
        print("🚨 [WorkoutV2Service] \(operationName) JSON 解析失敗")
        print("🔍 錯誤詳情:")
        print("  - 字段: \(errorDetail.missingField ?? "unknown")")
        print("  - 路徑: \(errorDetail.codingPath)")
        print("  - 描述: \(errorDetail.description)")
        print("  - Debug: \(errorDetail.debugDescription)")
        
        Logger.firebase(
            "\(operationName) JSON 解析失敗",
            level: .error,
            labels: [
                "module": "WorkoutV2Service",
                "action": operationName.lowercased().replacingOccurrences(of: " ", with: "_"),
                "error_type": "decoding_error"
            ],
            jsonPayload: [
                "error_description": errorDetail.description,
                "missing_field": errorDetail.missingField ?? "unknown",
                "coding_path": errorDetail.codingPath,
                "debug_description": errorDetail.debugDescription,
                "expected_type": String(describing: type)
            ]
        )
    }
    
    /// 解析 DecodingError 的詳細信息
    private func getDecodingErrorDetail(_ error: DecodingError) -> DecodingErrorDetail {
        switch error {
        case .keyNotFound(let key, let context):
            return DecodingErrorDetail(
                description: "缺少必要字段: \(key.stringValue)",
                missingField: key.stringValue,
                codingPath: context.codingPath.map { $0.stringValue }.joined(separator: "."),
                debugDescription: context.debugDescription
            )
            
        case .valueNotFound(let type, let context):
            return DecodingErrorDetail(
                description: "字段值為空: 期望 \(type) 類型",
                missingField: context.codingPath.last?.stringValue,
                codingPath: context.codingPath.map { $0.stringValue }.joined(separator: "."),
                debugDescription: context.debugDescription
            )
            
        case .typeMismatch(let type, let context):
            return DecodingErrorDetail(
                description: "字段類型不匹配: 期望 \(type) 類型",
                missingField: context.codingPath.last?.stringValue,
                codingPath: context.codingPath.map { $0.stringValue }.joined(separator: "."),
                debugDescription: context.debugDescription
            )
            
        case .dataCorrupted(let context):
            return DecodingErrorDetail(
                description: "數據損壞或格式錯誤",
                missingField: context.codingPath.last?.stringValue,
                codingPath: context.codingPath.map { $0.stringValue }.joined(separator: "."),
                debugDescription: context.debugDescription
            )
            
        @unknown default:
            return DecodingErrorDetail(
                description: "未知的解析錯誤",
                missingField: nil,
                codingPath: "",
                debugDescription: error.localizedDescription
            )
        }
    }
    
    // MARK: - Fetch Workouts
    
    /// 獲取運動列表（支援雙向分頁）
    /// - Parameters:
    ///   - pageSize: 每頁數量，預設 20，範圍 1-100
    ///   - cursor: 分頁游標（向後相容，等同於 afterCursor）
    ///   - beforeCursor: 取得指定 cursor 之前（更新）的資料
    ///   - afterCursor: 取得指定 cursor 之後（更舊）的資料
    ///   - direction: 查詢方向：newer 或 older，預設 older
    ///   - startDate: 開始日期 (ISO 8601 格式)
    ///   - endDate: 結束日期 (ISO 8601 格式)
    ///   - activityType: 運動類型篩選
    ///   - provider: 數據來源篩選 (garmin 或 apple_health)
    /// - Returns: 運動列表回應
    func fetchWorkouts(
        pageSize: Int = 20,
        cursor: String? = nil,
        beforeCursor: String? = nil,
        afterCursor: String? = nil,
        direction: String = "older",
        startDate: String? = nil,
        endDate: String? = nil,
        activityType: String? = nil,
        provider: String? = nil
    ) async throws -> WorkoutListResponse {
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]
        
        // 處理分頁游標 - 向後相容性
        if let beforeCursor = beforeCursor {
            queryItems.append(URLQueryItem(name: "before_cursor", value: beforeCursor))
        } else if let afterCursor = afterCursor {
            queryItems.append(URLQueryItem(name: "after_cursor", value: afterCursor))
        } else if let cursor = cursor {
            // 向後相容：cursor 等同於 after_cursor
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        
        // 查詢方向
        if direction != "older" {
            queryItems.append(URLQueryItem(name: "direction", value: direction))
        }
        
        // 日期篩選
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "start_date", value: startDate))
        }
        
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "end_date", value: endDate))
        }
        
        // 類型篩選
        if let activityType = activityType {
            queryItems.append(URLQueryItem(name: "activity_type", value: activityType))
        }
        
        if let provider = provider {
            queryItems.append(URLQueryItem(name: "provider", value: provider))
        }
        
        var components = URLComponents()
        components.path = "/v2/workouts"
        components.queryItems = queryItems
        
        do {
            Logger.firebase(
                "🔍 嘗試解碼 Workout V2 API 回應",
                level: .debug,
                labels: ["module": "WorkoutV2Service", "action": "fetch_workouts_debug"],
                jsonPayload: [
                    "request_path": components.url?.absoluteString ?? "/v2/workouts",
                    "expected_structure": "APIResponse<WorkoutListResponse>"
                ]
            )
            
            let response: WorkoutListResponse = try await makeAPICall(
                WorkoutListResponse.self,
                path: components.url?.absoluteString ?? "/v2/workouts",
                method: .GET,
                operationName: "Workout V2 列表獲取"
            )
            
            Logger.firebase(
                "Workout V2 列表獲取成功",
                level: .info,
                labels: [
                    "module": "WorkoutV2Service",
                    "action": "fetch_workouts"
                ],
                            jsonPayload: [
                "workouts_count": response.workouts.count,
                "has_more": response.pagination.hasMore,
                "provider_filter": provider ?? "all",
                "activity_type_filter": activityType ?? "all"
            ]
            )
            
            return response
            
        } catch {
            
            // 檢查是否為取消錯誤（App 進入背景或任務取消）
            if error is CancellationError || (error as NSError).code == NSURLErrorCancelled {
                print("[WorkoutV2Service] 請求被取消（App 進入背景或任務取消）")
                throw error  // 直接拋出，不記錄為錯誤
            }
            
            Logger.firebase(
                "Workout V2 請求失敗",
                level: .error,
                labels: [
                    "module": "WorkoutV2Service",
                    "action": "fetch_workouts",
                    "error_type": "general_error"
                ],
                jsonPayload: [
                    "error_description": error.localizedDescription,
                    "error_type": String(describing: type(of: error)),
                    "page_size": pageSize,
                    "provider_filter": provider ?? "all",
                    "activity_type_filter": activityType ?? "all"
                ]
            )
            
            throw error
        }
    }
    
    /// 獲取運動詳細資料
    /// - Parameter workoutId: 運動 ID
    /// - Returns: 運動詳細資料回應
    func fetchWorkoutDetail(workoutId: String) async throws -> WorkoutDetailResponse {
        
        do {
            let response: WorkoutDetailResponse = try await makeAPICall(
                WorkoutDetailResponse.self,
                path: "/v2/workouts/\(workoutId)",
                method: .GET,
                operationName: "Workout V2 詳情獲取"
            )
            
            Logger.firebase(
                "Workout V2 詳情獲取成功",
                level: .info,
                labels: [
                    "module": "WorkoutV2Service",
                    "action": "fetch_workout_detail"
                ],
                            jsonPayload: [
                "workout_id": workoutId,
                "activity_type": response.activityType,
                "duration_seconds": Int(response.duration)
            ]
            )
            
            return response
            
        } catch {
            
            // 檢查是否為取消錯誤（App 進入背景或任務取消）
            if error is CancellationError || (error as NSError).code == NSURLErrorCancelled {
                print("[WorkoutV2Service] 詳情請求被取消（App 進入背景或任務取消）")
                throw error  // 直接拋出，不記錄為錯誤
            }
            
            Logger.firebase(
                "Workout V2 詳情請求失敗",
                level: .error,
                labels: [
                    "module": "WorkoutV2Service",
                    "action": "fetch_workout_detail",
                    "error_type": "general_error"
                ],
                jsonPayload: [
                    "workout_id": workoutId,
                    "error_description": error.localizedDescription,
                    "error_type": String(describing: type(of: error))
                ]
            )
            
            throw error
        }
    }
    
    /// 獲取運動統計數據
    /// - Parameter days: 統計天數，預設 30 天
    /// - Returns: 運動統計回應
    func fetchWorkoutStats(days: Int = 30) async throws -> WorkoutStatsResponse {
        let response: WorkoutStatsResponse = try await makeAPICall(
            WorkoutStatsResponse.self,
            path: "/v2/workouts/stats?days=\(days)",
            method: .GET,
            operationName: "Workout V2 統計獲取"
        )
        
        Logger.firebase(
            "Workout V2 統計獲取成功",
            level: .info,
            labels: [
                "module": "WorkoutV2Service",
                "action": "fetch_stats"
            ],
            jsonPayload: [
                "period_days": days,
                "total_workouts": response.data.totalWorkouts,
                "total_distance_km": response.data.totalDistanceKm,
                "provider_distribution": response.data.providerDistribution
            ]
        )
        
        return response
    }
    

}

// MARK: - Convenience Methods

extension WorkoutV2Service {
    
    /// 獲取最近的運動記錄
    /// - Parameter limit: 數量限制
    /// - Returns: 運動列表
    func fetchRecentWorkouts(limit: Int = 20) async throws -> [WorkoutV2] {
        let response = try await fetchWorkouts(pageSize: limit)
        return response.workouts
    }
    
    /// 獲取特定類型的運動記錄
    /// - Parameters:
    ///   - activityType: 運動類型
    ///   - limit: 數量限制
    /// - Returns: 運動列表
    func fetchWorkoutsByType(_ activityType: String, limit: Int = 20) async throws -> [WorkoutV2] {
        let response = try await fetchWorkouts(pageSize: limit, activityType: activityType)
        return response.workouts
    }
    
    /// 獲取特定數據來源的運動記錄
    /// - Parameters:
    ///   - provider: 數據來源
    ///   - limit: 數量限制
    /// - Returns: 運動列表
    func fetchWorkoutsByProvider(_ provider: String, limit: Int = 20) async throws -> [WorkoutV2] {
        let response = try await fetchWorkouts(pageSize: limit, provider: provider)
        return response.workouts
    }
    
    /// 獲取日期範圍內的運動記錄
    /// - Parameters:
    ///   - startDate: 開始日期
    ///   - endDate: 結束日期
    ///   - limit: 數量限制
    /// - Returns: 運動列表
    func fetchWorkoutsInDateRange(
        startDate: Date,
        endDate: Date,
        limit: Int = 100
    ) async throws -> [WorkoutV2] {
        
        let iso8601Formatter = ISO8601DateFormatter()
        let startDateString = iso8601Formatter.string(from: startDate)
        let endDateString = iso8601Formatter.string(from: endDate)
        
        let response = try await fetchWorkouts(
            pageSize: limit,
            startDate: startDateString,
            endDate: endDateString
        )
        
        return response.workouts
    }
    
    // MARK: - Pagination Methods
    
    /// 載入更多運動記錄（向下滾動載入更舊資料）
    /// - Parameters:
    ///   - afterCursor: 最舊記錄的 ID，用作分頁游標
    ///   - pageSize: 每頁數量，預設 10
    /// - Returns: 分頁回應，包含運動列表和分頁資訊
    func loadMoreWorkouts(afterCursor: String, pageSize: Int = 10) async throws -> WorkoutListResponse {
        return try await fetchWorkouts(
            pageSize: pageSize,
            afterCursor: afterCursor,
            direction: "older"
        )
    }
    
    /// 刷新最新運動記錄（下拉刷新載入更新資料）
    /// - Parameters:
    ///   - beforeCursor: 最新記錄的 ID，用作分頁游標
    ///   - pageSize: 每頁數量，預設 10
    /// - Returns: 分頁回應，包含運動列表和分頁資訊
    func refreshLatestWorkouts(beforeCursor: String? = nil, pageSize: Int = 10) async throws -> WorkoutListResponse {
        if let beforeCursor = beforeCursor {
            return try await fetchWorkouts(
                pageSize: pageSize,
                beforeCursor: beforeCursor,
                direction: "newer"
            )
        } else {
            // 初次載入，獲取最新資料
            return try await fetchWorkouts(pageSize: pageSize)
        }
    }
    
    /// 初次載入運動記錄
    /// - Parameter pageSize: 每頁數量，預設 10
    /// - Returns: 分頁回應，包含運動列表和分頁資訊
    func loadInitialWorkouts(pageSize: Int = 10) async throws -> WorkoutListResponse {
        return try await fetchWorkouts(pageSize: pageSize)
    }
    
    // MARK: - Garmin Historical Data Processing
    
    /// 觸發 Garmin 歷史數據處理
    /// - Parameter daysBack: 處理天數，預設 30 天
    /// - Returns: 歷史數據處理回應
    func triggerGarminHistoricalDataProcessing(daysBack: Int = 30) async throws -> GarminHistoricalDataResponse {
        let requestBody = GarminHistoricalDataRequest(daysBack: daysBack)
        
        do {
            // 將請求體編碼為 JSON Data
            let bodyData = try JSONEncoder().encode(requestBody)
            
            let response: GarminHistoricalDataResponse = try await makeAPICall(
                GarminHistoricalDataResponse.self,
                path: "/connect/garmin/process-historical-data",
                method: .POST,
                body: bodyData,
                operationName: "Garmin 歷史數據處理觸發"
            )
            
            Logger.firebase(
                "Garmin 歷史數據處理觸發成功",
                level: .info,
                labels: [
                    "module": "WorkoutV2Service",
                    "action": "trigger_garmin_historical_data"
                ],
                jsonPayload: [
                    "days_back": daysBack,
                    "estimated_duration": response.data.estimatedDuration
                ]
            )
            
            return response
            
        } catch {
            Logger.firebase(
                "Garmin 歷史數據處理觸發失敗: \(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "WorkoutV2Service",
                    "action": "trigger_garmin_historical_data"
                ],
                jsonPayload: [
                    "days_back": daysBack
                ]
            )
            throw error
        }
    }
    
    /// 查詢 Garmin 數據處理狀態
    /// - Returns: 處理狀態回應
    func getGarminProcessingStatus() async throws -> GarminProcessingStatusResponse {
        do {
            Logger.firebase(
                "🔍 開始查詢 Garmin 處理狀態",
                level: .debug,
                labels: ["module": "WorkoutV2Service", "action": "get_garmin_processing_status_start"]
            )
            
            let response: GarminProcessingStatusResponse = try await makeAPICall(
                GarminProcessingStatusResponse.self,
                path: "/connect/garmin/processing-status",
                method: .GET,
                operationName: "Garmin 處理狀態查詢"
            )
            
            Logger.firebase(
                "Garmin 處理狀態查詢成功",
                level: .info,
                labels: [
                    "module": "WorkoutV2Service",
                    "action": "get_garmin_processing_status"
                ],
                jsonPayload: [
                    "response_success": response.success,
                    "in_progress": response.data.processingStatus.inProgress,
                    "processed_count": response.data.processingStatus.processedCount ?? 0,
                    "total_count": response.data.processingStatus.totalCount ?? 0,
                    "progress_percentage": response.data.processingStatus.progressPercentage ?? 0.0,
                    "current_item": response.data.processingStatus.currentItem ?? "",
                    "start_time": response.data.processingStatus.startTime ?? "",
                    "recent_results_count": response.data.recentResults.count
                ]
            )
            
            return response
            
        } catch {
            // 錯誤已經在 makeAPICall 中處理，直接拋出
            throw error
        }
    }
    

}

// MARK: - Error Handling

enum WorkoutV2ServiceError: Error, LocalizedError {
    case invalidWorkoutData
    case noHeartRateData
    case uploadFailed(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidWorkoutData:
            return "無效的運動數據"
        case .noHeartRateData:
            return "缺少心率數據"
        case .uploadFailed(let message):
            return "上傳失敗: \(message)"
        case .networkError(let error):
            return "網路錯誤: \(error.localizedDescription)"
        }
    }
}



// MARK: - Garmin Historical Data Models

struct GarminHistoricalDataRequest: Codable {
    let daysBack: Int
    
    enum CodingKeys: String, CodingKey {
        case daysBack = "days_back"
    }
}

struct GarminHistoricalDataResponse: Codable {
    let success: Bool  // 保持一致，使用 "success"
    let data: GarminHistoricalDataData
}

struct GarminHistoricalDataData: Codable {
    let message: String
    let provider: String
    let daysBack: Int
    let estimatedDuration: String
    let statusCheckEndpoint: String
    
    enum CodingKeys: String, CodingKey {
        case message
        case provider
        case daysBack = "days_back"
        case estimatedDuration = "estimated_duration"
        case statusCheckEndpoint = "status_check_endpoint"
    }
}

struct GarminProcessingStatusResponse: Codable {
    let success: Bool  // 實際API使用 "success": true，不是 "status"
    let data: GarminProcessingStatusData
}

struct GarminProcessingStatusData: Codable {
    let processingStatus: GarminProcessingStatus
    let recentResults: [GarminProcessingResult]
    
    enum CodingKeys: String, CodingKey {
        case processingStatus = "processing_status"
        case recentResults = "recent_results"
    }
}

struct GarminProcessingStatus: Codable {
    let inProgress: Bool
    let startTime: String?
    let processedCount: Int?
    let totalCount: Int?
    let progressPercentage: Double?
    let currentItem: String?
    let lastUpdated: String?
    
    enum CodingKeys: String, CodingKey {
        case inProgress = "in_progress"
        case startTime = "start_time"
        case processedCount = "processed_count"
        case totalCount = "total_count"
        case progressPercentage = "progress_percentage"
        case currentItem = "current_item"
        case lastUpdated = "last_updated"
    }
}

struct GarminProcessingResult: Codable {
    let id: String
    let type: String
    let status: String?  // API 中可能為 null
    let createdAt: String
    let summary: GarminProcessingSummary?  // 失敗時可能為 null
    let error: String?  // 錯誤信息
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case status
        case createdAt = "created_at"
        case summary
        case error
    }
}

struct GarminProcessingSummary: Codable {
    let processedCount: Int
    let errorCount: Int
    let totalFiles: Int
    
    enum CodingKeys: String, CodingKey {
        case processedCount = "processed_count"
        case errorCount = "error_count"
        case totalFiles = "total_files"
    }
}

// MARK: - Apple Health Upload Wrappers
extension WorkoutV2Service {
    typealias UploadResult = AppleHealthWorkoutUploadService.UploadResult
    typealias UploadBatchResult = AppleHealthWorkoutUploadService.UploadBatchResult

    // 基本工具
    func makeWorkoutId(for workout: HKWorkout) -> String {
        AppleHealthWorkoutUploadService.shared.makeWorkoutId(for: workout)
    }
    
    // 單筆上傳（僅當資料來源為 Apple Health）
    func uploadWorkout(_ workout: HKWorkout,
                       force: Bool = false,
                       retryHeartRate: Bool = false) async throws -> UploadResult {
        try await AppleHealthWorkoutUploadService.shared.uploadWorkout(workout,
                                                                      force: force,
                                                                      retryHeartRate: retryHeartRate)
    }
    
    // 批次上傳
    func uploadWorkouts(_ workouts: [HKWorkout],
                        force: Bool = false,
                        retryHeartRate: Bool = false) async -> UploadBatchResult {
        await AppleHealthWorkoutUploadService.shared.uploadWorkouts(workouts,
                                                                   force: force,
                                                                   retryHeartRate: retryHeartRate)
    }
    
    // Summary 快取相關
    func getWorkoutSummary(workoutId: String) async throws -> WorkoutSummary {
        try await AppleHealthWorkoutUploadService.shared.getWorkoutSummary(workoutId: workoutId)
    }
    func saveCachedWorkoutSummary(_ summary: WorkoutSummary, for id: String) {
        AppleHealthWorkoutUploadService.shared.saveCachedWorkoutSummary(summary, for: id)
    }
    func getCachedWorkoutSummary(for id: String) -> WorkoutSummary? {
        AppleHealthWorkoutUploadService.shared.getCachedWorkoutSummary(for: id)
    }
    func clearWorkoutSummaryCache() {
        AppleHealthWorkoutUploadService.shared.clearWorkoutSummaryCache()
    }
    
    // Upload tracker helpers
    func isWorkoutUploaded(_ workout: HKWorkout) -> Bool {
        AppleHealthWorkoutUploadService.shared.isWorkoutUploaded(workout)
    }
    func workoutHasHeartRate(_ workout: HKWorkout) -> Bool {
        AppleHealthWorkoutUploadService.shared.workoutHasHeartRate(workout)
    }
    func getWorkoutUploadTime(_ workout: HKWorkout) -> Date? {
        AppleHealthWorkoutUploadService.shared.getWorkoutUploadTime(workout)
    }
} 
