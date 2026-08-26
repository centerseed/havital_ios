import Foundation

// MARK: - App2PlanEndProjection
/// 計畫結束態的純投影（設計 **frame-00g** 首頁結束態／兩種語意、
/// **frame-00g2** 整期總結與課表 tab 結束態）。
///
/// 「payload → 畫面欄位」全部在這裡，**不碰網路**，所以三條分岔都能單獨測
/// （`HavitalTests/Features/App2/App2PlanEndProjectionTests.swift`）：
///
/// 1. **結束態偵測** —— 只有 `next_action == "training_completed"` 才成立。
///    這是與週回顧時機卡的**互斥點**：同一個事實同時決定「結束卡出現」與
///    「週回顧卡收掉」（`App2HomeViewModel.weekReviewState` 的第一道 guard），
///    兩邊讀的是同一欄，不會出現兩張卡同屏。
/// 2. **語意分岔** —— race vs maintenance 由 overview 的 `target_type` 決定。
/// 3. **降級** —— 沒有實際完賽成績就退目標＋當時預估並隱藏差值；沒有敘事就走數字版。
///
/// **為什麼投影住在 Presentation 而不是 Domain**：它組的是畫面欄位（已在地化的
/// 標籤、已格式化的日期），與 `App2HomeViewModel` 的 `goalCard`／
/// `App2MetricDetailProjection` 同一層、同一種東西。
enum App2PlanEndProjection {

    /// 後端 `next_action` 表示計畫已走完的那個值（`domains/plan_week/service.py:1218`）。
    static let completedAction = "training_completed"

    /// 這份 plan status 是不是結束態。
    ///
    /// **只認 `next_action`。** 不用 `current_week > total_weeks` 自己再判一次 ——
    /// 那是後端的判準（含使用者時區的週界），client 重算就是第二份答案。
    static func isCompleted(_ planStatus: PlanStatusV2Response?) -> Bool {
        planStatus?.nextAction == completedAction
    }

    /// `target_type` → 結束語意。
    ///
    /// 只有 `race_run` 是賽事語意；`beginner`／`maintenance`／未知一律走
    /// 「訓練期完成」—— 那些計畫沒有賽事日，**不得提賽事成績**。
    ///
    /// ⚠️ `PlanStatusV2Response.targetType` 的註解寫的是
    /// `"race" | "beginner" | "maintenance"`，但後端實際交的是 overview 的原值
    /// （`domains/plan_week/service.py:1275`：`overview.get("target_type", "race_run")`）
    /// ——**`race_run`**。兩個拼法都認，免得哪天註解那一版真的出現時整個變體判錯。
    static func kind(targetType: String?) -> App2PlanEndKind {
        switch targetType?.lowercased() {
        case "race_run", "race": return .race
        default:                 return .maintenance
        }
    }

    /// 結束語意的來源優先序。
    ///
    /// **`plan status` 自己就帶 `target_type`**（與 overview 同一份文件的同一欄），
    /// 所以正常路徑不必為了判變體多打一次 `GET /v2/plan/overview`。
    /// 它缺席（舊 payload）時才退 overview。
    static func kind(planStatus: PlanStatusV2Response?, overview: PlanOverviewV2?) -> App2PlanEndKind {
        kind(targetType: planStatus?.targetType ?? overview?.targetType)
    }

    // MARK: - 首頁結束態卡

    /// 首頁結束態卡。**不是結束態就回 nil**（呼叫端據此決定要不要換掉目標卡＋今日課表卡）。
    ///
    /// - `overview`：語意分岔的來源。讀不到 → `.maintenance`（保守：不提賽事成績）。
    /// - `target`：race 變體的賽名／賽日／距離／目標成績。maintenance 不用它。
    /// - `estimatedFinish`：readiness 流的完賽預估（**當時的預估**語意，見型別註解）。
    static func card(
        planStatus: PlanStatusV2Response?,
        overview: PlanOverviewV2?,
        target: Target?,
        estimatedFinish: String?
    ) -> App2PlanEndCard? {
        guard let planStatus, isCompleted(planStatus) else { return nil }
        return makeCard(
            kind: kind(planStatus: planStatus, overview: overview),
            planStatus: planStatus,
            overview: overview,
            target: target,
            estimatedFinish: estimatedFinish
        )
    }

    /// 卡片的組裝本體 —— **不含結束態 guard**。
    ///
    /// 拆出來是為了讓 DEBUG 的走查 override（`App2DevPlanEndOverride`）能在還沒走完的
    /// 計畫上指定變體，而**組法仍然只有這一份** —— 走查看到的版式與真實結束態
    /// 是同一段程式碼組出來的，不是另畫一張長得像的卡。
    static func makeCard(
        kind: App2PlanEndKind,
        planStatus: PlanStatusV2Response?,
        overview: PlanOverviewV2?,
        target: Target?,
        estimatedFinish: String?
    ) -> App2PlanEndCard {
        let isRace = kind == .race

        return App2PlanEndCard(
            kind: kind,
            // maintenance 沒有賽事 —— 就算帳號裡還留著一個 target，也不把它畫成
            // 這份計畫的目標賽事（那是別份計畫的東西）。
            raceName: isRace ? target?.name : nil,
            raceDate: isRace ? target.map { raceDateLabel($0) } : nil,
            distanceLabel: isRace ? target.map { distanceLabel(km: $0.distanceKm) } : nil,
            totalWeeks: totalWeeks(planStatus: planStatus, overview: overview, target: target),
            targetTime: isRace ? targetTimeLabel(target) : nil,
            estimatedFinish: isRace ? estimatedFinish : nil,
            // 賽事實際成績：**沒有 producer**（無「這場就是目標賽事」的綁定）。
            // 寫死 nil 而不是省略欄位 —— 降級規則要指得出「降級的是哪一格」。
            actualFinish: nil,
            // 整期敘事：端點未落地（`SPEC-plan-period-summary.md` status=Draft）。
            // production 路徑一律 nil → 首頁的 Rizo 敘事子卡整卡隱藏。
            narrative: nil
        )
    }

    /// 整期週數。plan status 的 `total_weeks` 是權威；缺席才退 overview／target。
    static func totalWeeks(
        planStatus: PlanStatusV2Response?,
        overview: PlanOverviewV2?,
        target: Target?
    ) -> Int? {
        if let weeks = planStatus?.totalWeeks, weeks > 0 { return weeks }
        if let weeks = overview?.totalWeeks, weeks > 0 { return weeks }
        if let weeks = target?.trainingWeeks, weeks > 0 { return weeks }
        return nil
    }

    // MARK: - 整期總結

    /// 整期總結的確定性數字版。
    ///
    /// 每一組數字都指得出來源，缺就 nil：
    ///
    /// | 格 | 來源 |
    /// |---|---|
    /// | 每週跑量／總跑量／峰值週 | `GET /v2/workouts/stats` 的 `weekly_series` |
    /// | 訓練次數／課表次數／完成率 | 逐週 `GET /v2/summary/weekly?week_of_plan=N` |
    /// | 總時間／最長單次 | `GET /v2/workouts`（濾到計畫期內的跑步） |
    /// | VDOT 起點→終點 | `GET /v2/workouts/vdots` 日序列 |
    ///
    /// **計畫期的窗口由 `bars` 自己界定**：`weekly_series` 已經是後端用使用者當地週
    /// 切好的 N 週，第一根柱的 `week_start` 就是這段的起點。client 不再自己推週界
    /// （`current_week − N` 那種算法會與後端的時區判定打架）。
    static func summary(
        card: App2PlanEndCard,
        weeklySeries: [WorkoutStatsWeeklyEntry],
        weeklySummaries: [WeeklySummaryV2],
        workouts: [WorkoutV2],
        vdots: [VDOTEntry]
    ) -> App2PeriodSummary {
        let bars = App2MetricDetailProjection.bars(weeklySeries)
        let periodStart = bars.first?.weekStart
        let periodWorkouts = runs(workouts, onOrAfter: periodStart)
        let series = vdotSeries(vdots, onOrAfter: periodStart)

        return App2PeriodSummary(
            kind: card.kind,
            raceName: card.raceName,
            totalWeeks: card.totalWeeks,
            targetTime: card.targetTime,
            estimatedFinish: card.estimatedFinish,
            actualFinish: card.actualFinish,
            totalDistanceKm: totalDistanceKm(bars),
            vdotDelta: vdotDelta(series),
            completionRate: completionRate(weeklySummaries),
            sessionCount: completedSessions(weeklySummaries),
            plannedSessionCount: plannedSessions(weeklySummaries),
            totalDurationSeconds: totalDurationSeconds(periodWorkouts),
            longestRunKm: longestRunKm(periodWorkouts),
            peakWeekKm: peakWeekKm(bars),
            bars: bars,
            vdotStart: series.first?.value,
            vdotEnd: series.last?.value,
            vdotSeries: series
        )
    }

    // MARK: - 聚合（純函式）

    /// 整期總跑量 ＝ 每一根柱加總。**一根柱都沒有 → nil**（畫「–」，不畫 0）。
    static func totalDistanceKm(_ bars: [App2WeeklyBar]) -> Double? {
        guard !bars.isEmpty else { return nil }
        return bars.reduce(0) { $0 + $1.distanceKm }
    }

    /// 峰值週。
    ///
    /// **這裡不濾掉「本週」**（不同於 `App2MetricDetailProjection.peakKm`）：計畫已經
    /// 走完，這段裡沒有半週 —— 每一根柱都是完整週。詳情頁那支濾當週是因為它畫的是
    /// 「到今天為止的近 N 週」，語境不同。
    static func peakWeekKm(_ bars: [App2WeeklyBar]) -> Double? {
        bars.map(\.distanceKm).max()
    }

    /// 完成率 ＝ 已生成的週回顧的 `percentage` 平均。
    ///
    /// 分母是**讀得到的週**，不是 `total_weeks` —— 沒生成回顧的那幾週沒有完成率可講，
    /// 把它們當 0 會把「沒做回顧」講成「一堂課都沒跑」。一份都讀不到 → nil。
    static func completionRate(_ summaries: [WeeklySummaryV2]) -> Double? {
        guard !summaries.isEmpty else { return nil }
        let total = summaries.reduce(0.0) { $0 + $1.trainingCompletion.percentage }
        return total / Double(summaries.count)
    }

    static func completedSessions(_ summaries: [WeeklySummaryV2]) -> Int? {
        guard !summaries.isEmpty else { return nil }
        return summaries.reduce(0) { $0 + $1.trainingCompletion.completedSessions }
    }

    static func plannedSessions(_ summaries: [WeeklySummaryV2]) -> Int? {
        guard !summaries.isEmpty else { return nil }
        let total = summaries.reduce(0) { $0 + $1.trainingCompletion.plannedSessions }
        return total > 0 ? total : nil
    }

    /// 計畫期內的跑步紀錄。
    ///
    /// `periodStart` 是 `weekly_series` 第一根柱的 `week_start`（**使用者當地日**
    /// `YYYY-MM-DD`），而 workout 的 `start_time_utc` 是 UTC instant —— 所以先把
    /// 後者換算成裝置當地日再比字串（`AGENTS.md` i18n 與時區規則）。
    /// `periodStart` 缺席（沒有序列）→ 不濾，交回全部，由呼叫端的其他格自行降級。
    static func runs(_ workouts: [WorkoutV2], onOrAfter periodStart: String?) -> [WorkoutV2] {
        let runs = workouts.filter { $0.activityType.lowercased().contains("run") }
        guard let periodStart else { return runs }
        return runs.filter { workout in
            guard let date = App2WeekCalendar.parseISO8601(workout.startTimeUtc) else { return false }
            return App2MetricDetailProjection.isoDate(epochSeconds: date.timeIntervalSince1970)
                >= periodStart
        }
    }

    static func totalDurationSeconds(_ workouts: [WorkoutV2]) -> Int? {
        guard !workouts.isEmpty else { return nil }
        let total = workouts.reduce(0) { $0 + $1.durationSeconds }
        return total > 0 ? total : nil
    }

    static func longestRunKm(_ workouts: [WorkoutV2]) -> Double? {
        workouts.compactMap { $0.distanceMeters.map { $0 / 1000 } }.max()
    }

    /// 計畫期內的 VDOT 日序列（舊→新）。
    ///
    /// 窗口內一筆都沒有時**不退回全序列**：那會把「這段沒有能力資料」講成
    /// 「這段從 39 長到 45」，而那兩個值可能來自完全不同的訓練期。
    static func vdotSeries(_ entries: [VDOTEntry], onOrAfter periodStart: String?) -> [App2MetricPoint] {
        let series = App2MetricDetailProjection.vdotSeries(entries)
        guard let periodStart else { return series }
        return series.filter { $0.date >= periodStart }
    }

    /// VDOT 增量 ＝ 終點 − 起點。序列少於兩點就沒有「變化」可講 → nil。
    static func vdotDelta(_ series: [App2MetricPoint]) -> Double? {
        guard series.count >= 2, let first = series.first, let last = series.last else { return nil }
        return last.value - first.value
    }

    // MARK: - 格式（與首頁目標卡同一組規則）

    /// 賽事日期以**賽事時區**顯示（數字 timestamp 是 UTC）。
    static func raceDateLabel(_ target: Target) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: target.timezone) ?? .current
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(target.raceDate)))
    }

    /// 距離標籤走既有的 `race_filter.*`（三語已齊，賽事清單頁與首頁目標卡在用同一組），
    /// 不把 `distance_km` 這種識別量直接印上去。
    static func distanceLabel(km: Int) -> String {
        switch km {
        case 42: return NSLocalizedString("race_filter.full_marathon", comment: "")
        case 21: return NSLocalizedString("race_filter.half_marathon", comment: "")
        case 10: return NSLocalizedString("race_filter.10k", comment: "")
        case 5:  return NSLocalizedString("race_filter.5k", comment: "")
        default: return "\(km) km"
        }
    }

    /// 目標成績。未設成績（0）→ nil，那一欄不出現。
    static func targetTimeLabel(_ target: Target?) -> String? {
        guard let target, target.targetTime > 0 else { return nil }
        return TimeFormatting.formatTime(target.targetTime)
    }

    /// 課表 tab 結束態那一行小計（`128 次課表 · 完成率 91% · 峰值 78 km`）。
    ///
    /// **缺哪一段就少那一段**，不用一個帶三個佔位符的長字串 —— 那樣缺一個就整行不能出。
    /// 三段都缺就回 nil（整行不畫）。
    static func stripStatsLine(_ strip: App2PlanEndStrip) -> String? {
        var parts: [String] = []
        if let sessions = strip.plannedSessionCount {
            parts.append(String(format: L10n.App2.PlanEnd.sessionsCountFormat.localized, sessions))
        }
        if let rate = strip.completionRate {
            parts.append(String(
                format: L10n.App2.PlanEnd.completionRateFormat.localized,
                Int(rate.rounded())
            ))
        }
        if let peak = strip.peakWeekKm {
            parts.append(String(
                format: L10n.App2.PlanEnd.peakFormat.localized,
                App2MetricDetailProjection.kmLabel(peak)
            ))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
