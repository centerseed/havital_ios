import Foundation

// MARK: - App2PlanViewModel
/// Presentation Layer — 2.0 課表頁（`DESIGN-app2-decision-chain-api.md` §3.3）。
///
/// 週目標量／每日安排來自 `GET /v2/plan/weekly/{plan_id}`；**已完成量不在該 payload 裡**
/// （§3.3 第 2 列），要另外從 `GET /v2/workouts` 的本週紀錄合併計算。
@MainActor
final class App2PlanViewModel: ObservableObject, TaskManageable, App2Revalidating {

    @Published private(set) var isLoading = true
    @Published private(set) var week: App2Sourced<App2PlanWeek>?
    /// 後端明說本週還沒有課表（`current_week_plan_id == nil`）。
    /// 讀取失敗不算 —— 那時 `week` 保持舊值或退樣本，這個旗標維持 true。
    @Published private(set) var isPlanGenerated = true
    /// 每日卡點下去要開的訓練詳情（設計 frame-02），key = `day_index`。
    /// **與課表頁同一份 payload**，詳情頁不再打端點；休息日不在這張表裡（不進詳情）。
    @Published private(set) var dayDetails: [Int: App2SessionDetail] = [:]
    private(set) var hasLoaded = false
    private(set) var lastLoadedAt: Date?

    nonisolated let taskRegistry = TaskRegistry()

    /// **課表資料只有這一個入口。**（2026-08-26 架構收斂）
    /// 冷啟先渲染的那一份與這一輪要重驗的那一份，都從它拿 —— App2 不再自己持有
    /// `TrainingPlanV2RemoteDataSource`，也不再另存一份週課表快照。
    private let planRepository: TrainingPlanV2Repository
    private let workoutRepository: WorkoutRepository

    init(
        planRepository: TrainingPlanV2Repository? = nil,
        workoutRepository: WorkoutRepository? = nil
    ) {
        let container = DependencyContainer.shared

        if let planRepository {
            self.planRepository = planRepository
        } else {
            if !container.isRegistered(TrainingPlanV2Repository.self) {
                container.registerTrainingPlanV2Module()
            }
            self.planRepository = container.resolve() as TrainingPlanV2Repository
        }

        if let workoutRepository {
            self.workoutRepository = workoutRepository
        } else {
            if !container.isRegistered(WorkoutRepository.self) {
                container.registerWorkoutModule()
            }
            self.workoutRepository = container.resolve() as WorkoutRepository
        }
    }

    deinit {
        cancelAllTasks()
    }

    func revalidate() async {
        // 冷啟第一輪：先把上一次的週課表渲染出來，這一輪的網路變成背景刷新。
        if !hasLoaded { hydrateFromCache() }
        isLoading = !hasLoaded && week == nil
        defer {
            isLoading = false
            hasLoaded = true
            lastLoadedAt = Date()
        }

        do {
            // `forceRefresh` ＝ 這一輪一定走網路。SWR 的「先舊後新」由上面那一行
            // 的快取渲染負責，不是靠 repository 的 cooldown 決定要不要重驗。
            let status = try await planRepository.getPlanStatus(forceRefresh: true)
            guard let planId = status.currentWeekPlanId else {
                // **本週沒有課表就說沒有。** 這裡原本退樣本，畫面上會出現一整週
                // 「第 5 週 / 22」的假課表，而首頁同時說「本週課表尚未產生」——
                // 2026-08-25 用戶截圖上那組矛盾就是這麼來的。
                Logger.debug("[App2PlanVM] 本週尚無課表 (next_action=\(status.nextAction))")
                week = nil
                isPlanGenerated = false
                return
            }
            isPlanGenerated = true

            // `fetchWeeklyPlan` ＝ 走網路並寫回 repository 快取（下一次冷啟就是它）。
            let plan = try await planRepository.fetchWeeklyPlan(planId: planId)
            let completed = await completedDistanceKmThisWeek()
            apply(plan: plan, planStatus: status, completedKm: completed)
        } catch {
            // 取消不是失敗（`AGENTS.md` 陷阱 2）：下拉刷新的 task 被收掉時
            // in-flight 請求會回 -999，當成失敗會把真課表換成樣本。
            guard !error.isCancellationError else { return }
            Logger.debug("[App2PlanVM] 週課表取得失敗,退樣本: \(error)")
            guard week == nil else { return }       // SWR：重驗失敗時保留舊資料
            week = App2Sourced(
                App2StubFixtures.planWeek,
                origin: .stub(pendingSection: App2StubFixtures.Section.offline)
            )
        }
    }

    /// 週課表 ＋ 每日詳情的組裝。網路回應與冷啟快取都走這一支。
    private func apply(plan: WeeklyPlanV2, planStatus: PlanStatusV2Response, completedKm: Double?) {
        isPlanGenerated = true
        week = App2Sourced(
            Self.planWeek(plan: plan, planStatus: planStatus, completedKm: completedKm),
            origin: .live(endpoint: "GET /v2/plan/weekly/{plan_id} + GET /v2/workouts")
        )
        let weekStart = App2WeekCalendar.currentWeekStart()
        dayDetails = Dictionary(
            uniqueKeysWithValues: plan.days.compactMap { day -> (Int, App2SessionDetail)? in
                guard let detail = App2SessionDetailProjection.detail(day: day, weekStart: weekStart)
                else { return nil }
                return (day.dayIndex, detail)
            }
        )
    }

    /// 冷啟：plan status ＋ 本週課表都在 repository 快取裡才渲染。
    ///
    /// **已完成量（`completedKm`）不進快取**：它是本週紀錄現算出來的，冷啟給的是
    /// 「上一次算的值」而不是「上一次的回應」，兩者的腐爛速度不一樣。先留白，
    /// 這一輪網路回來就有了。
    private func hydrateFromCache() {
        guard let status = planRepository.getCachedPlanStatus(),
              let plan = planRepository.getCachedWeeklyPlan(week: status.currentWeek),
              App2HomeViewModel.isWeeklyPlan(plan, boundTo: status) else { return }
        apply(plan: plan, planStatus: status, completedKm: nil)
    }

    #if DEBUG
    /// 測試／預覽用：直接填入本週課表，不打網路。
    func applyForTesting(week: App2Sourced<App2PlanWeek>?) {
        self.week = week
        isLoading = false
        hasLoaded = true
        lastLoadedAt = Date()
    }
    #endif

    // MARK: - Mapping

    /// 週課表投影。`map` 原本是 instance method 但沒用到任何 instance 狀態 ——
    /// 改成 static 之後可以單獨測（`App2PlanProjectionTests`）。
    static func planWeek(
        plan: WeeklyPlanV2,
        planStatus: PlanStatusV2Response,
        completedKm: Double?,
        /// 測試可指定「今天」；nil = 用裝置日曆。
        todayIndex: Int? = nil,
        /// 測試可指定當週週一（日起點）；nil = 用裝置日曆推。
        weekStart: Date? = nil
    ) -> App2PlanWeek {
        let today = todayIndex ?? App2WeekCalendar.todayDayIndex()
        let start = weekStart ?? App2WeekCalendar.currentWeekStart()
        let weekNumber = plan.weekOfTraining ?? plan.weekOfPlan ?? planStatus.currentWeek
        let climateByDayIndex = Dictionary(
            plan.climateDays.map { ($0.dayIndex, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let days: [App2PlanDay] = plan.days.map { day in
            // 沒有 primary activity ＝ 休息日。
            let primary = day.session?.primary
            let isRest = primary == nil
            let dayType = isRest ? DayType.rest : Self.dayType(primary)
            return App2PlanDay(
                id: day.dayIndex,
                weekdayLabel: Self.weekdayLabel(dayIndex: day.dayIndex),
                dateLabel: App2WeekCalendar.dateLabel(dayIndex: day.dayIndex, weekStart: start),
                // 課型顯示字走既有的 `DayType.localizedName`（三語已齊），
                // 不再把後端的 `run_type` 識別字（`easy`／`lsd`）直接印到畫面上。
                // 對不到課型就退 `day_target`（後端已在地化）。不退 `category` ——
                // 那是 run／strength／cross／rest 四值 enum，rawValue 是識別字。
                tag: dayType?.localizedName
                    ?? (isRest ? L10n.App2.Plan.rest.localized : day.dayTarget),
                dayType: dayType,
                // 設計 frame-01 的「課表」行是「量 · 配速」（`4.0 km · 7:17/km`），
                // 不是裸距離；與今日課表卡走同一支 `contentLine`，不另做一份格式。
                planned: Self.contentLine(primary, totalDistanceKm: day.distanceKm),
                description: Self.descriptionLine(day),
                // 實際值要按日期對齊 workouts；骨架階段僅在週總量層合併（見 completedKm）。
                actual: nil,
                temp: Self.temperatureLabel(climateByDayIndex[day.dayIndex]),
                isToday: day.dayIndex == today
            )
        }

        return App2PlanWeek(
            // 設計 frame-01 的週次切換器是「第 N 週 / M」，不是裸數字。
            // 「第 N 週」三語已有（1.x 週次選單在用同一條），不另開 app2 命名空間的重複字串。
            weekLabel: String(format: L10n.WeekSelector.weekNumber.localized, weekNumber),
            totalWeeks: plan.totalWeeks ?? planStatus.totalWeeks,
            targetDistanceKm: plan.totalDistance,
            completedDistanceKm: completedKm,
            intensityLowMinutes: plan.intensityTotalMinutes.map { Int($0.low.rounded()) },
            intensityMediumMinutes: plan.intensityTotalMinutes.map { Int($0.medium.rounded()) },
            intensityHighMinutes: plan.intensityTotalMinutes.map { Int($0.high.rounded()) },
            days: days
        )
    }

    private func completedDistanceKmThisWeek() async -> Double? {
        let calendar = Calendar.current
        let now = Date()
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return nil }
        let workouts = await workoutRepository.getWorkoutsInDateRangeAsync(
            startDate: interval.start,
            endDate: now
        )
        guard !workouts.isEmpty else { return nil }
        let meters = workouts
            .filter { $0.activityType.lowercased().contains("run") }
            .compactMap(\.distanceMeters)
            .reduce(0, +)
        return meters / 1000
    }

    // MARK: - Formatting

    /// `day_index` **1 = 週一 … 7 = 週日**。
    ///
    /// 原本這裡當成 0-based（`(dayIndex + 1) % 7`），星期與「今天」整整差一天。
    /// 2026-08-25 對 dev 的真實 payload 確認：`day_index: 2` 的 `reason` 寫的是
    /// 「週二安排長距離慢跑」，所以 1 = 週一。
    static func weekdayLabel(dayIndex: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        // shortWeekdaySymbols[0] 是週日；day_index 7（週日）→ 0，1…6 → 1…6。
        let index = dayIndex % 7
        return symbols.indices.contains(index) ? symbols[index] : "—"
    }

    // `todayDayIndex` / `currentWeekStart` / `dateLabel` 已搬到 `App2WeekCalendar`
    // （Domain，層中立）—— `App2StubFixtures` 在 Data 層要用同一組換算。

    static func plannedDistanceLabel(_ primary: PrimaryActivity?) -> String? {
        guard case .run(let run) = primary, let km = run.distanceKm, km > 0 else { return nil }
        return String(format: "%.1f km", km)
    }

    /// 每日卡的敘述行 —— 後端 `day_target`（已在地化、三語由後端 `content_lang` 決定）。
    /// 空字串當成沒有，不畫空行。
    static func descriptionLine(_ day: DayDetail) -> String? {
        let text = day.dayTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// `run_type` → 既有的 `DayType`。肌力／交叉訓練沒有跑步課型，各自映到對應的 case。
    static func dayType(_ primary: PrimaryActivity?) -> DayType? {
        switch primary {
        case .run(let run):
            return DayType(rawValue: run.runType.lowercased())
        case .strength:
            return .strength
        case .cross:
            return .crossTraining
        case .none:
            return .rest
        @unknown default:
            return nil
        }
    }

    /// 「課表」那一行的結構化內容（設計 frame-00 今日課表卡、frame-01 每日卡）。
    ///
    /// 全部從 payload 的結構欄位組出來，沒有一個字是編的：
    /// - 有間歇段 → `6 × 200m · 5:25/km · 組間 90 秒`
    /// - 一般跑   → `9.0 km · 7:55/km`
    /// 課表分段列表 —— 卡片摘要、配速結構圖、分段列三個投影共用的那一份。
    ///
    /// **後端對間歇課不送 `segments[]`**：dev 實測 4×400m 那天 `primary` 只有
    /// `interval`（`repeats` / `work_*` / `recovery_*`），`segments` 整個缺席。
    /// 下游全都只認 `segments[].kind == "interval"`，於是間歇課被畫成一整塊
    /// 綠色穩定段、分段列也不展開衝刺與組間恢復（2026-08-26 使用者截圖）。
    /// 這裡把 `interval` 攤平成同一種段，讓三個投影繼續走同一條路徑，
    /// 不在各自的分支裡再判一次 payload 形狀。
    static func effectiveSegments(_ run: RunActivity) -> [RunSegment] {
        if let segments = run.segments, !segments.isEmpty { return segments }
        guard let interval = run.interval, interval.repeats > 0 else { return [] }
        return [RunSegment(
            distanceKm: interval.workDistanceKm,
            distanceM: interval.workDistanceM,
            distanceDisplay: nil,
            distanceUnit: nil,
            durationMinutes: interval.workDurationMinutes,
            durationSeconds: nil,
            pace: interval.workPace,
            basePace: nil,
            climateAdjustedPace: nil,
            climateMeta: nil,
            heartRateRange: nil,
            intensity: nil,
            description: interval.workDescription,
            kind: "interval",
            repeats: interval.repeats,
            work: SegmentEffort(
                distanceKm: interval.workDistanceKm,
                distanceM: interval.workDistanceM,
                durationMinutes: interval.workDurationMinutes,
                durationSeconds: nil,
                pace: interval.workPace,
                basePace: nil,
                paceZone: nil,
                targetHrr: nil,
                recoveryType: nil
            ),
            recovery: SegmentEffort(
                distanceKm: interval.recoveryDistanceKm,
                distanceM: interval.recoveryDistanceM,
                durationMinutes: interval.recoveryDurationMinutes,
                durationSeconds: interval.recoveryDurationSeconds,
                pace: interval.recoveryPace,
                basePace: nil,
                paceZone: nil,
                targetHrr: nil,
                recoveryType: nil
            )
        )]
    }

    /// 兩者都拿不到 → nil（畫面就不顯示這一行，不用 placeholder 充數）。
    ///
    /// `totalDistanceKm` ＝ 這一天的總量（payload 的日層 `distance_km`）。給了就用它，
    /// 因為 `primary.distance_km` 在間歇課只算主課段（dev 實測 `2.2`＝4×400m 加組間
    /// 恢復），跟下面分段列的熱身 2.0 ＋ 衝刺 1.6 ＋ 緩和 1.0 加不起來
    /// （2026-08-26 使用者回報）。日層 `5.2` 才是那張卡在講的量。
    static func contentLine(_ primary: PrimaryActivity?, totalDistanceKm: Double? = nil) -> String? {
        guard case .run(let run) = primary else { return nil }

        if let line = intervalContentLine(run) { return line }

        var parts: [String] = []
        if let km = totalDistanceKm ?? run.distanceKm, km > 0 {
            parts.append(String(format: "%.1f km", km))
        } else if let minutes = run.durationMinutes {
            parts.append("\(minutes) min")
        }
        // 單位跟著用戶設定走（公制 `/km`／英制 `/mi`），走既有的 `UnitManager`，
        // 不在這裡寫死 `/km`。
        if let pace = dayPace(run) {
            parts.append(UnitManager.shared.formatPaceString(pace))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// 日級配速。**一律是處方配速**（2026-05 使用者裁決，2026-08-26 起 App2 全面適用）：
    /// 熱調整後的值只出現在訓練詳情的熱適應卡，不得在課表／卡片上頂替處方值。
    ///
    /// 間歇課的 `primary.pace` 缺席（dev 實測只有 `climate_adjusted_pace`），
    /// 這時從處方分段推導 —— 主課段的 `work_pace`（4×400m 那天是 `4:50`）。
    /// 推不出來就回 nil（那一段不顯示），不拿熱調整值充數。
    static func dayPace(_ run: RunActivity) -> String? {
        if let pace = run.pace { return pace }
        return effectiveSegments(run)
            .first { $0.segmentKind == .interval }
            .flatMap { $0.work?.pace ?? $0.pace }
    }

    /// 間歇日的「課表」行 ＝ **主課段（含組間恢復）總距離 ＋ 該段總時間**
    /// （2026-08-26 使用者裁決；設計 dc.html「今日課表 · 間歇」的 `1.6 km · 11:00`
    /// 那一行）。不是全程距離、也不是均配。
    ///
    /// 組間恢復的段數是 `repeats - 1`（最後一趟跑完就進緩和）—— dev 實測
    /// 4×400m ＋ 200m 恢復的 `primary.distance_km` 是 `2.2`＝`1.6 + 3×0.2`，
    /// 與這個算法一致。組不出距離或時間就少那一欄，兩欄都組不出就整行不顯示。
    static func intervalContentLine(_ run: RunActivity) -> String? {
        guard let segment = effectiveSegments(run).first(where: { $0.segmentKind == .interval }),
              let repeats = segment.repeats, repeats > 0,
              let work = segment.work else { return nil }
        let recoveryCount = Double(max(repeats - 1, 0))

        var parts: [String] = []
        if let workKm = effortDistanceKm(work) {
            let recoveryKm = segment.recovery.flatMap(effortDistanceKm) ?? 0
            parts.append(String(format: "%.1f km", workKm * Double(repeats) + recoveryKm * recoveryCount))
        }
        if let workSeconds = effortSeconds(work) {
            let recoverySeconds = segment.recovery.flatMap(effortSeconds) ?? 0
            parts.append(TimeFormatting.formatTime(
                Int((workSeconds * Double(repeats) + recoverySeconds * recoveryCount).rounded())
            ))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// 一段 effort 的距離（km）。距離缺席時回 nil —— 不用時長換算，那需要配速。
    static func effortDistanceKm(_ effort: SegmentEffort) -> Double? {
        if let km = effort.distanceKm, km > 0 { return km }
        if let metres = effort.distanceM, metres > 0 { return Double(metres) / 1000 }
        return nil
    }

    /// 一段 effort 的時間（秒）。明寫的時長優先；只有距離＋配速時才換算。
    static func effortSeconds(_ effort: SegmentEffort) -> Double? {
        if let seconds = effort.durationSeconds, seconds > 0 { return Double(seconds) }
        if let minutes = effort.durationMinutes, minutes > 0 { return Double(minutes) * 60 }
        guard let km = effortDistanceKm(effort),
              let perKm = (effort.pace ?? effort.basePace).flatMap(PaceFormatterHelper.paceToSeconds)
        else { return nil }
        return km * perKm
    }

    // `4:50` → 290 秒的解析走 `PaceFormatterHelper.paceToSeconds`，
    // `m:ss`／`h:mm:ss` 走 `TimeFormatting.formatTime` —— 兩支都是 `Havital/Utils/`
    // 的既有共用出口，App2 不再各留一份（2026-08-26 收斂）。

    /// 強度徽章（設計 dc.html 今日課表卡標題列右側的方角 chip）。
    ///
    /// payload 的 `target_intensity` 優先；**缺席時退到課型**（2026-08-26 裁決：
    /// 這顆 chip 每張今日卡都要有）。退法是結構化的 `DayType` → 強度級距對照，
    /// 不是對顯示字做詞表比對；課型也判不出來才回 nil。
    static func intensityLabel(_ primary: PrimaryActivity?) -> String? {
        if case .run(let run) = primary, let raw = run.targetIntensity {
            switch raw.lowercased() {
            case "low":    return L10n.App2.Session.effortChipLow.localized
            case "medium": return L10n.App2.Session.effortChipMedium.localized
            case "high":   return L10n.App2.Session.effortChipHigh.localized
            default:       break
            }
        }
        return TrainingEffortScale.chipLabel(for: dayType(primary))
    }

    /// 溫度缺席時整格不顯示（`climate[7]` 一定有溫度，legacy `climate_meta` 可能沒有）。
    private static func temperatureLabel(_ climate: ClimateDay?) -> String? {
        guard let temp = climate?.feelsLikeTempC else { return nil }
        return String(format: "%.0f°C", temp)
    }
}
