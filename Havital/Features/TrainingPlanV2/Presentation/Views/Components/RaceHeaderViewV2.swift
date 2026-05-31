import SwiftUI

// MARK: - RaceHeaderViewV2
/// Compact race header for the training plan main screen (Phase B2).
///
/// Single-row layout:
///   [倒數 · 天] | [賽名 / target → est] | [適能 score delta ›]
///
/// Adaptive gradient background: light mode 3D4663 → 525C7F, dark mode 2E3548 → 424D6B.
/// All sections hide gracefully when data is nil — no crash, no empty boxes.
struct RaceHeaderViewV2: View {

    @ObservedObject var viewModel: RaceHeaderViewModelV2
    @Environment(\.colorScheme) private var colorScheme

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
        .background(adaptiveDarkGradient(for: colorScheme))
        .cornerRadius(16)
        .shadow(color: Color(red: 20/255, green: 30/255, blue: 60/255).opacity(0.18), radius: 9, x: 0, y: 4)
    }

    // MARK: - Adaptive Background

    private func adaptiveDarkGradient(for colorScheme: ColorScheme) -> LinearGradient {
        let stops: [Gradient.Stop]
        if colorScheme == .dark {
            stops = [
                .init(color: Color(red: 0x2E / 255.0, green: 0x35 / 255.0, blue: 0x48 / 255.0), location: 0),
                .init(color: Color(red: 0x42 / 255.0, green: 0x4D / 255.0, blue: 0x6B / 255.0), location: 1)
            ]
        } else {
            stops = [
                .init(color: Color(red: 0x3D / 255.0, green: 0x46 / 255.0, blue: 0x63 / 255.0), location: 0),
                .init(color: Color(red: 0x52 / 255.0, green: 0x5C / 255.0, blue: 0x7F / 255.0), location: 1)
            ]
        }
        return LinearGradient(stops: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Countdown Column

    @ViewBuilder
    private var countdownColumn: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(NSLocalizedString("training_plan.race_countdown_label", comment: "倒數"))
                .font(AppFont.chip())
                .foregroundColor(.white.opacity(0.85))
                .tracking(0.6)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(viewModel.daysLeft.map { "\($0)" } ?? "--")
                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color(red: 1, green: 0.498, blue: 0.314))  // #FF7F50
                    .lineLimit(1)
                Text(NSLocalizedString("training_plan.race_countdown_days", comment: "天"))
                    .font(AppFont.micro())
                    .foregroundColor(.white.opacity(0.85))
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
                .font(AppFont.titleM())
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Target → estimated (goal first, then current projection)
            HStack(spacing: 4) {
                if let target = viewModel.targetFinish {
                    Text(target)
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .foregroundColor(.white)
                }

                if viewModel.targetFinish != nil, viewModel.estimatedFinish != nil {
                    Text("→")
                        .font(AppFont.micro())
                        .foregroundColor(.white.opacity(0.4))
                }

                if let est = viewModel.estimatedFinish {
                    Text(est)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(viewModel.estimatedTimeColor)
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
                .font(AppFont.chip())
                .foregroundColor(.white.opacity(0.85))
                .tracking(0.6)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(viewModel.readinessScore.map { "\($0)" } ?? "--")
                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
                    .foregroundColor(readinessColor)
                    .lineLimit(1)

                if let delta = viewModel.weekDeltaDisplay {
                    Text("\(delta.symbol)\(delta.magnitude)")
                        .font(AppFont.chip())
                        .foregroundColor(delta.color)
                }
            }

            Image(systemName: "chevron.right")
                .font(AppFont.micro())
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
