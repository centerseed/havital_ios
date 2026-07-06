import SwiftUI

// MARK: - DailyStateCardView
/// Presentation Layer — 今日狀態摺疊卡片。
/// 自帶 ViewModel 與 sheet：點卡片開 DailyStateDetailView。
/// - `.loading`：sparkles + 標題 + circular ProgressView + 讀取文案
/// - `.loaded`：headline + 第一個佐證 chip + chevron，整卡可點 → sheet
/// - `.error`/`.empty`：隱藏（不擾民）
struct DailyStateCardView: View {
    @StateObject private var viewModel: DailyStateCardViewModel
    @State private var showSheet = false

    init(viewModel: DailyStateCardViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? DailyStateCardViewModel())
    }

    var body: some View {
        VStack(spacing: 12) {
            // T-0142：今天有合格指標跑 → 校準卡置頂(一開就看到)。
            if let cal = viewModel.benchmarkCalibration {
                SameDayBenchmarkCard(
                    calibration: cal,
                    isApplying: viewModel.isApplyingBenchmark,
                    isSchedulingNext: viewModel.isSchedulingNext,
                    scheduledNextWeek: viewModel.scheduledNextWeek,
                    onApply: { viewModel.applyBenchmark() },
                    onLater: { viewModel.dismissBenchmark() },
                    onScheduleNext: { viewModel.scheduleNextBenchmark() }
                )
            }
            stateCard
        }
        .task { viewModel.load() }
    }

    private var stateCard: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PacerizRadius.card)
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if viewModel.state.hasData { showSheet = true }
            }
            .sheet(isPresented: $showSheet) {
                if let card = viewModel.state.data {
                    DailyStateDetailView(card: card) {
                        // 升級：先收掉本 sheet，再透過 InterruptCoordinator 走既有 paywall
                        // （與 FreeTierBanner 同一進場機制；paywall 在 root InterruptHost 呈現）。
                        showSheet = false
                        _ = InterruptCoordinator.shared.enqueue(.paywall(.featureLocked))
                    }
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .loading:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("daily_state.title", comment: "Today's state card title"))
                        .font(AppFont.headline())
                    Spacer()
                    ProgressView()
                }
                Text(NSLocalizedString("daily_state.loading", comment: "Today's state card loading text"))
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }
        case .loaded(let card):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.accentColor)
                    Text(NSLocalizedString("daily_state.title", comment: "Today's state card title"))
                        .font(AppFont.headline())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
                Text(card.headline)
                    .font(AppFont.body())
                    .foregroundColor(.primary)
                if let chip = card.chips.first {
                    PRChip(
                        text: chip,
                        fg: .accentColor,
                        bg: Color.accentColor.opacity(0.12),
                        leadingSymbol: "checkmark.seal"
                    )
                }
            }
        case .error, .empty:
            EmptyView()
        }
    }
}
