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

    /// §51-7 訓練負荷的三欄現況（CTL／ATL／TSB）。
    ///
    /// **一天都沒有 `tsb_metrics` → nil（那三欄不畫）。** dev 現況就是全 null；
    /// 這時畫三個「–」只是告訴用戶「這裡壞了」。
    static func loadBlock(_ records: [HealthRecord]) -> App2LoadBlock? {
        let latest = records
            .sorted { $0.date < $1.date }
            .last { $0.tsb != nil || $0.ctl != nil || $0.atl != nil }
        guard let latest else { return nil }
        return App2LoadBlock(ctl: latest.ctl, atl: latest.atl, tsb: latest.tsb)
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
        let latestBand = days.last { $0.envelope?.channels?.acwr?.sweetLow != nil }?
            .envelope?.channels?.acwr
        return App2AcwrBlock(
            series: series,
            sweetLow: latestBand?.sweetLow,
            sweetHigh: latestBand?.sweetHigh
        )
    }

    /// §51-6 甜區帶。**上下界兩端都在才畫** —— 只有一端等於編另一端。
    static func sweetBand(_ acwr: App2AcwrBlock) -> App2MetricLineChart.Band? {
        guard let low = acwr.sweetLow, let high = acwr.sweetHigh, high > low else {
            return nil
        }
        return App2MetricLineChart.Band(
            lower: low,
            upper: high,
            label: String(
                format: L10n.App2.Metric.volumeAcwrSweetFormat.localized,
                App2NumberFormat.grouped(low, maximumFractionDigits: 1),
                App2NumberFormat.grouped(high, maximumFractionDigits: 1)
            ),
            tint: App2Theme.accentGreenDot
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
                // 右緣原本掛著原始識別字（`personal_best`）。弱化字級不會讓欄位名變成
                // 產品文案 —— 它是給施工者看的，不該在使用者的畫面上（8/28 盤點 D11）。
                detail: nil
            ))
        }
        if let decision = entry.anchorDecision {
            rows.append(App2MetricDiagnosticRow(
                id: "decision",
                label: L10n.App2.Metric.capabilityRowDecision.localized,
                value: anchorDecisionLabel(decision),
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

    /// 四個固定距離的完賽預估列（T-0376；Android 對應 T-0375）。
    ///
    /// 資料源是 **readiness 流**的 `race_fitness.finish_time_predictions`，
    /// 由首頁那一輪已經載過的同一份 readiness 傳進來（見 `App2HomeViewModel`）——
    /// 這一頁不為它多打一次網路。
    ///
    /// 三條規則：
    /// 1. **排序依 `distance_km` 由小到大**。Swift 的 `[String: T]` 沒有順序，
    ///    靠 dict 迭代排必然每次都不一樣。`distance_km` 缺席時退回該 key 的已知距離；
    ///    連 key 都認不得就排到最後。
    /// 2. **標籤走既有的 `race_filter.*` 三語 key**（`5K`／`10K`／`半馬`／`全馬`）。
    ///    賽事名不是量測值，切英制不換算。**認不得的 key 才退回 payload 的
    ///    `distance_label`** —— 猜一個譯名比原樣顯示更糟（同 `vdotSourceLabel`）。
    /// 3. **沒有 `estimated_time` 的那一筆整列丟掉**，回空陣列＝呼叫端整區不畫。
    ///    不畫一排「–」（同 §51-7 `tsb_metrics` 全 null 整塊隱藏的 2026-08-26 裁決）。
    static func finishPredictions(from metric: RaceFitnessMetric?) -> [App2FinishPrediction] {
        guard let predictions = metric?.finishTimePredictions, !predictions.isEmpty else { return [] }

        return predictions
            .compactMap { entry -> (order: Double, row: App2FinishPrediction)? in
                let key = entry.key
                let prediction = entry.value
                guard let time = prediction.estimatedTime, !time.isEmpty else { return nil }
                return (
                    order: prediction.distanceKm ?? knownDistanceKm(key) ?? .greatestFiniteMagnitude,
                    row: App2FinishPrediction(
                        id: key,
                        label: finishDistanceLabel(key, fallback: prediction.distanceLabel),
                        time: time
                    )
                )
            }
            // 同距離（理論上不會有）時用 key 定序，讓輸出對同一份 payload 永遠一樣。
            .sorted { ($0.order, $0.row.id) < ($1.order, $1.row.id) }
            .map(\.row)
    }

    /// 後端 `STANDARD_RACE_DISTANCES` 的四個 key（`race_fitness.py:84-89`）。
    /// `distance_km` 缺席時才用得到。
    private static func knownDistanceKm(_ key: String) -> Double? {
        switch key {
        case "five_k":         return 5.0
        case "ten_k":          return 10.0
        case "half_marathon":  return 21.0975
        case "full_marathon":  return 42.195
        default:               return nil
        }
    }

    /// 賽事名。走既有的 `race_filter.*`（onboarding 已經在用同一組，
    /// `App2OnboardingContainerView.swift`），不新造距離字串。
    private static func finishDistanceLabel(_ key: String, fallback: String?) -> String {
        switch key {
        case "five_k":        return NSLocalizedString("race_filter.5k", comment: "5K")
        case "ten_k":         return NSLocalizedString("race_filter.10k", comment: "10K")
        case "half_marathon": return NSLocalizedString("race_filter.half_marathon", comment: "半馬")
        case "full_marathon": return NSLocalizedString("race_filter.full_marathon", comment: "全馬")
        default:              return fallback ?? key
        }
    }

    /// `weighted_16x` → 「高權重錨定（以個人最佳為主）」（8/28 盤點 D11）。
    ///
    /// **語意是權重，不是筆數**：PB／測驗錨點在配速能力估算裡的權重是一般訓練課的
    /// 16 倍（backend `BENCHMARK_WEIGHT_BOOST = 16.0`），不是「取最近 16 筆」
    /// ——2026-08-30 使用者裁決。認不得的值原樣顯示，同 `vdotSourceLabel`：
    /// 猜一個譯名比露出識別字更糟。
    static func anchorDecisionLabel(_ decision: String) -> String {
        switch decision {
        case "weighted_16x": return L10n.App2.Metric.anchorDecisionWeighted.localized
        default:             return decision
        }
    }

    /// `benchmark` → 「指標跑（8/2）」。沒有對應譯名的來源原樣顯示。
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

    // MARK: - 相對能力兩格（有氧續航／速度耐力）

    /// 這兩頁的 hero **完全是首頁那一列**：大數字是 `value_text`（0–100 相對能力）、
    /// 判語 chip 是 `verdict`、敘事是 `evidence` 的限制句。
    ///
    /// 右側對照整格不畫：「計畫起點 vs 現在」的逐週序列還沒有 producer
    /// （SPEC-today-state §11-7），掛一個永遠是「–」的標籤只是把缺口偽裝成欄位。
    /// 兩格共用同一個 hero 標題（大數字是同一種量），所以這裡不吃 `kind`。
    static func levelHero(insight: App2Insight) -> App2MetricHero {
        App2MetricHero(
            title: L10n.App2.Metric.levelHeroTitle.localized,
            valueText: insight.value,
            verdict: insight.verdict,
            direction: insight.direction,
            compareLabel: nil,
            compareValue: nil,
            narrative: insight.evidence
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
            return App2MetricPoint(date: row.day, value: value)
        }
    }

    /// 「這個指標量什麼」。兩格量的不是同一件事，各有自己的一段。
    static func levelAbout(_ kind: App2MetricDetailKind) -> String {
        switch kind {
        case .speedEndurance: return L10n.App2.Metric.levelAboutSpeed.localized
        default:              return L10n.App2.Metric.levelAboutAerobic.localized
        }
    }

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
