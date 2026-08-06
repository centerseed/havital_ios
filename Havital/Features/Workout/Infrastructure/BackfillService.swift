import Foundation

/// 資料回填服務 - 支援 Strava 和 Garmin 歷史資料回填
/// 在 onboarding 綁定資料源成功後自動觸發，背景執行不影響用戶體驗
class BackfillService {
    static let shared = BackfillService()

    // MARK: - New Architecture Dependencies
    private let httpClient: HTTPClient
    private let parser: APIParser

    /// 預設回填天數
    static let defaultBackfillDays = 14

    init(httpClient: HTTPClient = DefaultHTTPClient.shared,
         parser: APIParser = DefaultAPIParser.shared) {
        self.httpClient = httpClient
        self.parser = parser
    }

    // MARK: - Unified API Call Method

    /// 統一的 API 調用方法
    private func makeAPICall<T: Codable>(
        _ type: T.Type,
        path: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        operationName: String
    ) async throws -> T {
        Logger.debug("[BackfillService] \(operationName) - 調用 API: \(method.rawValue) \(path)")

        do {
            let rawData = try await httpClient.request(path: path, method: method, body: body)
            Logger.debug("[BackfillService] \(operationName) - 收到響應，數據大小: \(rawData.count) bytes")
            return try ResponseProcessor.extractData(type, from: rawData, using: parser)
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        } catch {
            throw error
        }
    }

    /// 低優先級 API 調用，用於背景操作
    private func makeBackgroundAPICall<T: Codable>(
        _ type: T.Type,
        path: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        operationName: String
    ) async throws -> T {
        // 使用低優先級任務，避免影響主要用戶操作
        return try await Task(priority: .background) {
            try await self.makeAPICall(type, path: path, method: method, body: body, operationName: operationName)
        }.value
    }

    // MARK: - Strava Backfill

    /// 觸發 Strava 資料回填
    /// - Parameters:
    ///   - days: 回填天數，預設 14 天
    /// - Returns: 回填 ID，用於查詢狀態，若遇到 429 則返回 nil
    func triggerStravaBackfill(days: Int = defaultBackfillDays) async throws -> String? {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let startDateString = dateFormatter.string(from: startDate)

        let request = BackfillRequest(startDate: startDateString, days: days)
        let bodyData = try JSONEncoder().encode(request)

        do {
            let response: BackfillTriggerResponse = try await makeBackgroundAPICall(
                BackfillTriggerResponse.self,
                path: "/strava/backfill",
                method: .POST,
                body: bodyData,
                operationName: "Strava Backfill 觸發"
            )

            Logger.firebase(
                "Strava Backfill 觸發成功",
                level: .info,
                labels: [
                    "module": "BackfillService",
                    "action": "trigger_strava_backfill",
                    "cloud_logging": "true"
                ],
                jsonPayload: [
                    "backfill_id": response.data.backfillId,
                    "status": response.data.status,
                    "days": days,
                    "start_date": startDateString
                ]
            )

            return response.data.backfillId

        } catch let error as HTTPError {
            // 429 錯誤表示已經有一個 backfill 正在進行，這不算錯誤
            if case .httpError(let statusCode, _) = error, statusCode == 429 {
                Logger.firebase(
                    "Strava Backfill 已在進行中 (429)",
                    level: .info,
                    labels: [
                        "module": "BackfillService",
                        "action": "trigger_strava_backfill",
                        "cloud_logging": "true"
                    ],
                    jsonPayload: [
                        "status": "rate_limited",
                        "days": days,
                        "message": "Strava backfill already in progress, skipping"
                    ]
                )
                return nil
            }
            // 記錄其他 HTTP 錯誤
            Logger.firebase(
                "Strava Backfill 觸發 HTTP 錯誤",
                level: .warn,
                labels: [
                    "module": "BackfillService",
                    "action": "trigger_strava_backfill",
                    "cloud_logging": "true"
                ],
                jsonPayload: [
                    "days": days,
                    "error": error.localizedDescription
                ]
            )
            throw error
        }
    }

    /// 查詢 Strava 回填狀態
    /// - Parameter backfillId: 回填 ID
    /// - Returns: 回填狀態回應
    func getStravaBackfillStatus(backfillId: String) async throws -> StravaBackfillStatusResponse {
        let response: StravaBackfillStatusResponse = try await makeBackgroundAPICall(
            StravaBackfillStatusResponse.self,
            path: "/strava/backfill/\(backfillId)",
            method: .GET,
            operationName: "Strava Backfill 狀態查詢"
        )

        Logger.firebase(
            "Strava Backfill 狀態查詢成功",
            level: .info,
            labels: [
                "module": "BackfillService",
                "action": "get_strava_backfill_status",
                "cloud_logging": "true"
            ],
            jsonPayload: [
                "backfill_id": backfillId,
                "status": response.data.status,
                "total_activities": response.data.progress?.totalActivities ?? 0,
                "processed_activities": response.data.progress?.processedActivities ?? 0,
                "stored_activities": response.data.progress?.storedActivities ?? 0
            ]
        )

        return response
    }

    // MARK: - Garmin Backfill

    /// 請求 Garmin 初始回填（背景執行，不阻斷 OAuth 後的主流程）
    ///
    /// AC-GARMIN-BF-01/02：App 不得自行判定「首次綁定」並直接呼叫 raw `POST /garmin/backfill`；
    /// 是否真的向 Garmin 發請求，一律由後端依 durable coverage record 決定。
    /// - Parameter days: 初始回填天數，預設 14 天（Garmin 限制最多 90 天）
    func ensureInitialGarminBackfill(days: Int = defaultBackfillDays) {
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            do {
                _ = try await self.performEnsureInitialGarminBackfill(days: days)
            } catch {
                // 背景判定失敗不影響用戶，只記錄日誌
                Logger.firebase(
                    "Onboarding Garmin backfill guard failed",
                    level: .warn,
                    labels: [
                        "module": "BackfillService",
                        "action": "onboarding_backfill_failed",
                        "cloud_logging": "true"
                    ],
                    jsonPayload: [
                        "provider": DataSourceType.garmin.rawValue,
                        "days": days,
                        "error": error.localizedDescription
                    ]
                )
            }
        }
    }

    /// `ensureInitialGarminBackfill` 的實作本體，回傳後端的判定結果。
    ///
    /// AC-GARMIN-BF-03：`already_requested` / `already_has_data` / `in_progress` / `not_eligible`
    /// 都是正常判定結果，後端以 HTTP 200 回傳，這裡不得當成錯誤拋出去阻斷流程。
    @discardableResult
    func performEnsureInitialGarminBackfill(days: Int = defaultBackfillDays) async throws -> GarminEnsureInitialData {
        // Garmin 限制最多 90 天
        let actualDays = min(days, 90)

        let request = EnsureInitialBackfillRequest(days: actualDays)
        let bodyData = try JSONEncoder().encode(request)

        do {
            let response: GarminEnsureInitialResponse = try await makeBackgroundAPICall(
                GarminEnsureInitialResponse.self,
                path: "/garmin/backfill/ensure-initial",
                method: .POST,
                body: bodyData,
                operationName: "Garmin ensure-initial backfill"
            )

            let decision = response.data.decision
            Logger.firebase(
                "Garmin ensure-initial backfill decision",
                level: decision == GarminEnsureInitialData.failedDecision ? .warn : .info,
                labels: [
                    "module": "BackfillService",
                    "action": "ensure_initial_garmin_backfill",
                    "cloud_logging": "true"
                ],
                jsonPayload: [
                    "decision": decision,
                    "backfill_id": response.data.backfillId ?? "",
                    "days": actualDays,
                    "trigger_source": "onboarding"
                ]
            )

            // 後端在 already_requested / in_progress 時也會回既有 job 的 id。
            // 這裡只要拿得到 id 就存，否則換裝置或重裝後本地沒有 id，
            // `checkAndLogBackfillResult` 會直接退出，後續狀態查詢等於失效。
            if let backfillId = response.data.backfillId {
                self.saveBackfillId(backfillId, for: .garmin)
            }

            return response.data

        } catch let error as HTTPError {
            Logger.firebase(
                "Garmin ensure-initial backfill HTTP error",
                level: .warn,
                labels: [
                    "module": "BackfillService",
                    "action": "ensure_initial_garmin_backfill",
                    "cloud_logging": "true"
                ],
                jsonPayload: [
                    "days": actualDays,
                    "error": error.localizedDescription
                ]
            )
            throw error
        }
    }

    /// 查詢 Garmin 回填狀態
    /// - Parameter backfillId: 回填 ID
    /// - Returns: 回填狀態回應
    func getGarminBackfillStatus(backfillId: String) async throws -> GarminBackfillStatusResponse {
        let response: GarminBackfillStatusResponse = try await makeBackgroundAPICall(
            GarminBackfillStatusResponse.self,
            path: "/garmin/backfill/\(backfillId)",
            method: .GET,
            operationName: "Garmin Backfill 狀態查詢"
        )

        Logger.firebase(
            "Garmin Backfill 狀態查詢成功",
            level: .info,
            labels: [
                "module": "BackfillService",
                "action": "get_garmin_backfill_status",
                "cloud_logging": "true"
            ],
            jsonPayload: [
                "backfill_id": backfillId,
                "status": response.data.status,
                "initial_workout_count": response.data.progress?.initialWorkoutCount ?? 0,
                "current_workout_count": response.data.progress?.currentWorkoutCount ?? 0,
                "new_workouts": response.data.progress?.newWorkouts ?? 0
            ]
        )

        return response
    }

    // MARK: - Onboarding Backfill (Background)

    /// 在 onboarding 時觸發背景回填（不影響用戶體驗）
    ///
    /// Garmin 不走這裡：它必須經後端 coverage guard（`ensureInitialGarminBackfill`），
    /// 見 AC-GARMIN-BF-01/02。
    /// - Parameters:
    ///   - provider: 資料來源類型（目前只有 .strava）
    ///   - days: 回填天數，預設 14 天
    func triggerOnboardingBackfill(provider: DataSourceType, days: Int = defaultBackfillDays) {
        // 使用 detached 確保不會影響主要用戶流程
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }

            do {
                switch provider {
                case .strava:
                    if let backfillId = try await self.triggerStravaBackfill(days: days) {
                        Logger.firebase(
                            "Onboarding Strava Backfill 已觸發",
                            level: .info,
                            labels: [
                                "module": "BackfillService",
                                "action": "onboarding_strava_backfill",
                                "cloud_logging": "true"
                            ],
                            jsonPayload: [
                                "backfill_id": backfillId,
                                "days": days,
                                "trigger_source": "onboarding"
                            ]
                        )

                        // 保存 backfill_id 供後續狀態檢查
                        self.saveBackfillId(backfillId, for: .strava)
                    }
                    // 如果 backfillId 為 nil，表示遇到 429，已在 triggerStravaBackfill 中記錄日誌

                case .garmin:
                    // Garmin 一律經後端 guard 判定，不從這裡直接打 raw backfill
                    try await self.performEnsureInitialGarminBackfill(days: days)

                default:
                    // Apple Health 或 unbound 不需要 backfill
                    break
                }

            } catch {
                // 背景 backfill 失敗不影響用戶，只記錄日誌
                Logger.firebase(
                    "Onboarding Garmin backfill guard failed",
                    level: .warn,
                    labels: [
                        "module": "BackfillService",
                        "action": "onboarding_backfill_failed",
                        "cloud_logging": "true"
                    ],
                    jsonPayload: [
                        "provider": provider.rawValue,
                        "days": days,
                        "error": error.localizedDescription
                    ]
                )
            }
        }
    }

    /// 檢查並記錄 backfill 結果（在 overview 產生後呼叫）
    /// - Parameter provider: 資料來源類型
    func checkAndLogBackfillResult(provider: DataSourceType) {
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }

            guard let backfillId = self.getBackfillId(for: provider) else {
                Logger.debug("[BackfillService] 無 backfill_id 可查詢 (\(provider.rawValue))")
                return
            }

            do {
                switch provider {
                case .strava:
                    let status = try await self.getStravaBackfillStatus(backfillId: backfillId)

                    Logger.firebase(
                        "Strava Backfill 結果檢查完成",
                        level: .info,
                        labels: [
                            "module": "BackfillService",
                            "action": "check_strava_backfill_result",
                            "cloud_logging": "true"
                        ],
                        jsonPayload: [
                            "backfill_id": backfillId,
                            "status": status.data.status,
                            "total_activities": status.data.progress?.totalActivities ?? 0,
                            "processed_activities": status.data.progress?.processedActivities ?? 0,
                            "stored_activities": status.data.progress?.storedActivities ?? 0,
                            "completion_reason": status.data.completionReason ?? "",
                            "error": status.data.error ?? ""
                        ]
                    )

                    // 如果完成或失敗，清除保存的 backfill_id
                    if status.data.status == "completed" || status.data.status == "failed" {
                        self.clearBackfillId(for: .strava)
                    }

                case .garmin:
                    let status = try await self.getGarminBackfillStatus(backfillId: backfillId)

                    Logger.firebase(
                        "Garmin Backfill 結果檢查完成",
                        level: .info,
                        labels: [
                            "module": "BackfillService",
                            "action": "check_garmin_backfill_result",
                            "cloud_logging": "true"
                        ],
                        jsonPayload: [
                            "backfill_id": backfillId,
                            "status": status.data.status,
                            "initial_workout_count": status.data.progress?.initialWorkoutCount ?? 0,
                            "current_workout_count": status.data.progress?.currentWorkoutCount ?? 0,
                            "new_workouts": status.data.progress?.newWorkouts ?? 0,
                            "elapsed_seconds": status.data.progress?.elapsedSeconds ?? 0,
                            "completion_reason": status.data.completionReason ?? "",
                            "error": status.data.error ?? ""
                        ]
                    )

                    // 如果完成或失敗，清除保存的 backfill_id
                    if status.data.status == "completed" || status.data.status == "failed" {
                        self.clearBackfillId(for: .garmin)
                    }

                default:
                    break
                }

            } catch {
                Logger.firebase(
                    "Backfill 結果檢查失敗",
                    level: .warn,
                    labels: [
                        "module": "BackfillService",
                        "action": "check_backfill_result_failed",
                        "cloud_logging": "true"
                    ],
                    jsonPayload: [
                        "provider": provider.rawValue,
                        "backfill_id": backfillId,
                        "error": error.localizedDescription
                    ]
                )
            }
        }
    }

    // MARK: - Backfill ID Storage

    private func saveBackfillId(_ backfillId: String, for provider: DataSourceType) {
        let key = "backfill_id_\(provider.rawValue)"
        UserDefaults.standard.set(backfillId, forKey: key)
        Logger.debug("[BackfillService] 已保存 backfill_id: \(backfillId) for \(provider.rawValue)")
    }

    private func getBackfillId(for provider: DataSourceType) -> String? {
        let key = "backfill_id_\(provider.rawValue)"
        return UserDefaults.standard.string(forKey: key)
    }

    private func clearBackfillId(for provider: DataSourceType) {
        let key = "backfill_id_\(provider.rawValue)"
        UserDefaults.standard.removeObject(forKey: key)
        Logger.debug("[BackfillService] 已清除 backfill_id for \(provider.rawValue)")
    }
}

// MARK: - Request Models

struct BackfillRequest: Codable {
    let startDate: String
    let days: Int

    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case days
    }
}

// MARK: - Response Models

struct BackfillTriggerResponse: Codable {
    let success: Bool
    let data: BackfillTriggerData
}

// MARK: - Garmin Ensure-Initial Response (AC-GARMIN-BF-02/03)

struct EnsureInitialBackfillRequest: Codable {
    let days: Int
}

struct GarminEnsureInitialResponse: Codable {
    let success: Bool
    let data: GarminEnsureInitialData
}

struct GarminEnsureInitialData: Codable {
    /// `started` / `already_requested` / `already_has_data` / `in_progress` / `not_eligible` / `failed`
    let decision: String
    let backfillId: String?
    let message: String?

    static let startedDecision = "started"
    static let failedDecision = "failed"

    /// 只有這個值代表後端真的向 Garmin 送出了新的 backfill 請求。
    var startedNewBackfill: Bool { decision == Self.startedDecision }

    enum CodingKeys: String, CodingKey {
        case decision
        case backfillId = "backfill_id"
        case message
    }
}

struct BackfillTriggerData: Codable {
    let backfillId: String
    let status: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case backfillId = "backfill_id"
        case status
        case message
    }
}

// MARK: - Strava Backfill Status Response (Internal - 用於 BackfillService 內部)

struct StravaBackfillStatusResponse: Codable {
    let success: Bool
    let data: StravaBackfillStatusData
}

struct StravaBackfillStatusData: Codable {
    let backfillId: String
    let status: String  // processing, completed, failed
    let provider: String
    let timeRange: StravaBackfillTimeRange?
    let progress: StravaBackfillProgress?
    let timestamps: StravaBackfillTimestamps?
    let completionReason: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case backfillId = "backfill_id"
        case status
        case provider
        case timeRange = "time_range"
        case progress
        case timestamps
        case completionReason = "completion_reason"
        case error
    }
}

struct StravaBackfillTimeRange: Codable {
    let startDate: String
    let endDate: String
    let days: Int

    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case days
    }
}

struct StravaBackfillProgress: Codable {
    let totalActivities: Int?
    let processedActivities: Int?
    let storedActivities: Int?

    enum CodingKeys: String, CodingKey {
        case totalActivities = "total_activities"
        case processedActivities = "processed_activities"
        case storedActivities = "stored_activities"
    }
}

struct StravaBackfillTimestamps: Codable {
    let triggeredAt: String?
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case triggeredAt = "triggered_at"
        case completedAt = "completed_at"
    }
}

// MARK: - Garmin Backfill Status Response

struct GarminBackfillStatusResponse: Codable {
    let success: Bool
    let data: GarminBackfillStatusData
}

struct GarminBackfillStatusData: Codable {
    let backfillId: String
    let userId: String?
    let status: String  // monitoring, completed, failed
    let startDate: String?
    let endDate: String?
    let days: Int?
    let triggeredAt: String?
    let completedAt: String?
    let progress: GarminBackfillProgress?
    let completionReason: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case backfillId = "backfill_id"
        case userId = "user_id"
        case status
        case startDate = "start_date"
        case endDate = "end_date"
        case days
        case triggeredAt = "triggered_at"
        case completedAt = "completed_at"
        case progress
        case completionReason = "completion_reason"
        case error
    }
}

struct GarminBackfillProgress: Codable {
    let initialWorkoutCount: Int?
    let currentWorkoutCount: Int?
    let newWorkouts: Int?
    let lastWorkoutReceivedAt: String?
    let lastCheckedAt: String?
    let elapsedSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case initialWorkoutCount = "initial_workout_count"
        case currentWorkoutCount = "current_workout_count"
        case newWorkouts = "new_workouts"
        case lastWorkoutReceivedAt = "last_workout_received_at"
        case lastCheckedAt = "last_checked_at"
        case elapsedSeconds = "elapsed_seconds"
    }
}
