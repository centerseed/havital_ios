import SwiftUI

// MARK: - PACERIZ REDESIGN 2026-05
// WeekOverviewCardV2 has been fully redesigned to match new VolumeIntensityCard layout.
// Removed: circular progress ring (ZStack with Circle), CompactIntensityBarV2.
// Added: hero row (badge + distance + intensity bar + dot legend) + flat action buttons.
// Phase B: badge hero now driven by AchievementRepository via TrainingPlanV2ViewModel.
//   - any badge (any status) → real badge image colorful + "新解鎖" chip
//   - nil                    → PRPlaceholderBadge fallback (no crash)
// Note: grayscale + "解鎖中" chip intentionally removed per 2026-05 UX decision.
// WeekTargetDetailViewV2 struct is preserved unchanged at the bottom of this file.

/// V2 週總覽卡片 - 顯示本週跑量和強度分配
struct WeekOverviewCardV2: View {
    var viewModel: TrainingPlanV2ViewModel
    @ObservedObject private var unitManager = UnitManager.shared
    @Environment(\.colorScheme) var colorScheme
    let plan: WeeklyPlanV2
    @State private var showWeekTargetDetail = false
    @State private var showTrainingCalendar = false
    @State private var showBadgePicker = false

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

    // 展示徽章是否為「最近 1 天內解鎖」→ 決定是否顯示 NEW chip
    private var isDisplayBadgeNew: Bool {
        guard let badge = viewModel.displayBadge,
              badge.status == .unlocked,
              let raw = badge.unlockedAt,
              let date = Self.parseUnlockedAt(raw) else { return false }
        let oneDay: TimeInterval = 24 * 60 * 60
        return Date().timeIntervalSince(date) <= oneDay
    }

    private static func parseUnlockedAt(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: trimmed) { return d }
        let noFraction = ISO8601DateFormatter()
        noFraction.formatOptions = [.withInternetDateTime]
        if let d = noFraction.date(from: trimmed) { return d }
        let ymd = DateFormatter()
        ymd.dateFormat = "yyyy-MM-dd"
        ymd.locale = Locale(identifier: "en_US_POSIX")
        ymd.timeZone = TimeZone(identifier: "UTC")
        return ymd.date(from: String(trimmed.prefix(10)))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Hero row ─────────────────────────────────────────────────
            HStack(alignment: .center, spacing: 14) {

                // Left: badge hero (86×86, 邊長 +20%)
                // Phase B: real badge from AchievementRepository; fallback to PRPlaceholderBadge when nil.
                // F6.d: status chip placed at top-left corner per design spec
                ZStack(alignment: .topLeading) {
                    AchievementBadgeHeroView(
                        badge: viewModel.displayBadge,
                        isUnlocked: viewModel.displayBadge?.status == .unlocked,
                        size: 86
                    )

                    // "NEW" chip 只在展示徽章為「最近 7 天內解鎖」時顯示，
                    // 避免釘選舊徽章 / 自動挑到舊徽章時永久掛 NEW（誤導）。
                    if isDisplayBadgeNew {
                        badgeStatusChip()
                            .offset(x: -4, y: -4)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { showBadgePicker = true }
                .accessibilityIdentifier("v2.weekly.showcase_badge")
                .accessibilityLabel("選擇展示徽章")

                // Right: badge name + distance + intensity bar + dot legend
                VStack(alignment: .leading, spacing: 6) {

                    // Badge name row — real badge name when available; fallback to placeholder key.
                    // F1.c: removed title row per design jsx (no separate header)
                    // F1.d: date chip moved here, right-aligned per design jsx L417-423
                    HStack(spacing: 6) {
                        // F5.a: 16pt + blueDeep color, fixedSize ensures full display without truncation
                        Text(viewModel.displayBadge.map { $0.nameKey.localizedOrFallback(default: $0.badgeId) } ?? NSLocalizedString("training_plan.weekly_badge_placeholder_name", comment: "本週進度"))
                            .font(AppFont.titleM())
                            .foregroundColor(PacerizColor.blueDeep)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        Spacer()
                    }

                    // Distance row: big current + small "/ target unit" + spacer + percentage chip
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(String(format: "%.0f", unitManager.convertedDistance(viewModel.loader.currentWeekDistance)))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text("/ \(String(format: "%.0f", unitManager.convertedDistance(plan.totalDistance))) \(unitManager.currentUnitSystem.distanceSuffix)")
                            .font(AppFont.label())
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

                    // Progress bar with intensity-coloured fill: filled portion = mileage
                    // progress (currentWeekDistance / totalDistance), subdivided by the actual
                    // low/medium/high split; the remaining distance shows as a grey track tail.
                    intensityBarView

                    // Dot legend — same horizontal layout as the bar above.
                    intensityLegendView
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
                            .font(AppFont.bodyStrong())
                            .foregroundColor(PacerizColor.blue)

                        Text(NSLocalizedString("training_plan.week_target", comment: "Week Target"))
                            .font(AppFont.bodyStrong())
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(AppFont.micro())
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
                            .font(AppFont.bodyStrong())
                            .foregroundColor(PacerizColor.greenDeep)

                        Text(NSLocalizedString("training_plan.training_calendar", comment: "Training Calendar"))
                            .font(AppFont.bodyStrong())
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(AppFont.micro())
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
        // 2026-05-19: adaptive dark mode — white glow + secondarySystemGroupedBackground (consistent with DayCard)
        .background(
            RoundedRectangle(cornerRadius: PacerizRadius.card)
                .fill(adaptiveCardGradient(for: colorScheme))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .accessibilityIdentifier("v2.weekly.overview_card")
        .sheet(isPresented: $showWeekTargetDetail) {
            NavigationView {
                WeekTargetDetailViewV2(
                    purpose: plan.purpose,
                    designReason: designReason,
                    coachNote: plan.coachNote
                )
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showTrainingCalendar) {
            NavigationView {
                TrainingCalendarView()
            }
        }
        .sheet(isPresented: $showBadgePicker) {
            BadgeShowcasePickerView(
                badges: viewModel.unlockedBadges,
                selectedBadgeId: viewModel.showcaseBadgeId,
                onSelect: { badgeId in viewModel.setShowcaseBadge(badgeId) }
            )
        }
    }

    // MARK: - Private Helpers

    // Progress bar: filled width = week mileage progress; filled portion split by the
    // actual low/medium/high intensity proportions; remaining distance shows as grey track.
    private var intensityBarView: some View {
        WeekProgressIntensityBar(progress: weekProgress, low: actualLow, medium: actualMedium, high: actualHigh)
    }

    // Dot legend: circle dots (matching bar's rounded aesthetic) + labels.
    // Spacing mirrors bar width so they feel visually anchored together.
    @ViewBuilder
    private var intensityLegendView: some View {
        HStack(spacing: 0) {
            legendDot(color: PacerizColor.green,
                      label: NSLocalizedString("training_plan.intensity_legend_low", comment: "輕鬆"))
            Spacer()
            legendDot(color: PacerizColor.orange,
                      label: NSLocalizedString("training_plan.intensity_legend_medium", comment: "中等"))
            Spacer()
            legendDot(color: PacerizColor.error,
                      label: NSLocalizedString("training_plan.intensity_legend_high", comment: "強度"))
        }
    }

    @ViewBuilder
    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(AppFont.micro())
                .foregroundColor(.secondary)
        }
    }

    private func adaptiveCardGradient(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            // Dark mode: white glow top-left → secondarySystemGroupedBackground (consistent with DayCard)
            return LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.10), location: 0.0),
                    .init(color: Color(UIColor.secondarySystemGroupedBackground), location: 0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Light mode: blue glow top-left → secondarySystemGroupedBackground (consistent with DayCard)
            return LinearGradient(
                stops: [
                    .init(color: PacerizColor.blue.opacity(0.14), location: 0.0),
                    .init(color: Color(UIColor.secondarySystemGroupedBackground), location: 0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func badgeStatusChip() -> some View {
        // Hardcoded "NEW" chip — not localized per 2026-05 UX decision.
        PRChip(
            text: "NEW",
            fg: .white,
            bg: PacerizColor.blue,
            fontSize: 11,
            leadingSymbol: "sparkles"
        )
    }
}

// MARK: - WeekProgressIntensityBar
// Progress bar whose filled width = week mileage progress (0...1), with the filled
// portion subdivided by the actual low/medium/high intensity proportions. The remaining
// distance shows as a grey track tail, so the bar reads as "how much of the week is done"
// while still conveying how that effort split across intensities.
// Fill caps are rounded (pill); inner segment joins are square (flush).
private struct WeekProgressIntensityBar: View {
    let progress: Double   // 0...1 (currentWeekDistance / totalDistance)
    let low: Int
    let medium: Int
    let high: Int

    private let barH: CGFloat = 8
    private var radius: CGFloat { barH / 2 }
    private var clampedProgress: CGFloat { CGFloat(min(max(progress, 0), 1)) }
    private var intensityDenom: CGFloat { CGFloat(max(low + medium + high, 1)) }
    private var hasIntensity: Bool { low + medium + high > 0 }

    private var hasLow: Bool { low > 0 }
    private var hasMed: Bool { medium > 0 }
    private var hasHigh: Bool { high > 0 }

    var body: some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            let fillW = totalW * clampedProgress
            // Within the filled width, split by intensity proportions.
            let lowW  = fillW * CGFloat(low)    / intensityDenom
            let medW  = fillW * CGFloat(medium) / intensityDenom
            let highW = fillW * CGFloat(high)   / intensityDenom

            ZStack(alignment: .leading) {
                // Track (remaining distance)
                Capsule()
                    .fill(Color(UIColor { t in
                        t.userInterfaceStyle == .dark
                            ? UIColor.white.withAlphaComponent(0.12)
                            : UIColor.black.withAlphaComponent(0.08)
                    }))
                    .frame(height: barH)

                // Filled portion
                if fillW > 0 {
                    if hasIntensity {
                        HStack(spacing: 0) {
                            if hasLow {
                                let trailR: CGFloat = (!hasMed && !hasHigh) ? radius : 0
                                UnevenRoundedRectangle(
                                    topLeadingRadius: radius, bottomLeadingRadius: radius,
                                    bottomTrailingRadius: trailR, topTrailingRadius: trailR
                                )
                                .fill(PacerizColor.green)
                                .frame(width: lowW, height: barH)
                            }
                            if hasMed {
                                let leadR: CGFloat = !hasLow  ? radius : 0
                                let trailR: CGFloat = !hasHigh ? radius : 0
                                UnevenRoundedRectangle(
                                    topLeadingRadius: leadR, bottomLeadingRadius: leadR,
                                    bottomTrailingRadius: trailR, topTrailingRadius: trailR
                                )
                                .fill(PacerizColor.orange)
                                .frame(width: medW, height: barH)
                            }
                            if hasHigh {
                                let leadR: CGFloat = (!hasLow && !hasMed) ? radius : 0
                                UnevenRoundedRectangle(
                                    topLeadingRadius: leadR, bottomLeadingRadius: leadR,
                                    bottomTrailingRadius: radius, topTrailingRadius: radius
                                )
                                .fill(PacerizColor.error)
                                .frame(width: highW, height: barH)
                            }
                        }
                        .frame(height: barH)
                    } else {
                        // Progress exists but no intensity breakdown → neutral fill.
                        Capsule()
                            .fill(PacerizColor.blue)
                            .frame(width: fillW, height: barH)
                    }
                }
            }
        }
        .frame(height: barH)
    }
}

// MARK: - 週目標詳情視圖 V2
struct WeekTargetDetailViewV2: View {
    let purpose: String
    let designReason: [String]?
    let coachNote: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 教練的話（coach_note）— 本週重點總結，放最上方當開場
                if let coachNote = coachNote, !coachNote.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "quote.bubble.fill")
                                .foregroundColor(PacerizColor.blue)
                                .font(AppFont.title3())

                            Text(NSLocalizedString("training_plan.coach_note", comment: "Coach's Note"))
                                .font(AppFont.headline())
                                .foregroundColor(.primary)
                        }

                        Text(coachNote)
                            .font(AppFont.body())
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                            .padding(.leading, 4)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(PacerizColor.blue.opacity(0.10))
                    )
                }

                // 週目標區域
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "target")
                            .foregroundColor(PacerizColor.greenDeep)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(PacerizColor.greenDeep.opacity(0.08))
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

private extension String {
    /// 徽章 name_key 可能是 base key（未含 .name 後綴）。先試原 key，找不到再補 .name，
    /// 仍找不到才用 fallback。避免顯示 raw key（如 achievements.badge.mileage_markers.100k）。
    func localizedOrFallback(default fallback: String) -> String {
        let value = NSLocalizedString(self, comment: "")
        if value != self { return value }
        let named = NSLocalizedString(self + ".name", comment: "")
        return named != self + ".name" ? named : fallback
    }
}

#Preview {
    // TODO: 實作正確的 Preview mock 資料
    Text("WeekOverviewCardV2 Preview")
        .padding()
}
