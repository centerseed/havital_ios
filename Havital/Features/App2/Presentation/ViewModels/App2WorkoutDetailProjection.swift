import Foundation

// MARK: - App2WorkoutDetailProjection
/// Presentation Layer — 2.0「訓練詳情（已完成跑步）」的純投影
/// （設計 **frame-15**／dc.html「訓練詳情 · 總覽」）。
///
/// **這裡沒有第二條資料路徑。** 資料來源是 1.4 既有的
/// `WorkoutDetailViewModelV2`（`GET /v2/workouts/{id}` ＋ `WorkoutRepository`），
/// 所有寫入（VDOT override、里程校正、裁剪、重新上傳、刪除）也都走那支 VM 的既有
/// 方法 —— 查過了，`updateVDOTOverride` 是全 repo 唯一的 VDOT override 寫入點。
/// 這個檔案只把 `WorkoutV2Detail` 攤成設計稿那幾格要顯示的字串，沒有 I/O、
/// 沒有 `@Published`，所以可以直接單元測試。
///
/// 與 `App2SessionDetailProjection` 是不同的東西：那個投影的是**課表上還沒跑的
/// 一天**（`DayDetailDTO`），這個投影的是**已完成的一筆紀錄**（`WorkoutV2Detail`）。
///
/// 組不出值的格子**不出現**，不用 placeholder 補。
struct App2WorkoutDetailProjection: Equatable {

    // MARK: - Hero

    /// 課型標題（`輕鬆跑`）。沒有課型時退成活動型別的在地化名。
    let title: String
    /// 這一筆對應的課型。hero 卡的主色與 icon 圓章跟著它走（設計 frame-02f）；
    /// 對不出課型就是 nil，hero 退成中性藍。
    let dayType: DayType?
    /// `戶外跑步 · 今天 06:32`
    let subtitle: String
    /// 資料來源徽章文字（`Garmin`／`Strava`／`Apple Health`）。
    let providerLabel: String
    /// 主導強度區（`恢復區`／`閾值區`…）。算不出來就沒有這顆 chip。
    let dominantZoneLabel: String?
    /// 新 PB 徽章文字（`新 PB · 10K`）。沒破 PB 就是 nil。
    let personalBestLabel: String?

    // MARK: - 基礎指標

    /// 距離／時長／平均配速／平均心率／最大心率／RPE
    /// （2026-08-27（l）（m）使用者重分類：**進階三項不在這裡**；卡路里已拿掉）。
    let metrics: [Metric]

    // MARK: - Rizo 教練分析（課表 vs 實際）

    /// 課表那一格（`輕鬆跑 · 8.0 km · 6:50`）。這天沒有對應課表就是 nil。
    let plannedSummary: String?
    /// 實際那一格（`58:24 · 均心 148`）。
    let actualSummary: String?
    /// Rizo 的分析文字（`ai_summary.analysis`）。
    let coachAnalysis: String?

    // MARK: - 進階指標

    /// **只有三項**：訓練負荷 TSS、跑力 Dynamic VDOT、垂直振幅比
    /// （2026-08-27（m）使用者拍板，取代 2026-08-26「進階指標區去掉 VDOT／TSS」
    /// 那條 Claude 裁定）。這三項**不再出現在 `metrics`**——同一頁列兩次就是重複。
    let advancedMetrics: [Metric]

    /// 訓練心得（`training_notes`）。
    let trainingNotes: String?

    // MARK: - 這筆紀錄

    let vdotInclusion: VDOTInclusion

    // MARK: - 型別

    struct Metric: Equatable, Identifiable {
        var id: String { key }
        /// 穩定鍵（給 accessibility identifier 與測試用，不顯示）。
        let key: String
        let label: String
        let value: String
        /// `km`／`kcal`／`bpm`／`/km`。沒有單位就是 nil。
        let unit: String?
        let tone: Tone

        init(key: String, label: String, value: String, unit: String? = nil, tone: Tone = .neutral) {
            self.key = key
            self.label = label
            self.value = value
            self.unit = unit
            self.tone = tone
        }

        enum Tone: Equatable {
            case neutral
            case pace
            case heartRate
        }
    }

    /// 「納入 VDOT 計算」的三態（設計 frame-16）。
    ///
    /// **這不是新語意**：後端既有的 `vdot_override` 就是「不存在／`excluded:false`／
    /// `excluded:true`」三種，剛好對應設計的「自動／一定納入／排除」。
    enum VDOTInclusion: Equatable {
        /// `vdot_override` 不存在 —— 由後端自行判斷。
        case automatic
        /// `excluded: false` —— 使用者要求一定納入。
        case included
        /// `excluded: true` —— 使用者排除，附既有的 reason（`trail`／`manual_entry`／`other`）。
        case excluded(reason: String?)

        var rowValueLabel: String {
            switch self {
            case .automatic: return L10n.App2.WorkoutDetail.vdotAutomatic.localized
            case .included:  return L10n.App2.WorkoutDetail.vdotIncluded.localized
            case .excluded:  return L10n.App2.WorkoutDetail.vdotExcluded.localized
            }
        }

        /// 送回後端的請求。`automatic` ＝ 清掉 override（`nil`）。
        var request: VDOTOverrideRequest? {
            switch self {
            case .automatic:
                return nil
            case .included:
                return VDOTOverrideRequest(excluded: false, reason: nil)
            case .excluded(let reason):
                // 既有的 reason taxonomy（`trail`／`manual_entry`／`other`）。
                // 2.0 的 sheet 只給一顆「排除」，沿用 1.4 的 `other`。
                return VDOTOverrideRequest(excluded: true, reason: reason ?? "other")
            }
        }

        /// 兩個 case 是不是同一種選擇（`excluded` 的 reason 不同不算不同選擇）。
        func isSameChoice(as other: VDOTInclusion) -> Bool {
            switch (self, other) {
            case (.automatic, .automatic), (.included, .included), (.excluded, .excluded):
                return true
            default:
                return false
            }
        }

        static func from(_ override: VDOTOverride?) -> VDOTInclusion {
            guard let override else { return .automatic }
            return override.excluded ? .excluded(reason: override.reason) : .included
        }
    }
}

// MARK: - 組裝

extension App2WorkoutDetailProjection {

    /// 從 1.4 的 payload 組出這一頁要顯示的東西。
    ///
    /// - Parameters:
    ///   - workout: 清單那一筆（`GET /v2/workouts` 的 row）—— detail 還沒回來時先用它，
    ///     所以進頁不會空白一秒。
    ///   - detail: `GET /v2/workouts/{id}` 的完整 payload。
    ///   - personalBestLabel: 破 PB 徽章文字，由 View 從 VM 的
    ///     `personalBestUpdatesForWorkout` 給（PB 判定不在這裡重做一份）。
    ///   - maxHR／restingHR：用戶心率區間設定（既有 profile 的 `max_hr`／`relaxing_hr`），
    ///     只在 `hr_zone_distribution` 缺席或全零時，用來把 avgHR 換算成區間 chip
    ///     （設計 frame-02f：區間 chip 由實際均心對用戶心率區間推得）。這裡不做 IO，
    ///     值由呼叫端（View）先從 profile 讀好傳入。
    static func make(
        workout: WorkoutV2,
        detail: WorkoutV2Detail?,
        personalBestLabel: String?,
        unitSystem: UnitSystem,
        maxHR: Int? = nil,
        restingHR: Int? = nil,
        now: Date = Date()
    ) -> App2WorkoutDetailProjection {
        let basic = detail?.basicMetrics
        let advanced = detail?.advancedMetrics

        // detail 優先（它是校正／裁剪後的值），沒有才用清單那筆。
        let distanceM = basic?.totalDistanceM ?? workout.distanceMeters
        let durationS = basic?.totalDurationS ?? workout.durationSeconds
        let paceSPerKm = basic?.avgPaceSPerKm ?? workout.displayPaceSecondsPerKm
        let avgHR = basic?.avgHeartRateBpm ?? workout.basicMetrics?.avgHeartRateBpm
        let maxHR = basic?.maxHeartRateBpm ?? workout.basicMetrics?.maxHeartRateBpm

        let vdotValue = advanced?.dynamicVdot ?? workout.advancedMetrics?.dynamicVdot
        let tssValue = advanced?.tss ?? workout.advancedMetrics?.tss

        // 基礎指標磚的順序（2026-08-27（m）重分類）：
        // 距離／時長 · 平均配速／平均心率 · 最大心率／RPE（卡路里已拿掉）。
        // **跑力 VDOT 與訓練負荷 TSS 不在這裡**——它們搬到進階指標區（見下）。
        var metrics: [Metric] = []
        if let distanceM, distanceM > 0 {
            metrics.append(distanceMetric(meters: distanceM, unitSystem: unitSystem))
        }
        metrics.append(
            Metric(
                key: "duration",
                label: NSLocalizedString("workout.metrics.time", comment: "時長"),
                value: formatDuration(seconds: durationS)
            )
        )
        if let paceSPerKm, paceSPerKm > 0 {
            metrics.append(
                Metric(
                    key: "pace",
                    label: NSLocalizedString("performance.avg_pace", comment: "平均配速"),
                    value: formatPace(secondsPerKm: paceSPerKm, unitSystem: unitSystem),
                    unit: unitSystem == .metric ? "/km" : "/mi",
                    tone: .pace
                )
            )
        }
        if let avgHR, avgHR > 0 {
            metrics.append(
                Metric(
                    key: "avg_hr",
                    label: NSLocalizedString("performance.avg_hr", comment: "平均心率"),
                    value: "\(avgHR)",
                    unit: "bpm",
                    tone: .heartRate
                )
            )
        }
        // 卡路里不畫（2026-08-27 走查：使用者拍板拿掉——訓練詳情看的是課表達成，
        // 不是消耗量）。
        if let maxHR, maxHR > 0 {
            metrics.append(
                Metric(
                    key: "max_hr",
                    label: NSLocalizedString("profile.max_hr", comment: "最大心率"),
                    value: "\(maxHR)",
                    unit: "bpm",
                    tone: .heartRate
                )
            )
        }

        if let rpe = advanced?.rpe ?? workout.advancedMetrics?.rpe {
            metrics.append(
                Metric(
                    key: "rpe",
                    label: NSLocalizedString("workout.detail.rpe_editor_title", comment: "主觀強度"),
                    value: String(format: "%.0f", rpe),
                    unit: "/10"
                )
            )
        }

        // 進階指標＝訓練負荷 TSS、跑力 Dynamic VDOT、垂直振幅比，順序照
        // 2026-08-27（m）使用者拍板的那三項。上面的基礎指標磚不再列這三項。
        var advancedMetrics: [Metric] = []
        if let tssValue {
            advancedMetrics.append(
                Metric(
                    key: "load",
                    label: NSLocalizedString("workout.detail.training_load", comment: "訓練負荷"),
                    value: String(format: "%.0f", tssValue),
                    unit: "TSS"
                )
            )
        }
        if let vdotValue {
            advancedMetrics.append(
                Metric(
                    key: "vdot",
                    label: L10n.App2.WorkoutDetail.runningPower.localized,
                    value: String(format: "%.1f", vdotValue),
                    unit: "VDOT"
                )
            )
        }
        if let vertical = advanced?.avgVerticalRatioPercent ?? workout.advancedMetrics?.avgVerticalRatioPercent {
            advancedMetrics.append(
                Metric(
                    key: "vertical_ratio",
                    label: L10n.App2.WorkoutDetail.verticalRatio.localized,
                    value: String(format: "%.1f", vertical),
                    unit: "%"
                )
            )
        }

        return App2WorkoutDetailProjection(
            title: titleLabel(workout: workout, detail: detail),
            dayType: dayType(workout: workout, detail: detail),
            subtitle: subtitleLabel(workout: workout, now: now),
            providerLabel: providerLabel(workout.provider),
            dominantZoneLabel: dominantZoneLabel(advanced?.hrZoneDistribution)
                ?? fallbackZoneLabel(avgHR: avgHR, maxHR: maxHR, restingHR: restingHR),
            personalBestLabel: personalBestLabel,
            metrics: metrics,
            plannedSummary: plannedSummary(detail?.dailyPlanSummary ?? workout.dailyPlanSummary),
            actualSummary: actualSummary(durationS: durationS, avgHR: avgHR),
            coachAnalysis: (detail?.aiSummary ?? workout.aiSummary)?.analysis.app2NonEmpty,
            advancedMetrics: advancedMetrics,
            trainingNotes: detail?.trainingNotes?.app2NonEmpty,
            vdotInclusion: .from(detail?.vdotOverride)
        )
    }

    // MARK: - 各格的組法

    /// 標題優先用課型，沒有才退成活動型別。
    ///
    /// 課型是「這堂課練什麼」，活動型別只是「是跑步還是騎車」；設計 frame-15 的
    /// 大標「輕鬆跑」是前者。課型顯示字走既有的 `DayType.localizedName`（三語已齊），
    /// 不另建一份對照表。
    static func titleLabel(workout: WorkoutV2, detail: WorkoutV2Detail?) -> String {
        if let dayType = dayType(workout: workout, detail: detail) {
            return dayType.localizedName
        }
        if let rawType = rawTrainingType(workout: workout, detail: detail), !rawType.isEmpty {
            return rawType
        }
        return activityTypeLabel(workout.activityType)
    }

    static func rawTrainingType(workout: WorkoutV2, detail: WorkoutV2Detail?) -> String? {
        detail?.advancedMetrics?.trainingType
            ?? workout.advancedMetrics?.trainingType
            ?? detail?.dailyPlanSummary?.trainingType
            ?? workout.dailyPlanSummary?.trainingType
    }

    /// 這一筆的課型。**是 `run_type` 識別字的型別解析**，不是對顯示字做詞表比對；
    /// 對不上已知集合就 nil（hero 退成中性色）。
    static func dayType(workout: WorkoutV2, detail: WorkoutV2Detail?) -> DayType? {
        guard let raw = rawTrainingType(workout: workout, detail: detail) else { return nil }
        return DayType(rawValue: raw)
    }

    static func subtitleLabel(workout: WorkoutV2, now: Date) -> String {
        let activity = activityTypeLabel(workout.activityType)
        guard workout.startTimeUtc != nil else { return activity }
        _ = now
        // 相對時間走既有的 `DateFormatterHelper`（紀錄頁的 `r.when` 同一支）。
        let when = DateFormatterHelper.formatRelativeForWorkoutCard(workout.startDate)
        return "\(activity) · \(when)"
    }

    static func activityTypeLabel(_ raw: String) -> String {
        switch raw.lowercased() {
        case "running", "street_running", "outdoor_running":
            return L10n.App2.WorkoutDetail.activityRunning.localized
        case "treadmill_running", "indoor_running":
            return L10n.App2.WorkoutDetail.activityTreadmill.localized
        case "trail_running":
            return L10n.App2.WorkoutDetail.activityTrail.localized
        case "track_running":
            return L10n.App2.WorkoutDetail.activityTrack.localized
        default:
            return raw
        }
    }

    static func providerLabel(_ raw: String) -> String {
        switch raw.lowercased() {
        case "garmin": return "Garmin"
        case "strava": return "Strava"
        case "healthkit", "apple_health", "apple": return "Apple Health"
        default: return raw.capitalized
        }
    }

    /// 佔比最大的心率區間。全零／全 nil ＝ 沒有這顆 chip。
    ///
    /// 區間名是既有的 Daniels 六段（`recovery`／`easy`／`marathon`／`threshold`／
    /// `interval`／`anaerobic`），不是 Z1–Z5；顯示字用既有的
    /// `workout.detail.*_zone`，不另造一組。
    static func dominantZoneLabel(_ zones: V2ZoneDistribution?) -> String? {
        guard let zones else { return nil }
        let candidates: [(String, Double?)] = [
            ("workout.detail.recovery_zone", zones.recovery),
            ("workout.detail.aerobic_zone", zones.easy),
            ("workout.detail.marathon_zone", zones.marathon),
            ("workout.detail.threshold_zone", zones.threshold),
            ("workout.detail.interval_zone", zones.interval),
            ("workout.detail.anaerobic_zone", zones.anaerobic)
        ]
        let best = candidates
            .compactMap { key, value -> (String, Double)? in
                guard let value, value > 0 else { return nil }
                return (key, value)
            }
            .max { $0.1 < $1.1 }
        guard let best else { return nil }
        return NSLocalizedString(best.0, comment: "")
    }

    /// `hr_zone_distribution` 缺席（或全零）時的退路：拿這一趟的 avgHR 對用戶心率
    /// 區間（既有 `HeartRateZone.calculateZones`，HRR／Karvonen 六區）推落點。
    /// Android 已是這樣算（avg HR 對六區），這裡補齊 iOS 對應行為。
    ///
    /// 拿不到 avgHR 或拿不到用戶 profile 的 max／resting HR 就沒有這顆 chip
    /// ——不臆測預設值。
    static func fallbackZoneLabel(avgHR: Int?, maxHR: Int?, restingHR: Int?) -> String? {
        guard let avgHR, avgHR > 0 else { return nil }
        guard let maxHR, let restingHR, maxHR > restingHR else { return nil }
        let zones = HeartRateZone.calculateZones(maxHR: maxHR, restingHR: restingHR)
        let zoneNumber = HeartRateZone.zoneFor(heartRate: Double(avgHR), in: zones)
        let keys = [
            1: "workout.detail.recovery_zone",
            2: "workout.detail.aerobic_zone",
            3: "workout.detail.marathon_zone",
            4: "workout.detail.threshold_zone",
            5: "workout.detail.anaerobic_zone",
            6: "workout.detail.interval_zone"
        ]
        guard let key = keys[zoneNumber] else { return nil }
        return NSLocalizedString(key, comment: "")
    }

    /// 課表那一格。有課型／距離／配速就串起來，一項都沒有＝這天沒課表。
    static func plannedSummary(_ plan: DailyPlanSummary?) -> String? {
        guard let plan else { return nil }
        var parts: [String] = []
        if let raw = plan.trainingType, !raw.isEmpty {
            parts.append(DayType(rawValue: raw)?.localizedName ?? raw)
        }
        if let km = plan.distanceKm, km > 0 {
            parts.append(String(format: "%.1f km", km))
        }
        if let pace = plan.pace?.app2NonEmpty {
            parts.append(pace)
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    static func actualSummary(durationS: Int?, avgHR: Int?) -> String? {
        var parts: [String] = []
        if let durationS, durationS > 0 {
            parts.append(formatDuration(seconds: durationS))
        }
        if let avgHR, avgHR > 0 {
            parts.append(String(format: L10n.App2.WorkoutDetail.avgHeartRateShort.localized, avgHR))
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    // MARK: - 格式化
    //
    // 公制／英制換算與 1.4 的 `WorkoutDetailViewModelV2` 同一組規則
    // （`UnitManager` 的 `metric`／`imperial`），不在這裡另訂一套。

    static func distanceMetric(meters: Double, unitSystem: UnitSystem) -> Metric {
        let km = meters / 1000
        let label = NSLocalizedString("workout.metrics.distance", comment: "距離")
        switch unitSystem {
        case .metric:
            return Metric(key: "distance", label: label, value: String(format: "%.2f", km), unit: "km")
        case .imperial:
            return Metric(key: "distance", label: label, value: String(format: "%.2f", km * 0.621371), unit: "mi")
        }
    }

    static func formatDuration(seconds: Int?) -> String {
        TimeFormatting.formatTime(max(0, seconds ?? 0))
    }

    static func formatPace(secondsPerKm: Double, unitSystem: UnitSystem) -> String {
        let rounded = Int(unitSystem.convertedPaceSeconds(secondsPerKm).rounded())
        return String(format: "%d:%02d", rounded / 60, rounded % 60)
    }
}

extension String {
    /// 去掉前後空白後還有內容才回傳。空字串在畫面上是一個佔位的空洞，不是資料。
    var app2NonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
