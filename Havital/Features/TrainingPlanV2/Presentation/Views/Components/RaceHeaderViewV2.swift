import SwiftUI

// MARK: - RaceHeaderViewV2
/// Compact race header for the training plan main screen (Phase B2).
///
/// Single-row layout:
///   [倒數 · 天] | [賽名 / 差 chip / est → target] | [適能 score delta ›]
///
/// Dark gradient background (1A1F2C → 2A3550).
/// All sections hide gracefully when data is nil — no crash, no empty boxes.
struct RaceHeaderViewV2: View {

    @ObservedObject var viewModel: RaceHeaderViewModelV2

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            countdownColumn
            divider
            raceInfoColumn
            divider
            readinessColumn
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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
        .shadow(color: Color(red: 20/255, green: 30/255, blue: 60/255).opacity(0.18), radius: 9, x: 0, y: 4)
    }

    // MARK: - Countdown Column

    @ViewBuilder
    private var countdownColumn: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(NSLocalizedString("training_plan.race_countdown_label", comment: "倒數"))
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.white.opacity(0.7))
                .tracking(0.6)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(viewModel.daysLeft.map { "\($0)" } ?? "--")
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color(red: 1, green: 0.498, blue: 0.314))  // #FF7F50
                    .lineLimit(1)
                Text(NSLocalizedString("training_plan.race_countdown_days", comment: "天"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(minWidth: 50, alignment: .center)
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
    }

    // MARK: - Race Info Column

    @ViewBuilder
    private var raceInfoColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Race title
            Text(viewModel.raceTitle ?? "")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Gap chip + estimated → target
            HStack(spacing: 4) {
                if let gapText = viewModel.gapText {
                    Text(gapText)
                        .font(.system(size: 10.5, weight: .heavy))
                        .foregroundColor(viewModel.isOnTrack
                            ? Color(red: 0.651, green: 0.851, blue: 0.722)  // #A6D9B8
                            : Color(red: 1, green: 0.690, blue: 0.533))     // #FFB088
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(viewModel.isOnTrack
                                    ? Color(red: 0.463, green: 0.784, blue: 0.576, opacity: 0.25)
                                    : Color(red: 1, green: 0.498, blue: 0.314, opacity: 0.20))
                        )
                }

                if let est = viewModel.estimatedFinish {
                    Text(est)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                }

                if viewModel.estimatedFinish != nil, viewModel.targetFinish != nil {
                    Text("→")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                }

                if let target = viewModel.targetFinish {
                    Text(target)
                        .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color(red: 1, green: 0.690, blue: 0.533))  // #FFB088
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Readiness Column

    @ViewBuilder
    private var readinessColumn: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(NSLocalizedString("training_plan.race_readiness_label", comment: "適能"))
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.white.opacity(0.7))
                .tracking(0.6)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(viewModel.readinessScore.map { "\($0)" } ?? "--")
                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                    .foregroundColor(readinessColor)
                    .lineLimit(1)

                if let delta = viewModel.weekDeltaDisplay {
                    Text("\(delta.symbol)\(delta.magnitude)")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(delta.color)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(minWidth: 56, alignment: .trailing)
    }

    // MARK: - Helpers

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
        @StateObject private var vm: RaceHeaderViewModelV2 = {
            let loader = WeeklyPlanLoader(
                repository: DependencyContainer.shared.resolve(),
                workoutRepository: DependencyContainer.shared.resolve(),
                shouldSuppressError: { _, _, _ in false },
                onNetworkError: { _ in }
            )
            let readinessVM = TrainingReadinessViewModel()
            return RaceHeaderViewModelV2(loader: loader, readinessVM: readinessVM)
        }()

        var body: some View {
            RaceHeaderViewV2(viewModel: vm)
                .padding()
                .background(Color(.systemGroupedBackground))
        }
    }
    return PreviewWrapper()
}
