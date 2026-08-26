import Foundation

// MARK: - App2SessionDetailProjection
/// Presentation Layer — 訓練詳情頁的投影（設計 frame-02／dc.html「課表詳細 · …」四版）。
///
/// **這一頁不打端點。** 首頁與課表頁手上已經有本週課表的 `DayDetail`，詳情頁
/// 只是同一份 payload 的第二個版面。分段列、配速結構圖、熱適應卡全部從那一份組出來，
/// 組不出來的區塊整塊不出現 —— 不用 placeholder，也不本機推一個值。
///
/// **為什麼不接 1.4 的那一份**：`PlannedSessionDetailView` 內的
/// `buildDetailSegments()`／`DetailSegmentData` 與 `SegmentIntervalDisplay` 是 1.4 的版面，
/// 拆段規則綁著那一版的視覺。2.0 復用的是自己這一份投影
/// （`App2HomeViewModel.segments/structureBars/effortLabel`、
/// `App2PlanViewModel.contentLine/dayType/intensityLabel`），不另立第三套拆段規則。
/// **型別與 1.4 已經同源**：兩邊都吃 domain entity（`DayDetail`／`RunSegment`），
/// 2.0 不再從 `TrainingPlanV2RemoteDataSource` 直讀 DTO（2026-08-26 架構收斂）。
@MainActor
enum App2SessionDetailProjection {

    /// 休息日不進詳情（設計沒有休息日的詳情版式；點下去只會看到一頁空卡）。
    static func detail(
        day: DayDetail,
        weekStart: Date,
        calendar: Calendar = .current
    ) -> App2SessionDetail? {
        let primary = day.session?.primary
        let dayType = primary == nil ? DayType.rest : App2PlanViewModel.dayType(primary)
        guard dayType != .rest else { return nil }

        let date = calendar.date(byAdding: .day, value: day.dayIndex - 1, to: weekStart)
        let segments = detailSegments(day: day)
        let bars = App2HomeViewModel.structureBars(day: day)

        var distanceKm: Double?
        var durationMinutes: Int?
        var durationSeconds: Double?
        var isRun = false
        switch primary {
        case .run(let run):
            isRun = true
            // 間歇課的 `duration_minutes` 缺席（dev 實測 4×400m 那天沒有這一欄），
            // hero 的「預計時間」那一格就會整格消失。從處方分段推：
            // 熱身 ＋ 主課（含組間恢復）＋ 緩和。推不出來才留白。
            durationMinutes = run.durationMinutes
            durationSeconds = run.durationMinutes.map { Double($0) * 60 }
                ?? plannedSeconds(day: day, run: run)
            // 日層 `distance_km` 是這一天的總量（熱身＋主課＋緩和）。`primary.distance_km`
            // 在間歇課只算主課段（dev 實測 2.2 vs 日層 5.2），拿它當 hero 的「總距離」
            // 會跟下面的分段列加不起來（2026-08-26 使用者回報）。
            distanceKm = day.distanceKm ?? run.distanceKm
        case .cross(let cross):
            durationMinutes = cross.durationMinutes
        case .strength(let strength):
            durationMinutes = strength.durationMinutes
        case .none:
            break
        }

        return App2SessionDetail(
            dayIndex: day.dayIndex,
            dateString: date.map { dateKey($0, calendar: calendar) },
            dateTitle: dateTitle(date: date, dayIndex: day.dayIndex, weekStart: weekStart, calendar: calendar),
            // 同 `App2HomeViewModel.todaySession`：對不到課型就退 `day_target`，不印識別字。
            title: dayType?.localizedName ?? day.dayTarget,
            dayType: dayType,
            kicker: kicker(day: day),
            distanceKm: (distanceKm ?? 0) > 0 ? distanceKm : nil,
            // 設計 frame-02 的「預計時間」是 `24:00`／`54:40`／`2:36`（等寬數字），
            // 不是「41 分鐘」。有秒數就用秒數格式，只有分鐘就補成 `mm:00`。
            durationLabel: (durationSeconds ?? durationMinutes.map { Double($0) * 60 })
                .map { TimeFormatting.formatTime(Int($0.rounded())) },
            durationMinutes: durationMinutes
                ?? durationSeconds.map { Int(($0 / 60).rounded()) },
            phaseCount: max(segments.count, 1),
            structureBars: bars,
            paceBand: paceBand(bars: bars, distanceKm: distanceKm),
            // 逐日敘述只在證明得出它仍對應現在這一天時才交出去。
            goalText: isDayNarrativeConsistent(day: day) ? nonEmpty(day.dayTarget) : nil,
            // **`reason` 一律不顯示。** 它與 `day_target` 是分開生成的兩段，
            // payload 裡沒有任何欄位能證明它對應現在這一天，而 dev 上它本身就是錯的：
            // 2026-08-26 創辦人帳號 `e1289e60f251_1` 的 day_index 3 是 4×400m 間歇，
            // `reason` 卻寫「週三休息，為接下來的訓練儲備能量。」——後端缺陷，
            // 已回報，App 端先不把矛盾的話印在用戶眼前（不在 app 硬繞成別的內容）。
            reasonText: nil,
            segments: segments,
            climate: climate(meta: day.climateMeta),
            showsFuelingNote: showsFuelingNote(dayType: dayType, durationMinutes: durationMinutes),
            isRunSession: isRun
        )
    }

    // MARK: - Hero

    /// Hero 第一行的 kicker（設計 `STEADY + INTERVALS · Z3 → Z5`）。
    ///
    /// **這一行不得消失**（2026-08-26 裁決）：payload 有 `pace_zone` 就用它，
    /// 沒有就退到課型的區間對照（`TrainingEffortScale.zone`），再退到結構詞。
    /// 結構詞是 `DayType` 的英文大寫短語，不是把 `run_type` 識別字原樣印出去。
    static func kicker(day: DayDetail) -> String? {
        let primary = day.session?.primary
        let dayType = primary == nil ? DayType.rest : App2PlanViewModel.dayType(primary)
        var parts: [String] = []
        if let word = structureWord(dayType) { parts.append(word) }

        if case .run(let run) = primary {
            let zones = App2PlanViewModel.effectiveSegments(run).compactMap { $0.work?.paceZone ?? $0.pace }
            if let zone = zones.first(where: { $0.uppercased().hasPrefix("Z") }) {
                parts.append(zone.uppercased())
            } else if let dayType, let zone = TrainingEffortScale.value(for: dayType)?.zone {
                parts.append(zone)
            }
        }
        if parts.isEmpty { return App2PlanViewModel.intensityLabel(primary) }
        return parts.joined(separator: " · ")
    }

    /// 課型的結構詞（`EASY RUN`／`INTERVALS`／`STEADY + INTERVALS`）。
    /// 是 `DayType` 的型別對照，不是對顯示字做詞表比對；對不上就 nil。
    static func structureWord(_ dayType: DayType?) -> String? {
        switch dayType {
        case .easy, .easyRun:            return "EASY RUN"
        case .recovery_run:              return "RECOVERY"
        case .lsd, .longRun:             return "LONG RUN"
        case .hiking:                    return "HIKE"
        case .tempo:                     return "TEMPO"
        case .threshold:                 return "THRESHOLD"
        case .cruiseIntervals:           return "CRUISE INTERVALS"
        case .norwegianSingles:          return "SUB-THRESHOLD"
        case .norwegian4x4:              return "NORWEGIAN 4×4"
        case .interval:                  return "INTERVALS"
        case .shortInterval:             return "SHORT INTERVALS"
        case .longInterval:              return "LONG INTERVALS"
        case .yasso800:                  return "YASSO 800"
        case .hillRepeats:               return "HILL REPEATS"
        case .strides:                   return "STRIDES"
        case .fartlek:                   return "FARTLEK"
        case .steadyIntervals:           return "STEADY + INTERVALS"
        case .progression:               return "PROGRESSION"
        case .fastFinish:                return "FAST FINISH"
        case .racePace:                  return "RACE PACE"
        case .race:                      return "RACE"
        case .benchmark:                 return "BENCHMARK"
        case .combination:               return "COMBINATION"
        case .strength:                  return "STRENGTH"
        case .crossTraining, .yoga, .cycling, .swimming, .elliptical, .rowing:
            return "CROSS TRAINING"
        case .rest, .none:               return nil
        }
    }

    /// 這一堂課的預計時間（秒）：熱身 ＋ 主課（間歇含組間恢復）＋ 緩和。
    /// 每一段都用處方值推（明寫時長優先，否則距離 ÷ 處方配速）；
    /// 主課段推不出來就整個回 nil —— 少一格數據，不編一個數字。
    static func plannedSeconds(day: DayDetail, run: RunActivity) -> Double? {
        func seconds(_ segment: RunSegment?) -> Double? {
            guard let segment else { return nil }
            return App2PlanViewModel.effortSeconds(SegmentEffort(
                distanceKm: segment.distanceKm,
                distanceM: segment.distanceM,
                durationMinutes: segment.durationMinutes,
                durationSeconds: segment.durationSeconds,
                pace: segment.pace,
                basePace: segment.basePace,
                paceZone: nil,
                targetHrr: nil,
                recoveryType: nil
            ))
        }

        var total: Double = 0
        var hasMain = false
        for segment in App2PlanViewModel.effectiveSegments(run) {
            if segment.segmentKind == .interval, let repeats = segment.repeats, repeats > 0,
               let work = segment.work, let workSeconds = App2PlanViewModel.effortSeconds(work) {
                let recovery = segment.recovery.flatMap(App2PlanViewModel.effortSeconds) ?? 0
                total += workSeconds * Double(repeats) + recovery * Double(max(repeats - 1, 0))
                hasMain = true
            } else if let value = seconds(segment) {
                total += value
                hasMain = true
            }
        }
        guard hasMain else { return nil }
        total += seconds(day.session?.warmup) ?? 0
        total += seconds(day.session?.cooldown) ?? 0
        return total
    }

    /// `day_target`／`reason` 這兩段**逐日生成的敘述**還對得上現在這一天嗎？
    ///
    /// 用戶在編輯器改過課型之後後端不重生那兩段，畫面上就會出現與當日課表矛盾的話
    /// （2026-08-26 使用者截圖：間歇課的「本次訓練目標」寫著週三休息）。
    ///
    /// payload 內唯一能拿來證明的結構訊號是 `primary.description`：課表生成時它被
    /// 寫成與 `day_target` 同一句，而編輯器換課型時會用新課型的描述覆寫它
    /// （`EditScheduleV2ViewModel.swift:334/362/390/398`）。所以兩者相等＝這一段
    /// 敘述與現在的 primary 同一次產出；不相等＝證明不了，就不顯示。
    ///
    /// **這是字串相等比對，不是語意判斷** —— 不去猜敘述在講哪一種課。
    static func isDayNarrativeConsistent(day: DayDetail) -> Bool {
        let target = day.dayTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return false }
        let description: String?
        switch day.session?.primary {
        case .run(let run):           description = run.description
        case .strength(let strength): description = strength.description
        case .cross(let cross):       description = cross.description
        case .none:                   return false
        }
        return description?.trimmingCharacters(in: .whitespacesAndNewlines) == target
    }

    // MARK: - 訓練結構

    /// 逐段列。順序照 payload：`warmup` → `primary.segments[]` → `cooldown`。
    /// 單段課（輕鬆跑／長跑）只有一列主課 —— 那也是結構，不是「沒有結構」。
    static func detailSegments(day: DayDetail) -> [App2SessionDetailSegment] {
        var rows: [App2SessionDetailSegment] = []
        func append(_ name: String, detail: String?, repeats: String? = nil, note: String? = nil, isWork: Bool) {
            guard detail != nil || note != nil else { return }
            rows.append(.init(
                id: rows.count,
                index: rows.count + 1,
                name: name,
                detail: detail,
                repeatsLabel: repeats,
                note: note,
                isWork: isWork
            ))
        }

        append(
            NSLocalizedString("training.segment.warmup", comment: ""),
            detail: day.session?.warmup.flatMap(App2HomeViewModel.effortLabel(segment:)),
            note: day.session?.warmup?.description.flatMap(nonEmpty),
            isWork: false
        )

        switch day.session?.primary {
        case .run(let run):
            let runSegments = App2PlanViewModel.effectiveSegments(run)
            if runSegments.isEmpty {
                // **不掛 `run.description`**：那一欄是後端組出來的機器回音
                // （dev 實測 `"lsd 6.0 km"` —— 識別字 ＋ 已經在同一列上的量），
                // 印出來等於把 `run_type` 直接顯示給用戶。人話那一句是 `day_target`，
                // 已經在上面的「本次訓練目標」卡。
                append(
                    L10n.App2.Home.segmentMain.localized,
                    detail: App2PlanViewModel.contentLine(day.session?.primary),
                    isWork: true
                )
            }
            for segment in runSegments {
                if segment.segmentKind == .interval {
                    let repeats = segment.repeats ?? 0
                    append(
                        NSLocalizedString("training.segment.sprint", comment: ""),
                        detail: segment.work.flatMap(App2HomeViewModel.effortLabel(effort:)),
                        repeats: repeats > 1 ? "× \(repeats)" : nil,
                        note: recoveryNote(segment.recovery),
                        isWork: true
                    )
                } else {
                    append(
                        L10n.App2.Home.segmentMain.localized,
                        detail: App2HomeViewModel.effortLabel(segment: segment),
                        note: segment.description.flatMap(nonEmpty),
                        isWork: true
                    )
                }
            }
        case .strength(let strength):
            for exercise in strength.exercises {
                append(exercise.name, detail: strengthDetail(exercise), isWork: true)
            }
        case .cross(let cross):
            append(
                L10n.App2.Home.segmentMain.localized,
                detail: String(format: L10n.App2.Home.minutes.localized, cross.durationMinutes),
                note: cross.description.flatMap(nonEmpty),
                isWork: true
            )
        case .none:
            break
        }

        append(
            NSLocalizedString("training.segment.cooldown", comment: ""),
            detail: day.session?.cooldown.flatMap(App2HomeViewModel.effortLabel(segment:)),
            note: day.session?.cooldown?.description.flatMap(nonEmpty),
            isWork: false
        )

        return rows
    }

    /// `組間休息：90 秒`。組不出量就沒有這一句。
    static func recoveryNote(_ recovery: SegmentEffort?) -> String? {
        guard let recovery else { return nil }
        let value: String?
        if let seconds = recovery.durationSeconds {
            value = String(format: L10n.App2.Home.recoverySeconds.localized, seconds)
        } else if let metres = recovery.distanceM {
            value = String(format: L10n.App2.Home.recoveryMetres.localized, metres)
        } else if let minutes = recovery.durationMinutes {
            value = String(format: L10n.App2.Home.minutes.localized, minutes)
        } else {
            value = nil
        }
        return value.map { String(format: L10n.App2.Detail.recoveryNote.localized, $0) }
    }

    /// `3 組 × 12 下`／`3 組 × 45 秒`。
    static func strengthDetail(_ exercise: Exercise) -> String? {
        guard let sets = exercise.sets else { return nil }
        if let reps = exercise.reps {
            return String(format: L10n.App2.Detail.strengthSetsReps.localized, sets, reps)
        }
        if let seconds = exercise.durationSeconds {
            return String(format: L10n.App2.Detail.strengthSetsSeconds.localized, sets, seconds)
        }
        return String(format: L10n.App2.Detail.strengthSets.localized, sets)
    }

    // MARK: - 熱適應

    /// 熱適應卡。`comfortable` 不說話（沿用 `ClimateDay+Display` 的規則與同一組 `climate.*` 文案）。
    static func climate(meta: ClimateMeta?) -> App2SessionClimate? {
        guard let meta else { return nil }
        let level = meta.heatPressureLevel.lowercased()
        guard ["mild", "moderate", "high", "danger"].contains(level) else { return nil }
        let reason = meta.reasonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else { return nil }
        return App2SessionClimate(
            shortLevel: NSLocalizedString("climate.short_level.\(level)", comment: ""),
            feelsLike: meta.feelsLikeTempC.map {
                "\(NSLocalizedString("climate.temperature_title", comment: "")) \(String(format: "%.1f°C", $0))"
            },
            reason: reason,
            level: level
        )
    }

    // MARK: - 目標區間（設計 frame-02d 的兩張並排卡）

    /// 預估時間的**範圍**（設計 frame-02d：`24-28 分`／`53-57 分`／`2:30-2:42`）。
    ///
    /// 處方時長是一個點值，但實際跑起來不會落在那個點上；設計刻意把它畫成一段區間。
    /// 寬度＝處方時長的 ±4%，最少 ±2 分鐘（對回設計稿的四個例子：26→24-28、
    /// 55→53-57、42→40-44、156→2:30-2:42）。**推不出處方時長就沒有這一格。**
    static func estimatedRangeLabel(durationMinutes: Int?) -> String? {
        guard let durationMinutes, durationMinutes > 0 else { return nil }
        let tolerance = max(2, Int((Double(durationMinutes) * estimatedRangeRatio).rounded()))
        let low = max(1, durationMinutes - tolerance)
        let high = durationMinutes + tolerance
        return "\(minuteLabel(low))-\(minuteLabel(high))"
    }

    static let estimatedRangeRatio: Double = 0.04

    /// 60 分鐘以內印分鐘數，超過印 `h:mm`（設計 frame-02d 的 `2:30`）。
    private static func minuteLabel(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes)" }
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    /// 預估時間那一格的單位小字。60 分以內是「分」，超過就沒有單位（值本身是 `h:mm`）。
    static func estimatedRangeUnit(durationMinutes: Int?) -> String? {
        guard let durationMinutes, durationMinutes > 0 else { return nil }
        let tolerance = max(2, Int((Double(durationMinutes) * estimatedRangeRatio).rounded()))
        return durationMinutes + tolerance < 60 ? L10n.App2.Detail.minutesUnit.localized : nil
    }

    // MARK: - 段附註句

    /// 主課段的附註句（設計 frame-02d：「連續不中斷，維持穩定閾值配速」
    /// 「全程勻速，最後 5 公里才是重點」）。
    ///
    /// **來源是課型的確定性文案，不是逐日生成敘述** —— 逐日敘述在編輯器改過課型之後
    /// 後端不重生，會與當日課表矛盾（同 `isDayNarrativeConsistent` 的理由）。
    /// 這是 `DayType` 的型別對照，對不上的課型就沒有這一句。
    static func workSegmentNoteKey(_ dayType: DayType?) -> String? {
        switch dayType {
        case .tempo, .threshold, .cruiseIntervals, .norwegianSingles, .progression:
            return L10n.App2.Detail.structureNoteThreshold
        case .lsd, .longRun, .hiking:
            return L10n.App2.Detail.structureNoteLong
        case .easy, .easyRun, .recovery_run:
            return L10n.App2.Detail.structureSteadyNote
        default:
            return nil
        }
    }

    // MARK: - 補給建議

    /// 長距離課的補給建議框。
    ///
    /// **這是設計稿的靜態教練建議，不是 payload 欄位**（後端沒有補給出口）。
    /// 只在真的是長距離課且預計時長 ≥ 90 分鐘時出現 —— 一堂 40 分鐘的「長跑」
    /// 掛「每 45 分鐘補給一次」是廢話。
    static let fuelingMinimumMinutes = 90

    static func showsFuelingNote(dayType: DayType?, durationMinutes: Int?) -> Bool {
        guard let dayType, dayType == .lsd || dayType == .longRun else { return false }
        guard let durationMinutes else { return false }
        return durationMinutes >= fuelingMinimumMinutes
    }

    // MARK: - 配速帶（單段勻速課）

    /// 只有**整堂課就一段穩定跑**時才有配速帶（設計 frame-02c）。
    /// 有暖身／緩和／間歇＝多段，維持長條圖。
    ///
    /// 邊界目前用處方配速 ±15 秒、目標窗 ±10 秒 —— payload 沒有配速區間欄位
    /// （見 `App2SessionPaceBand` 的註解）。
    static func paceBand(
        bars: [App2SessionStructureBar],
        distanceKm: Double?
    ) -> App2SessionPaceBand? {
        guard bars.count == 1,
              let bar = bars.first,
              bar.kind == .steady,
              let pace = bar.paceLabel,
              let seconds = PaceFormatterHelper.paceToSeconds(pace),
              let legend = bar.noteLabel
        else { return nil }

        // 配速一律換算成用戶的單位制。這幾格原本一律當公制、由圖表寫死 `/km` 補單位，
        // 英制用戶看到的是「公里配速掛著 /km」（2026-08-26 架構收斂順修）。
        // 值本身不含單位，單位由 `paceUnitLabel` 交給圖表 —— 設計上那個字是分開排版的。
        let unitSystem = UnitManager.shared.currentUnitSystem
        return App2SessionPaceBand(
            paceLabel: paceLabel(seconds, unitSystem: unitSystem),
            fastLabel: paceLabel(seconds - boundaryToleranceSeconds, unitSystem: unitSystem),
            slowLabel: paceLabel(seconds + boundaryToleranceSeconds, unitSystem: unitSystem),
            windowLabel: paceLabel(seconds - windowToleranceSeconds, unitSystem: unitSystem)
                + "-" + paceLabel(seconds + windowToleranceSeconds, unitSystem: unitSystem),
            paceUnitLabel: unitSystem.paceSuffix,
            endKmLabel: (distanceKm ?? 0) > 0
                ? App2NumberFormat.grouped(distanceKm ?? 0, maximumFractionDigits: 1)
                : nil,
            legendLabel: legend
        )
    }

    /// 快／慢邊界離處方配速多遠。
    static let boundaryToleranceSeconds: Double = 15
    /// 目標窗離處方配速多遠。
    static let windowToleranceSeconds: Double = 10

    /// 秒／km → 用戶單位制的配速值（**不含**單位字，單位由 `paceUnitLabel` 給）。
    /// 換算係數走 `UnitSystem`，與 `UnitManager.formatPace` 同一份，不另訂。
    static func paceLabel(_ secondsPerKm: Double, unitSystem: UnitSystem) -> String {
        let total = max(Int(unitSystem.convertedPaceSeconds(secondsPerKm).rounded()), 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - Formatting

    /// `星期一 · 8/10`
    static func dateTitle(
        date: Date?,
        dayIndex: Int,
        weekStart: Date,
        calendar: Calendar = .current
    ) -> String {
        let dayLabel = App2WeekCalendar.dateLabel(dayIndex: dayIndex, weekStart: weekStart, calendar: calendar)
        guard let date else { return dayLabel }
        let weekday = DateFormatter()
        // 跟著 app 語言走，不是 `Locale.current`（見 `SupportedLanguage.locale`）。
        weekday.locale = LanguageManager.shared.locale
        weekday.calendar = calendar
        weekday.setLocalizedDateFormatFromTemplate("EEEE")
        return "\(weekday.string(from: date)) · \(dayLabel)"
    }

    /// Garmin push 要的 `yyyy-MM-dd`（裝置當地日期）。
    static func dateKey(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
