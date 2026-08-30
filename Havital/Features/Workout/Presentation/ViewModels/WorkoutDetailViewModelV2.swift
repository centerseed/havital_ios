import SwiftUI
import Combine
import HealthKit

/// WorkoutDetailViewModelV2 - Clean Architecture Presentation Layer
/// Phase 3 重構：使用 ViewState 統一狀態管理，注入 WorkoutRepository
class WorkoutDetailViewModelV2: ObservableObject, TaskManageable {

    // MARK: - ViewState (主要狀態)

    @Published private(set) var state: ViewState<WorkoutV2Detail> = .loading

    // MARK: - Backward Compatibility Computed Properties

    /// 訓練詳情（向後兼容）
    var workoutDetail: WorkoutV2Detail? {
        state.data
    }

    /// 是否正在載入（向後兼容）
    var isLoading: Bool {
        state.isLoading
    }

    /// 錯誤訊息（向後兼容）
    var error: String? {
        state.error?.localizedDescription
    }

    // MARK: - Chart Data (圖表數據)

    @Published var heartRates: [DataPoint] = []
    @Published var paces: [DataPoint] = []
    @Published var speeds: [DataPoint] = []
    @Published var altitudes: [DataPoint] = []
    @Published var cadences: [DataPoint] = []

    // MARK: - Gait Analysis Data (步態分析數據)

    @Published var stanceTimes: [DataPoint] = []
    @Published var verticalRatios: [DataPoint] = []
    @Published var groundContactTimes: [DataPoint] = []
    @Published var verticalOscillations: [DataPoint] = []

    /// 原始流是否存在（用於控制是否顯示分頁）
    @Published var hasStanceTimeStream: Bool = false

    // MARK: - Zone Distribution (區間分佈)

    @Published var hrZoneDistribution: [String: Double] = [:]
    @Published var paceZoneDistribution: [String: Double] = [:]

    // MARK: - Chart Properties (圖表相關屬性)

    /// 沒有心率序列時的預設 Y 軸範圍。清空重建時要退回這個值，不能留上一份的範圍。
    static let defaultHeartRateAxisRange: (min: Double, max: Double) = (60, 180)

    @Published var yAxisRange: (min: Double, max: Double) = WorkoutDetailViewModelV2.defaultHeartRateAxisRange

    // MARK: - AC-IOS-ANALYTICS-P1-10: session-level dedup for workout_analysis_view
    @Published var hasTrackedAnalyticsView: Bool = false

    // MARK: - PB Moment

    @Published private(set) var personalBestUpdatesForWorkout: [PersonalBestUpdate] = []
    @Published private(set) var pendingPBMomentUpdate: PersonalBestUpdate?
    @Published private(set) var pendingCelebrationContent: CelebrationContent?

    // MARK: - Dependencies

    let workout: WorkoutV2
    private let repository: WorkoutRepository
    private let userProfileRepository: UserProfileRepository
    private let achievementRepository: AchievementRepository

    // MARK: - Badge Celebration State

    // shownBadgeIds is in-memory only — dedup does not persist across VM
    // recreation or app restarts. A user who kills the app between viewing the
    // celebration and re-opening the same workout detail may see the badge
    // celebration re-trigger. Acceptable for v1; PB dedup uses
    // PersonalBestCelebrationStorage for cross-restart suppression.
    private var shownBadgeIds: Set<String> = []

    /// Guards against infinite retry when achievementRepository.cachedSummary stays nil.
    private var summaryFetchAttempted = false

    // MARK: - TaskManageable

    let taskRegistry = TaskRegistry()

    /// Combine 訂閱（Track B 回寫）。
    private var cancellables = Set<AnyCancellable>()

    /// 主路徑還沒把 `state` 切成 `.loaded` 之前就收到的那一份 Track B 刷新。
    /// 載完之後補套用（見 `observeBackgroundDetailRefresh`）。
    private var pendingRefreshedDetail: WorkoutV2Detail?

    // MARK: - Initialization

    /// ✅ Clean Architecture: 建構子注入 Repository Protocol（不依賴 Singleton）
    init(workout: WorkoutV2,
         repository: WorkoutRepository,
         userProfileRepository: UserProfileRepository? = nil,
         achievementRepository: AchievementRepository? = nil) {
        self.workout = workout
        self.repository = repository
        let container = DependencyContainer.shared
        if let userProfileRepository {
            self.userProfileRepository = userProfileRepository
        } else {
            if !container.isRegistered(UserProfileRepository.self) {
                container.registerUserProfileModule()
            }
            self.userProfileRepository = container.resolve()
        }
        if let achievementRepository {
            self.achievementRepository = achievementRepository
        } else {
            if !container.isRegistered(AchievementRepository.self) {
                container.registerAchievementModule()
            }
            self.achievementRepository = container.resolve()
        }

        observeBackgroundDetailRefresh()

        Logger.debug("[WorkoutDetailViewModelV2] 初始化完成 - workout: \(workout.id)")
    }

    /// Track B 背景刷新完成 → **回寫畫面**（8/28 盤點 F5，2026-08-30 使用者裁決「要」）。
    ///
    /// `getWorkoutDetail` 是 cache-first：24 小時內的快取直接回，同時丟一個背景刷新。
    /// 那次刷新原本只寫進快取，於是重跑同一堂課、重新上傳、裁剪之後，詳情頁上的數字
    /// 要等快取過期（最多一天）才會變。
    ///
    /// **只在已經有畫面內容時回寫**：`state` 還在 loading／error 時由那條主路徑決定
    /// 要顯示什麼，背景那一份不搶著把畫面切成 loaded（否則錯誤畫面會被默默蓋掉）。
    /// 只認這一筆 workout 的詳情——同一個 repository 是 app 範圍的單例。
    ///
    /// **還沒有畫面內容的那一份要留著，不是丟掉**（外審 D04／E03／E11）：repository 是
    /// 一拿到快取就立刻丟 Track B（`WorkoutRepositoryImpl.getWorkoutDetail`），那一次刷新
    /// 很可能在主路徑把 `state` 切成 `.loaded` 之前就回來了。丟掉它＝畫面停在剛剛那份
    /// 24 小時內的舊快取，而且**不會再有第二次事件**——那正是 F5 要修掉的症狀，只是換成
    /// 時序造成的。存進 `pendingRefreshedDetail`，主路徑載完就套用。
    private func observeBackgroundDetailRefresh() {
        repository.workoutDetailDidRefresh
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detail in
                guard let self, detail.id == self.workout.id else { return }
                guard self.state.hasData else {
                    self.pendingRefreshedDetail = detail
                    Logger.debug("[WorkoutDetailViewModelV2] Track B 早於主路徑，先留著 - \(detail.id)")
                    return
                }
                self.applyDerivedSeries(from: detail)
                self.state = .loaded(detail)
                Logger.debug("[WorkoutDetailViewModelV2] Track B 刷新回寫畫面 - \(detail.id)")
            }
            .store(in: &cancellables)
    }

    /// **初次載入**進 `.loaded` 之後，把等在那裡的那一份背景刷新套上去。
    ///
    /// 只有初次載入這條路徑可以套用。理由是誰比較新：Track B 是
    /// `getWorkoutDetail` 拿到快取的那一刻才丟出去的，所以它一定晚於、也就新於
    /// 初次載入那份 24 小時內的舊快取，蓋上去是對的。沒有等待中的就什麼都不做。
    ///
    /// **手動刷新不得走這一支**，見 `discardPendingRefreshedDetail`。
    private func applyPendingRefreshedDetailIfNeeded() {
        guard let pending = pendingRefreshedDetail, pending.id == workout.id else {
            pendingRefreshedDetail = nil
            return
        }
        pendingRefreshedDetail = nil
        applyDerivedSeries(from: pending)
        state = .loaded(pending)
        Logger.debug("[WorkoutDetailViewModelV2] 補套用主路徑之前收到的 Track B 刷新 - \(pending.id)")
    }

    /// 手動刷新完成後，把等在那裡的那一份背景刷新**丟掉**（外審第三輪 D04／E03／E11）。
    ///
    /// 手動刷新走的是 `refreshWorkoutDetail`（強制回源），它的回應必定晚於、也就新於
    /// 任何在它 loading 期間才被收下的 Track B——那一次背景刷新是**更早**的
    /// `getWorkoutDetail` 丟出去的。`performRefreshWorkoutDetail` 一開始把 `state`
    /// 切成 `.loading`，於是那段期間回來的 Track B 會被 observer 收進
    /// `pendingRefreshedDetail`；若照初次載入那樣無條件補套用，就會**拿舊的背景資料蓋掉
    /// 使用者剛剛主動要來的新資料**。
    ///
    /// 所以這裡只清掉、不套用：畫面上已經是強制回源的最新那一份了。
    private func discardPendingRefreshedDetail() {
        guard pendingRefreshedDetail != nil else { return }
        pendingRefreshedDetail = nil
        Logger.debug("[WorkoutDetailViewModelV2] 手動刷新已取得更新的資料，丟棄等待中的 Track B 刷新")
    }

    /// 便利初始化器（使用 DI Container 解析依賴）
    convenience init(workout: WorkoutV2) {
        let container = DependencyContainer.shared

        // 確保 Workout 模組已註冊
        if !container.isRegistered(WorkoutRepository.self) {
            container.registerWorkoutModule()
        }

        let repository: WorkoutRepository = container.resolve()

        self.init(
            workout: workout,
            repository: repository
        )
    }
    
    deinit {
        cancelAllTasks()
        // 確保所有異步任務都被取消
        heartRates.removeAll()
        paces.removeAll()
        speeds.removeAll()
        altitudes.removeAll()
        cadences.removeAll()
        
        // 步態分析數據
        stanceTimes.removeAll()
        verticalRatios.removeAll()
        groundContactTimes.removeAll()
        verticalOscillations.removeAll()
    }
    
    // MARK: - 刪除功能

    /// 刪除運動記錄 - 使用 Repository
    /// - Returns: 是否刪除成功
    func deleteWorkout() async -> Bool {
        do {
            // 使用 Repository 刪除（會同時處理 API 和緩存）
            try await repository.deleteWorkout(id: workout.id)

            // ✅ Clean Architecture: 發布 CacheEventBus 事件通知其他模組
            await MainActor.run {
                CacheEventBus.shared.publish(.dataChanged(.workouts))
            }
            Logger.debug("[WorkoutDetailViewModelV2] 發布 .dataChanged(.workouts) 事件 (刪除)")

            Logger.firebase(
                "成功刪除運動記錄",
                level: .info,
                labels: [
                    "module": "WorkoutDetailViewModelV2",
                    "action": "delete_workout"
                ],
                jsonPayload: [
                    "workout_id": workout.id,
                    "activity_type": workout.activityType
                ]
            )

            return true
        } catch {
            Logger.firebase(
                "刪除運動記錄失敗",
                level: .error,
                labels: [
                    "module": "WorkoutDetailViewModelV2",
                    "action": "delete_workout",
                    "cloud_logging": "true"
                ],
                jsonPayload: [
                    "workout_id": workout.id,
                    "error": error.localizedDescription
                ]
            )
            return false
        }
    }

    // MARK: - 訓練心得更新功能

    func updateVDOTOverride(_ override: VDOTOverrideRequest?) async -> Bool {
        do {
            try await repository.updateVDOTOverride(id: workout.id, override: override)
            await refreshWorkoutDetail()
            return state.data != nil && state.error == nil
        } catch is CancellationError {
            return false
        } catch {
            Logger.error("[WorkoutDetailViewModelV2] updateVDOTOverride failed: \(error.localizedDescription)")
            return false
        }
    }

    /// 更新訓練心得
    /// - Parameter notes: 訓練心得文本（最多 \(WorkoutConstants.maxTrainingNotesLength) 字符）
    /// - Returns: 是否更新成功
    func updateTrainingNotes(_ notes: String) async -> Bool {
        // 驗證字符數限制
        guard notes.count <= WorkoutConstants.maxTrainingNotesLength else {
            Logger.error("[WorkoutDetailViewModelV2] 訓練心得超過\(WorkoutConstants.maxTrainingNotesLength)字符限制")
            return false
        }

        do {
            Logger.debug("[WorkoutDetailViewModelV2] 更新訓練心得 - workout_id: \(workout.id)")

            // ✅ Clean Architecture: 使用 Repository 更新訓練心得
            try await repository.updateTrainingNotes(id: workout.id, notes: notes)

            // Repository 已經清除了緩存，現在刷新詳情以立即顯示更新
            await refreshWorkoutDetail()

            // ✅ Clean Architecture: 發布 CacheEventBus 事件通知其他模組
            await MainActor.run {
                CacheEventBus.shared.publish(.dataChanged(.workouts))
            }
            Logger.debug("[WorkoutDetailViewModelV2] 發布 .dataChanged(.workouts) 事件 (訓練心得更新)")

            Logger.firebase(
                "訓練心得更新成功",
                level: .info,
                labels: [
                    "module": "WorkoutDetailViewModelV2",
                    "action": "update_training_notes"
                ],
                jsonPayload: [
                    "workout_id": workout.id,
                    "notes_length": notes.count
                ]
            )

            return true
        } catch is CancellationError {
            Logger.debug("[WorkoutDetailViewModelV2] 訓練心得更新已取消")
            return false
        } catch {
            Logger.firebase(
                "訓練心得更新失敗",
                level: .error,
                labels: [
                    "module": "WorkoutDetailViewModelV2",
                    "action": "update_training_notes",
                    "cloud_logging": "true"
                ],
                jsonPayload: [
                    "workout_id": workout.id,
                    "error": error.localizedDescription
                ]
            )
            return false
        }
    }

    // MARK: - 跑步機里程校正

    /// 套用跑步機里程校正
    /// - Parameters:
    ///   - actualDistanceM: 實際距離（公尺），合法範圍 100..100000
    ///   - avgInclinePercent: 平均坡度（%），optional，合法範圍 -10..25
    ///   - notes: 備註，optional，最多 500 字
    /// - Returns: 是否成功
    func applyTreadmillCorrection(
        actualDistanceM: Double,
        avgInclinePercent: Double?,
        notes: String?
    ) async -> Bool {
        do {
            Logger.debug("[WorkoutDetailViewModelV2] applyTreadmillCorrection - workout_id: \(workout.id)")

            let updatedDetail = try await repository.applyTreadmillCorrection(
                id: workout.id,
                actualDistanceM: actualDistanceM,
                avgInclinePercent: avgInclinePercent,
                notes: notes
            )

            // The POST response carries the new `correction` object (so the card flips to the
            // corrected state) but the recomputed headline metrics (distance / pace / VDOT) only
            // land via a fresh GET. Re-fetch the authoritative detail so the headline updates
            // in place instead of staying stale until the next app launch. Falls back to the
            // POST response if the refresh fails. Direct repo call bypasses refreshWorkoutDetail()'s
            // cooldown so a correction applied <5s after opening still refreshes.
            let freshDetail = (try? await repository.refreshWorkoutDetail(id: workout.id)) ?? updatedDetail

            await MainActor.run {
                self.state = .loaded(freshDetail)
                // 列表更新由 repo.refreshSubject → WorkoutListViewModel → CacheEventBus 鏈處理
                // 此處不重複 publish，避免雙重 reload（MEDIUM-2）
            }

            Logger.firebase(
                "跑步機里程校正成功",
                level: .info,
                labels: ["module": "WorkoutDetailViewModelV2", "action": "treadmill_correction"],
                jsonPayload: [
                    "workout_id": workout.id,
                    "actual_distance_m": actualDistanceM
                ]
            )

            return true
        } catch is CancellationError {
            Logger.debug("[WorkoutDetailViewModelV2] 跑步機校正已取消")
            return false
        } catch {
            Logger.firebase(
                "跑步機里程校正失敗",
                level: .error,
                labels: [
                    "module": "WorkoutDetailViewModelV2",
                    "action": "treadmill_correction",
                    "cloud_logging": "true"
                ],
                jsonPayload: [
                    "workout_id": workout.id,
                    "error": error.localizedDescription
                ]
            )
            return false
        }
    }

    // MARK: - 運動紀錄裁剪

    /// 裁剪結果
    enum TrimApplyResult {
        case success
        case cannotTrim   // 409 — 原始 raw 已清，無法裁剪
        case cancelled    // 任務取消，UI 不顯示錯誤
        case failure
    }

    /// 套用運動紀錄裁剪
    /// - Parameters:
    ///   - keepStartS: 保留起點（相對原始 start_time 的秒數，>= 0）
    ///   - keepEndS: 保留終點（相對原始 start_time 的秒數，> keepStartS）
    /// - Returns: 裁剪結果（success / cannotTrim(409) / cancelled / failure）
    func applyTrim(keepStartS: Double, keepEndS: Double) async -> TrimApplyResult {
        do {
            Logger.debug("[WorkoutDetailViewModelV2] applyTrim - workout_id: \(workout.id)")

            let updatedDetail = try await repository.applyTrim(
                id: workout.id,
                keepStartS: keepStartS,
                keepEndS: keepEndS
            )

            // POST 回應已是重算後的 detail；再強制 GET 拿權威值，讓 headline（時長/距離/配速/VDOT）
            // 原地刷新（與 treadmill 同模式，直接呼叫 repo 繞過 refreshWorkoutDetail() 的 5s cooldown）。
            // refresh 失敗則回退用 POST 回應。
            let freshDetail = (try? await repository.refreshWorkoutDetail(id: workout.id)) ?? updatedDetail

            await MainActor.run {
                self.state = .loaded(freshDetail)
                // 列表更新由 repo.refreshSubject → WorkoutListViewModel → CacheEventBus 鏈處理
            }

            Logger.firebase(
                "運動紀錄裁剪成功",
                level: .info,
                labels: ["module": "WorkoutDetailViewModelV2", "action": "trim"],
                jsonPayload: [
                    "workout_id": workout.id,
                    "keep_start_s": keepStartS,
                    "keep_end_s": keepEndS
                ]
            )
            return .success
        } catch is CancellationError {
            Logger.debug("[WorkoutDetailViewModelV2] 裁剪已取消")
            return .cancelled
        } catch let error as HTTPError {
            if error.isCancelled { return .cancelled }
            if case .httpError(409, _) = error {
                Logger.debug("[WorkoutDetailViewModelV2] 裁剪失敗 409：原始資料已清，無法裁剪")
                return .cannotTrim
            }
            Logger.firebase(
                "運動紀錄裁剪失敗",
                level: .error,
                labels: ["module": "WorkoutDetailViewModelV2", "action": "trim", "cloud_logging": "true"],
                jsonPayload: ["workout_id": workout.id, "error": error.localizedDescription]
            )
            return .failure
        } catch {
            Logger.firebase(
                "運動紀錄裁剪失敗",
                level: .error,
                labels: ["module": "WorkoutDetailViewModelV2", "action": "trim", "cloud_logging": "true"],
                jsonPayload: ["workout_id": workout.id, "error": error.localizedDescription]
            )
            return .failure
        }
    }

    func updateRPE(_ rpe: Int?) async -> Bool {
        if let rpe, !(1...10).contains(rpe) {
            Logger.error("[WorkoutDetailViewModelV2] RPE 超出 1-10 範圍")
            return false
        }

        do {
            try await repository.updateRPE(id: workout.id, rpe: rpe)
            await refreshWorkoutDetail()

            await MainActor.run {
                CacheEventBus.shared.publish(.dataChanged(.workouts))
            }

            Logger.firebase(
                "RPE 更新成功",
                level: .info,
                labels: [
                    "module": "WorkoutDetailViewModelV2",
                    "action": "update_rpe"
                ],
                jsonPayload: [
                    "workout_id": workout.id,
                    "has_rpe": rpe != nil
                ]
            )

            return true
        } catch is CancellationError {
            Logger.debug("[WorkoutDetailViewModelV2] RPE 更新已取消")
            return false
        } catch {
            Logger.firebase(
                "RPE 更新失敗",
                level: .error,
                labels: [
                    "module": "WorkoutDetailViewModelV2",
                    "action": "update_rpe",
                    "cloud_logging": "true"
                ],
                jsonPayload: [
                    "workout_id": workout.id,
                    "error": error.localizedDescription
                ]
            )
            return false
        }
    }

    // MARK: - 重新上傳功能 (Apple Health Only)

    /// 重新上傳結果枚舉
    enum ReuploadResult {
        case success(hasHeartRate: Bool)
        case insufficientHeartRate(count: Int)
        case failure(message: String)
    }
    
    /// 從 HealthKit 查找匹配的運動記錄
    private func findMatchingHKWorkout() async -> HKWorkout? {
        let healthStore = HKHealthStore()
        let workoutType = HKObjectType.workoutType()

        let startTime = workout.startDate.addingTimeInterval(-60)
        let endTime = workout.endDate.addingTimeInterval(60)
        let predicate = HKQuery.predicateForSamples(withStart: startTime, end: endTime, options: .strictStartDate)

        let targetDuration = TimeInterval(self.workout.durationSeconds)
        let targetDistance = self.workout.distanceMeters ?? 0

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    print("❌ 查詢 HealthKit 運動記錄失敗: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let workouts = samples as? [HKWorkout], !workouts.isEmpty else {
                    print("❌ 找不到對應的 HealthKit 運動記錄")
                    continuation.resume(returning: nil)
                    return
                }

                let matchingWorkout = workouts.first { hkWorkout in
                    let durationDiff = abs(hkWorkout.duration - targetDuration)
                    let distance = hkWorkout.totalDistance?.safeDoubleValue(for: .meter()) ?? 0
                    let distanceDiff = abs(distance - targetDistance)
                    return durationDiff <= 5 && distanceDiff <= 50
                } ?? workouts.first

                continuation.resume(returning: matchingWorkout)
            }

            healthStore.execute(query)
        }
    }

    /// 重新上傳 Apple Health 的運動記錄（包含心率檢查）
    func reuploadWorkoutWithHeartRateCheck() async -> ReuploadResult {
        let provider = workout.provider.lowercased()
        guard provider.contains("apple") || provider.contains("health") || provider == "apple_health" else {
            print("⚠️ 只有 Apple Health 資料才能重新上傳")
            return .failure(message: NSLocalizedString("workout_reupload.error.only_apple_health", comment: ""))
        }

        print("🔄 開始重新上傳運動記錄（含心率檢查）- ID: \(workout.id)")

        guard let hkWorkout = await findMatchingHKWorkout() else {
            return .failure(message: NSLocalizedString("workout_reupload.error.no_matching_hk", comment: ""))
        }

        do {
            let heartRateData = try await HealthKitManager.shared.fetchHeartRateData(for: hkWorkout, forceRefresh: true, retryAttempt: 0)

            print("🔍 心率數據檢查: \(heartRateData.count) 筆")

            if heartRateData.count < 2 {
                print("⚠️ 心率數據不足: \(heartRateData.count) < 2 筆")
                return .insufficientHeartRate(count: heartRateData.count)
            }

            let uploadService = AppleHealthWorkoutUploadService.shared
            let result = try await uploadService.uploadWorkout(
                hkWorkout,
                force: true,
                retryHeartRate: true,
                source: "apple_health"
            )

            switch result {
            case .success(let hasHeartRate):
                print("✅ 運動記錄重新上傳成功，心率資料: \(hasHeartRate ? "有" : "無")")
                await MainActor.run {
                    CacheEventBus.shared.publish(.dataChanged(.workouts))
                }
                Logger.debug("[WorkoutDetailViewModelV2] 發布 .dataChanged(.workouts) 事件 (心率檢查上傳)")
                return .success(hasHeartRate: hasHeartRate)

            case .failure(let error):
                print("❌ 運動記錄重新上傳失敗: \(error.localizedDescription)")
                return .failure(message: String(format: NSLocalizedString("workout_reupload.error.failed", comment: ""), error.localizedDescription))
            }
        } catch {
            print("❌ 重新上傳過程發生錯誤: \(error.localizedDescription)")
            return .failure(message: String(format: NSLocalizedString("workout_reupload.error.exception", comment: ""), error.localizedDescription))
        }
    }
    
    /// 強制重新上傳（忽略心率檢查）
    func forceReuploadWorkout() async -> Bool {
        return await reuploadWorkout()
    }
    
    /// 重新上傳 Apple Health 的運動記錄
    func reuploadWorkout() async -> Bool {
        let provider = workout.provider.lowercased()
        guard provider.contains("apple") || provider.contains("health") || provider == "apple_health" else {
            print("⚠️ 只有 Apple Health 資料才能重新上傳")
            return false
        }

        print("🔄 開始重新上傳運動記錄 - ID: \(workout.id)")

        guard let hkWorkout = await findMatchingHKWorkout() else {
            print("❌ 找不到匹配的 HealthKit 運動記錄")
            return false
        }

        print("✅ 找到匹配的 HealthKit 運動記錄: \(hkWorkout.uuid)")

        do {
            let uploadService = AppleHealthWorkoutUploadService.shared
            let result = try await uploadService.uploadWorkout(
                hkWorkout,
                force: true,
                retryHeartRate: true,
                source: "apple_health"
            )

            switch result {
            case .success(let hasHeartRate):
                print("✅ 運動記錄重新上傳成功，心率資料: \(hasHeartRate ? "有" : "無")")
                await MainActor.run {
                    CacheEventBus.shared.publish(.dataChanged(.workouts))
                }
                Logger.debug("[WorkoutDetailViewModelV2] 發布 .dataChanged(.workouts) 事件 (重新上傳)")
                return true

            case .failure(let error):
                print("❌ 運動記錄重新上傳失敗: \(error.localizedDescription)")
                return false
            }
        } catch {
            print("❌ 重新上傳過程發生錯誤: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - 時間序列數據處理

    /// 把一份 detail 的圖表資料**整份換掉**：先清空所有衍生序列，再處理，再重算心率 Y 軸。
    ///
    /// 為什麼要清空：`processTimeSeriesData` 只在對應欄位有值時才寫，缺席的欄位它不碰。
    /// 少了前面這一步，新的一份 payload 沒有的序列會留著上一份的資料——畫面上就是一張
    /// 已經不屬於這筆 workout 的圖。強制刷新那條路徑本來就先清，Track B 背景刷新回寫那條
    /// 沒有，於是部分欄位缺席的刷新會留下舊圖（外審 D04／E03／E11）。三條進入
    /// loaded 的路徑（初次載入／強制刷新／背景回寫）現在都走這一支。
    private func applyDerivedSeries(from detail: WorkoutV2Detail) {
        heartRates.removeAll()
        paces.removeAll()
        speeds.removeAll()
        altitudes.removeAll()
        cadences.removeAll()

        stanceTimes.removeAll()
        verticalRatios.removeAll()
        groundContactTimes.removeAll()
        verticalOscillations.removeAll()

        processTimeSeriesData(from: detail)

        // 心率 Y 軸跟著新的序列走；新的一份沒有心率就退回預設，不留上一份的範圍。
        if heartRates.isEmpty {
            yAxisRange = WorkoutDetailViewModelV2.defaultHeartRateAxisRange
        } else {
            let hrValues = heartRates.map { $0.value }
            let minHR = hrValues.min() ?? 60
            let maxHR = hrValues.max() ?? 180
            let margin = (maxHR - minHR) * 0.1
            yAxisRange = (max(minHR - margin, 50), min(maxHR + margin, 220))
        }
    }

    /// 處理時間序列數據，轉換成圖表格式
    private func processTimeSeriesData(from detail: WorkoutV2Detail) {
        // 基於實際 API 回應格式處理時間序列數據
        if let timeSeriesData = detail.timeSeries {
            processTimeSeriesFromAPI(timeSeriesData)
        }
    }
    
    /// 處理來自 API 的時間序列數據
    private func processTimeSeriesFromAPI(_ timeSeries: V2TimeSeries) {
        let baseTime = workout.startDate

        // 處理心率數據
        if let heartRateData = timeSeries.heartRatesBpm,
           let timestamps = timeSeries.timestampsS {
            
            var heartRatePoints: [DataPoint] = []
            
            for (index, heartRate) in heartRateData.enumerated() {
                if index < timestamps.count,
                   let hr = heartRate,
                   let timestamp = timestamps[index] {
                    let time = baseTime.addingTimeInterval(TimeInterval(timestamp))
                    heartRatePoints.append(DataPoint(time: time, value: Double(hr)))
                }
            }
            
            // 數據降採樣以提升效能
            self.heartRates = downsampleData(heartRatePoints, maxPoints: 500)
        }

        // 處理配速數據，使用 paces_s_per_km 直接顯示配速
        if let pacesData = timeSeries.pacesSPerKm,
           let timestamps = timeSeries.timestampsS {
            
            var pacePoints: [DataPoint] = []
            
            for (index, pace) in pacesData.enumerated() {
                if index < timestamps.count,
                   let timestamp = timestamps[index] {
                    let time = baseTime.addingTimeInterval(TimeInterval(timestamp))
                    
                    // 只處理有效的配速值
                    if let paceValue = pace,
                       paceValue > 0 && paceValue < 3600 && paceValue.isFinite { // 合理的配速範圍：0-60分鐘/公里
                        pacePoints.append(DataPoint(time: time, value: paceValue))
                    }
                    // 如果配速是null或異常值，就直接跳過該數據點
                    // 這樣圖表會在該時間段出現斷點，正確顯示間歇訓練的休息段
                }
            }
            
            // 直接使用所有有效數據點，不進行降採樣
            self.paces = pacePoints
        }
        
        // 處理步態分析數據 - 觸地時間 (毫秒)
        print("📊 [GaitAnalysis] 檢查觸地時間數據...")
        print("📊 [GaitAnalysis] stanceTimesMs 存在: \(timeSeries.stanceTimesMs != nil)")
        print("📊 [GaitAnalysis] groundContactTimesMs 存在: \(timeSeries.groundContactTimesMs != nil)")
        print("📊 [GaitAnalysis] timestampsS 存在: \(timeSeries.timestampsS != nil)")

        // 優先使用 stance_times_ms，若缺失則回退到 ground_contact_times_ms
        let stanceTimeSource: String
        let stanceTimeDataFallback = timeSeries.stanceTimesMs ?? timeSeries.groundContactTimesMs
        if timeSeries.stanceTimesMs != nil {
            stanceTimeSource = "stance_times_ms"
        } else if timeSeries.groundContactTimesMs != nil {
            stanceTimeSource = "ground_contact_times_ms"
        } else {
            stanceTimeSource = "none"
        }
        self.hasStanceTimeStream = stanceTimeSource != "none"

        if let stanceTimeData = stanceTimeDataFallback,
           let timestamps = timeSeries.timestampsS {

            print("📊 [GaitAnalysis] 使用資料來源: \(stanceTimeSource)")
            print("📊 [GaitAnalysis] 觸地時間原始數據點數: \(stanceTimeData.count)")
            print("📊 [GaitAnalysis] 時間戳數據點數: \(timestamps.count)")

            var stanceTimePoints: [DataPoint] = []
            var validPointsCount = 0
            var invalidPointsCount = 0

            for (index, stanceTime) in stanceTimeData.enumerated() {
                if index < timestamps.count,
                   let timestamp = timestamps[index] {
                    let time = baseTime.addingTimeInterval(TimeInterval(timestamp))

                    // 合理的觸地時間範圍過濾 (50-600ms)
                    if let stanceValue = stanceTime,
                       stanceValue > 50 && stanceValue < 600 && stanceValue.isFinite {
                        stanceTimePoints.append(DataPoint(time: time, value: stanceValue))
                        validPointsCount += 1

                        if validPointsCount <= 5 { // 顯示前5個有效數據點
                            print("📊 [GaitAnalysis] 觸地時間[\(validPointsCount)]: \(String(format: "%.1f", stanceValue)) ms")
                        }
                    } else {
                        invalidPointsCount += 1
                        if invalidPointsCount <= 3 { // 顯示前3個無效數據點的詳細信息
                            if stanceTime == nil {
                                print("📊 [GaitAnalysis] 無效觸地時間[\(invalidPointsCount)]: null (索引 \(index))")
                            } else {
                                print("📊 [GaitAnalysis] 無效觸地時間[\(invalidPointsCount)]: \(stanceTime!) ms (索引 \(index))")
                            }
                        }
                    }
                }
            }

            print("📊 [GaitAnalysis] 有效觸地時間數據點: \(validPointsCount)")
            print("📊 [GaitAnalysis] 無效觸地時間數據點: \(invalidPointsCount)")

            self.stanceTimes = downsampleData(stanceTimePoints, maxPoints: 500)
            print("📊 [GaitAnalysis] 降採樣後觸地時間數據點: \(self.stanceTimes.count)")
        } else {
            print("⚠️ [GaitAnalysis] 沒有觸地時間數據或時間戳數據")
            self.stanceTimes = []
        }
        
        // 處理步態分析數據 - 垂直比率/移動效率 (%)
        if let verticalRatioData = timeSeries.verticalRatios,
           let timestamps = timeSeries.timestampsS {
            
            var verticalRatioPoints: [DataPoint] = []
            
            for (index, verticalRatio) in verticalRatioData.enumerated() {
                if index < timestamps.count,
                   let timestamp = timestamps[index] {
                    let time = baseTime.addingTimeInterval(TimeInterval(timestamp))
                    
                    // 只處理有效的垂直比率值 (3-15%是合理範圍)
                    if let ratioValue = verticalRatio,
                       ratioValue > 0 && ratioValue < 30 && ratioValue.isFinite {
                        verticalRatioPoints.append(DataPoint(time: time, value: ratioValue))
                    }
                }
            }
            
            self.verticalRatios = downsampleData(verticalRatioPoints, maxPoints: 500)
        }
        
        // 處理步態分析數據 - 地面接觸時間 (毫秒) 
        if let groundContactData = timeSeries.groundContactTimesMs,
           let timestamps = timeSeries.timestampsS {
            
            var groundContactPoints: [DataPoint] = []
            
            for (index, contactTime) in groundContactData.enumerated() {
                if index < timestamps.count,
                   let timestamp = timestamps[index] {
                    let time = baseTime.addingTimeInterval(TimeInterval(timestamp))
                    
                    // 只處理有效的地面接觸時間值 (150-400毫秒是合理範圍)
                    if let contactValue = contactTime,
                       contactValue > 100 && contactValue < 500 && contactValue.isFinite {
                        groundContactPoints.append(DataPoint(time: time, value: contactValue))
                    }
                }
            }
            
            self.groundContactTimes = downsampleData(groundContactPoints, maxPoints: 500)
        }
        
        // 處理步態分析數據 - 垂直振幅 (毫米)
        if let verticalOscillationData = timeSeries.verticalOscillationsMm,
           let timestamps = timeSeries.timestampsS {
            
            var verticalOscillationPoints: [DataPoint] = []
            
            for (index, oscillation) in verticalOscillationData.enumerated() {
                if index < timestamps.count,
                   let timestamp = timestamps[index] {
                    let time = baseTime.addingTimeInterval(TimeInterval(timestamp))
                    
                    // 只處理有效的垂直振幅值 (50-150毫米是合理範圍)
                    if let oscillationValue = oscillation,
                       oscillationValue > 30 && oscillationValue < 200 && oscillationValue.isFinite {
                        verticalOscillationPoints.append(DataPoint(time: time, value: oscillationValue))
                    }
                }
            }
            
            self.verticalOscillations = downsampleData(verticalOscillationPoints, maxPoints: 500)
        }
        
        // 處理步頻數據 (每分鐘步數)
        if let cadenceData = timeSeries.cadencesSpm,
           let timestamps = timeSeries.timestampsS {

            var cadencePoints: [DataPoint] = []

            for (index, cadence) in cadenceData.enumerated() {
                if index < timestamps.count,
                   let timestamp = timestamps[index] {
                    let time = baseTime.addingTimeInterval(TimeInterval(timestamp))

                    // 只處理有效的步頻值 (120-220 spm是合理範圍)
                    if let cadenceValue = cadence,
                       cadenceValue > 100 && cadenceValue < 250 && cadenceValue != 0 {
                        cadencePoints.append(DataPoint(time: time, value: Double(cadenceValue)))
                    }
                }
            }

            self.cadences = downsampleData(cadencePoints, maxPoints: 500)
        }
    }
    
    /// 數據降採樣以提升圖表效能
    private func downsampleData(_ dataPoints: [DataPoint], maxPoints: Int) -> [DataPoint] {
        guard dataPoints.count > maxPoints else { return dataPoints }
        
        let step = dataPoints.count / maxPoints
        var sampledPoints: [DataPoint] = []
        
        for i in stride(from: 0, to: dataPoints.count, by: step) {
            sampledPoints.append(dataPoints[i])
        }
        
        // 確保包含最後一個點
        if let lastPoint = dataPoints.last, sampledPoints.last != lastPoint {
            sampledPoints.append(lastPoint)
        }
        
        return sampledPoints
    }
    
    // MARK: - 數據載入
    
    /// 載入運動詳細資料（只載入一次，不支援刷新）
    func loadWorkoutDetail() async {
        // 如果已經載入過，直接返回
        if state.hasData {
            return
        }

        await executeTask(id: TaskID("load_workout_detail_\(workout.id)"), cooldownSeconds: 5) {
            await self.performLoadWorkoutDetail()
        }
    }
    
    /// 重新載入運動詳細資料（用於下拉刷新）
    func refreshWorkoutDetail() async {
        await executeTask(id: TaskID("refresh_workout_detail_\(workout.id)"), cooldownSeconds: 5) {
            await self.performRefreshWorkoutDetail()
        }
    }
    
    /// 取消載入任務
    func cancelLoadingTasks() {
        cancelAllTasks()
    }

    // MARK: - AC-IOS-ANALYTICS-P1-10

    /// Track workout_analysis_view once per view presentation (dedup by hasTrackedAnalyticsView).
    /// No-op when workoutDetail is nil (data not yet loaded) or already tracked.
    func markAnalyticsViewTracked(workoutId: String, hasCoachNotes: Bool) {
        guard !hasTrackedAnalyticsView else { return }
        hasTrackedAnalyticsView = true
        let analyticsService: AnalyticsService = DependencyContainer.shared.resolve()
        analyticsService.track(.workoutAnalysisView(workoutId: workoutId, hasCoachNotes: hasCoachNotes))
    }

    @MainActor
    func markPBMomentShown() {
        if let update = pendingPBMomentUpdate {
            PersonalBestCelebrationStorage.markCelebrationAsShown(for: update)
        }
        // Mark any badges that were part of the shown celebration so they don't repeat.
        pendingCelebrationContent?.badges.forEach { shownBadgeIds.insert($0.badgeId) }
        pendingPBMomentUpdate = nil
        pendingCelebrationContent = nil
    }

    // MARK: - Celebration Content Derivation

    @MainActor
    private func deriveCelebrationContent() {
        // If cache is absent, kick off a one-shot fetch then retry.
        // summaryFetchAttempted guards against infinite retry on persistent failure.
        if achievementRepository.cachedSummary == nil && !summaryFetchAttempted {
            summaryFetchAttempted = true
            Task { [weak self] in
                guard let self else { return }
                _ = try? await achievementRepository.fetchSummary(forceRefresh: false)
                await MainActor.run {
                    self.deriveCelebrationContent()
                }
            }
            return
        }

        let pb = pendingPBMomentUpdate
        // Badges are scoped to the currently-viewed workout, independent of which
        // workout's PB triggered the celebration. Using pb?.workoutId here would
        // mis-attribute badges when a stale pendingPBMomentUpdate is present.
        let newBadges = newlyUnlockedBadges(forWorkoutId: workout.id)

        if let pb, !newBadges.isEmpty {
            pendingCelebrationContent = .pbWithBadges(pb, newBadges)
        } else if let pb {
            pendingCelebrationContent = .pbOnly(pb)
        } else if !newBadges.isEmpty {
            pendingCelebrationContent = .badgesOnly(newBadges)
        } else {
            pendingCelebrationContent = nil
        }
    }

    /// Returns badges that are unlocked for `workoutId` and have not yet been shown in this VM.
    @MainActor
    private func newlyUnlockedBadges(forWorkoutId workoutId: String) -> [AchievementBadge] {
        let allBadges = achievementRepository.cachedSummary?.badgeGroups.flatMap { $0.badges } ?? []
        return allBadges.filter { badge in
            guard badge.status == .unlocked else { return false }
            guard !shownBadgeIds.contains(badge.badgeId) else { return false }
            guard let sourceParams = badge.sourceRef?.summaryParams else { return false }
            if case .string(let s) = sourceParams["workout_id"], s == workoutId {
                return true
            }
            return false
        }
    }

    func trackPBMoment(action: String, entry: String = "workout_detail") {
        guard let update = pendingPBMomentUpdate ?? personalBestUpdatesForWorkout.first else { return }
        let analyticsService: AnalyticsService = DependencyContainer.shared.resolve()
        analyticsService.track(.pbMoment(
            action: action,
            distance: update.distance,
            entry: entry,
            isFirstRecord: update.isFirstRecord
        ))
    }
    
    @MainActor
    private func performRefreshWorkoutDetail() async {
        // 保持當前數據，設置載入中狀態
        state = .loading

        do {
            // 檢查任務是否被取消
            try Task.checkCancellation()

            // ✅ Clean Architecture: 使用 Repository 強制刷新詳細數據
            let response = try await repository.refreshWorkoutDetail(id: workout.id)

            // 檢查任務是否被取消
            try Task.checkCancellation()

            // 圖表資料整份換掉（清空 → 處理 → 重算 Y 軸），三條路徑同一支。
            self.applyDerivedSeries(from: response)

            // 更新狀態
            self.state = .loaded(response)
            await refreshPersonalBestMomentIfNeeded()
            // 手動刷新是強制回源，它這一份必定新於 loading 期間收到的 Track B
            // （那是更早的 `getWorkoutDetail` 丟出去的）。所以這裡是**丟掉**、不是套用，
            // 否則會拿舊的背景資料蓋掉使用者剛剛主動要來的新資料（外審第三輪 D04／E03／E11）。
            self.discardPendingRefreshedDetail()

            Logger.firebase(
                "運動詳情刷新成功",
                level: .info,
                labels: ["module": "WorkoutDetailViewModelV2", "action": "refresh_detail"],
                jsonPayload: [
                    "workout_id": workout.id,
                    "activity_type": response.activityType
                ]
            )

        } catch is CancellationError {
            Logger.debug("[WorkoutDetailViewModelV2] 刷新任務被取消")
            // 取消時不更新狀態，保持原有數據
        } catch {
            self.state = .error(error.toDomainError())

            // 記錄詳細錯誤資訊到 Firebase Cloud Logging
            let errorDetails: [String: Any] = [
                "error_type": String(describing: type(of: error)),
                "error_description": error.localizedDescription,
                "error_domain": (error as NSError).domain,
                "error_code": (error as NSError).code,
                "workout_id": workout.id,
                "activity_type": workout.activityType,
                "has_cached_detail": workoutDetail != nil,
                "context": "workout_detail_refresh"
            ]

            Logger.firebase("Workout detail refresh failed with detailed error info",
                          level: .error,
                          labels: ["cloud_logging": "true", "component": "WorkoutDetailViewModelV2", "operation": "refreshWorkoutDetail"],
                          jsonPayload: errorDetails)
        }
    }

    @MainActor
    private func performLoadWorkoutDetail() async {
        state = .loading

        do {
            // 檢查任務是否被取消
            try Task.checkCancellation()

            // ✅ Clean Architecture: 使用 Repository 獲取詳細數據（自動處理緩存）
            let response = try await repository.getWorkoutDetail(id: workout.id)

            // 檢查任務是否被取消
            try Task.checkCancellation()

            // 圖表資料整份換掉（清空 → 處理 → 重算 Y 軸），三條路徑同一支。
            self.applyDerivedSeries(from: response)

            // 更新狀態
            self.state = .loaded(response)
            await refreshPersonalBestMomentIfNeeded()
            // 主路徑跑完之前收到的那一份 Track B 刷新在這裡補上（外審 D04）。
            // 放在 PB 之後：PB 那一支的順序被 `AC-PBM-03` 釘住（`.loaded` 之後才認 PB），
            // 而一般的背景回寫路徑本來也不重跑 PB，兩條保持一致。
            self.applyPendingRefreshedDetailIfNeeded()

            Logger.firebase(
                "運動詳情載入成功",
                level: .info,
                labels: ["module": "WorkoutDetailViewModelV2", "action": "load_detail"],
                jsonPayload: [
                    "workout_id": workout.id,
                    "activity_type": response.activityType
                ]
            )

        } catch is CancellationError {
            Logger.debug("[WorkoutDetailViewModelV2] 載入任務被取消")
            // 取消時不更新狀態
        } catch {
            self.state = .error(error.toDomainError())

            // 記錄詳細錯誤資訊到 Firebase Cloud Logging
            let errorDetails: [String: Any] = [
                "error_type": String(describing: type(of: error)),
                "error_description": error.localizedDescription,
                "error_domain": (error as NSError).domain,
                "error_code": (error as NSError).code,
                "workout_id": workout.id,
                "activity_type": workout.activityType,
                "has_cached_detail": workoutDetail != nil,
                "context": "workout_detail_load"
            ]

            Logger.firebase("Workout detail load failed with detailed error info",
                          level: .error,
                          labels: ["cloud_logging": "true", "component": "WorkoutDetailViewModelV2", "operation": "loadWorkoutDetail"],
                          jsonPayload: errorDetails)
        }
    }

    @MainActor
    private func refreshPersonalBestMomentIfNeeded() async {
        guard state.hasData else { return }

        do {
            let oldProfile = try await userProfileRepository.getUserProfile()
            let newProfile = try await userProfileRepository.refreshUserProfile()
            let oldData = oldProfile.personalBestV2?["race_run"]
            let newData = newProfile.personalBestV2?["race_run"]

            let workoutUpdates = makePersonalBestUpdatesForWorkout(
                oldData: oldData,
                newData: newData,
                workoutId: workout.id
            )
            personalBestUpdatesForWorkout = workoutUpdates

            await userProfileRepository.detectPersonalBestUpdates(
                oldData: oldData,
                newData: newData,
                workoutId: workout.id
            )
            pendingPBMomentUpdate = userProfileRepository.getPendingCelebrationUpdate()
            deriveCelebrationContent()

            if pendingPBMomentUpdate != nil {
                trackPBMoment(action: "view")
            }
        } catch {
            Logger.debug("[WorkoutDetailViewModelV2] PB Moment profile refresh skipped: \(error.localizedDescription)")
        }
    }

    private func makePersonalBestUpdatesForWorkout(
        oldData: [String: [PersonalBestRecordV2]]?,
        newData: [String: [PersonalBestRecordV2]]?,
        workoutId: String
    ) -> [PersonalBestUpdate] {
        guard let newData else { return [] }

        var updates: [PersonalBestUpdate] = []
        for (distance, newRecords) in newData {
            guard let newBest = newRecords.first, newBest.workoutId == workoutId else { continue }

            let oldBest = oldData?[distance]?.first
            let improvement = max((oldBest?.completeTime ?? newBest.completeTime) - newBest.completeTime, 0)
            updates.append(PersonalBestUpdate(
                distance: distance,
                oldTime: oldBest?.completeTime,
                newTime: newBest.completeTime,
                improvementSeconds: improvement,
                workoutDate: newBest.workoutDate,
                workoutId: newBest.workoutId,
                detectedAt: Date(),
                isFirstRecord: oldBest == nil
            ))
        }

        let sorted = updates.sorted {
            if $0.improvementSeconds == $1.improvementSeconds {
                return $0.distancePriority > $1.distancePriority
            }
            return $0.improvementSeconds > $1.improvementSeconds
        }
        return sorted.map { update in
            var mutable = update
            mutable.relatedUpdateCount = max(sorted.count - 1, 0)
            return mutable
        }
    }
    
    // MARK: - 格式化方法
    
    var workoutType: String {
        workout.activityType
    }
    
    var duration: String {
        let duration = workout.duration
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var distance: String? {
        guard let distance = workout.distance else { return nil }
        let unit = MainActor.assumeIsolated { UnitManager.shared.currentUnitSystem }
        if distance >= 1000 {
            let km = distance / 1000
            switch unit {
            case .metric:
                return String(format: "%.2f km", km)
            case .imperial:
                return String(format: "%.2f mi", km * 0.621371)
            }
        } else {
            switch unit {
            case .metric:
                return String(format: "%.0f m", distance)
            case .imperial:
                return String(format: "%.0f ft", distance * 3.28084)
            }
        }
    }
    
    var calories: String? {
        guard let calories = workout.calories else { return nil }
        return String(format: "%.0f kcal", calories)
    }
    
    var pace: String? {
        guard let paceSecondsPerKm = workout.displayPaceSecondsPerKm else { return nil }
        return MainActor.assumeIsolated {
            UnitManager.shared.formatPace(secondsPerKm: paceSecondsPerKm)
        }
    }
    
    var averageHeartRate: String? {
        return workout.basicMetrics?.avgHeartRateBpm.map { "\($0) bpm" }
    }
    
    var maxHeartRate: String? {
        return workout.basicMetrics?.maxHeartRateBpm.map { "\($0) bpm" }
    }
    
    var dynamicVdot: String? {
        return workout.dynamicVdot.map { String(format: "%.1f", $0) }
    }

    var currentRPE: Double? {
        return workoutDetail?.advancedMetrics?.rpe ?? workout.advancedMetrics?.rpe
    }
    
    var trainingType: String? {
        guard let type = workout.trainingType else { return nil }
        
        switch type.lowercased() {
        case "easy_run", "easy":
            return L10n.Training.TrainingType.easy.localized
        case "recovery_run":
            return L10n.Training.TrainingType.recovery.localized
        case "long_run":
            return L10n.Training.TrainingType.long.localized
        case "tempo":
            return L10n.Training.TrainingType.tempo.localized
        case "threshold":
            return L10n.Training.TrainingType.threshold.localized
        case "interval":
            return L10n.Training.TrainingType.interval.localized
        case "fartlek":
            return L10n.Training.TrainingType.fartlek.localized
        case "combination":
            return L10n.Training.TrainingType.combination.localized
        case "hill_training":
            return L10n.Training.TrainingType.hill.localized
        case "race":
            return L10n.Training.TrainingType.race.localized
        case "rest":
            return L10n.Training.TrainingType.rest.localized
        default:
            return type
        }
    }
    
    // MARK: - 圖表相關屬性
    
    var maxHeartRateString: String {
        guard let max = heartRates.map({ $0.value }).max(), !heartRates.isEmpty else { return "--" }
        return "\(Int(max)) bpm"
    }
    
    var minHeartRateString: String {
        guard let min = heartRates.map({ $0.value }).min(), !heartRates.isEmpty else { return "--" }
        return "\(Int(min)) bpm"
    }
    
    var chartAverageHeartRate: Double? {
        guard !heartRates.isEmpty else { return nil }
        let sum = heartRates.reduce(0.0) { $0 + $1.value }
        return sum / Double(heartRates.count)
    }
} 
