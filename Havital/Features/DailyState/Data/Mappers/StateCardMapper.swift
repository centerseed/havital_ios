import Foundation

// MARK: - StateCardMapper
/// DTO → Entity 轉換。純函式 enum，無狀態。
enum StateCardMapper {
    static func toEntity(from dto: StateCardDTO) -> DailyStateCard {
        DailyStateCard(
            lens: DailyStateCard.Lens(rawValue: dto.lens) ?? .pre,
            source: dto.source ?? "steady",
            headline: dto.headline,
            factType: dto.factType,
            narrativeText: dto.narrativeText,
            collapsedReason: dto.collapsedReason,
            chips: dto.chips ?? [],
            causeChips: dto.causeChips ?? [],
            mileageProgression: dto.mileageProgression,
            actionLine: actionLine(from: dto.action),
            rizoScenario: dto.action?.rizoHandoff?.scenario ?? dto.divergence?.suggestedRizoScenario,
            divergenceFlagText: (dto.divergence?.present == true) ? dto.divergence?.flagText : nil,
            isPaid: dto.access.isPaid,
            isLocked: dto.access.locked,
            upsellReason: dto.access.upsell?.reason,
            benchmarkCalibration: benchmark(from: dto.benchmarkCalibration),
            insights: (dto.insights ?? []).map(insight(from:))
        )
    }

    /// `insights[]` 的一列。`label` 缺就退 `key`（不編一個顯示名出來）。
    private static func insight(from dto: StateCardDTO.InsightDTO) -> DailyStateInsight {
        DailyStateInsight(
            key: dto.key,
            label: dto.label ?? dto.key,
            valueText: dto.valueText,
            arrow: dto.arrow.flatMap { DailyStateInsight.Arrow(rawValue: $0) } ?? .unknown,
            verdict: dto.verdict,
            change: dto.change,
            evidence: dto.evidence,
            dot: dto.dot,
            status: dto.status
        )
    }

    /// T-0142:巢狀 calibration_preview → 攤平成既有 BenchmarkCalibrationPayload。
    /// 缺關鍵欄位(id/日期/距離/完賽 before-after)→ nil(卡片不顯示,不給假數字)。
    private static func benchmark(
        from dto: StateCardDTO.BenchmarkCalibrationDTO?
    ) -> SameDayBenchmarkCalibration? {
        guard let dto,
              let wid = dto.workoutId,
              let wdate = dto.workoutDate,
              let distM = dto.benchmarkDistanceM,
              let durS = dto.benchmarkDurationS,
              let preview = dto.calibrationPreview,
              let before = preview.raceTimeBeforeS,
              let after = preview.raceTimeAfterS else { return nil }
        let payload = BenchmarkCalibrationPayload(
            workoutDate: wdate,
            distanceKm: dto.distanceKm ?? (distM / 1000.0),
            durationS: durS,
            shouldHedge: dto.shouldHedge ?? false,
            paceBeforeSPerKm: nil,
            paceAfterSPerKm: nil,
            raceDistanceLabel: nil,
            raceTimeBeforeS: before,
            raceTimeAfterS: after,
            vdotBefore: preview.vdotBefore,
            vdotAfter: preview.vdotAfter
        )
        return SameDayBenchmarkCalibration(
            workoutId: wid,
            workoutDate: wdate,
            benchmarkDistanceM: distM,
            benchmarkDurationS: durS,
            overviewId: dto.overviewId ?? "",
            weekOfTraining: dto.weekOfTraining ?? 0,
            canScheduleNext: dto.canScheduleNext ?? true,
            payload: payload
        )
    }

    private static func actionLine(from action: StateCardDTO.ActionDTO?) -> String? {
        guard let s = action?.sessionRef, let rt = s.runType else { return nil }
        var parts: [String] = []
        if let km = s.distanceKm { parts.append("\(Int(km))K \(rt)") } else { parts.append(rt) }
        if let pace = s.pace { parts.append(pace) }
        return parts.joined(separator: " · ")
    }
}
