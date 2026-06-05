import Combine
import SwiftUI

// MARK: - RizoJournalSection
//
// Rizo「訓練日記」UI 區塊，嵌入 WorkoutReflectionView。
//
// 內容：使用上方 note 送出給 Rizo + 回應顯示。可收合/略過，不擋看跑步數據。
// 資料捕捉與回應「兩步解耦」由 RizoJournalViewModel 處理：UI 永遠「已記錄」。
//
// 用法：父層（WorkoutReflectionView）持有 freeNote binding（沿用既有 editor 文字）。
struct RizoJournalSection: View {
    @ObservedObject var viewModel: RizoJournalViewModel
    /// 與既有自由文字 editor 共用的文字。
    let freeNote: () -> String

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isExpanded {
                if viewModel.isRecorded {
                    recordedView
                } else {
                    selectionView
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Header (collapsible — AC-TJF-03)

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(PacerizColor.blue)
                Text(NSLocalizedString("rizo.journal.title", comment: "跟 Rizo 聊聊這次訓練"))
                    .font(AppFont.bodyStrong())
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("rizo_journal_header")
    }

    // MARK: - Note Chat

    private var selectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("rizo.journal.subtitle", comment: "先寫下訓練心得，Rizo 會看你的心得和數據回應"))
                .font(AppFont.micro())
                .foregroundColor(.secondary)

            submitButton

            if let error = viewModel.captureError {
                retryRow(error: error)
            }
        }
    }

    private var submitButton: some View {
        Button {
            viewModel.submit(note: freeNote())
        } label: {
            HStack(spacing: 6) {
                if viewModel.isSubmitting {
                    ProgressView().tint(.white)
                }
                Text(NSLocalizedString("rizo.journal.submit", comment: "送出給 Rizo"))
                    .font(AppFont.bodyStrong())
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(canSubmit ? PacerizColor.blue : Color(UIColor.tertiaryLabel))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit || viewModel.isSubmitting)
        .accessibilityIdentifier("rizo_journal_submit")
    }

    private var canSubmit: Bool {
        !freeNote().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func retryRow(error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(PacerizColor.error)
                .font(.system(size: 12))
            Text(error)
                .font(AppFont.micro())
                .foregroundColor(PacerizColor.error)
            Spacer()
            Button(NSLocalizedString("common.retry", comment: "重試")) {
                viewModel.retry(note: freeNote())
            }
            .font(AppFont.micro())
            .foregroundColor(PacerizColor.blue)
        }
        .accessibilityIdentifier("rizo_journal_retry")
    }

    // MARK: - Recorded + Reply (AC-TJF-06 / 09b / 11 / 16 / 17b / 17c)

    private var recordedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(PacerizColor.green)
                    .font(.system(size: 14))
                Text(NSLocalizedString("rizo.journal.recorded", comment: "已記錄"))
                    .font(AppFont.bodyStrong())
                    .foregroundColor(.primary)
            }
            .accessibilityIdentifier("rizo_journal_recorded")

            if viewModel.isReplyLoading {
                replyLoadingRow
            } else if let reply = viewModel.reply,
                      !reply.reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                replyBubble(reply: reply)
            }

            upsellRow
        }
    }

    private var replyLoadingRow: some View {
        HStack(alignment: .center, spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .tint(PacerizColor.blue)
            Text(NSLocalizedString("rizo.journal.replyLoading", comment: "Rizo 正在回覆..."))
                .font(AppFont.bodyRegular())
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(PacerizColor.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PacerizColor.blue.opacity(0.25), lineWidth: 0.5)
        )
        .accessibilityIdentifier("rizo_journal_reply_loading")
    }

    private func replyBubble(reply: RizoReply) -> some View {
        let isDanger = viewModel.quotaState == .safetyCanned
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: isDanger ? "exclamationmark.shield.fill" : "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isDanger ? PacerizColor.error : PacerizColor.blue)
                .padding(.top, 2)
            Text(reply.reply)
                .font(AppFont.bodyRegular())
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            (isDanger ? PacerizColor.error : PacerizColor.blue).opacity(0.08)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke((isDanger ? PacerizColor.error : PacerizColor.blue).opacity(0.25), lineWidth: 0.5)
        )
        .accessibilityIdentifier(isDanger ? "rizo_journal_reply_canned" : "rizo_journal_reply")
    }

    @ViewBuilder
    private var upsellRow: some View {
        switch viewModel.quotaState {
        case .suggestionWithUpsell:
            upsell(NSLocalizedString("rizo.journal.upsell.adjust", comment: "訂閱後可讓 Rizo 直接幫你調整"))
        case .quotaExhausted:
            upsell(NSLocalizedString("rizo.journal.upsell.quotaExhausted", comment: "本月免費對話次數已用完，訂閱可無限暢聊"))
        case .none, .safetyCanned:
            EmptyView()
        }
    }

    private func upsell(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.system(size: 11))
                .foregroundColor(PacerizColor.orange)
            Text(text)
                .font(AppFont.micro())
                .foregroundColor(.secondary)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(PacerizColor.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityIdentifier("rizo_journal_upsell")
    }
}

#if DEBUG
// MARK: - Preview Support

/// 預覽用 mock repository（純假資料，不連後端）。
private final class _PreviewRizoRepo: RizoRepository {
    let reply: RizoReply?
    init(reply: RizoReply?) { self.reply = reply }
    func sendJournalChat(workoutId: String, message: String, presetSelections: [String], sessionId: String?) async throws -> RizoReply {
        if let reply { return reply }
        throw NSError(domain: "preview", code: 0)
    }
    func getPresets(scenario: String) async throws -> [RizoPreset] { [] }
    func getHistory() async throws -> [RizoHistoryItem] { [] }
}

private final class _PreviewWorkoutRepo: WorkoutRepository {
    func updateSubjectiveInputs(id: String, presets: [String], note: String?) async throws {}
    var workoutsDidRefresh: AnyPublisher<Void, Never> { Empty().eraseToAnyPublisher() }
    var workoutsPaginationDidUpdate: AnyPublisher<PaginationInfo, Never> { Empty().eraseToAnyPublisher() }
    var workoutsDidUpdateNotification: Notification.Name { .workoutsDidUpdate }
    func getCachedPagination() -> PaginationInfo? { nil }
    func getWorkoutsInDateRange(startDate: Date, endDate: Date) -> [WorkoutV2] { [] }
    func getAllWorkouts() -> [WorkoutV2] { [] }
    func getWorkoutsInDateRangeAsync(startDate: Date, endDate: Date) async -> [WorkoutV2] { [] }
    func getAllWorkoutsAsync() async -> [WorkoutV2] { [] }
    func getLatestWorkout() async throws -> WorkoutV2? { nil }
    func ensureMonthLoaded(year: Int, month: Int) async {}
    func getWorkouts(limit: Int?, offset: Int?) async throws -> [WorkoutV2] { [] }
    func refreshWorkouts() async throws -> [WorkoutV2] { [] }
    func loadInitialWorkouts(pageSize: Int) async throws -> WorkoutListResponse { WorkoutListResponse(workouts: [], pagination: PaginationInfo(nextCursor: nil, prevCursor: nil, hasMore: false, hasNewer: false, oldestId: nil, newestId: nil, totalItems: 0, pageSize: pageSize)) }
    func loadMoreWorkouts(afterCursor: String, pageSize: Int) async throws -> WorkoutListResponse { WorkoutListResponse(workouts: [], pagination: PaginationInfo(nextCursor: nil, prevCursor: nil, hasMore: false, hasNewer: false, oldestId: nil, newestId: nil, totalItems: 0, pageSize: pageSize)) }
    func refreshLatestWorkouts(beforeCursor: String?, pageSize: Int) async throws -> WorkoutListResponse { WorkoutListResponse(workouts: [], pagination: PaginationInfo(nextCursor: nil, prevCursor: nil, hasMore: false, hasNewer: false, oldestId: nil, newestId: nil, totalItems: 0, pageSize: pageSize)) }
    func getWorkout(id: String) async throws -> WorkoutV2 { throw DomainError.notFound("preview") }
    func getWorkoutDetail(id: String) async throws -> WorkoutV2Detail { throw DomainError.notFound("preview") }
    func refreshWorkoutDetail(id: String) async throws -> WorkoutV2Detail { throw DomainError.notFound("preview") }
    func clearWorkoutDetailCache(id: String) async {}
    func syncWorkout(_ workout: WorkoutV2) async throws -> WorkoutV2 { workout }
    func updateTrainingNotes(id: String, notes: String) async throws {}
    func deleteWorkout(id: String) async throws {}
    func invalidateRefreshCooldown() {}
    func clearCache() async {}
    func preloadData() async {}
}

enum RizoJournalPreviewFactory {
    static func sampleReply() -> RizoReply {
        RizoReply(
            reply: "你這趟 8K 的後半段配速掉了約 12 秒，搭配你說的「很疲勞」，看起來是累積疲勞。今天的平均心率比上週同距離高 6 bpm，建議明天排輕鬆跑或休息，讓身體吸收這週的量。",
            sessionId: "sess-preview",
            quota: RizoQuota(allowed: true, used: 1, limit: 3, remaining: 2, resetsAt: nil, reserved: true),
            safety: RizoSafety(dangerClass: "none", canned: false)
        )
    }

    @MainActor
    static func makeViewModel(recorded: Bool) -> RizoJournalViewModel {
        let vm = RizoJournalViewModel(
            workoutId: "wk-preview",
            rizoRepository: _PreviewRizoRepo(reply: sampleReply()),
            workoutRepository: _PreviewWorkoutRepo()
        )
        if recorded {
            vm.submit(note: "後段腿很沉")
        }
        return vm
    }
}

#Preview("選擇態") {
    ScrollView {
        RizoJournalSection(viewModel: RizoJournalPreviewFactory.makeViewModel(recorded: false), freeNote: { "後段腿很沉" })
            .padding(16)
    }
    .background(Color(UIColor.systemGroupedBackground))
}

#Preview("已記錄 + 回應") {
    ScrollView {
        RizoJournalSection(viewModel: RizoJournalPreviewFactory.makeViewModel(recorded: true), freeNote: { "後段腿很沉" })
            .padding(16)
    }
    .background(Color(UIColor.systemGroupedBackground))
}
#endif
