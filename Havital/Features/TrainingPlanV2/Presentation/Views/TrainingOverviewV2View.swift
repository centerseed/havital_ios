import SwiftUI

// MARK: - TrainingOverviewV2View
//
// Task 1/5: Outer container + Hero gradient section + Stats card (race mode only).
// Pushed via NavigationStack.navigationDestination (not .sheet).
// System back button is white (via .tint(.white) + toolbarBackground hidden) so it
// remains visible over the blue hero gradient.
//
// Data source: viewModel.loader (V2 path — PlanOverviewV2 entity).
// Design reference: OverviewScreenB in plan-overview.jsx, lines 498–591.

struct TrainingOverviewV2View: View {

    var viewModel: TrainingPlanV2ViewModel

    // TargetFeatureViewModel — mirrors PlanOverviewSheetV2:7 pattern
    @StateObject private var targetViewModel = TargetFeatureViewModel()

    @Environment(\.dismiss) private var dismiss

    // Task 3: MethodologyStrategyCard state — mirrors TrainingOverviewTabV2 in PlanOverviewSheetV2
    @State private var showMethodologySheet = false
    @State private var isChangingMethodology = false
    @State private var showStageSelectionForMethodology = false
    @State private var pendingMethodologyId: String? = nil

    // Edit main race/target — mirrors PlanOverviewSheetV2 showEditMainTarget flow
    @State private var showEditMainTarget = false

    // MARK: - Body

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    if let overview = viewModel.loader.planOverview {
                        heroSection(overview: overview)

                        VStack(spacing: 12) {
                            // Stats card — race mode only (JSX lines 573–591)
                            if overview.isRaceRunTarget {
                                statsCard(overview: overview)
                            }

                            // Task 2 — PhaseRoadmap (JSX lines 724–1035)
                            PhaseRoadmapView(viewModel: viewModel, targetViewModel: targetViewModel)

                            // Task 3 — MethodologyCardB (JSX 1357–1390) + MilestonesCardB (JSX 1258–1291)
                            if let methodology = overview.methodologyOverview {
                                methodologyStrategyCard(overview: overview, methodology: methodology)
                            }

                            if !overview.milestones.isEmpty {
                                milestonesCard(overview: overview)
                            }

                            Spacer(minLength: 24)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 100)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color(UIColor.systemGroupedBackground))

            // Task 3: 切換方法論中 overlay — mirrors PlanOverviewSheetV2 TrainingOverviewTabV2
            if isChangingMethodology {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text(L10n.Training.overviewUpdatingPlan.localized)
                        .font(AppFont.bodySmall())
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                }
                .padding(28)
                .background(Color.black.opacity(0.6))
                .cornerRadius(16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(.white)
        // Edit main race/target lives in the nav bar (hero is full-bleed under the
        // transparent nav bar, so an in-hero button would be swallowed by the bar).
        .toolbar {
            if viewModel.loader.planOverview != nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showEditMainTarget = true
                    } label: {
                        Label(L10n.Training.overviewEditAction.localized, systemImage: "pencil")
                            .font(AppFont.bodyStrong())
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .task {
            // Load supporting races (mirrors PlanOverviewSheetV2:114-116)
            await targetViewModel.loadTargets()
            // Ensure weekly summaries are loaded for 課表/回顧 flags
            // (mirrors TrainingProgressViewV2:35-38)
            if viewModel.summary.weeklySummaries.isEmpty {
                await viewModel.summary.fetchWeeklySummaries()
            }
        }
        // Task 3: methodology selection sheet
        .sheet(isPresented: $showMethodologySheet) {
            methodologySelectionSheet
        }
        // Task 3: stage selection sheet (race plans only)
        .sheet(isPresented: $showStageSelectionForMethodology) {
            if let overview = viewModel.loader.planOverview {
                let weeksRemaining = max(1, overview.totalWeeks - viewModel.loader.currentWeek + 1)
                let distanceKm = overview.distanceKm ?? 42.195
                EditTargetStageSelectionView(
                    weeksRemaining: weeksRemaining,
                    targetDistanceKm: distanceKm
                ) { selectedStageApiIdentifier in
                    showStageSelectionForMethodology = false
                    if let methodologyId = pendingMethodologyId {
                        Task {
                            withAnimation { isChangingMethodology = true }
                            await viewModel.methodology.changeMethodology(
                                methodologyId: methodologyId,
                                startFromStage: selectedStageApiIdentifier
                            )
                            withAnimation { isChangingMethodology = false }
                        }
                    }
                }
            }
        }
        // Edit main race/target — mirrors PlanOverviewSheetV2:162-166
        .sheet(isPresented: $showEditMainTarget) {
            if let target = targetViewModel.mainTarget {
                EditTargetView(target: target)
            }
        }
    }

    // MARK: - Task 3: MethodologyStrategyCard (JSX 1357–1390)

    /// 方法論 + 訓練策略合併卡 (MethodologyCardB).
    /// Upper half: gradient icon + methodology name + intensity distribution text.
    /// Lower half (approach): divider + approachSummary text if non-empty.
    /// Right action: "更換" button that opens methodology selection sheet (preserves existing flow).
    ///
    /// NOTE: MethodologyOverviewV2 has no easy/med/hard percentage fields.
    /// Intensity is displayed via `intensityDescription` text (e.g. "75% 低強度 / 20% 中強度 / 5% 高強度").
    @ViewBuilder
    private func methodologyStrategyCard(overview: PlanOverviewV2, methodology: MethodologyOverviewV2) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Upper section: icon + name + intensity + change button
            HStack(spacing: 12) {
                // Gradient icon (JSX: linear-gradient blue 12%–8%)
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.12), Color.blue.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 42, height: 42)
                    Image(systemName: "sparkles")
                        .font(AppFont.systemScaled(size: 20, weight: .medium))
                        .foregroundColor(PacerizColor.blue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(methodology.name)
                        .font(AppFont.subheadline())
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)

                    // Intensity: use intensityDescription (no easyPct/medPct/hardPct on MethodologyOverviewV2)
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(AppFont.caption2())
                            .foregroundColor(.secondary)
                        Text(methodology.intensityDescription)
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Change button — JSX: "更換" (right-aligned, blue)
                Button {
                    Task {
                        await viewModel.methodology.loadMethodologies()
                        showMethodologySheet = true
                    }
                } label: {
                    Text(L10n.Training.overviewChangeMethodology.localized)
                        .font(AppFont.caption())
                        .fontWeight(.bold)
                        .foregroundColor(PacerizColor.blue)
                }
            }
            .padding(14)

            // Lower section (approach): divider + approachSummary text
            if let approach = overview.approachSummary, !approach.isEmpty {
                Divider()
                    .padding(.horizontal, 14)

                Text(approach)
                    .font(AppFont.captionRegular())
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(PacerizRadius.card)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .accessibilityIdentifier("v2.overviewV2.methodology_card")
    }

    // MARK: - Task 3: Methodology Selection Sheet (mirrors TrainingOverviewTabV2 in PlanOverviewSheetV2)

    private var methodologySelectionSheet: some View {
        NavigationStack {
            Group {
                if viewModel.methodology.availableMethodologies.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(NSLocalizedString("common.loading", comment: "Loading"))
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.methodology.availableMethodologies, id: \.id) { methodology in
                                methodologyOptionRow(methodology)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(L10n.Training.overviewSelectMethodology.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.close", comment: "Close")) {
                        showMethodologySheet = false
                    }
                }
            }
        }
    }

    /// Single methodology option row inside the selection sheet.
    private func methodologyOptionRow(_ methodology: MethodologyV2) -> some View {
        let isSelected = viewModel.loader.planOverview?.methodologyOverview?.name == methodology.name

        return Button {
            pendingMethodologyId = methodology.id
            showMethodologySheet = false
            Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                if viewModel.loader.planOverview?.isRaceRunTarget == true {
                    showStageSelectionForMethodology = true
                } else {
                    withAnimation { isChangingMethodology = true }
                    await viewModel.methodology.changeMethodology(
                        methodologyId: methodology.id,
                        startFromStage: nil
                    )
                    withAnimation { isChangingMethodology = false }
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.blue : Color.secondary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: methodologyIcon(for: methodology.id))
                        .font(AppFont.systemScaled(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? .white : .secondary)
                }

                Text(methodology.name)
                    .font(AppFont.bodySmall())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(AppFont.title3())
                    .foregroundColor(isSelected ? .blue : Color.secondary.opacity(0.4))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.blue.opacity(0.8) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func methodologyIcon(for id: String) -> String {
        switch id {
        case "paceriz":          return "sparkles"
        case "polarized":        return "chart.bar.xaxis"
        case "hansons":          return "figure.run"
        case "norwegian":        return "mountain.2.fill"
        case "complete_10k":     return "flag.checkered"
        case "balanced_fitness": return "heart.circle.fill"
        case "aerobic_endurance": return "wind"
        default:                 return "bolt.circle.fill"
        }
    }

    // MARK: - Task 3: MilestonesCard (JSX 1258–1291)

    /// 關鍵里程碑卡片 (MilestonesCardB).
    /// Shows a card with title "關鍵里程碑" and a list of MilestoneV2 rows.
    /// If milestoneBasis == "no_prior_target", shows disclaimer text under the title.
    /// isKeyMilestone → orange badge + sparkles icon on title; otherwise blue badge.
    @ViewBuilder
    private func milestonesCard(overview: PlanOverviewV2) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card title
            HStack {
                Text(L10n.Training.overviewKeyMilestones.localized)
                    .font(AppFont.subheadline())
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, overview.milestoneBasis == "no_prior_target" ? 6 : 12)

            // Disclaimer for "no_prior_target" basis — reuses existing L10n key
            if overview.milestoneBasis == "no_prior_target" {
                Text(L10n.Training.overviewMilestoneDisclaimer.localized)
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }

            Divider()
                .padding(.horizontal, 14)

            // Milestone rows
            ForEach(Array(overview.milestones.enumerated()), id: \.element.week) { idx, milestone in
                milestoneRow(milestone, isFirst: idx == 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(PacerizRadius.card)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .accessibilityIdentifier("v2.overviewV2.milestones_card")
    }

    /// Single milestone row — mirrors PlanOverviewSheetV2.milestoneRow + JSX MilestonesCardB.
    /// Fields used: week, title, description, isKeyMilestone.
    @ViewBuilder
    private func milestoneRow(_ milestone: MilestoneV2, isFirst: Bool) -> some View {
        VStack(spacing: 0) {
            if !isFirst {
                Divider()
                    .padding(.horizontal, 14)
            }
            HStack(alignment: .top, spacing: 12) {
                // Week badge: orange fill if isKeyMilestone, blue-light if not (JSX 1268–1274)
                ZStack {
                    Circle()
                        .fill(milestone.isKeyMilestone ? PacerizColor.orange : PacerizColor.blue.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Text("W\(milestone.week)")
                        .font(AppFont.caption2())
                        .fontWeight(.bold)
                        .foregroundColor(milestone.isKeyMilestone ? .white : PacerizColor.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Title row: title + sparkles if isKeyMilestone (JSX 1276–1282)
                    HStack(spacing: 4) {
                        Text(milestone.title)
                            .font(AppFont.bodySmall())
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        if milestone.isKeyMilestone {
                            Image(systemName: "sparkles")
                                .font(AppFont.caption2())
                                .foregroundColor(PacerizColor.orange)
                        }
                    }

                    // Description (JSX 1284)
                    Text(milestone.description)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Hero Section (JSX lines 507–569)

    @ViewBuilder
    private func heroSection(overview: PlanOverviewV2) -> some View {
        let accentColor = heroAccentColor(for: overview)

        ZStack(alignment: .top) {
            // Gradient background: linear-gradient(160deg, accent 0%, accent-18% 65%, #1E62D0 105%)
            heroGradient(accent: accentColor)
                .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: 0) {
                // Safe area spacer
                Color.clear.frame(height: 52)

                // Nav row: "訓練總覽" label — push 模式下系統返回鍵在 nav bar 左側，此 label 作為頁面小標題
                Text(L10n.Training.overview.localized)
                    .font(AppFont.micro())
                    .foregroundColor(.white.opacity(0.92))
                    .tracking(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 14)

                // Target / race title row with edit pill (JSX lines 520–540)
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        // kind small label (e.g. "RACE RUN")
                        Text(overview.targetType.uppercased())
                            .font(AppFont.micro())
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(1)

                        // Title
                        Text(heroTitle(for: overview))
                            .font(AppFont.titleL())
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Big countdown — race mode only (JSX lines 542–551)
                if overview.isRaceRunTarget {
                    countdownRow(overview: overview)
                        .padding(.top, 16)
                } else {
                    // Non-race subtitle (JSX line 554)
                    Text(nonRaceSubtitle(for: overview))
                        .font(AppFont.captionRegular())
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(4)
                        .padding(.top, 14)
                }

                // Phase + week chip (JSX lines 557–568)
                phaseWeekChip(overview: overview)
                    .padding(.top, 14)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Hero Helpers

    private func heroAccentColor(for overview: PlanOverviewV2) -> Color {
        guard overview.isRaceRunTarget else {
            return PacerizColor.blue  // #3F86F6
        }
        let currentWeek = viewModel.loader.currentWeek
        let stage = overview.trainingStages.first { $0.contains(week: currentWeek) }
            ?? overview.trainingStages.first
        return stageColor(for: stage?.stageId ?? "base")
    }

    @ViewBuilder
    private func heroGradient(accent: Color) -> some View {
        // Approximate shade(-18%): darken accent by blending with black.
        // accent at 0% → accent-darkened at 65% → #1E62D0 at 105% (clipped to 100%)
        let darkAccent = accent.opacity(1).blended(with: .black, fraction: 0.18)
        LinearGradient(
            stops: [
                .init(color: accent, location: 0.0),
                .init(color: darkAccent, location: 0.65),
                .init(color: Color(red: 0x1E / 255.0, green: 0x62 / 255.0, blue: 0xD0 / 255.0), location: 1.0)
            ],
            startPoint: UnitPoint(x: 0.0, y: 0.0),
            endPoint: UnitPoint(x: 0.55, y: 1.0)  // ~160 deg mapped to SwiftUI UnitPoint
        )
    }

    @ViewBuilder
    private func countdownRow(overview: PlanOverviewV2) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            // Large monospaced countdown number (JSX: 76pt mono)
            Text("\(daysLeft(for: overview))")
                .font(.system(size: 76, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .fixedSize()

            Text(L10n.Training.overviewDaysUnit.localized)
                .font(AppFont.subheadline())
                .foregroundColor(.white.opacity(0.85))
                .padding(.bottom, 8)

            Spacer()

            // Race date label aligned bottom-right
            if let raceDate = overview.raceDateValue {
                Text(formattedRaceDate(raceDate))
                    .font(AppFont.captionRegular())
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.bottom, 6)
            }
        }
    }

    @ViewBuilder
    private func phaseWeekChip(overview: PlanOverviewV2) -> some View {
        let currentWeek = viewModel.loader.currentWeek
        let stage = overview.trainingStages.first { $0.contains(week: currentWeek) }
            ?? overview.trainingStages.first

        if let stage = stage {
            let stageWeek = currentWeek - stage.weekStart + 1
            let stageTotalWeeks = stage.weekEnd - stage.weekStart + 1
            let chipText = L10n.Training.overviewPhaseWeekChip
                .localized(with: stage.stageName, stageWeek, stageTotalWeeks)

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                Text(chipText)
                    .font(AppFont.chip())
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.22))
            .clipShape(Capsule())
        }
    }

    // MARK: - Stats Card (JSX lines 573–591, FitnessGapGauge excluded)

    @ViewBuilder
    private func statsCard(overview: PlanOverviewV2) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Column 1: Distance
                statColumn(
                    label: L10n.Training.distance.localized,
                    value: distanceDisplay(for: overview),
                    suffix: overview.distanceUnit ?? "km"
                )
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 48)

                // Column 2: Target time
                statColumn(
                    label: L10n.Training.targetTime.localized,
                    value: overview.targetTime.map { formatTime(seconds: $0) } ?? "--",
                    suffix: nil
                )
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 48)

                // Column 3: Target pace
                statColumn(
                    label: L10n.Training.targetPace.localized,
                    value: overview.targetPace ?? "--",
                    suffix: "/km"
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(PacerizRadius.card)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func statColumn(label: String, value: String, suffix: String?) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(AppFont.micro())
                .foregroundColor(.secondary)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(AppFont.numberMedium())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let suffix = suffix {
                    Text(suffix)
                        .font(AppFont.micro())
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Utility helpers

    private func heroTitle(for overview: PlanOverviewV2) -> String {
        if overview.isRaceRunTarget {
            return overview.targetName ?? overview.targetDescription ?? "--"
        } else {
            return overview.targetDescription ?? overview.targetName ?? "--"
        }
    }

    private func nonRaceSubtitle(for overview: PlanOverviewV2) -> String {
        if overview.isBeginnerTarget {
            return L10n.Training.overviewBeginnerSubtitle.localized
        } else {
            return L10n.Training.overviewMaintenanceSubtitle.localized
        }
    }

    private func daysLeft(for overview: PlanOverviewV2) -> Int {
        guard let raceDate = overview.raceDateValue else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let race = calendar.startOfDay(for: raceDate)
        return max(0, calendar.dateComponents([.day], from: today, to: race).day ?? 0)
    }

    private func formattedRaceDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func distanceDisplay(for overview: PlanOverviewV2) -> String {
        let value = overview.distanceKmDisplay ?? overview.distanceKm
        guard let value else { return "--" }
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    // Reused from PlanOverviewSheetV2.formatTime(seconds:) — same logic
    private func formatTime(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    // Mirrors getStageColor(stageId:) from TrainingProgressViewV2
    private func stageColor(for stageId: String) -> Color {
        switch stageId {
        case "conversion": return .teal
        case "base":       return PacerizColor.blue
        case "build":      return PacerizColor.green
        case "peak":       return PacerizColor.orange
        case "taper":      return .purple
        default:           return PacerizColor.blue
        }
    }
}

// MARK: - Color blend helper (for gradient darkening)

private extension Color {
    /// Blend this color toward `other` by `fraction` (0 = self, 1 = other).
    func blended(with other: Color, fraction: CGFloat) -> Color {
        // Use UIColor for component access.
        let base = UIColor(self)
        let target = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        base.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        target.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            red: r1 + (r2 - r1) * fraction,
            green: g1 + (g2 - g1) * fraction,
            blue: b1 + (b2 - b1) * fraction,
            opacity: a1 + (a2 - a1) * fraction
        )
    }
}

// MARK: - Preview

#Preview("Race Mode") {
    // DependencyContainer wires the real stack; planOverview starts nil → shows ProgressView.
    // Full data-driven preview (with mock PlanOverviewV2) is deferred to Task 4/5 integration.
    let vm = DependencyContainer.shared.makeTrainingPlanV2ViewModel()
    TrainingOverviewV2View(viewModel: vm)
}
