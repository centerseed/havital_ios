import Foundation

// MARK: - App2SessionDetailProjection
/// Presentation Layer — 訓練詳情頁的投影（設計 frame-02／dc.html「課表詳細 · …」四版）。
///
/// **這一頁不打端點。** 首頁與課表頁手上已經有本週課表的 `DayDetailDTO`，詳情頁
/// 只是同一份 payload 的第二個版面。分段列、配速結構圖、熱適應卡全部從那一份組出來，
/// 組不出來的區塊整塊不出現 —— 不用 placeholder，也不本機推一個值。
///
/// **為什麼不接 1.4 的那一份**：`PlannedSessionDetailView` 內的
/// `buildDetailSegments()`／`DetailSegmentData`（同檔 927–1018 行）與
/// `SegmentIntervalDisplay` 都吃 **Domain entity**（`DayDetail`／`RunSegment`），
/// 而 2.0 這條線從 `TrainingPlanV2RemoteDataSource` 直接讀 **DTO**，中間沒有 mapper。
/// 這裡復用的是 2.0 自己那一份 DTO 投影（`App2HomeViewModel.segments/structureBars/
/// effortLabel`、`App2PlanViewModel.contentLine/dayType/intensityLabel`），不另立第三套
/// 拆段規則。
@MainActor
enum App2SessionDetailProjection {

    /// 休息日不進詳情（設計沒有休息日的詳情版式；點下去只會看到一頁空卡）。
    static func detail(
        day: DayDetailDTO,
        weekStart: Date,
        calendar: Calendar = .current
    ) -> App2SessionDetail? {
        let dayType = day.primary == nil ? DayType.rest : App2PlanViewModel.dayType(day.primary)
        guard dayType != .rest else { return nil }

        let date = calendar.date(byAdding: .day, value: day.dayIndex - 1, to: weekStart)
        let segments = detailSegments(day: day)

        var distanceKm: Double?
        var durationMinutes: Int?
        var isRun = false
        switch day.primary {
        case .run(let run):
            isRun = true
            distanceKm = run.distanceKm
            durationMinutes = run.durationMinutes
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
            title: dayType?.localizedName ?? (day.category ?? day.dayTarget),
            dayType: dayType,
            kicker: kicker(day: day),
            distanceKm: (distanceKm ?? 0) > 0 ? distanceKm : nil,
            durationLabel: durationMinutes.map { String(format: L10n.App2.Home.minutes.localized, $0) },
            phaseCount: max(segments.count, 1),
            structureBars: App2HomeViewModel.structureBars(day: day),
            goalText: nonEmpty(day.dayTarget),
            reasonText: nonEmpty(day.reason),
            segments: segments,
            climate: climate(meta: day.climateMeta),
            showsFuelingNote: showsFuelingNote(dayType: dayType, durationMinutes: durationMinutes),
            isRunSession: isRun
        )
    }

    // MARK: - Hero

    /// `Z2`／`高強度`。payload 兩個欄位都沒有就沒有這一行。
    /// **不印 `run_type`** —— 那是識別字，不是文案。
    static func kicker(day: DayDetailDTO) -> String? {
        guard case .run(let run) = day.primary else {
            return App2PlanViewModel.intensityLabel(day.primary)
        }
        let zones = (run.segments ?? []).compactMap { $0.work?.paceZone ?? $0.pace }
        if let zone = zones.first(where: { $0.uppercased().hasPrefix("Z") }) {
            return zone.uppercased()
        }
        return App2PlanViewModel.intensityLabel(day.primary)
    }

    // MARK: - 訓練結構

    /// 逐段列。順序照 payload：`warmup` → `primary.segments[]` → `cooldown`。
    /// 單段課（輕鬆跑／長跑）只有一列主課 —— 那也是結構，不是「沒有結構」。
    static func detailSegments(day: DayDetailDTO) -> [App2SessionDetailSegment] {
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
            detail: day.warmup.flatMap(App2HomeViewModel.effortLabel(segment:)),
            note: day.warmup?.description.flatMap(nonEmpty),
            isWork: false
        )

        switch day.primary {
        case .run(let run):
            let runSegments = run.segments ?? []
            if runSegments.isEmpty {
                // **不掛 `run.description`**：那一欄是後端組出來的機器回音
                // （dev 實測 `"lsd 6.0 km"` —— 識別字 ＋ 已經在同一列上的量），
                // 印出來等於把 `run_type` 直接顯示給用戶。人話那一句是 `day_target`，
                // 已經在上面的「本次訓練目標」卡。
                append(
                    L10n.App2.Home.segmentMain.localized,
                    detail: App2PlanViewModel.contentLine(day.primary),
                    isWork: true
                )
            }
            for segment in runSegments {
                if segment.kind == "interval" {
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
            detail: day.cooldown.flatMap(App2HomeViewModel.effortLabel(segment:)),
            note: day.cooldown?.description.flatMap(nonEmpty),
            isWork: false
        )

        return rows
    }

    /// `組間休息：90 秒`。組不出量就沒有這一句。
    static func recoveryNote(_ recovery: SegmentEffortDTO?) -> String? {
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
    static func strengthDetail(_ exercise: ExerciseDTO) -> String? {
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
    static func climate(meta: ClimateMetaDTO?) -> App2SessionClimate? {
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

    // MARK: - Formatting

    /// `星期一 · 8/10`
    static func dateTitle(
        date: Date?,
        dayIndex: Int,
        weekStart: Date,
        calendar: Calendar = .current
    ) -> String {
        let dayLabel = App2PlanViewModel.dateLabel(dayIndex: dayIndex, weekStart: weekStart, calendar: calendar)
        guard let date else { return dayLabel }
        let weekday = DateFormatter()
        weekday.locale = Locale.current
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
