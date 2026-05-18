import SwiftUI

// MARK: - PACERIZ REDESIGN 2026-05
// WeekOverviewCardV2 has been fully redesigned to match new VolumeIntensityCard layout.
// Removed: circular progress ring (ZStack with Circle), CompactIntensityBarV2.
// Added: hero row (PRPlaceholderBadge + distance + intensity bar + dot legend) + flat action buttons.
// WeekTargetDetailViewV2 struct is preserved unchanged at the bottom of this file.

/// V2 週總覽卡片 - 顯示本週跑量和強度分配
struct WeekOverviewCardV2: View {
    var viewModel: TrainingPlanV2ViewModel
    @ObservedObject private var unitManager = UnitManager.shared
    @Environment(\.colorScheme) var colorScheme
    let plan: WeeklyPlanV2
    @State private var showWeekTargetDetail = false
    @State private var showTrainingCalendar = false

    // ✅ 從 intensityTotalMinutes 提取強度目標（分鐘）
    private var lowIntensityTarget: Int {
        return Int(plan.intensityTotalMinutes?.low ?? 0)
    }

    private var mediumIntensityTarget: Int {
        return Int(plan.intensityTotalMinutes?.medium ?? 0)
    }

    private var highIntensityTarget: Int {
        return Int(plan.intensityTotalMinutes?.high ?? 0)
    }

    // ✅ 直接從 WeeklyPlanV2 Entity 提取設計原因（V1 欄位）
    private var designReason: [String]? {
        return plan.designReason
    }

    private var weekProgress: Double {
        guard plan.totalDistance > 0 else { return 0 }
        return min(viewModel.loader.currentWeekDistance / plan.totalDistance, 1.0)
    }

    // Week range string derived from plan day dates (e.g. "5/11 – 5/17")
    private var weekRangeText: String? {
        guard let startDate = viewModel.getDate(for: 1),
              let endDate = viewModel.getDate(for: 7) else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        return "\(fmt.string(from: startDate)) – \(fmt.string(from: endDate))"
    }

    // Intensity actual values
    private var actualLow: Int { Int(viewModel.loader.currentWeekIntensity.low) }
    private var actualMedium: Int { Int(viewModel.loader.currentWeekIntensity.medium) }
    private var actualHigh: Int { Int(viewModel.loader.currentWeekIntensity.high) }

    // For segmented bar denominator: use max of planned total vs actual total so bar never overflows
    private var intensityBarTotal: Int {
        let planned = lowIntensityTarget + mediumIntensityTarget + highIntensityTarget
        let actual = actualLow + actualMedium + actualHigh
        return max(planned, actual, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Hero row ─────────────────────────────────────────────────
            HStack(alignment: .center, spacing: 14) {

                // Left: placeholder badge (72×72) with NEW overlay badge top-left corner
                // PHASE_B_BADGE: Replace with real BadgeRepository data in Phase B
                // F6.d: NEW badge placed at top-left corner per design spec
                ZStack(alignment: .topLeading) {
                    PRPlaceholderBadge(size: 72)

                    Text("NEW")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.5)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(PacerizColor.blue)
                        )
                        .overlay(Capsule().stroke(Color.white, lineWidth: 1.5))
                        .offset(x: -4, y: -4)
                }

                // Right: badge name + distance + intensity bar + dot legend
                VStack(alignment: .leading, spacing: 6) {

                    // Badge name row (placeholder) — F1.c: removed title row per design jsx (no separate header)
                    // F1.d: date chip moved here, right-aligned per design jsx L417-423
                    // F6.d: PRChip "新解鎖" removed; NEW badge now lives on the badge icon instead
                    // PHASE_B_BADGE: Badge name & "Coming soon" chip will be data-driven in Phase B
                    HStack(spacing: 6) {
                        // F5.a: 16pt + blueDeep color, fixedSize ensures full display without truncation
                        Text(NSLocalizedString("training_plan.weekly_badge_placeholder_name", comment: "本週進度"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(PacerizColor.blueDeep)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        Spacer()

                        // F1.d: date chip moved here per design jsx L417-423
                        // F4.a: .fixedSize(horizontal: true, vertical: false) prevents date from wrapping
                        // F5.a: calendar icon 11pt, date 12pt
                        if let range = weekRangeText {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(range)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    // Distance row: big current + small "/ target unit" + spacer + percentage chip
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(String(format: "%.0f", unitManager.convertedDistance(viewModel.loader.currentWeekDistance)))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text("/ \(String(format: "%.0f", unitManager.convertedDistance(plan.totalDistance))) \(unitManager.currentUnitSystem.distanceSuffix)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)

                        Spacer()

                        let pct = plan.totalDistance > 0
                            ? Int(min(viewModel.loader.currentWeekDistance / plan.totalDistance * 100, 100))
                            : 0
                        PRChip(
                            text: "\(pct)%",
                            fg: PacerizColor.blueDeep,
                            bg: PacerizColor.blue12,
                            fontSize: 13
                        )
                    }

                    // Segmented intensity bar
                    PRSegmentedIntensityBar(
                        low: actualLow,
                        medium: actualMedium,
                        high: actualHigh,
                        total: intensityBarTotal
                    )

                    // Dot legend — F1.e: new keys per TD §3.5 D 2026-05-18 校準
                    HStack(spacing: 12) {
                        PRDotLegendItem(
                            dotColor: PacerizColor.green,
                            label: NSLocalizedString("training_plan.intensity_legend_low", comment: "輕鬆")
                        )
                        PRDotLegendItem(
                            dotColor: PacerizColor.orange,
                            label: NSLocalizedString("training_plan.intensity_legend_medium", comment: "中等")
                        )
                        PRDotLegendItem(
                            dotColor: PacerizColor.error,
                            label: NSLocalizedString("training_plan.intensity_legend_high", comment: "強度")
                        )
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("v2.weekly.intensity_distribution")

            Divider()

            // ── Action button row ────────────────────────────────────────
            HStack(spacing: 8) {
                // 本週目標
                Button(action: {
                    showWeekTargetDetail = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "target")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(PacerizColor.blue)

                        Text(NSLocalizedString("training_plan.week_target", comment: "Week Target"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(PacerizColor.blue12)
                    .cornerRadius(PacerizRadius.inner)
                }
                .buttonStyle(PlainButtonStyle())

                // 訓練日曆
                Button(action: {
                    showTrainingCalendar = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(PacerizColor.greenDeep)

                        Text(NSLocalizedString("training_plan.training_calendar", comment: "Training Calendar"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(PacerizColor.green12)
                    .cornerRadius(PacerizRadius.inner)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(14)
        // MARK: PACERIZ REDESIGN 2026-05 — gradient "暈開" per design jsx L373
        // F7: faster transition — 2-stop, white at 50%
        .background(
            RoundedRectangle(cornerRadius: PacerizRadius.card)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: PacerizColor.blue.opacity(0.14), location: 0.0),
                            .init(color: Color(UIColor.tertiarySystemBackground), location: 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .accessibilityIdentifier("v2.weekly.overview_card")
        .sheet(isPresented: $showWeekTargetDetail) {
            NavigationView {
                WeekTargetDetailViewV2(
                    purpose: plan.purpose,
                    designReason: designReason
                )
            }
        }
        .sheet(isPresented: $showTrainingCalendar) {
            NavigationView {
                TrainingCalendarView()
            }
        }
    }
}

// MARK: - 週目標詳情視圖 V2
struct WeekTargetDetailViewV2: View {
    let purpose: String
    let designReason: [String]?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 週目標區域
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "target")
                            .foregroundColor(.blue)
                            .font(AppFont.title3())

                        Text(NSLocalizedString("training_plan.week_target", comment: "Week Target"))
                            .font(AppFont.headline())
                            .foregroundColor(.primary)
                    }

                    Text(purpose)
                        .font(AppFont.body())
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 4)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.08))
                )

                // 設計原因區域（如果有的話）
                if let designReason = designReason, !designReason.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.circle.fill")
                                .foregroundColor(.orange)
                                .font(AppFont.title3())

                            Text(NSLocalizedString("training.design_reason", comment: "Design Reason"))
                                .font(AppFont.headline())
                                .foregroundColor(.primary)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(designReason.enumerated()), id: \.offset) { index, reason in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1).")
                                        .font(AppFont.body())
                                        .fontWeight(.medium)
                                        .foregroundColor(.orange)

                                    Text(reason)
                                        .font(AppFont.body())
                                        .foregroundColor(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.leading, 4)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.08))
                    )
                }
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("training_plan.week_target", comment: "Week Target"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(NSLocalizedString("common.close", comment: "Close")) {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    // TODO: 實作正確的 Preview mock 資料
    Text("WeekOverviewCardV2 Preview")
        .padding()
}
