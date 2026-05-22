import SwiftUI

// MARK: - PhaseRoadmapView
//
// Task 2/5: PhaseRoadmap — vertical roadmap, one row per phase.
// Subsumes the old 「訓練進度」screen (TrainingProgressViewV2).
//
// Design reference: plan-overview.jsx lines 724–1035 (PhaseRoadmap function).
// Navigation logic ported from TrainingProgressViewV2.swift lines 217–298.
//
// Data sources:
//   viewModel.loader.planOverview.trainingStages  — TrainingStageV2 array
//   viewModel.loader.weeklyPreview?.weeks          — WeekPreview array
//   viewModel.summary.weeklySummaries              — has-plan / has-review flags
//   targetViewModel.sortedSupportingTargets        — supporting races (non-main)

struct PhaseRoadmapView: View {

    var viewModel: TrainingPlanV2ViewModel
    var targetViewModel: TargetFeatureViewModel

    @Environment(\.dismiss) private var dismiss

    // Expanded phase index: default to current phase index (-1 = all collapsed)
    @State private var expandedPhaseIndex: Int = -1
    // Per-phase "show all weeks" state (keyed by phase index)
    @State private var showAllWeeksForPhase: Set<Int> = []

    var body: some View {
        if let overview = viewModel.loader.planOverview {
            let stages = overview.trainingStages
            VStack(spacing: 0) {
                roadmapCard(overview: overview, stages: stages)
            }
            .onAppear {
                expandCurrentPhase(stages: stages)
            }
        }
    }

    // MARK: - Main Card

    @ViewBuilder
    private func roadmapCard(overview: PlanOverviewV2, stages: [TrainingStageV2]) -> some View {
        VStack(spacing: 0) {
            // Header row (JSX 778-789)
            headerRow(overview: overview, stages: stages)

            // Phase rows (JSX 792-1003)
            VStack(spacing: 0) {
                ForEach(stages.indices, id: \.self) { index in
                    let stage = stages[index]
                    let isLast = index == stages.count - 1
                    phaseRow(
                        stage: stage,
                        index: index,
                        isLast: isLast,
                        overview: overview
                    )
                }

                // Main race finish line — race mode only (JSX 1005-1031)
                if overview.isRaceRunTarget {
                    mainRaceFinishLine(overview: overview)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(PacerizRadius.card)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Header Row (JSX 778-789)

    @ViewBuilder
    private func headerRow(overview: PlanOverviewV2, stages: [TrainingStageV2]) -> some View {
        let totalWeeks = overview.totalWeeks
        let phaseCount = stages.count
        let supportCount = targetViewModel.sortedSupportingTargets.count

        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.PhaseRoadmap.title.localized)
                    .font(AppFont.bodyStrong())

                Text(subtitleText(
                    phaseCount: phaseCount,
                    totalWeeks: totalWeeks,
                    isRace: overview.isRaceRunTarget,
                    supportCount: supportCount
                ))
                .font(AppFont.caption())
                .foregroundColor(.secondary)
            }

            Spacer()

            // "加賽事" entry — visual placeholder per spec (non-functional in Task 2)
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text(L10n.PhaseRoadmap.addRace.localized)
                    .font(AppFont.chip())
            }
            .foregroundColor(PacerizColor.blue)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private func subtitleText(phaseCount: Int, totalWeeks: Int, isRace: Bool, supportCount: Int) -> String {
        let base = L10n.PhaseRoadmap.subtitle.localized(with: phaseCount, totalWeeks)
        if isRace && supportCount > 0 {
            let races = L10n.PhaseRoadmap.subtitleRaceCount.localized(with: supportCount + 1)
            return base + " · " + races
        }
        return base
    }

    // MARK: - Phase Row (JSX 813-1001)

    @ViewBuilder
    private func phaseRow(stage: TrainingStageV2, index: Int, isLast: Bool, overview: PlanOverviewV2) -> some View {
        let currentWeek = viewModel.loader.currentWeek
        let isCurrent = stage.contains(week: currentWeek)
        let isPast = currentWeek > stage.weekEnd
        let isFuture = currentWeek < stage.weekStart
        let isExpanded = index == expandedPhaseIndex
        let stageClr = stageColor(for: stage.stageId)

        HStack(alignment: .top, spacing: 12) {
            // Rail (JSX 816-831)
            railColumn(
                isCurrent: isCurrent,
                isPast: isPast,
                isFuture: isFuture,
                isLast: isLast,
                color: stageClr,
                isExpanded: isExpanded
            )

            // Body
            VStack(alignment: .leading, spacing: 0) {
                // Title row (tap to expand/collapse)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expandedPhaseIndex == index {
                            expandedPhaseIndex = -1
                        } else {
                            expandedPhaseIndex = index
                        }
                    }
                } label: {
                    phaseTitleRow(
                        stage: stage,
                        isCurrent: isCurrent,
                        isPast: isPast,
                        isFuture: isFuture,
                        isExpanded: isExpanded,
                        color: stageClr,
                        currentWeek: currentWeek
                    )
                }
                .buttonStyle(PlainButtonStyle())

                if isExpanded {
                    phaseExpandedContent(
                        stage: stage,
                        index: index,
                        isCurrent: isCurrent,
                        color: stageClr,
                        overview: overview,
                        currentWeek: currentWeek
                    )
                }
            }
            .padding(.bottom, isLast ? 0 : 16)
        }
    }

    // MARK: - Rail Column (JSX 816-831)

    @ViewBuilder
    private func railColumn(
        isCurrent: Bool,
        isPast: Bool,
        isFuture: Bool,
        isLast: Bool,
        color: Color,
        isExpanded: Bool
    ) -> some View {
        ZStack(alignment: .top) {
            // Dot
            Circle()
                .fill(isFuture ? Color.clear : color)
                .overlay(
                    Circle()
                        .stroke(color, lineWidth: 2.5)
                        .opacity(isFuture ? 0.5 : 1)
                )
                .frame(width: 14, height: 14)
                .opacity(isFuture ? 0.5 : 1)
                .padding(.top, 2)

            // Connector line
            if !isLast {
                Rectangle()
                    .fill(isPast ? color.opacity(0.9) : Color(UIColor.separator))
                    .frame(width: 3)
                    .cornerRadius(2)
                    .offset(y: 18)
                    // Use infinity so it fills the row height; masked by parent clip
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(width: 24)
    }

    // MARK: - Phase Title Row (JSX 836-849)

    @ViewBuilder
    private func phaseTitleRow(
        stage: TrainingStageV2,
        isCurrent: Bool,
        isPast: Bool,
        isFuture: Bool,
        isExpanded: Bool,
        color: Color,
        currentWeek: Int
    ) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Text(stage.stageName)
                .font(AppFont.bodyStrong())
                .foregroundColor(isFuture ? .secondary : .primary)

            if isCurrent {
                let weekInStage = currentWeek - stage.weekStart + 1
                let totalInStage = stage.weekEnd - stage.weekStart + 1
                Text(L10n.PhaseRoadmap.inProgressBadge.localized(with: weekInStage, totalInStage))
                    .font(AppFont.caption())
                    .fontWeight(.bold)
                    .foregroundColor(color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }

            if isPast {
                Text(L10n.PhaseRoadmap.completedBadge.localized)
                    .font(AppFont.caption())
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(L10n.Training.weekRange.localized(with: stage.weekStart, stage.weekEnd))
                .font(AppFont.caption())
                .foregroundColor(.secondary)
                .monospacedDigit()

            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Expanded Phase Content (JSX 851-999)

    @ViewBuilder
    private func phaseExpandedContent(
        stage: TrainingStageV2,
        index: Int,
        isCurrent: Bool,
        color: Color,
        overview: PlanOverviewV2,
        currentWeek: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Today progress bar — current phase only (JSX 852-862)
            if isCurrent {
                let withinPct = Double(currentWeek - stage.weekStart + 1) /
                                Double(stage.weekEnd - stage.weekStart + 1)
                todayProgressBar(pct: withinPct, color: color)
                    .padding(.top, 8)
            }

            // Phase summary line: 重點 + 週跑量 (JSX 864-876)
            phaseSummaryRow(stage: stage, isCurrent: isCurrent)

            // Week list (JSX 878-968)
            weekListSection(
                stage: stage,
                index: index,
                isCurrent: isCurrent,
                color: color,
                currentWeek: currentWeek
            )

            // Key workouts chips (JSX 972-983)
            if let keyWorkouts = stage.keyWorkouts, !keyWorkouts.isEmpty {
                keyWorkoutsChips(keyWorkouts: keyWorkouts, color: color)
                    .padding(.top, 8)
            }

            // Supporting races in this phase (JSX 985-999)
            let phaseRaces = supportingRacesForPhase(stage: stage, currentWeek: currentWeek)
            if !phaseRaces.isEmpty {
                ForEach(phaseRaces, id: \.id) { race in
                    supportingRaceRow(race: race)
                        .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - Today Progress Bar (JSX 853-862)

    @ViewBuilder
    private func todayProgressBar(pct: Double, color: Color) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.13))
                    .frame(height: 6)

                // Fill
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: max(geometry.size.width * CGFloat(min(pct, 1.0)), 0), height: 6)

                // Thumb dot
                Circle()
                    .fill(Color.white)
                    .overlay(
                        Circle().stroke(color, lineWidth: 2.5)
                    )
                    .frame(width: 12, height: 12)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                    .offset(
                        x: max(geometry.size.width * CGFloat(min(pct, 1.0)) - 6, 0),
                        y: -3
                    )
            }
        }
        .frame(height: 12)
    }

    // MARK: - Phase Summary Row (JSX 866-876)

    @ViewBuilder
    private func phaseSummaryRow(stage: TrainingStageV2, isCurrent: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // 重點 column
            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.PhaseRoadmap.focusLabel.localized)
                    .font(AppFont.micro())
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                Text(stage.trainingFocus)
                    .font(AppFont.captionRegular())
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 週跑量 column
            VStack(alignment: .trailing, spacing: 1) {
                Text(L10n.Training.weeklyVolume.localized)
                    .font(AppFont.micro())
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                let kmText = kmRangeText(stage: stage)
                Text(kmText)
                    .font(AppFont.numberMedium())
                    .foregroundColor(.primary)
                    .monospacedDigit()
            }
            .frame(alignment: .trailing)
        }
        .padding(.top, isCurrent ? 12 : 8)
    }

    private func kmRangeText(stage: TrainingStageV2) -> String {
        if let display = stage.targetWeeklyKmRangeDisplay {
            let unit = display.distanceUnit
            return "\(Int(display.lowDisplay.rounded()))–\(Int(display.highDisplay.rounded())) \(unit)"
        } else {
            let r = stage.targetWeeklyKmRange
            return "\(Int(r.low.rounded()))–\(Int(r.high.rounded())) km"
        }
    }

    // MARK: - Week List Section (JSX 882-968)

    @ViewBuilder
    private func weekListSection(
        stage: TrainingStageV2,
        index: Int,
        isCurrent: Bool,
        color: Color,
        currentWeek: Int
    ) -> some View {
        let allWeeks = Array(stage.weekStart...stage.weekEnd)
        let showAll = showAllWeeksForPhase.contains(index)

        // Visible rows: current phase ±2 (max 5) by default; other phases: all
        let visibleWeeks: [Int] = {
            if showAll || allWeeks.count <= 5 {
                return allWeeks
            }
            if isCurrent {
                return allWeeks.filter { abs($0 - currentWeek) <= 2 }
            }
            return Array(allWeeks.prefix(3))
        }()

        let hiddenCount = allWeeks.count - visibleWeeks.count

        VStack(spacing: 0) {
            if !visibleWeeks.isEmpty {
                VStack(spacing: 0) {
                    ForEach(visibleWeeks.indices, id: \.self) { i in
                        let weekNum = visibleWeeks[i]
                        weekRow(
                            weekNumber: weekNum,
                            isFirst: i == 0,
                            color: color,
                            currentWeek: currentWeek
                        )

                        if i < visibleWeeks.count - 1 {
                            Divider()
                                .padding(.horizontal, 0)
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(UIColor.separator), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.top, 10)
            }

            // "Show all N weeks" button (JSX 947-966)
            if hiddenCount > 0 {
                Button {
                    showAllWeeksForPhase.insert(index)
                } label: {
                    HStack {
                        Text(L10n.PhaseRoadmap.showAllWeeks.localized(with: allWeeks.count, hiddenCount))
                            .font(AppFont.captionRegular())
                            .fontWeight(.bold)
                            .foregroundColor(PacerizColor.blue)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(PacerizColor.blue)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 8)
            }

            // "Collapse" button when showing all (JSX 957-966)
            if hiddenCount == 0 && allWeeks.count > 5 && showAll {
                Button {
                    showAllWeeksForPhase.remove(index)
                } label: {
                    HStack {
                        Text(L10n.PhaseRoadmap.collapseWeeks.localized)
                            .font(AppFont.caption())
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Week Row (JSX 884-945, logic from TrainingProgressViewV2:213-350)

    @ViewBuilder
    private func weekRow(weekNumber: Int, isFirst: Bool, color: Color, currentWeek: Int) -> some View {
        let isCurrentWeek = currentWeek == weekNumber
        let isFutureWeek = weekNumber > currentWeek

        // Summary data (TrainingProgressViewV2:218-225)
        let weekSummaryItem = viewModel.summary.weeklySummaries.first { $0.weekIndex == weekNumber }
        let hasWeekPlan = weekSummaryItem?.weekPlan != nil
        let hasSummary = weekSummaryItem?.weekSummary != nil
        let summariesLoaded = !viewModel.summary.weeklySummaries.isEmpty
        let showSchedule = summariesLoaded ? hasWeekPlan : !isFutureWeek
        let showReview = summariesLoaded ? hasSummary : false

        // Skeleton data — only current/future (TrainingProgressViewV2:228-230)
        let skeletonWeek = weekNumber >= currentWeek
            ? viewModel.loader.weeklyPreview?.weeks.first { $0.week == weekNumber }
            : nil

        let weekTextColor: Color = isCurrentWeek
            ? color
            : (isFutureWeek ? Color.secondary.opacity(0.5) : .secondary)

        VStack(alignment: .leading, spacing: 8) {
            // Row 1: W# · km · "本週" badge · spacer · 課表 · 回顧 (JSX 892-928)
            HStack(alignment: .center, spacing: 8) {
                // W{N}
                Text("W\(weekNumber)")
                    .font(AppFont.bodySmall())
                    .fontWeight(.bold)
                    .foregroundColor(weekTextColor)
                    .monospacedDigit()

                // km number
                if let skeleton = skeletonWeek {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(Int(skeleton.targetKmDisplay ?? skeleton.targetKm))")
                            .font(AppFont.numberMedium())
                            .foregroundColor(isCurrentWeek ? .primary : .secondary)
                            .monospacedDigit()
                        Text(skeleton.distanceUnit ?? "km")
                            .font(AppFont.micro())
                            .foregroundColor(.secondary)
                    }
                }

                // "本週" badge (JSX 902-904)
                if isCurrentWeek {
                    Text(L10n.Training.currentWeekLabel.localized)
                        .font(AppFont.caption())
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(color)
                        .clipShape(Capsule())
                }

                // Recovery badge (TrainingProgressViewV2:303-313)
                if let skeleton = skeletonWeek, skeleton.isRecovery {
                    Text(L10n.Training.recoveryWeek.localized)
                        .font(AppFont.caption2())
                        .foregroundColor(.green)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                }

                Spacer()

                // 課表 button (JSX 906-915; navigation from TrainingProgressViewV2:277-292)
                if showSchedule {
                    Button {
                        Task {
                            await viewModel.loader.switchToWeek(weekNumber)
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(AppFont.systemScaled(size: 12, weight: .medium))
                            Text(L10n.TrainingProgress.schedule.localized)
                                .font(AppFont.footnote())
                                .fontWeight(.semibold)
                        }
                        .fixedSize()
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(isCurrentWeek ? color : Color(UIColor.secondarySystemBackground))
                        .foregroundColor(isCurrentWeek ? .white : .primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // 回顧 button (JSX 916-927; navigation from TrainingProgressViewV2:254-272)
                if showReview {
                    Button {
                        Task {
                            await viewModel.summary.viewHistoricalSummary(week: weekNumber)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(AppFont.systemScaled(size: 12, weight: .medium))
                            Text(L10n.TrainingProgress.review.localized)
                                .font(AppFont.footnote())
                                .fontWeight(.semibold)
                        }
                        .fixedSize()
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Row 2: Long run / Quality session (JSX 930-943; from TrainingProgressViewV2:317-345)
            if let skeleton = skeletonWeek {
                let longRunDisplay = TrainingTypeDisplayName.longRunDisplay(skeleton.longRun)
                let qualityDisplay = TrainingTypeDisplayName.qualityOptionsDisplay(skeleton.qualityOptions)

                if longRunDisplay != "—" || qualityDisplay != "—" {
                    HStack(spacing: 12) {
                        if longRunDisplay != "—" {
                            HStack(spacing: 4) {
                                Text(L10n.Training.workoutTypeLongRun.localized)
                                    .font(AppFont.caption2())
                                    .foregroundColor(.secondary)
                                Text(longRunDisplay)
                                    .font(AppFont.caption2())
                                    .fontWeight(.medium)
                                    .foregroundColor(isFutureWeek ? .secondary.opacity(0.7) : .primary)
                            }
                        }
                        if qualityDisplay != "—" {
                            HStack(spacing: 4) {
                                Text(L10n.Training.qualitySession.localized)
                                    .font(AppFont.caption2())
                                    .foregroundColor(.secondary)
                                Text(qualityDisplay)
                                    .font(AppFont.caption2())
                                    .fontWeight(.medium)
                                    .foregroundColor(isFutureWeek ? .secondary.opacity(0.7) : .primary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            isCurrentWeek
                ? color.opacity(0.06)
                : Color.clear
        )
        .overlay(alignment: .leading) {
            if isCurrentWeek {
                Rectangle()
                    .fill(color)
                    .frame(width: 3)
            }
        }
    }

    // MARK: - Key Workouts Chips (JSX 972-983)

    @ViewBuilder
    private func keyWorkoutsChips(keyWorkouts: [String], color: Color) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(keyWorkouts, id: \.self) { kw in
                Text(kw)
                    .font(AppFont.caption2())
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.11))
                    .cornerRadius(6)
            }
        }
    }

    // MARK: - Supporting Race Row (JSX 985-999)

    @ViewBuilder
    private func supportingRaceRow(race: Target) -> some View {
        let raceDateStr = formattedRaceDateEpoch(race.raceDate)
        let distanceLabel = "\(race.distanceKm) km"

        HStack(spacing: 8) {
            Text(L10n.PhaseRoadmap.raceBadge.localized)
                .font(AppFont.caption2())
                .fontWeight(.bold)
                .foregroundColor(PacerizColor.orange)
                .tracking(0.5)

            Text(raceDateStr)
                .font(AppFont.caption())
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .monospacedDigit()

            Text(race.name)
                .font(AppFont.captionRegular())
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(distanceLabel)
                .font(AppFont.caption())
                .foregroundColor(.secondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(PacerizColor.orange)
                .frame(width: 3)
                .cornerRadius(1.5)
        }
    }

    // MARK: - Main Race Finish Line (JSX 1005-1031)

    @ViewBuilder
    private func mainRaceFinishLine(overview: PlanOverviewV2) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Target icon circle
            ZStack {
                Circle()
                    .fill(PacerizColor.blue)
                    .frame(width: 22, height: 22)
                    .shadow(color: PacerizColor.blue.opacity(0.4), radius: 4, x: 0, y: 2)
                Image(systemName: "target")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 24)
            .padding(.top, -2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(L10n.PhaseRoadmap.mainRaceLabel.localized)
                        .font(AppFont.caption())
                        .fontWeight(.bold)
                        .foregroundColor(PacerizColor.blue)
                        .tracking(0.5)

                    Text(overview.targetName ?? "")
                        .font(AppFont.bodyStrong())
                        .foregroundColor(PacerizColor.blue)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                mainRaceSubtitle(overview: overview)
            }
        }
        .padding(.top, 14)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(UIColor.separator))
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func mainRaceSubtitle(overview: PlanOverviewV2) -> some View {
        let subtitle = mainRaceSubtitleText(overview: overview)
        if !subtitle.isEmpty {
            Text(subtitle)
                .font(AppFont.captionRegular())
                .foregroundColor(.secondary)
        }
    }

    private func mainRaceSubtitleText(overview: PlanOverviewV2) -> String {
        var parts: [String] = []

        if let raceDate = overview.raceDateValue {
            parts.append(formattedRaceDate(raceDate))
        }

        let distValue = overview.distanceKmDisplay ?? overview.distanceKm
        if let dist = distValue {
            let unit = overview.distanceUnit ?? "km"
            if dist == dist.rounded() {
                parts.append("\(Int(dist)) \(unit)")
            } else {
                parts.append(String(format: "%.1f \(unit)", dist))
            }
        }

        if let targetTime = overview.targetTime, targetTime > 0 {
            let timeStr = formatTime(seconds: targetTime)
            parts.append(L10n.PhaseRoadmap.targetTimePrefix.localized + timeStr)
        }

        return parts.joined(separator: " · ")
    }

    // MARK: - Supporting Race Bucketing (JSX 766-774)

    /// Place a supporting race into the phase it falls in, based on epoch raceDate.
    private func supportingRacesForPhase(stage: TrainingStageV2, currentWeek: Int) -> [Target] {
        return targetViewModel.sortedSupportingTargets.filter { race in
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let raceDay = calendar.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(race.raceDate)))
            let daysLeft = max(0, calendar.dateComponents([.day], from: today, to: raceDay).day ?? 0)
            // Estimate the race week
            let sWeek = Double(currentWeek) + Double(daysLeft) / 7.0
            // Assign to the phase whose window contains sWeek (same logic as JSX 769-773)
            return sWeek >= Double(stage.weekStart) && sWeek <= Double(stage.weekEnd) + 0.5
        }
    }

    // MARK: - Helpers

    private func expandCurrentPhase(stages: [TrainingStageV2]) {
        let currentWeek = viewModel.loader.currentWeek
        if let idx = stages.firstIndex(where: { $0.contains(week: currentWeek) }) {
            expandedPhaseIndex = idx
        }
    }

    /// Mirrors stageColor(for:) from TrainingOverviewV2View to avoid duplication.
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

    private func formattedRaceDateEpoch(_ epoch: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epoch))
        return formattedRaceDate(date)
    }

    private func formattedRaceDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

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
}

// MARK: - FlowLayout (chip wrapping)

/// Simple wrapping HStack for key workout chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowH: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowH + spacing
                rowH = 0
            }
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
        y += rowH
        return CGSize(width: maxWidth, height: y)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowH: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowH + spacing
                rowH = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}
