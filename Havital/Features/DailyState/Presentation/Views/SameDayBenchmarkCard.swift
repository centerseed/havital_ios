import SwiftUI

// MARK: - SameDayBenchmarkCard (T-0142)
/// 今日畫面的指標跑當日即時校準卡。偵測到今天合格全力跑時顯示:
/// 完賽預估 before → after(同 T-0140 ML 引擎)+ 三動作(套用 / 稍後 / 預約下次)。
/// 純渲染 + closure 動作(業務在 ViewModel)。
struct SameDayBenchmarkCard: View {
    let calibration: SameDayBenchmarkCalibration
    let isApplying: Bool
    let isSchedulingNext: Bool
    let scheduledNextWeek: Int?
    let onApply: () -> Void
    let onLater: () -> Void
    let onScheduleNext: (Int) -> Void   // 參數 = 幾週後(最少 2)

    @State private var showWeeksPicker = false
    private let weekOptions = [2, 3, 4, 6, 8]

    private func hms(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return String(format: "%d:%02d:%02d", h, m, sec)
    }

    private var payload: BenchmarkCalibrationPayload { calibration.payload }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: PacerizIcon.benchmark)
                Text(NSLocalizedString("benchmark.today.title", comment: "Same-day benchmark calibration title"))
                    .font(AppFont.micro())
            }
            .foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(PacerizColor.benchmark))

            Text(NSLocalizedString("benchmark.today.headline", comment: "Same-day benchmark headline"))
                .font(AppFont.subheadline()).fontWeight(.medium)
                .fixedSize(horizontal: false, vertical: true)

            if let rb = payload.raceTimeBeforeS, let ra = payload.raceTimeAfterS {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("benchmark.calib.race_label", comment: ""))
                        .font(AppFont.caption()).foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Text(hms(rb)).font(AppFont.subheadline()).foregroundColor(.secondary).strikethrough()
                        Image(systemName: "arrow.right").font(AppFont.caption()).foregroundColor(.secondary)
                        Text(hms(ra)).font(AppFont.title3()).fontWeight(.bold).foregroundColor(.primary)
                    }
                }
            }
            if let vb = payload.vdotBefore, let va = payload.vdotAfter {
                Text("\(NSLocalizedString("benchmark.calib.vdot_label", comment: "")) \(String(format: "%.1f", vb)) → \(String(format: "%.1f", va))")
                    .font(AppFont.caption()).foregroundColor(.secondary)
            }

            Text(payload.shouldHedge
                 ? NSLocalizedString("benchmark.calib.hedge", comment: "")
                 : NSLocalizedString("benchmark.calib.lag_notice", comment: ""))
                .font(AppFont.caption()).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            // 套用(主) / 稍後
            HStack(spacing: 12) {
                Button(action: onApply) {
                    HStack(spacing: 6) {
                        if isApplying { ProgressView().tint(.white) }
                        Text(NSLocalizedString("benchmark.today.apply", comment: "Apply calibration"))
                            .font(AppFont.subheadline()).fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: PacerizRadius.card).fill(PacerizColor.benchmark))
                    .foregroundColor(.white)
                }
                .disabled(isApplying)
                .accessibilityIdentifier("v2.today.benchmark_apply")

                Button(action: onLater) {
                    Text(NSLocalizedString("benchmark.today.later", comment: "Later"))
                        .font(AppFont.subheadline())
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .foregroundColor(.secondary)
                }
                .disabled(isApplying)
                .accessibilityIdentifier("v2.today.benchmark_later")
            }

            // 預約下次(不管套不套用都可)
            if calibration.canScheduleNext {
                if let wk = scheduledNextWeek {
                    // 已預約 → 確認
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").font(AppFont.caption())
                        Text(String(format: NSLocalizedString("benchmark.today.scheduled", comment: "Next benchmark scheduled"), wk))
                            .font(AppFont.caption())
                    }
                    .foregroundColor(PacerizColor.green)
                    .accessibilityIdentifier("v2.today.benchmark_scheduled")
                } else {
                    Button { showWeeksPicker = true } label: {
                        HStack(spacing: 4) {
                            if isSchedulingNext {
                                ProgressView().controlSize(.mini)
                            } else {
                                Image(systemName: "calendar.badge.plus").font(AppFont.caption())
                            }
                            Text(NSLocalizedString("benchmark.today.schedule_next", comment: "Schedule next benchmark"))
                                .font(AppFont.caption())
                        }
                        .foregroundColor(PacerizColor.benchmark)
                    }
                    .disabled(isApplying || isSchedulingNext)
                    .accessibilityIdentifier("v2.today.benchmark_schedule_next")
                    .confirmationDialog(
                        NSLocalizedString("benchmark.today.schedule_next_title", comment: "Schedule how many weeks later"),
                        isPresented: $showWeeksPicker,
                        titleVisibility: .visible
                    ) {
                        ForEach(weekOptions, id: \.self) { wk in
                            Button(String(format: NSLocalizedString("benchmark.today.weeks_after", comment: "%d weeks later"), wk)) {
                                onScheduleNext(wk)
                            }
                        }
                        Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {}
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: PacerizRadius.card)
                .stroke(PacerizColor.benchmark.opacity(0.5), lineWidth: 1.5)
                .background(RoundedRectangle(cornerRadius: PacerizRadius.card).fill(PacerizColor.benchmark.opacity(0.06))))
        .accessibilityIdentifier("v2.today.benchmark_calib_card")
    }
}

#if DEBUG
#Preview {
    SameDayBenchmarkCard(
        calibration: SameDayBenchmarkCalibration(
            workoutId: "w1", workoutDate: "2026-07-06",
            benchmarkDistanceM: 3582, benchmarkDurationS: 1092,
            overviewId: "ov1", weekOfTraining: 4, canScheduleNext: true,
            payload: BenchmarkCalibrationPayload(
                workoutDate: "2026-07-06", distanceKm: 3.58, durationS: 1092, shouldHedge: false,
                paceBeforeSPerKm: nil, paceAfterSPerKm: nil, raceDistanceLabel: nil,
                raceTimeBeforeS: 17742, raceTimeAfterS: 17260, vdotBefore: 36.4, vdotAfter: 38.6)),
        isApplying: false, isSchedulingNext: false, scheduledNextWeek: nil,
        onApply: {}, onLater: {}, onScheduleNext: { _ in }
    )
    .padding()
}
#endif
