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
    /// 0–100 分數線（恢復）的 Y 軸範圍：固定，不貼著資料縮放。
    static let scoreAxisRange: ClosedRange<Double> = 0...100

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

    /// §51-6 近 30 天急慢性負荷比（`load_index` 的 `channels.acwr`，T-0618）。
    ///
    /// 比值算不出來的那天（CTL 低於門檻、缺 CTL/ATL）沒有點——後端 §4.10.7
    /// 禁 LOCF，這裡也不補鄰日的值。一天都沒有 → nil，畫面畫佔位句。
    ///
    /// 甜區上下界取**最新一天**那一列帶的值：它依訓練期變，畫在圖上的那條帶子
    /// 要對應使用者現在所處的期。app 端不寫死 0.8–1.3（SPEC-today-state §5.1）。
    static func acwrBlock(_ response: AthleteStateSeriesResponse) -> App2AcwrBlock? {
        let days = (response.series["load_index"] ?? []).sorted { $0.day < $1.day }
        let series = days.compactMap { row -> App2MetricPoint? in
            guard let value = row.envelope?.channels?.acwr?.raw else { return nil }
            return App2MetricPoint(date: row.day, value: value)
        }
        guard !series.isEmpty else { return nil }
        let latestBand = days.last?.envelope?.channels?.acwr
        return App2AcwrBlock(
            series: series,
            sweetLow: latestBand?.sweetLow,
            sweetHigh: latestBand?.sweetHigh
        )
    }

    /// SPEC-load-index §5.1：只使用完整有效的後端門檻，不補預設值或前日門檻。
    static func acwrThresholds(_ acwr: App2AcwrBlock) -> (low: Double, high: Double)? {
        if let low = acwr.sweetLow, let high = acwr.sweetHigh, high > low {
            return (low, high)
        }
        return nil
    }

    /// 負荷比圖的三色背景帶（畫法同 1.4 的 TSB 圖）：偏輕（藍）／合適（綠）／過量（紅）。
    static func acwrBands(_ acwr: App2AcwrBlock) -> [App2MetricLineChart.Band] {
        guard let t = acwrThresholds(acwr) else { return [] }
        let low = App2NumberFormat.grouped(t.low, maximumFractionDigits: 1)
        let high = App2NumberFormat.grouped(t.high, maximumFractionDigits: 1)
        return [
            App2MetricLineChart.Band(
                lower: nil, upper: t.low, tint: .blue,
                legendLabel: L10n.App2.Metric.acwrZoneLight.localized, legendDetail: "< \(low)"
            ),
            App2MetricLineChart.Band(
                lower: t.low, upper: t.high, tint: .green,
                legendLabel: L10n.App2.Metric.acwrZoneOk.localized, legendDetail: "\(low)–\(high)"
            ),
            App2MetricLineChart.Band(
                lower: t.high, upper: nil, tint: .red,
                legendLabel: L10n.App2.Metric.acwrZoneHeavy.localized, legendDetail: "> \(high)"
            )
        ]
    }

    /// < low 偏輕、low…high 合適（含兩端）、> high 過量。
    static func acwrZoneLabel(for value: Double, thresholds: (low: Double, high: Double)) -> String {
        if value < thresholds.low { return L10n.App2.Metric.acwrZoneLight.localized }
        if value <= thresholds.high { return L10n.App2.Metric.acwrZoneOk.localized }
        return L10n.App2.Metric.acwrZoneHeavy.localized
    }

    /// 圖下一句「目前：合適」，依序列最近一個有值的點。一點都沒有 → nil。
    static func acwrCurrentZone(_ acwr: App2AcwrBlock) -> String? {
        guard let thresholds = acwrThresholds(acwr),
              let latest = acwr.series.last(where: { $0.value != nil })?.value else { return nil }
        return String(
            format: L10n.App2.Metric.currentZoneFormat.localized,
            acwrZoneLabel(for: latest, thresholds: thresholds)
        )
    }

    /// Y 軸只標兩條分界（高的先）。
    static func acwrAxisTicks(_ acwr: App2AcwrBlock) -> [Double] {
        guard let t = acwrThresholds(acwr) else { return [] }
        return [t.high, t.low]
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

    /// 「30 天前」那一格：decision-chain 序列（`capability_baseline`）在**那一天**的
    /// `center.value`。沒有那天的點、或那天沒有 center → nil（不拿鄰日補，同後端禁 LOCF）。
    static func baselineValue(_ response: AthleteStateSeriesResponse, on day: String) -> Double? {
        (response.series["capability_baseline"] ?? [])
            .first { $0.day == day }?
            .envelope?.center?.value
    }

    /// 詳情頁 hero 的「近 7 天趨勢 97.5 → 80.2」：用首頁那一列同一條 `change`，不在 app 重算。
    static func trendLine(change: String?) -> String? {
        guard let change, !change.isEmpty else { return nil }
        return String(format: L10n.App2.Metric.heroTrendFormat.localized, change)
    }

    /// 四個固定距離的完賽預估列；只投影 active/computed 的 race_projection channels。
    static func finishPredictions(from item: AthleteStateRaceProjectionItem?) -> [App2FinishPrediction] {
        guard let item else { return [] }

        return namedRaceDistances.compactMap { distance in
            guard let seconds = AthleteStateRaceProjectionPresenter.projectedSeconds(
                deliveryStatus: item.deliveryStatus,
                envelope: item.envelope,
                channelKey: distance.key
            ) else {
                return nil
            }
            return App2FinishPrediction(
                id: distance.key,
                label: NSLocalizedString(distance.labelKey, comment: distance.comment),
                time: AthleteStateRaceProjectionPresenter.formattedTime(seconds: seconds)
            )
        }
    }

    private struct NamedRaceDistance {
        let key: String
        let labelKey: String
        let comment: String
    }

    /// 固定四距離列表；km 容差與 channel key 映射集中在 athlete-state presenter。
    private static let namedRaceDistances = [
        NamedRaceDistance(key: "5k", labelKey: "race_filter.5k", comment: "5K"),
        NamedRaceDistance(key: "10k", labelKey: "race_filter.10k", comment: "10K"),
        NamedRaceDistance(key: "half_marathon", labelKey: "race_filter.half_marathon", comment: "半馬"),
        NamedRaceDistance(key: "full_marathon", labelKey: "race_filter.full_marathon", comment: "全馬")
    ]

    /// Target distance to backend channel; the backend rule is copied once in the shared presenter.
    static func raceProjectionChannelKey(distanceKm: Double?) -> String? {
        AthleteStateRaceProjectionPresenter.channelKey(distanceKm: distanceKm)
    }

    static func estimatedFinish(
        deliveryStatus: String?,
        envelope: AthleteStateMetricEnvelope?,
        targetDistanceKm: Double?
    ) -> String? {
        AthleteStateRaceProjectionPresenter.formattedTime(
            deliveryStatus: deliveryStatus,
            envelope: envelope,
            distanceKm: targetDistanceKm
        )
    }

    // MARK: - §53 恢復

    /// HRV／靜息心率日序列（舊→新）。缺值留在序列中，讓兩條線共用同一條日期軸。
    static func healthSeries(
        _ records: [HealthRecord],
        value: (HealthRecord) -> Double?
    ) -> [App2MetricPoint] {
        records
            .map { App2MetricPoint(date: $0.date, value: value($0)) }
            .sorted { $0.date < $1.date }
    }

    /// §53-3 的「7 日趨勢」判語。
    ///
    /// 判準是**最近 7 天的 HRV 平均 vs 前 7 天**：HRV 逐日抖動很大，比單日等於在讀雜訊。
    /// 兩邊各至少 3 天有值才判（穿戴裝置常有整天缺值），否則回 nil → 畫「–」。
    /// 門檻 ±3%：低於它的差在 HRV 的日間變異裡沒有意義，一律算持平。
    static func hrvTrend(_ series: [App2MetricPoint]) -> App2RecoveryTrend? {
        let recent = series.suffix(7).compactMap(\.value)
        let previous = series.dropLast(7).suffix(7).compactMap(\.value)
        guard recent.count >= 3, previous.count >= 3 else { return nil }
        let recentMean = recent.reduce(0, +) / Double(recent.count)
        let previousMean = previous.reduce(0, +) / Double(previous.count)
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
                value: hrv.compactMap(\.value).last.map { String(format: "%.0f ms", $0) }
            ),
            App2MetricStat(
                id: "rhr",
                label: L10n.App2.Metric.recoveryStatRhr.localized,
                value: restingHR.compactMap(\.value).last.map { String(format: "%.0f bpm", $0) }
            ),
            App2MetricStat(
                id: "trend",
                label: L10n.App2.Metric.recoveryStatTrend.localized,
                value: hrvTrend(hrv)?.label
            )
        ]
    }

    // MARK: - 相對能力兩格（有氧續航／速度耐力）

    /// 這兩頁的 hero **完全是首頁那一列**：大數字是 `value_text`（0–100 相對能力）、
    /// 判語 chip 是 `verdict`、敘事是 `evidence` 的限制句。
    ///
    /// 右側對照整格不畫：「計畫起點 vs 現在」的逐週序列還沒有 producer
    /// （SPEC-today-state §11-7），掛一個永遠是「–」的標籤只是把缺口偽裝成欄位。
    /// 標題寫該指標名＋「分數」，所以吃 `kind`。
    static func levelHero(insight: App2Insight, kind: App2MetricDetailKind) -> App2MetricHero {
        App2MetricHero(
            title: kind == .speedEndurance
                ? L10n.App2.Metric.levelHeroTitleSpeed.localized
                : L10n.App2.Metric.levelHeroTitleAerobic.localized,
            valueText: insight.value,
            verdict: insight.verdict,
            direction: insight.direction,
            compareLabel: nil,
            compareValue: nil,
            narrative: insight.evidence,
            trendText: trendLine(change: insight.change)
        )
    }

    /// 分級尺的兩個切點（SPEC-today-state §5.1）。**這是後端的評級門檻**，
    /// 不是畫面自己的刻度：同一個判準決定 hero 的判語與尺上的分段，兩者不得分歧。
    /// 改門檻要先改 spec，這裡跟著改。
    static let levelDevelopingMax: Double = 35
    static let levelStrongMin: Double = 65

    /// 尺 ＋ 使用者位置。`value_text` 是後端交的 0–100（純數字字串），拿不出數字
    /// 就沒有指針 —— 尺照畫（判準是固定的），位置不編。
    static func levelScale(insight: App2Insight) -> App2LevelScale? {
        App2LevelScale(
            position: insight.value.flatMap(Double.init),
            developingMax: levelDevelopingMax,
            strongMin: levelStrongMin
        )
    }

    /// 依據句。後端組好的一句（`basis`），**照抄**：句裡每個數都出自 metric envelope
    /// 的 `raw`／`limits.params`，在 app 端重拼會變成第二個算法。沒有就不畫那一塊。
    static func levelBasis(insight: App2Insight) -> String? {
        guard let basis = insight.basis, !basis.isEmpty else { return nil }
        return basis
    }

    /// 近 30 天的 index 逐日線。逐日取 `index`，缺則 `level_index`（v1 的
    /// `speed_endurance` 只有後者）。
    ///
    /// **沒有 envelope 的那一天直接跳過**：那天的答案是「算不出來」，用鄰日的值補
    /// 就是 LOCF，後端在序列端點明令禁止（SPEC-athlete-state §4.10.7），畫面更不該
    /// 自己補一個回去。
    static func levelSeries(_ response: AthleteStateSeriesResponse, key: String) -> [App2MetricPoint] {
        (response.series[key] ?? []).compactMap { row in
            guard let value = row.envelope?.index ?? row.envelope?.levelIndex else { return nil }
            return App2MetricPoint(date: row.day, value: value, band: row.envelope?.band)
        }
    }

    /// 恢復分數柱狀圖：`asof−29 … asof` 共 30 個日曆日，每天一格；沒有 envelope 的天
    /// `value` 為 nil（留空，不補值）。最後一格（asof）標為今天。
    static func recoveryBars(_ points: [App2MetricPoint], asof: String?) -> [App2RecoveryBar] {
        let window = App2LevelDetailViewModel.window(asof: asof)
        let byDate = Dictionary(points.map { ($0.date, $0) }, uniquingKeysWith: { _, latest in latest })
        return (0..<App2LevelDetailViewModel.windowDays).compactMap { offset in
            let back = App2LevelDetailViewModel.windowDays - 1 - offset
            guard let date = dateString(byAdding: -back, to: window.end) else { return nil }
            let point = byDate[date]
            return App2RecoveryBar(
                date: date,
                value: point?.value,
                band: App2RecoveryBand(wire: point?.band),
                isToday: date == window.end
            )
        }
    }

    /// 「這個指標量什麼」：五頁各一段白話（統一版型第 3 塊）。
    /// 訓練量那段帶合適範圍門檻——讀後端 `channels.acwr` 的 sweet_low／sweet_high，不寫死。
    static func aboutText(_ kind: App2MetricDetailKind, thresholds: (low: Double, high: Double)?) -> String {
        switch kind {
        case .capabilityBaseline:
            return L10n.App2.Metric.aboutCapability.localized
        case .aerobicEndurance:
            return L10n.App2.Metric.levelAboutAerobic.localized
        case .speedEndurance:
            return L10n.App2.Metric.levelAboutSpeed.localized
        case .recoveryIndex:
            return L10n.App2.Metric.aboutRecovery.localized
        case .weeklyVolume:
            guard let thresholds else {
                return L10n.App2.Metric.aboutVolumeThresholdsUnavailable.localized
            }
            return String(
                format: L10n.App2.Metric.aboutVolumeFormat.localized,
                App2NumberFormat.grouped(thresholds.low, maximumFractionDigits: 1),
                App2NumberFormat.grouped(thresholds.high, maximumFractionDigits: 1)
            )
        }
    }

    /// 「怎麼算出來的」（統一版型第 4 塊，預設收合）。能力基準／恢復／訓練量是 app 端寫死的一句；
    /// 有氧／速度是後端 `basis`（帶實際堂數），照抄，後端沒給就沒有 basis 那一句。
    /// 資料不足時，「還差什麼」的說明（`levelShortfall`）接在 basis 之後、同一張卡同一個收合狀態；
    /// basis 沒有但說明有，這張卡仍出現（只放說明）。
    static func howText(_ kind: App2MetricDetailKind, insight: App2Insight) -> String? {
        switch kind {
        case .capabilityBaseline: return L10n.App2.Metric.howCapability.localized
        case .recoveryIndex: return L10n.App2.Metric.howRecovery.localized
        case .weeklyVolume: return L10n.App2.Metric.howVolume.localized
        case .aerobicEndurance, .speedEndurance:
            let parts = [levelBasis(insight: insight), levelShortfall(insight: insight, kind: kind)]
                .compactMap { $0 }
            return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
        }
    }

    static let howCardStartsExpanded = false

    /// 訓練量頁的區塊順序：統一版型的例外——專屬的週里程卡提前到 hero 正下方（週里程最直觀、會顯示本週目標）
    ///（使用者 2026-09-29 裁決）。頁面照這個陣列由上到下畫。
    enum VolumeSection: Equatable {
        case hero, loadRatio, weeklyMileage, about, how
    }

    static let volumeSectionOrder: [VolumeSection] = [.hero, .weeklyMileage, .loadRatio, .about, .how]

    /// `insufficient_data` 時把 `evidence` 的限制句**展開成解釋**：這個分數要什麼樣的課
    /// 才算得出來、補齊之後會怎樣。hero 的敘事已經在講「現在累積到哪」，這一段講的是
    /// 「還差什麼」，兩段不重複同一句。
    ///
    /// 已評級 → nil（那一塊不出現）。
    static func levelShortfall(insight: App2Insight, kind: App2MetricDetailKind) -> String? {
        guard !insight.isGraded else { return nil }
        switch kind {
        case .speedEndurance: return L10n.App2.Metric.levelShortfallSpeed.localized
        default:              return L10n.App2.Metric.levelShortfallAerobic.localized
        }
    }

    // MARK: - 共用格式

    /// `34.6 km`／`1,284 km`（整數不帶小數點，沿用 `App2NumberFormat`）。
    static func kmLabel(_ km: Double) -> String {
        "\(App2NumberFormat.grouped(km, maximumFractionDigits: 1)) km"
    }

    /// `−0.3`／`+1.2`。差為 0 → `0.0`（不加號）。
    static func signedLabel(_ delta: Double, fractionDigits: Int = 1) -> String {
        let text = String(format: "%.\(fractionDigits)f", abs(delta))
        // 四捨五入後是 0 的（-0.3 取整數）一律不帶號，不顯示 -0。
        if Double(text) == 0 { return text }
        if delta > 0 { return "+\(text)" }
        return "−\(text)"
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
