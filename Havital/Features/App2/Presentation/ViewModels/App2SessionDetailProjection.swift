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
    ///
    /// - Parameters:
    ///   - climateDay: 這一天的氣候。呼叫端一律給 `WeeklyPlanV2.climate(forDayIndex:)`
    ///     的結果 —— 那是氣候的 UI 唯一入口（`climate[7]` 優先、缺席才退 legacy
    ///     `climate_meta`）。只有配速帶的溫度補償用它（裁決（n））。
    ///   - vdot: 用戶 VDOT。nil ＝ 現場向 `VDOTManager` 要（測試才會明給）。
    ///   - isClimateAdjustmentEnabled: 溫度補償開關。nil ＝ 讀既有的
    ///     `ClimateAdjustmentSyncStore`（1.4 `climateAdjustmentEnabled` 同一個 key）。
    static func detail(
        day: DayDetail,
        weekStart: Date,
        calendar: Calendar = .current,
        climateDay: ClimateDay? = nil,
        vdot: Double? = nil,
        isClimateAdjustmentEnabled: Bool? = nil,
        planId: String? = nil
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
            // 同 `App2HomeViewModel.todaySession`：對不到課型就退 `day_target`，
            // 再退中性的「訓練」；不印識別字，也不退「輕鬆跑」。
            title: App2PlanViewModel.dayTypeLabel(dayType: dayType, dayTarget: day.dayTarget),
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
            paceBand: paceBand(
                bars: bars,
                dayType: dayType,
                vdot: vdot ?? nonZeroVDOT(),
                climate: climateDay,
                isClimateAdjustmentEnabled: isClimateAdjustmentEnabled
                    ?? (ClimateAdjustmentSyncStore.read() ?? false)
            ),
            // 逐日敘述只在證明得出它仍對應現在這一天時才交出去。
            goalText: isDayNarrativeConsistent(day: day) ? nonEmpty(day.dayTarget) : nil,
            // **`reason` 一律不顯示。** 它與 `day_target` 是分開生成的兩段，
            // payload 裡沒有任何欄位能證明它對應現在這一天，而 dev 上它本身就是錯的：
            // 2026-08-26 創辦人帳號 `e1289e60f251_1` 的 day_index 3 是 4×400m 間歇，
            // `reason` 卻寫「週三休息，為接下來的訓練儲備能量。」——後端缺陷，
            // 已回報，App 端先不把矛盾的話印在用戶眼前（不在 app 硬繞成別的內容）。
            reasonText: nil,
            segments: segments,
            strength: strength(day: day),
            climate: climate(
                meta: day.climateMeta,
                adjustedSummary: climateAdjustedSummary(day: day, segments: segments)
            ),
            showsFuelingNote: showsFuelingNote(dayType: dayType, durationMinutes: durationMinutes),
            isRunSession: isRun,
            watchPlan: day.primaryRunActivity.flatMap { activity in
                date.map { WatchPlanProjector.project(activity: activity, date: dateKey($0, calendar: calendar), planId: planId ?? "") }
            }
        )
    }

    /// 用戶 VDOT。`VDOTManager` 沒有值時給 0，這裡把 0 當成「沒有」——
    /// 拿 0 去算配速區間會得到荒謬的配速。
    private static func nonZeroVDOT() -> Double? {
        let value = VDOTManager.shared.currentVDOT
        return value > 0 ? value : nil
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

    /// 段落列要畫的內容。**換算在這裡做，不在投影的時候**（外審第八輪 E03）：
    /// 單段課的主課列存的是原始 payload，其餘列的字與單位無關。
    ///
    /// 同一份 `segment`（＝ modal 手上那一份）問兩種單位就得到兩種字，
    /// 不必重建 model —— 與 `App2SessionPaceBand.paceLabel(_:)` 同一種形狀。
    static func segmentDetail(
        _ segment: App2SessionDetailSegment,
        unitSystem: UnitSystem
    ) -> String? {
        if let steadyPrimary = segment.steadyPrimary {
            return App2PlanViewModel.contentLine(steadyPrimary, unitSystem: unitSystem)
        }
        return segment.fixedDetail
    }

    /// 逐段列。順序照 payload：`warmup` → `primary.segments[]` → `cooldown`。
    /// 單段課（輕鬆跑／長跑）只有一列主課 —— 那也是結構，不是「沒有結構」。
    static func detailSegments(day: DayDetail) -> [App2SessionDetailSegment] {
        var rows: [App2SessionDetailSegment] = []
        func append(
            _ name: String,
            detail: String? = nil,
            steadyPrimary: PrimaryActivity? = nil,
            repeats: String? = nil,
            note: String? = nil,
            isWork: Bool
        ) {
            guard detail != nil || steadyPrimary != nil || note != nil else { return }
            rows.append(.init(
                id: rows.count,
                index: rows.count + 1,
                name: name,
                fixedDetail: detail,
                steadyPrimary: steadyPrimary,
                repeatsLabel: repeats,
                note: note,
                isWork: isWork
            ))
        }

        // **暖身／緩和不掛 payload 的 `description`。** dev 實查那兩欄就是
        // 「熱身」「緩和」——段名的回音，一個字的新資訊都沒有（2026-08-28 走查 D27）。
        // 設計 frame-02d 的段附註句本來就規定「來源＝課型／段語意的確定性文案，
        // 不是逐日生成敘述」（同 `workSegmentNoteKey` 的理由）；這兩段沒有確定性
        // 文案，就不畫附註，而不是拿逐日敘述來填。
        append(
            NSLocalizedString("training.segment.warmup", comment: ""),
            detail: day.session?.warmup.flatMap(App2HomeViewModel.effortLabel(segment:)),
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
                //
                // **存原始 payload，不存格式化字串**（外審第八輪 E03）：這一列的距離
                // 與配速跟單位走，而詳情頁是 `fullScreenCover` 的 item，重投影換不掉
                // 已經遞進去的那一份。
                //
                // 「這一列存不存在」與單位無關（`contentLine` 只在距離／時長／配速
                // 三欄都缺席時回 nil），所以拿 `.metric` 問一次就夠，不必等到畫的時候。
                let hasSteadyLine = App2PlanViewModel.contentLine(
                    day.session?.primary, unitSystem: .metric
                ) != nil
                append(
                    L10n.App2.Home.segmentMain.localized,
                    steadyPrimary: hasSteadyLine ? day.session?.primary : nil,
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
        case .strength:
            // 肌力課的動作清單走「力量訓練」區塊（`strength(day:)`），不在這裡再列一次
            // —— 同一份內容不擺兩處（2026-08-27 晚走查裁決（d）收斂）。
            break
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

        // 同上：緩和段的 `description` 也只是段名回音，不掛。
        append(
            NSLocalizedString("training.segment.cooldown", comment: ""),
            detail: day.session?.cooldown.flatMap(App2HomeViewModel.effortLabel(segment:)),
            isWork: false
        )

        return rows
    }

    /// `組間休息：90 秒`。組不出量就沒有這一句。
    ///
    /// **量的部分用純數量字串**，不用首頁那組 chip（`app2.home.recovery_*`）——
    /// 那組自己就帶「組間」前綴，塞進「組間休息：」之後會變成
    /// 「組間休息：組間 120 秒」（2026-08-28 走查 D27）。秒／分沿用 1.4 分段列
    /// 在用的 `training.recovery.amount_*`，不另立第二份數量格式。
    static func recoveryNote(_ recovery: SegmentEffort?) -> String? {
        guard let recovery else { return nil }
        // 帶了恢復方式就寫出怎麼休息（AC-TRAIN-HUB-23），與首頁同一個 helper。
        if let label = App2HomeViewModel.typedRecoveryLabel(recovery) {
            return String(format: L10n.App2.Detail.recoveryNoteTyped.localized, label)
        }
        let value: String?
        if let seconds = recovery.durationSeconds {
            value = String(
                format: NSLocalizedString("training.recovery.amount_seconds", comment: ""),
                seconds
            )
        } else if let metres = recovery.distanceM {
            value = String(format: L10n.App2.Detail.recoveryMetres.localized, metres)
        } else if let minutes = recovery.durationMinutes {
            value = String(
                format: NSLocalizedString("training.recovery.amount_minutes", comment: ""),
                minutes
            )
        } else {
            value = nil
        }
        return value.map { String(format: L10n.App2.Detail.recoveryNote.localized, $0) }
    }

    // MARK: - 力量訓練（2026-08-27 晚走查裁決（d））

    /// 這一天的肌力內容 → 「力量訓練」區塊。
    ///
    /// **來源兩處，順序固定**：primary 本身是肌力課的那一份在前（那是今天的主課），
    /// 再接 day 層 `effectiveSupplementary` 的肌力項目（跑步日附加的那幾個動作）。
    /// 交叉訓練的 supplementary 不進這裡 —— 那不是力量訓練。
    ///
    /// 一個動作都排不出來（動作清單空、也沒有類型名可講）就整組丟掉；
    /// 全部都丟掉就回 nil，畫面整塊不出現。
    static func strength(day: DayDetail) -> App2SessionStrength? {
        var activities: [StrengthActivity] = []
        if case .strength(let primary)? = day.session?.primary {
            activities.append(primary)
        }
        for activity in day.effectiveSupplementary ?? [] {
            if case .strength(let supplementary) = activity {
                activities.append(supplementary)
            }
        }

        let groups = activities.enumerated().compactMap { index, activity -> App2SessionStrengthGroup? in
            let exercises = activity.exercises.enumerated().compactMap { position, exercise -> App2SessionStrengthExercise? in
                let name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return nil }
                return App2SessionStrengthExercise(
                    id: position,
                    name: name,
                    detail: strengthDetail(exercise)
                )
            }
            let typeLabel = strengthTypeLabel(activity.strengthType)
            guard !exercises.isEmpty || typeLabel != nil else { return nil }
            return App2SessionStrengthGroup(
                id: index,
                typeLabel: typeLabel,
                note: activity.description.flatMap(nonEmpty),
                durationLabel: activity.durationMinutes.map {
                    String(format: L10n.App2.Home.minutes.localized, $0)
                },
                exercises: exercises
            )
        }

        guard !groups.isEmpty else { return nil }
        return App2SessionStrength(groups: groups)
    }

    /// 後端已支援的肌力類型。**對不上就回 nil** —— 直接把 `strength_type` 插進
    /// `training.strength_type.<t>` 會在未知類型時把識別字原樣印給用戶
    /// （`NSLocalizedString` 找不到 key 就回 key 本身）。
    static let strengthTypeKeys: Set<String> = [
        "core_stability", "glutes_hip", "lower_strength",
        "upper_strength", "full_body", "plyometric", "mobility"
    ]

    static func strengthTypeLabel(_ rawType: String) -> String? {
        let key = rawType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard strengthTypeKeys.contains(key) else { return nil }
        return NSLocalizedString("training.strength_type.\(key)", comment: "")
    }

    /// `3 組 × 12 下`／`3 組 × 8-12 下`／`3 組 × 45 秒`。
    ///
    /// **`reps` 是字串不是數字**（後端可能給 `8-12` 這種範圍，見
    /// `TrainingSessionMapper.swift:234` 的 `reps_range` 合併），所以那一格是 `%2$@`。
    /// 之前用 `%2$d` 餵一個 String，印出來是指標值
    /// （2026-08-27 補投影測試時發現的既有缺陷）。
    static func strengthDetail(_ exercise: Exercise) -> String? {
        guard let sets = exercise.sets else { return nil }
        if let reps = exercise.reps?.trimmingCharacters(in: .whitespacesAndNewlines), !reps.isEmpty {
            return String(format: L10n.App2.Detail.strengthSetsReps.localized, sets, reps)
        }
        if let seconds = exercise.durationSeconds {
            return String(format: L10n.App2.Detail.strengthSetsSeconds.localized, sets, seconds)
        }
        return String(format: L10n.App2.Detail.strengthSets.localized, sets)
    }

    // MARK: - 熱適應

    /// 熱適應卡。`comfortable` 不說話（沿用 `ClimateDay+Display` 的規則與同一組 `climate.*` 文案）。
    ///
    /// 8/28 盤點 D3：說明句改走 app 自己的 `climate.recommendation.<level>`
    /// （三語齊，1.4 熱適應頁的同一組），不再原樣印後端 `reason_text` —— 那一句是
    /// 後端按請求語言生成的，實機上是英文坐在中文卡片裡。判準是結構化的
    /// `heat_pressure_level`，不是拿字串猜語言。**`reason_text` 只剩「這一天有沒有熱調整」
    /// 的存在性判定**（空字串＝後端沒有話說，整張卡不出現，與改動前同一條）。
    static func climate(meta: ClimateMeta?, adjustedSummary: String? = nil) -> App2SessionClimate? {
        guard let meta else { return nil }
        let level = meta.heatPressureLevel.lowercased()
        guard ["mild", "moderate", "high", "danger"].contains(level) else { return nil }
        guard !meta.reasonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return App2SessionClimate(
            shortLevel: NSLocalizedString("climate.short_level.\(level)", comment: ""),
            feelsLike: meta.feelsLikeTempC.map {
                "\(NSLocalizedString("climate.temperature_title", comment: "")) \(String(format: "%.1f°C", $0))"
            },
            reason: NSLocalizedString("climate.recommendation.\(level)", comment: ""),
            level: level,
            adjustedSummary: adjustedSummary
        )
    }

    /// 「調整後」那一句裡的量摘要 —— `4×400m @ 5:09/km`（Android
    /// `climateAdjustedTarget` 同一條）。
    ///
    /// 量取主課段（`isWork`）的距離半邊、趟數取同一段的 `repeats`；配速取
    /// `climate_adjusted_pace`。三者缺一就沒有這一行 —— 不編一個調整後配速出來。
    static func climateAdjustedSummary(
        day: DayDetail,
        segments: [App2SessionDetailSegment]
    ) -> String? {
        guard let raw = day.primaryRunActivity?.climateAdjustedPace,
              let pace = nonEmpty(raw)
        else { return nil }
        let adjusted = App2SegmentFormat.paceWithUnit(pace)
        let work = segments.first { $0.isWork } ?? segments.first
        // **這一行整行是公制**：右半邊的 `adjusted` 走 `App2SegmentFormat.paceWithUnit`，
        // 那是後端以公里給的處方配速字串，本票明確排除（票面「不在範圍」第 9 項）。
        // 量的半邊若跟著 app 單位走，這一行就變成本票要消滅的「同一行兩種單位」
        // （`5.0 mi @ 5:09/km`）。所以顯式傳 `.metric`，不吃當前設定。
        // 間歇日走的 `effortLabel(effort:)` 本來就是公制，兩種課型因此一致。
        guard let amount = work.flatMap({ segmentDetail($0, unitSystem: .metric) })?
            .components(separatedBy: App2SegmentFormat.separator).first?
            .trimmingCharacters(in: .whitespaces),
            !amount.isEmpty
        else {
            return adjusted
        }
        // 趟數取同一段的 `repeatsLabel`（`× 4`）的數字半邊 —— 趟數怎麼判只有一份
        // （`segments` 已經判好了），這裡不重讀 payload。
        let reps = (work?.repeatsLabel).flatMap { label -> String? in
            let digits = label.filter(\.isNumber)
            return digits.isEmpty ? nil : "\(digits)×"
        } ?? ""
        return "\(reps)\(amount) @ \(adjusted)"
    }

    // MARK: - 目標區間（設計 frame-02d 的兩張並排卡）

    /// 預估時間的**範圍**（設計 frame-02d：`24-28 分`／`53-57 分`／`2:30-2:42`）。
    ///
    /// 處方時長是一個點值，但實際跑起來不會落在那個點上；設計刻意把它畫成一段區間。
    /// 寬度＝處方時長的 ±4%，最少 ±2 分鐘（對回設計稿的四個例子：26→24-28、
    /// 55→53-57、42→40-44、156→2:30-2:42）。**推不出處方時長就沒有這一格。**
    static func estimatedRangeLabel(durationMinutes: Int?, dayType: DayType? = nil) -> String? {
        guard let range = estimatedRange(durationMinutes: durationMinutes, dayType: dayType) else { return nil }
        return "\(minuteLabel(range.low))-\(minuteLabel(range.high))"
    }

    static let estimatedRangeRatio: Double = 0.04
    static let easyEstimatedRangeRatio: Double = 0.10

    /// 輕鬆跑不強調配速，範圍只往慢的那一邊放（AC-TRAIN-HUB-24）。
    private static func estimatedRange(durationMinutes: Int?, dayType: DayType?) -> (low: Int, high: Int)? {
        guard let durationMinutes, durationMinutes > 0 else { return nil }
        if let dayType, [.easy, .easyRun, .lsd].contains(dayType) {
            let slack = max(2, Int((Double(durationMinutes) * easyEstimatedRangeRatio).rounded()))
            return (durationMinutes, durationMinutes + slack)
        }
        let tolerance = max(2, Int((Double(durationMinutes) * estimatedRangeRatio).rounded()))
        return (max(1, durationMinutes - tolerance), durationMinutes + tolerance)
    }

    /// 60 分鐘以內印分鐘數，超過印 `h:mm`（設計 frame-02d 的 `2:30`）。
    private static func minuteLabel(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes)" }
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    /// 預估時間那一格的單位小字。60 分以內是「分」，超過就沒有單位（值本身是 `h:mm`）。
    static func estimatedRangeUnit(durationMinutes: Int?, dayType: DayType? = nil) -> String? {
        guard let range = estimatedRange(durationMinutes: durationMinutes, dayType: dayType) else { return nil }
        return range.high < 60 ? L10n.App2.Detail.minutesUnit.localized : nil
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
    /// 邊界有兩種來源（2026-08-27 走查裁決（n））：
    /// - **輕鬆跑／恢復跑**：用戶自己的配速區間（`easyPaceRangeSeconds`，與設定頁
    ///   「配速區間」同一支 `PaceCalculator.getPaceRange(for:vdot:)`）。處方配速仍是
    ///   帶上那顆 pill —— 換掉的是帶寬，不是處方。
    /// - **其餘課型**：維持處方配速 ±15 秒（payload 沒有配速區間欄位）。
    ///
    /// 溫度補償開啟且當日帶 `pace_adjustment_pct` 時，帶上的值**維持原始處方配速**，
    /// 補償額度換算成「每公里（或每英里）可慢 N 秒」一句話交出去
    /// （2026-08-27 走查改版：用戶要看的是原配速＋允許慢多少，不是被換算過的配速）。
    static func paceBand(
        bars: [App2SessionStructureBar],
        dayType: DayType? = nil,
        vdot: Double? = nil,
        climate: ClimateDay? = nil,
        isClimateAdjustmentEnabled: Bool = false
    ) -> App2SessionPaceBand? {
        guard bars.count == 1,
              let bar = bars.first,
              bar.kind == .steady,
              let pace = bar.paceLabel,
              let seconds = PaceFormatterHelper.paceToSeconds(pace),
              let legend = bar.noteLabel
        else { return nil }

        var fastSeconds = seconds - boundaryToleranceSeconds
        var slowSeconds = seconds + boundaryToleranceSeconds
        if let range = easyPaceRangeSeconds(dayType: dayType, vdot: vdot) {
            // 處方配速落在區間外時把帶撐開到含住它 —— 否則 pill 會畫在自己的帶外面。
            fastSeconds = min(range.fast, seconds)
            slowSeconds = max(range.slow, seconds)
        }

        // 溫度補償：`pace × (1 + pct/100)`，與 1.4 熱適應卡
        // （`ClimateDay.climateAdjustedPace(forBasePace:)`）同一條公式，不另算一份。
        // 帶上的值**不換算** —— 補償只出現在下面那句「每公里可慢 N 秒」。
        let adjustmentPct = isClimateAdjustmentEnabled ? (climate?.paceAdjustmentPct ?? 0) : 0

        // **這裡不做單位換算**（2026-09-01，T-0366 外審第四輪 E03）：這份 model 會被
        // `fullScreenCover` 的 item 捕捉住，投影時換算完，切換單位後那張已經開著的
        // 詳情頁就永遠是舊單位。換算與單位字都在畫的時候做（`App2SessionPaceBand`）。
        return App2SessionPaceBand(
            paceSecondsPerKm: seconds,
            fastSecondsPerKm: fastSeconds,
            slowSecondsPerKm: slowSeconds,
            legendLabel: legend,
            climateAdjustmentPct: adjustmentPct
        )
    }

    /// 恢復課的配速區間（秒／km），裁決（n）的帶寬來源。
    ///
    /// **與設定頁「配速區間」同一支** `PaceCalculator.getPaceRange(for:vdot:)`
    /// （`App2PaceZoneSettingsView.paceText(for:)` 也是它）——不在這裡另訂第二份區間。
    /// 沒有 VDOT、課型不是輕鬆／恢復、或區間退化成一個點時回 nil，帶就退回處方 ±15 秒。
    static func easyPaceRangeSeconds(dayType: DayType?, vdot: Double?) -> (fast: Double, slow: Double)? {
        guard let vdot, vdot > 0,
              let trainingType = easyPaceTrainingType(dayType),
              let range = PaceCalculator.getPaceRange(for: trainingType, vdot: vdot),
              let fast = PaceFormatterHelper.paceToSeconds(range.min),
              let slow = PaceFormatterHelper.paceToSeconds(range.max),
              slow > fast
        else { return nil }
        return (fast: fast, slow: slow)
    }

    /// 課型 → `PaceCalculator` 的訓練類型鍵。裁決（n）原本含輕鬆跑，
    /// 但 2026-09-11 裁決「輕鬆跑／長距離輕鬆跑一律不顯示配速」之後那一支走不到了
    /// （`paceBand` 的第一道 guard 就是塊上的配速字），所以只留**恢復跑**。
    /// 其餘課型（長跑、節奏、閾值…）維持處方窄窗，不在這裡擴充。
    static func easyPaceTrainingType(_ dayType: DayType?) -> String? {
        switch dayType {
        case .recovery_run: return "recovery"
        default:            return nil
        }
    }

    /// 快／慢邊界離處方配速多遠。
    static let boundaryToleranceSeconds: Double = 15

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
