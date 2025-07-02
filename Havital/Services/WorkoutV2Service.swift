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
    
    private let apiClient = APIClient.shared
    private let healthKitManager = HealthKitManager()
    
    private init() {}
    
    // MARK: - Error Handling Helpers
    
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
    
    /// 獲取運動列表
    /// - Parameters:
    ///   - pageSize: 每頁數量，預設 20
    ///   - cursor: 分頁游標
    ///   - startDate: 開始日期
    ///   - endDate: 結束日期
    ///   - activityType: 運動類型篩選
    ///   - provider: 數據來源篩選
    /// - Returns: 運動列表回應
    func fetchWorkouts(
        pageSize: Int = 20,
        cursor: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        activityType: String? = nil,
        provider: String? = nil
    ) async throws -> WorkoutListResponse {
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]
        
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "start_date", value: startDate))
        }
        
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "end_date", value: endDate))
        }
        
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
            
            let response: WorkoutListResponse = try await apiClient.request(
                WorkoutListResponse.self,
                path: components.url?.absoluteString ?? "/v2/workouts",
                method: "GET"
            )
            
            Logger.firebase(
                "Workout V2 列表獲取成功",
                level: .info,
                labels: [
                    "module": "WorkoutV2Service",
                    "action": "fetch_workouts"
                ],
                            jsonPayload: [
                "workouts_count": response.data.workouts.count,
                "has_more": response.data.pagination.hasMore,
                "provider_filter": provider ?? "all",
                "activity_type_filter": activityType ?? "all"
            ]
            )
            
            return response
            
        } catch let decodingError as DecodingError {
            
            // 詳細記錄 JSON 解析錯誤
            let errorDetail = getDecodingErrorDetail(decodingError)
            
            // 輸出詳細錯誤信息到 console 以便 debug
            print("🚨 [WorkoutV2Service] JSON 解析失敗")
            print("🔍 錯誤詳情:")
            print("  - 字段: \(errorDetail.missingField ?? "unknown")")
            print("  - 路徑: \(errorDetail.codingPath)")
            print("  - 描述: \(errorDetail.description)")
            print("  - Debug: \(errorDetail.debugDescription)")
            
            // 嘗試從 APIClient 獲取原始回應數據
            print("⚠️ 請檢查 APIClient 的原始回應數據")
            
            Logger.firebase(
                "Workout V2 JSON 解析失敗",
                level: .error,
                labels: [
                    "module": "WorkoutV2Service",
                    "action": "fetch_workouts",
                    "error_type": "decoding_error"
                ],
                jsonPayload: [
                    "error_description": errorDetail.description,
                    "missing_field": errorDetail.missingField ?? "unknown",
                    "coding_path": errorDetail.codingPath,
                    "debug_description": errorDetail.debugDescription,
                    "page_size": pageSize,
                    "provider_filter": provider ?? "all",
                    "activity_type_filter": activityType ?? "all"
                ]
            )
            
            throw WorkoutV2Error.decodingFailed(errorDetail.description)
            
        } catch {
            
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
            let response: WorkoutDetailResponse = try await apiClient.request(
                WorkoutDetailResponse.self,
                path: "/v2/workouts/\(workoutId)",
                method: "GET"
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
                "activity_type": response.data.activityType,
                "duration_seconds": Int(response.data.duration)
            ]
            )
            
            return response
            
        } catch let decodingError as DecodingError {
            
            // 詳細記錄 JSON 解析錯誤
            let errorDetail = getDecodingErrorDetail(decodingError)
            
            Logger.firebase(
                "Workout V2 詳情 JSON 解析失敗",
                level: .error,
                labels: [
                    "module": "WorkoutV2Service",
                    "action": "fetch_workout_detail",
                    "error_type": "decoding_error"
                ],
                jsonPayload: [
                    "workout_id": workoutId,
                    "error_description": errorDetail.description,
                    "missing_field": errorDetail.missingField ?? "unknown",
                    "coding_path": errorDetail.codingPath,
                    "debug_description": errorDetail.debugDescription
                ]
            )
            
            throw WorkoutV2Error.decodingFailed(errorDetail.description)
            
        } catch {
            
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
        let response: WorkoutStatsResponse = try await apiClient.request(
            WorkoutStatsResponse.self,
            path: "/v2/workouts/stats?days=\(days)",
            method: "GET"
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
    
    // MARK: - Upload Apple Health Workout
    
    /// 上傳 Apple Health 運動數據到 V2 API
    /// - Parameters:
    ///   - workout: HealthKit 運動記錄
    ///   - heartRateData: 心率數據
    ///   - includeTimeSeries: 是否包含時間序列數據
    /// - Returns: 上傳回應
    func uploadAppleHealthWorkout(
        _ workout: HKWorkout,
        heartRateData: [(Date, Double)] = [],
        includeTimeSeries: Bool = true
    ) async throws -> UploadWorkoutResponse {
        
        // 如果需要心率數據但沒有提供，則獲取
        var finalHeartRateData = heartRateData
        if finalHeartRateData.isEmpty {
            finalHeartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
        }
        
        let uploadRequest = try buildUploadRequest(
            from: workout,
            heartRateData: finalHeartRateData,
            includeTimeSeries: includeTimeSeries
        )
        
        let requestData = try JSONEncoder().encode(uploadRequest)
        
        let response: UploadWorkoutResponse = try await apiClient.request(
            UploadWorkoutResponse.self,
            path: "/v2/workouts",
            method: "POST",
            body: requestData
        )
        
        Logger.firebase(
            "Apple Health Workout 上傳成功",
            level: .info,
            labels: [
                "module": "WorkoutV2Service",
                "action": "upload_apple_health"
            ],
            jsonPayload: [
                "workout_id": response.id,
                "workout_type": workout.workoutActivityType.name,
                "duration_seconds": Int(workout.duration),
                "heart_rate_data_points": finalHeartRateData.count,
                "has_advanced_metrics": response.advancedMetrics != nil
            ]
        )
        
        return response
    }
    
    // MARK: - Private Helper Methods
    
    /// 建立上傳請求結構
    private func buildUploadRequest(
        from workout: HKWorkout,
        heartRateData: [(Date, Double)],
        includeTimeSeries: Bool
    ) throws -> UploadWorkoutRequest {
        
        let iso8601Formatter = ISO8601DateFormatter()
        
        // 建立來源資訊
        let sourceInfo = UploadSourceInfo(
            name: "apple_health",
            importMethod: "app_sdk"
        )
        
        // 建立活動資料
        let activityProfile = UploadActivityProfile(
            type: mapWorkoutActivityType(workout.workoutActivityType),
            startTimeUtc: iso8601Formatter.string(from: workout.startDate),
            endTimeUtc: iso8601Formatter.string(from: workout.endDate),
            durationTotalSeconds: Int(workout.duration)
        )
        
        // 建立摘要指標
        let summaryMetrics = UploadSummaryMetrics(
            distanceMeters: workout.totalDistance?.doubleValue(for: .meter()),
            activeCaloriesKcal: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
            avgHeartRateBpm: heartRateData.isEmpty ? nil : Int(heartRateData.map(\.1).reduce(0, +) / Double(heartRateData.count)),
            maxHeartRateBpm: heartRateData.isEmpty ? nil : Int(heartRateData.map(\.1).max() ?? 0)
        )
        
        // 建立時間序列數據（如果需要且有心率數據）
        var timeSeriesStreams: UploadTimeSeriesStreams? = nil
        if includeTimeSeries && !heartRateData.isEmpty {
            let startTime = workout.startDate
            let timestamps = heartRateData.map { data in
                Int(data.0.timeIntervalSince(startTime))
            }
            let heartRates = heartRateData.map { Int($0.1) }
            
            timeSeriesStreams = UploadTimeSeriesStreams(
                timestampsSecondsOffset: timestamps,
                heartRateBpm: heartRates
            )
        }
        
        return UploadWorkoutRequest(
            sourceInfo: sourceInfo,
            activityProfile: activityProfile,
            summaryMetrics: summaryMetrics,
            timeSeriesStreams: timeSeriesStreams
        )
    }
    
    /// 映射 HealthKit 運動類型到 API 格式
    private func mapWorkoutActivityType(_ activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .running, .trackAndField:
            return "running"
        case .walking:
            return "walking"
        case .cycling, .handCycling:
            return "cycling"
        case .swimming, .swimBikeRun:
            return "swimming"
        case .hiking:
            return "hiking"
        case .yoga, .mindAndBody:
            return "yoga"
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return "strength_training"
        case .highIntensityIntervalTraining:
            return "hiit"
        case .crossTraining:
            return "cross_training"
        case .mixedCardio:
            return "mixed_cardio"
        case .pilates:
            return "pilates"
        default:
            return "other"
        }
    }
}

// MARK: - Convenience Methods

extension WorkoutV2Service {
    
    /// 獲取最近的運動記錄
    /// - Parameter limit: 數量限制
    /// - Returns: 運動列表
    func fetchRecentWorkouts(limit: Int = 20) async throws -> [WorkoutV2] {
        let response = try await fetchWorkouts(pageSize: limit)
        return response.data.workouts
    }
    
    /// 獲取特定類型的運動記錄
    /// - Parameters:
    ///   - activityType: 運動類型
    ///   - limit: 數量限制
    /// - Returns: 運動列表
    func fetchWorkoutsByType(_ activityType: String, limit: Int = 20) async throws -> [WorkoutV2] {
        let response = try await fetchWorkouts(pageSize: limit, activityType: activityType)
        return response.data.workouts
    }
    
    /// 獲取特定數據來源的運動記錄
    /// - Parameters:
    ///   - provider: 數據來源
    ///   - limit: 數量限制
    /// - Returns: 運動列表
    func fetchWorkoutsByProvider(_ provider: String, limit: Int = 20) async throws -> [WorkoutV2] {
        let response = try await fetchWorkouts(pageSize: limit, provider: provider)
        return response.data.workouts
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
        
        return response.data.workouts
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
