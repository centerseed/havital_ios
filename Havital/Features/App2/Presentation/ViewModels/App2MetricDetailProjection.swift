import Foundation

// MARK: - App2MetricDetailProjection
/// 指標第二層的純投影（checklist §51–53）。
///
/// 「payload → 畫面欄位」全部在這裡，**不碰網路**，所以每一條現算欄都能單獨測
/// （`HavitalTests/Features/App2/App2MetricDetailProjectionTests.swift`）。
///
/// **為什麼不接 1.4 的 `MetricDetailSheet`**（`Havital/Views/Components/
/// TrainingReadinessView.swift:810`）：那一支吃的是 `/plan/readiness/latest` 的 28 天
/// `trend_data` —— **readiness 流**（凍結）。這一組畫面吃 decision-chain 的 insights
/// ＋ workouts 序列。`AGENTS.md`「兩條資料流」明定同名指標不得互相佐證，
/// 所以這不是同一件事的第二份實作。
///
/// 三條規則貫穿整份檔案：
/// 1. **大數字與判語一律沿用首頁那一列的 `insights[]`**（後端已評級、已在地化）。
///    詳情頁不重新算一次，也不重新評級 —— 同一個量在兩個畫面上必須是同一個字。
/// 2. **現算欄只由序列推**（8 週平均、週高點、7 日趨勢判語），推不出來就回 nil，
///    畫面畫「–」。缺值不補零、不編數字。
/// 3. **`tsb_metrics` 全 null → 整塊隱藏**（2026-08-26 裁決）：不畫空圖，
///    prod 有資料自然出現。
enum App2MetricDetailProjection {

    /// 值缺席時畫的字。**不是 0、也不是空白** —— 要看得出「這個量現在沒有」。
    static let placeholder = "–"

    // MARK: - §51 訓練量

    /// 週跑量柱狀圖的資料列。`weekly_series` 已是舊→新、含當週。
    static func bars(_ entries: [WorkoutStatsWeeklyEntry]) -> [App2WeeklyBar] {
        entries.map {
            App2WeeklyBar(
                weekStart: $0.weekStart,
                distanceKm: $0.distanceKm,
                isCurrentWeek: $0.isCurrentWeek,
                shortLabel: App2DateLabel.short(isoDate: $0.weekStart)
            )
        }
    }

    /// 平均與高點的分母 ＝ **已經跑完的週**。
    ///
    /// 本週是半週：把它算進平均會把「平均」壓成一個沒人認得的數（今天週三就等於
    /// 拿三天的量跟八個完整週比）。所以平均與高點都只看完整週，畫面上的標籤也跟著
    /// 寫實際週數（`app2.metric.volume.avg_format`），不寫死「8 週」。
    static func completedWeeks(_ bars: [App2WeeklyBar]) -> [App2WeeklyBar] {
        bars.filter { !$0.isCurrentWeek }
    }

    /// 完整週的平均週跑量。一週完整週都沒有 → nil。
    static func averageKm(_ bars: [App2WeeklyBar]) -> Double? {
        let weeks = completedWeeks(bars)
        guard !weeks.isEmpty else { return nil }
        return weeks.reduce(0) { $0 + $1.distanceKm } / Double(weeks.count)
    }

    /// 完整週的週高點。
    static func peakKm(_ bars: [App2WeeklyBar]) -> Double? {
        completedWeeks(bars).map(\.distanceKm).max()
    }

    /// §51-5 統計三欄。
    static func volumeStats(bars: [App2WeeklyBar], ytdKm: Double?) -> [App2MetricStat] {
        let weeks = completedWeeks(bars)
        return [
            App2MetricStat(
                id: "average",
                label: String(format: L10n.App2.Metric.volumeAverageFormat.localized, weeks.count),
                value: averageKm(bars).map { kmLabel($0) }
            ),
            App2MetricStat(
                id: "ytd",
                label: L10n.App2.Metric.volumeYtd.localized,
                value: ytdKm.map { kmLabel($0) }
            ),
            App2MetricStat(
                id: "peak",
                label: L10n.App2.Metric.volumePeak.localized,
                value: peakKm(bars).map { kmLabel($0) }
            )
        ]
    }

    /// §51-6／§51-7 訓練負荷。
    ///
    /// **一天都沒有 `tsb_metrics` → nil（整塊不畫）。** dev 現況就是全 null；
    /// 這時畫一張空圖跟三個「–」只是告訴用戶「這裡壞了」。
    /// `records` 由後端交來時是新→舊，這裡轉成舊→新給折線圖。
    static func loadBlock(_ records: [HealthRecord]) -> App2LoadBlock? {
        let ordered = records.sorted { $0.date < $1.date }
        let series = ordered.compactMap { record -> App2MetricPoint? in
            guard let tsb = record.tsb else { return nil }
            return App2MetricPoint(date: record.date, value: tsb)
        }
        guard !series.isEmpty else { return nil }
        let latest = ordered.last { $0.tsb != nil || $0.ctl != nil || $0.atl != nil }
        return App2LoadBlock(
            series: series,
            ctl: latest?.ctl,
            atl: latest?.atl,
            tsb: latest?.tsb
        )
    }

    // MARK: - §52 能力基準

    /// `pace_vdot` 日序列。後端交來是新→舊，轉成舊→新。
    ///
    /// 取的是 `pace_vdot`（缺就退 `dynamic_vdot`，`resolvedPaceVdot` 已封裝這條規則）
    /// —— 首頁那一列的能力基準綁的就是它。
    static func vdotSeries(_ entries: [VDOTEntry]) -> [App2MetricPoint] {
        entries
            .map { App2MetricPoint(date: isoDate(epochSeconds: $0.datetime), value: $0.resolvedPaceVdot) }
            .sorted { $0.date < $1.date }
    }

    /// 把 `vdots` 序列切成「已經發生的」與「建計畫時生成的未來每日預估」兩段
    /// （2026-08-27 晚走查裁決（f））。
    ///
    /// **後端一條序列同時裝兩種東西**：dev 帳號實測 45 筆裡 28 筆是未來日期
    /// （2026-08-28 → 10-04，`pace_vdot` 38.6→39.6，建計畫時一路排到賽事日）。
    /// 把它們畫成同一條實線＝宣稱那些天已經量到了。切點是**用戶當地的今天**：
    /// `date <= today` 是歷史，其餘是預估。
    ///
    /// 回傳的 `projectedFromIndex` 是**整條序列**裡第一個未來點的索引
    /// （圖表要用整條的座標系畫，見 `App2MetricLineChart.path`）；全是歷史就 nil。
    static func splitProjected(
        _ series: [App2MetricPoint],
        today: String
    ) -> (history: [App2MetricPoint], projectedFromIndex: Int?) {
        guard let index = series.firstIndex(where: { $0.date > today }) else {
            return (series, nil)
        }
        return (Array(series[..<index]), index)
    }

    /// 「30 天前」那一格：序列裡**不晚於 30 天前**的最後一筆。
    ///
    /// 序列還不到 30 天長（新帳號）→ nil，畫「–」。不拿最舊那一筆冒充「30 天前」：
    /// 那會把「這個月沒變」講成「這個月掉了 2.0」。
    static func value(in series: [App2MetricPoint], daysAgo days: Int, from today: String) -> Double? {
        guard let cutoff = dateString(byAdding: -days, to: today),
              let oldest = series.first?.date,
              oldest <= cutoff else { return nil }
        return series.last { $0.date <= cutoff }?.value
    }

    /// §52-4「這個值怎麼來的」。**資料驅動**：欄位沒有就整列不出現，不畫一排「–」。
    static func diagnostics(latest entry: VDOTEntry?) -> [App2MetricDiagnosticRow] {
        guard let entry else { return [] }
        var rows: [App2MetricDiagnosticRow] = []

        if let source = entry.vdotSource {
            rows.append(App2MetricDiagnosticRow(
                id: "anchor",
                label: L10n.App2.Metric.capabilityRowAnchor.localized,
                value: vdotSourceLabel(source, anchorDate: entry.anchorDate),
                detail: source
            ))
        }
        if let decision = entry.anchorDecision {
            rows.append(App2MetricDiagnosticRow(
                id: "decision",
                label: L10n.App2.Metric.capabilityRowDecision.localized,
                value: decision,
                detail: nil
            ))
        }
        if let completeness = entry.evidenceCompleteness {
            rows.append(App2MetricDiagnosticRow(
                id: "evidence",
                label: L10n.App2.Metric.capabilityRowEvidence.localized,
                value: String(format: "%.1f%%", completeness * 100),
                detail: entry.dailyCount.map {
                    String(format: L10n.App2.Metric.capabilityEvidenceCountFormat.localized, $0)
                }
            ))
        } else if let count = entry.dailyCount {
            // 完整度沒給、但天數有 —— 只講知道的那一件（`n = 9`），不換算成百分比。
            rows.append(App2MetricDiagnosticRow(
                id: "evidence",
                label: L10n.App2.Metric.capabilityRowEvidence.localized,
                value: String(format: L10n.App2.Metric.capabilityEvidenceCountFormat.localized, count),
                detail: nil
            ))
        }
        if let confidence = entry.confidence {
            rows.append(App2MetricDiagnosticRow(
                id: "confidence",
                label: L10n.App2.Metric.capabilityRowConfidence.localized,
                value: confidenceLabel(confidence),
                detail: nil
            ))
        }
        return rows
    }

    /// `benchmark` → 「指標跑（8/2）」。沒有對應譯名的來源原樣顯示（右緣本來就掛 mono 原字）。
    static func vdotSourceLabel(_ source: String, anchorDate: String?) -> String {
        let name: String
        switch source {
        case "benchmark":     name = L10n.App2.Metric.vdotSourceBenchmark.localized
        case "personal_best": name = L10n.App2.Metric.vdotSourcePersonalBest.localized
        case "estimated":     name = L10n.App2.Metric.vdotSourceEstimated.localized
        default:              name = source
        }
        guard let anchorDate else { return name }
        return String(format: L10n.App2.Metric.capabilityAnchorFormat.localized,
                      name, App2DateLabel.short(isoDate: anchorDate))
    }

    static func confidenceLabel(_ confidence: String) -> String {
        switch confidence {
        case "high":   return L10n.App2.Metric.confidenceHigh.localized
        case "medium": return L10n.App2.Metric.confidenceMedium.localized
        case "low":    return L10n.App2.Metric.confidenceLow.localized
        default:       return confidence
        }
    }

    // MARK: - §53 恢復

    /// HRV／靜息心率日序列（舊→新）。缺值那一天**不進序列**（折線跳過，不補 0）。
    static func healthSeries(
        _ records: [HealthRecord],
        value: (HealthRecord) -> Double?
    ) -> [App2MetricPoint] {
        records
            .compactMap { record in value(record).map { App2MetricPoint(date: record.date, value: $0) } }
            .sorted { $0.date < $1.date }
    }

    /// §53-3 的「7 日趨勢」判語。
    ///
    /// 判準是**最近 7 天的 HRV 平均 vs 前 7 天**：HRV 逐日抖動很大，比單日等於在讀雜訊。
    /// 兩邊各至少 3 天有值才判（穿戴裝置常有整天缺值），否則回 nil → 畫「–」。
    /// 門檻 ±3%：低於它的差在 HRV 的日間變異裡沒有意義，一律算持平。
    static func hrvTrend(_ series: [App2MetricPoint]) -> App2RecoveryTrend? {
        let recent = Array(series.suffix(7))
        let previous = Array(series.dropLast(7).suffix(7))
        guard recent.count >= 3, previous.count >= 3 else { return nil }
        let recentMean = recent.reduce(0) { $0 + $1.value } / Double(recent.count)
        let previousMean = previous.reduce(0) { $0 + $1.value } / Double(previous.count)
        guard previousMean > 0 else { return nil }
        let ratio = (recentMean - previousMean) / previousMean
        if ratio > 0.03 { return .up }
        if ratio < -0.03 { return .down }
        return .flat
    }

    /// §53-3 統計三欄。
    static func recoveryStats(hrv: [App2MetricPoint], restingHR: [App2MetricPoint]) -> [App2MetricStat] {
        [
            App2MetricStat(
                id: "hrv",
                label: L10n.App2.Metric.recoveryStatHrv.localized,
                value: hrv.last.map { String(format: "%.0f ms", $0.value) }
            ),
            App2MetricStat(
                id: "rhr",
                label: L10n.App2.Metric.recoveryStatRhr.localized,
                value: restingHR.last.map { String(format: "%.0f bpm", $0.value) }
            ),
            App2MetricStat(
                id: "trend",
                label: L10n.App2.Metric.recoveryStatTrend.localized,
                value: hrvTrend(hrv)?.label
            )
        ]
    }

    // MARK: - 共用格式

    /// `34.6 km`／`1,284 km`（整數不帶小數點，沿用 `App2NumberFormat`）。
    static func kmLabel(_ km: Double) -> String {
        "\(App2NumberFormat.grouped(km, maximumFractionDigits: 1)) km"
    }

    /// `−0.3`／`+1.2`。差為 0 → `0.0`（不加號）。
    static func signedLabel(_ delta: Double, fractionDigits: Int = 1) -> String {
        let text = String(format: "%.\(fractionDigits)f", abs(delta))
        if delta > 0 { return "+\(text)" }
        if delta < 0 { return "−\(text)" }
        return text
    }

    /// UTC epoch 秒 → 用戶當地日 `YYYY-MM-DD`。
    ///
    /// `vdots[].datetime` 是數字 timestamp ＝ UTC instant，要換算成當地日期才能與
    /// `health_daily.date`／`week_start` 這些當地日字串放在同一條軸上
    /// （`AGENTS.md`：數字 timestamp 是 UTC、`YYYY-MM-DD` 是當地時間）。
    static func isoDate(epochSeconds: TimeInterval, calendar: Calendar = .current) -> String {
        let date = Date(timeIntervalSince1970: epochSeconds)
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return "" }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// 今天的當地日 `YYYY-MM-DD`。
    static func today(now: Date = Date(), calendar: Calendar = .current) -> String {
        isoDate(epochSeconds: now.timeIntervalSince1970, calendar: calendar)
    }

    /// `2026-08-26` ＋ `-30` → `2026-07-27`。解不開就 nil。
    static func dateString(byAdding days: Int, to isoDate: String, calendar: Calendar = .current) -> String? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: isoDate),
              let moved = calendar.date(byAdding: .day, value: days, to: date) else { return nil }
        return formatter.string(from: moved)
    }
}

// MARK: - App2RecoveryTrend
/// §53-3 的趨勢判語。**箭頭與用字綁在一起**（`↑ 佳`），不讓畫面自己拼。
enum App2RecoveryTrend: Equatable {
    case up, flat, down

    var label: String {
        switch self {
        case .up:   return L10n.App2.Metric.recoveryTrendUp.localized
        case .flat: return L10n.App2.Metric.recoveryTrendFlat.localized
        case .down: return L10n.App2.Metric.recoveryTrendDown.localized
        }
    }
}
