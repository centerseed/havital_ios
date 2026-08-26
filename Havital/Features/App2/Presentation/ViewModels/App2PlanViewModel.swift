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

    private let planV2DataSource: TrainingPlanV2RemoteDataSourceProtocol
    private let workoutRepository: WorkoutRepository
    /// 冷啟快照。與首頁今日課表卡讀寫**同一組 key**，不各存一份週課表。
    private let snapshots: any App2SnapshotStoring

    init(
        planV2DataSource: TrainingPlanV2RemoteDataSourceProtocol? = nil,
        workoutRepository: WorkoutRepository? = nil,
        snapshots: (any App2SnapshotStoring)? = nil
    ) {
        let container = DependencyContainer.shared
        self.planV2DataSource = planV2DataSource ?? TrainingPlanV2RemoteDataSource()
        self.snapshots = snapshots ?? App2FileSnapshotStore.shared

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
        if !hasLoaded { hydrateFromSnapshot() }
        isLoading = !hasLoaded && week == nil
        defer {
            isLoading = false
            hasLoaded = true
            lastLoadedAt = Date()
        }

        do {
            let status = try await planV2DataSource.getPlanStatus()
            snapshots.save(status, for: .planStatus)
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

            let dto = try await planV2DataSource.getWeeklyPlan(planId: planId)
            snapshots.save(dto, for: .weeklyPlan)
            let completed = await completedDistanceKmThisWeek()
            apply(dto: dto, planStatus: status, completedKm: completed)
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

    /// 週課表 ＋ 每日詳情的組裝。網路回應與冷啟快照都走這一支。
    private func apply(dto: WeeklyPlanV2DTO, planStatus: PlanStatusV2Response, completedKm: Double?) {
        isPlanGenerated = true
        week = App2Sourced(
            Self.planWeek(dto: dto, planStatus: planStatus, completedKm: completedKm),
            origin: .live(endpoint: "GET /v2/plan/weekly/{plan_id} + GET /v2/workouts")
        )
        let weekStart = Self.currentWeekStart()
        dayDetails = Dictionary(
            uniqueKeysWithValues: dto.days.compactMap { day -> (Int, App2SessionDetail)? in
                guard let detail = App2SessionDetailProjection.detail(day: day, weekStart: weekStart)
                else { return nil }
                return (day.dayIndex, detail)
            }
        )
    }

    /// 冷啟：plan status ＋ 本週課表都在快照裡才渲染。
    ///
    /// **已完成量（`completedKm`）不進快照**：它是本週紀錄現算出來的，冷啟給的是
    /// 「上一次算的值」而不是「上一次的回應」，兩者的腐爛速度不一樣。先留白，
    /// 這一輪網路回來就有了。
    private func hydrateFromSnapshot() {
        guard let status = snapshots.load(PlanStatusV2Response.self, for: .planStatus)?.value,
              let dto = snapshots.load(WeeklyPlanV2DTO.self, for: .weeklyPlan)?.value,
              App2HomeViewModel.isWeeklyPlan(dto, boundTo: status) else { return }
        apply(dto: dto, planStatus: status, completedKm: nil)
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
        dto: WeeklyPlanV2DTO,
        planStatus: PlanStatusV2Response,
        completedKm: Double?,
        /// 測試可指定「今天」；nil = 用裝置日曆。
        todayIndex: Int? = nil,
        /// 測試可指定當週週一（日起點）；nil = 用裝置日曆推。
        weekStart: Date? = nil
    ) -> App2PlanWeek {
        let today = todayIndex ?? Self.todayDayIndex()
        let start = weekStart ?? Self.currentWeekStart()
        let weekNumber = dto.weekOfTraining ?? dto.weekOfPlan ?? planStatus.currentWeek
        let climateByDayIndex = Dictionary(
            (dto.climate ?? []).map { ($0.dayIndex, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let days: [App2PlanDay] = dto.days.map { day in
            // 沒有 primary activity ＝ 休息日。
            let isRest = day.primary == nil
            let dayType = isRest ? DayType.rest : Self.dayType(day.primary)
            return App2PlanDay(
                id: day.dayIndex,
                weekdayLabel: Self.weekdayLabel(dayIndex: day.dayIndex),
                dateLabel: Self.dateLabel(dayIndex: day.dayIndex, weekStart: start),
                // 課型顯示字走既有的 `DayType.localizedName`（三語已齊），
                // 不再把後端的 `run_type` 識別字（`easy`／`lsd`）直接印到畫面上。
                tag: dayType?.localizedName
                    ?? (isRest ? L10n.App2.Plan.rest.localized : (day.category ?? day.dayTarget)),
                dayType: dayType,
                // 設計 frame-01 的「課表」行是「量 · 配速」（`4.0 km · 7:17/km`），
                // 不是裸距離；與今日課表卡走同一支 `contentLine`，不另做一份格式。
                planned: Self.contentLine(day.primary, totalDistanceKm: day.distanceKm),
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
            totalWeeks: dto.totalWeeks ?? planStatus.totalWeeks,
            targetDistanceKm: dto.totalDistance,
            completedDistanceKm: completedKm,
            intensityLowMinutes: dto.intensityTotalMinutes.map { Int($0.low.rounded()) },
            intensityMediumMinutes: dto.intensityTotalMinutes.map { Int($0.medium.rounded()) },
            intensityHighMinutes: dto.intensityTotalMinutes.map { Int($0.high.rounded()) },
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

    /// 今天的 `day_index`（1 = 週一 … 7 = 週日）。
    static func todayDayIndex() -> Int {
        // Calendar.weekday: 1 = 週日 … 7 = 週六。
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 ? 7 : weekday - 1
    }

    /// 當週週一的日起點（裝置日曆）。
    ///
    /// 不用 `dateInterval(of: .weekOfYear)`：那條的週首隨 locale 變（zh-TW 是週日），
    /// 而 `day_index` 的週首固定是週一。
    nonisolated static func currentWeekStart(reference: Date = Date(), calendar: Calendar = .current) -> Date {
        let weekday = calendar.component(.weekday, from: reference)     // 1 = 週日
        let mondayBased = weekday == 1 ? 7 : weekday - 1                // 1 = 週一
        let startOfToday = calendar.startOfDay(for: reference)
        return calendar.date(byAdding: .day, value: -(mondayBased - 1), to: startOfToday) ?? startOfToday
    }

    /// 每日卡標題的日期（設計 frame-01：`週一 8/10`）。週起點 ＋ `day_index - 1` 天。
    nonisolated static func dateLabel(dayIndex: Int, weekStart: Date, calendar: Calendar = .current) -> String {
        guard let date = calendar.date(byAdding: .day, value: dayIndex - 1, to: weekStart) else { return "" }
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(month)/\(day)"
    }

    static func plannedDistanceLabel(_ primary: PrimaryActivityDTO?) -> String? {
        guard case .run(let run) = primary, let km = run.distanceKm, km > 0 else { return nil }
        return String(format: "%.1f km", km)
    }

    /// 每日卡的敘述行 —— 後端 `day_target`（已在地化、三語由後端 `content_lang` 決定）。
    /// 空字串當成沒有，不畫空行。
    static func descriptionLine(_ day: DayDetailDTO) -> String? {
        let text = day.dayTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// `run_type` → 既有的 `DayType`。肌力／交叉訓練沒有跑步課型，各自映到對應的 case。
    static func dayType(_ primary: PrimaryActivityDTO?) -> DayType? {
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
    static func effectiveSegments(_ run: RunActivityDTO) -> [RunSegmentDTO] {
        if let segments = run.segments, !segments.isEmpty { return segments }
        guard let interval = run.interval, interval.repeats > 0 else { return [] }
        return [RunSegmentDTO(
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
            work: SegmentEffortDTO(
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
            recovery: SegmentEffortDTO(
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
    static func contentLine(_ primary: PrimaryActivityDTO?, totalDistanceKm: Double? = nil) -> String? {
        guard case .run(let run) = primary else { return nil }

        if let line = intervalContentLine(run) { return line }

        var parts: [String] = []
        if let km = totalDistanceKm ?? run.distanceKm, km > 0 {
            parts.append(String(format: "%.1f km", km))
        } else if let minutes = run.durationMinutes {
            parts.append("\(minutes) min")
        }
        if let pace = dayPace(run) {
            parts.append("\(pace)/km")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// 日級配速。**一律是處方配速**（2026-05 使用者裁決，2026-08-26 起 App2 全面適用）：
    /// 熱調整後的值只出現在訓練詳情的熱適應卡，不得在課表／卡片上頂替處方值。
    ///
    /// 間歇課的 `primary.pace` 缺席（dev 實測只有 `climate_adjusted_pace`），
    /// 這時從處方分段推導 —— 主課段的 `work_pace`（4×400m 那天是 `4:50`）。
    /// 推不出來就回 nil（那一段不顯示），不拿熱調整值充數。
    static func dayPace(_ run: RunActivityDTO) -> String? {
        if let pace = run.pace { return pace }
        return effectiveSegments(run)
            .first { $0.kind == "interval" }
            .flatMap { $0.work?.pace ?? $0.pace }
    }

    /// 間歇日的「課表」行 ＝ **主課段（含組間恢復）總距離 ＋ 該段總時間**
    /// （2026-08-26 使用者裁決；設計 dc.html「今日課表 · 間歇」的 `1.6 km · 11:00`
    /// 那一行）。不是全程距離、也不是均配。
    ///
    /// 組間恢復的段數是 `repeats - 1`（最後一趟跑完就進緩和）—— dev 實測
    /// 4×400m ＋ 200m 恢復的 `primary.distance_km` 是 `2.2`＝`1.6 + 3×0.2`，
    /// 與這個算法一致。組不出距離或時間就少那一欄，兩欄都組不出就整行不顯示。
    static func intervalContentLine(_ run: RunActivityDTO) -> String? {
        guard let segment = effectiveSegments(run).first(where: { $0.kind == "interval" }),
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
            parts.append(durationLabel(seconds: workSeconds * Double(repeats) + recoverySeconds * recoveryCount))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// 一段 effort 的距離（km）。距離缺席時回 nil —— 不用時長換算，那需要配速。
    static func effortDistanceKm(_ effort: SegmentEffortDTO) -> Double? {
        if let km = effort.distanceKm, km > 0 { return km }
        if let metres = effort.distanceM, metres > 0 { return Double(metres) / 1000 }
        return nil
    }

    /// 一段 effort 的時間（秒）。明寫的時長優先；只有距離＋配速時才換算。
    static func effortSeconds(_ effort: SegmentEffortDTO) -> Double? {
        if let seconds = effort.durationSeconds, seconds > 0 { return Double(seconds) }
        if let minutes = effort.durationMinutes, minutes > 0 { return Double(minutes) * 60 }
        guard let km = effortDistanceKm(effort),
              let perKm = paceSeconds(effort.pace ?? effort.basePace) else { return nil }
        return km * perKm
    }

    /// `4:50` → 290 秒／km。格式對不上就回 nil，不猜。
    static func paceSeconds(_ pace: String?) -> Double? {
        guard let pace else { return nil }
        let parts = pace.split(separator: ":")
        guard parts.count == 2,
              let minutes = Double(parts[0]), let seconds = Double(parts[1]) else { return nil }
        return minutes * 60 + seconds
    }

    /// `12:17`／`1:02:30`（設計的數字一律等寬 mono，這裡只管字串形狀）。
    static func durationLabel(seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// 強度徽章（設計 dc.html 今日課表卡標題列右側的方角 chip）。
    ///
    /// payload 的 `target_intensity` 優先；**缺席時退到課型**（2026-08-26 裁決：
    /// 這顆 chip 每張今日卡都要有）。退法是結構化的 `DayType` → 強度級距對照，
    /// 不是對顯示字做詞表比對；課型也判不出來才回 nil。
    static func intensityLabel(_ primary: PrimaryActivityDTO?) -> String? {
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

    private static func temperatureLabel(_ climate: ClimateDayDTO?) -> String? {
        guard let climate else { return nil }
        return String(format: "%.0f°C", climate.feelsLikeTempC)
    }
}
