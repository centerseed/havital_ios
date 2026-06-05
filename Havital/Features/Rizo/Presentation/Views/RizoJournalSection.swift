import Combine
import SwiftUI

// MARK: - RizoJournalSection
//
// Rizo「訓練日記」UI 區塊，嵌入 WorkoutReflectionView（SPEC-training-journal-feedback S02）。
//
// 內容：4 類預設複選 + 送出 + 回應顯示。可收合/略過（AC-TJF-03，不擋看跑步數據）。
// 資料捕捉與回應「兩步解耦」由 RizoJournalViewModel 處理：UI 永遠「已記錄」。
//
// 用法：父層（WorkoutReflectionView）持有 freeNote binding（沿用既有 editor 文字），
//      送出時連同預設一起交給 ViewModel。
struct RizoJournalSection: View {
    @ObservedObject var viewModel: RizoJournalViewModel
    /// 與既有自由文字 editor 共用的文字（AC-TJF-04：自由文字與預設一起送）。
    let freeNote: () -> String

    @State private var isExpanded = true

    // category 顯示順序（與後端四類對齊）
    private static let categoryOrder = [
        "overall_status", "fatigue_recovery", "pace_effort", "body_discomfort"
    ]

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
        .onAppear { viewModel.loadPresets() }
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

    // MARK: - Selection (AC-TJF-01 / 02)

    private var selectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("rizo.journal.subtitle", comment: "勾選符合的感受，Rizo 會看你的數據回應"))
                .font(AppFont.micro())
                .foregroundColor(.secondary)

            if viewModel.isLoadingPresets && viewModel.presets.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .padding(.vertical, 12)
            } else {
                ForEach(Self.categoryOrder, id: \.self) { category in
                    let items = viewModel.presets.filter { $0.category == category }
                    if !items.isEmpty {
                        categoryGroup(category: category, items: items)
                    }
                }
            }

            submitButton

            if let error = viewModel.captureError {
                retryRow(error: error)
            }
        }
    }

    private func categoryGroup(category: String, items: [RizoPreset]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(categoryTitle(category))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            FlowLayoutChips(
                items: items,
                isSelected: { viewModel.selectedPresetIDs.contains($0.id) },
                onTap: { viewModel.toggle($0.id) }
            )
        }
        .accessibilityIdentifier("rizo_journal_category_\(category)")
    }

    private func categoryTitle(_ category: String) -> String {
        switch category {
        case "overall_status":
            return NSLocalizedString("rizo.journal.category.overall_status", comment: "整體狀態")
        case "fatigue_recovery":
            return NSLocalizedString("rizo.journal.category.fatigue_recovery", comment: "疲勞/恢復")
        case "pace_effort":
            return NSLocalizedString("rizo.journal.category.pace_effort", comment: "配速/費力")
        case "body_discomfort":
            return NSLocalizedString("rizo.journal.category.body_discomfort", comment: "身體不適")
        default:
            return category
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
        viewModel.hasSelection || !freeNote().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

            if let reply = viewModel.reply,
               !reply.reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                replyBubble(reply: reply)
            }

            upsellRow
        }
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

// MARK: - FlowLayoutChips (preset 複選 chips；簡易折行排版)

private struct FlowLayoutChips: View {
    let items: [RizoPreset]
    let isSelected: (RizoPreset) -> Bool
    let onTap: (RizoPreset) -> Void

    var body: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(items) { item in
                chip(item)
            }
        }
    }

    private func chip(_ item: RizoPreset) -> some View {
        let selected = isSelected(item)
        let isDanger = item.dangerClass != "none"
        let tint: Color = isDanger ? PacerizColor.error : PacerizColor.blue
        return Button {
            onTap(item)
        } label: {
            Text(item.label)
                .font(AppFont.micro())
                .foregroundColor(selected ? .white : (isDanger ? tint : .primary))
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(selected ? tint : tint.opacity(isDanger ? 0.10 : 0.0))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        selected ? Color.clear : (isDanger ? tint.opacity(0.4) : Color(UIColor.separator).opacity(0.4)),
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FlowLayout (iOS 16+ Layout：chips 自動折行)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows = computeRows(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * lineSpacing
        let width = rows.map { $0.width }.max() ?? 0
        rows.removeAll()
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    private struct RowInfo { var width: CGFloat; var height: CGFloat }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [RowInfo] {
        var rows: [RowInfo] = []
        var x: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                rows.append(RowInfo(width: rowWidth - spacing, height: rowHeight))
                x = 0
                rowWidth = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        if rowWidth > 0 {
            rows.append(RowInfo(width: rowWidth - spacing, height: rowHeight))
        }
        return rows
    }
}


#if DEBUG
// MARK: - Preview Support

/// 預覽用 mock repository（純假資料，不連後端）。
private final class _PreviewRizoRepo: RizoRepository {
    let presets: [RizoPreset]
    let reply: RizoReply?
    init(presets: [RizoPreset], reply: RizoReply?) { self.presets = presets; self.reply = reply }
    func sendJournalChat(workoutId: String, message: String, presetSelections: [String], sessionId: String?) async throws -> RizoReply {
        if let reply { return reply }
        throw NSError(domain: "preview", code: 0)
    }
    func getPresets(scenario: String) async throws -> [RizoPreset] { presets }
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
    static let samplePresets: [RizoPreset] = [
        RizoPreset(id: "great", category: "overall_status", dangerClass: "none", label: "狀態很好"),
        RizoPreset(id: "normal", category: "overall_status", dangerClass: "none", label: "普通"),
        RizoPreset(id: "tired", category: "fatigue_recovery", dangerClass: "none", label: "很疲勞"),
        RizoPreset(id: "sore", category: "fatigue_recovery", dangerClass: "none", label: "肌肉痠痛"),
        RizoPreset(id: "slept_bad", category: "fatigue_recovery", dangerClass: "none", label: "睡不好"),
        RizoPreset(id: "pace_off", category: "pace_effort", dangerClass: "none", label: "配速比預期吃力"),
        RizoPreset(id: "easy", category: "pace_effort", dangerClass: "none", label: "輕鬆完成"),
        RizoPreset(id: "knee", category: "body_discomfort", dangerClass: "medical", label: "膝蓋不適"),
        RizoPreset(id: "chest", category: "body_discomfort", dangerClass: "medical", label: "胸悶")
    ]

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
            rizoRepository: _PreviewRizoRepo(presets: samplePresets, reply: sampleReply()),
            workoutRepository: _PreviewWorkoutRepo()
        )
        vm.loadPresets()
        if recorded {
            vm.selectedPresetIDs = ["tired", "pace_off"]
            vm.submit(note: "後段腿很沉")
        }
        return vm
    }
}

#Preview("選擇態") {
    ScrollView {
        RizoJournalSection(viewModel: RizoJournalPreviewFactory.makeViewModel(recorded: false), freeNote: { "" })
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
