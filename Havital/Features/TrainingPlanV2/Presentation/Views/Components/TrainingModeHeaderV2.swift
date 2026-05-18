import SwiftUI

// MARK: - TrainingModeHeaderV2
/// Mode header for Starter / Maintenance training (Phase B3).
///
/// Layout:
///   [mode chip   第 N 週]
///   [鼓勵訊息]
///   [連續訓練 | 本月里程 | 就緒指數]
///   [就緒指數 progress bar]
///
/// Dark gradient background (1A1F2C → 2A3550).
/// All stat sections hide gracefully when data is nil.
struct TrainingModeHeaderV2: View {

    @ObservedObject var viewModel: TrainingModeHeaderViewModelV2

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Row 1: mode chip + week label
            HStack {
                modeChip
                Spacer()
                if let week = viewModel.currentWeek {
                    Text(String(format: NSLocalizedString("training_mode.week_number", comment: ""), week))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.bottom, 10)

            // Row 2: tagline / motivational message
            Text(tagline)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white.opacity(0.92))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 14)

            // Row 3: 3-stat row
            statsRow
                .padding(.bottom, 12)

            // Row 4: readiness progress bar
            readinessBar
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0x1A/255.0, green: 0x1F/255.0, blue: 0x2C/255.0),
                    Color(red: 0x2A/255.0, green: 0x35/255.0, blue: 0x50/255.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(
            color: Color(red: 20/255, green: 30/255, blue: 60/255).opacity(0.22),
            radius: 12, x: 0, y: 5
        )
    }

    // MARK: - Mode Chip

    @ViewBuilder
    private var modeChip: some View {
        let meta = modeMetadata
        HStack(spacing: 4) {
            Text(meta.icon)
                .font(.system(size: 11))
            Text(meta.label)
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.6)
        }
        .foregroundColor(meta.color)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(meta.color.opacity(0.25))
        )
    }

    // MARK: - Tagline

    private var tagline: String {
        switch viewModel.mode {
        case .starter:
            return NSLocalizedString("training_mode.starter_tagline", comment: "")
        case .maintain:
            return NSLocalizedString("training_mode.maintain_tagline", comment: "")
        }
    }

    // MARK: - Stats Row

    @ViewBuilder
    private var statsRow: some View {
        HStack(alignment: .top, spacing: 0) {
            // Streak
            statCell(
                label: NSLocalizedString("training_mode.streak_label", comment: ""),
                valueText: viewModel.streakDays.map { "\($0)" } ?? "--",
                unit: NSLocalizedString("training_plan.race_countdown_days", comment: "天"),
                valueFontSize: 26,
                valueColor: Color(red: 1, green: 0.498, blue: 0.314)  // #FF7F50
            )

            divider

            // Monthly km
            statCell(
                label: NSLocalizedString("training_mode.monthly_km_label", comment: ""),
                valueText: viewModel.monthlyKm.map { String(format: "%.1f", $0) } ?? "--",
                unit: "km",
                valueFontSize: 22,
                valueColor: .white
            )

            divider

            // Readiness score
            statCell(
                label: NSLocalizedString("training_mode.readiness_label", comment: ""),
                valueText: viewModel.readinessScore.map { "\($0)" } ?? "--",
                unit: "/ 100",
                valueFontSize: 22,
                valueColor: readinessColor
            )
        }
    }

    @ViewBuilder
    private func statCell(
        label: String,
        valueText: String,
        unit: String,
        valueFontSize: CGFloat,
        valueColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9.5, weight: .heavy))
                .foregroundColor(.white.opacity(0.7))
                .tracking(0.6)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(valueText)
                    .font(.system(size: valueFontSize, weight: .heavy, design: .monospaced))
                    .foregroundColor(valueColor)
                    .lineLimit(1)
                Text(unit)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
            .frame(width: 1, height: 44)
            .padding(.horizontal, 4)
    }

    // MARK: - Readiness Bar

    @ViewBuilder
    private var readinessBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [readinessColor.opacity(0.6), readinessColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * viewModel.readinessProgress, height: 6)
                    .animation(.easeOut(duration: 0.4), value: viewModel.readinessProgress)
            }
        }
        .frame(height: 6)
    }

    // MARK: - Helpers

    private struct ModeMetadata {
        let icon: String
        let label: String
        let color: Color
    }

    private var modeMetadata: ModeMetadata {
        switch viewModel.mode {
        case .starter:
            return ModeMetadata(
                icon: "🌱",
                label: NSLocalizedString("training_mode.starter_label", comment: ""),
                color: Color(red: 0.463, green: 0.784, blue: 0.576)  // #76C893
            )
        case .maintain:
            return ModeMetadata(
                icon: "🔄",
                label: NSLocalizedString("training_mode.maintain_label", comment: ""),
                color: Color(red: 0.247, green: 0.525, blue: 0.965)  // #3F86F6
            )
        }
    }

    private var readinessColor: Color {
        guard let score = viewModel.readinessScore else { return .white }
        if score >= 75 { return Color(red: 0.463, green: 0.784, blue: 0.576) }  // #76C893
        if score >= 50 { return Color(red: 1, green: 0.498, blue: 0.314) }       // #FF7F50
        return Color(red: 0.957, green: 0.267, blue: 0.212)                       // #F44336
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var vm: TrainingModeHeaderViewModelV2 = {
            let loader = WeeklyPlanLoader(
                repository: DependencyContainer.shared.resolve(),
                workoutRepository: DependencyContainer.shared.resolve(),
                shouldSuppressError: { _, _, _ in false },
                onNetworkError: { _ in }
            )
            let readinessVM = TrainingReadinessViewModel()
            let monthlyRepo: MonthlyStatsRepository = DependencyContainer.shared.resolve()
            return TrainingModeHeaderViewModelV2(
                loader: loader,
                monthlyStatsRepository: monthlyRepo,
                readinessVM: readinessVM
            )
        }()

        var body: some View {
            TrainingModeHeaderV2(viewModel: vm)
                .padding()
                .background(Color(.systemGroupedBackground))
        }
    }
    return PreviewWrapper()
}
