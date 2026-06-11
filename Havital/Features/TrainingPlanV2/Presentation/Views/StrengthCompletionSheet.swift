import SwiftUI

struct StrengthCompletionSheet: View {
    @StateObject var viewModel: StrengthCompletionViewModel
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .feedback(let fb):
                    feedbackView(fb)
                default:
                    formView
                }
            }
            .navigationTitle(NSLocalizedString("strength.completion.title", comment: "完成回報"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.close", comment: "關閉")) { onClose() }
                }
            }
        }
    }

    // MARK: - Form View

    private var formView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(strengthTypeName(viewModel.activity.strengthType))
                        .font(AppFont.bodyStrong())
                    Text(NSLocalizedString("strength.completion.instructions", comment: "逐項標記完成或略過，再評估整體感受"))
                        .font(AppFont.micro())
                        .foregroundColor(.secondary)

                    ForEach(Array(viewModel.activity.exercises.enumerated()), id: \.offset) { (i, ex) in
                        exerciseRow(ex, key: StrengthCompletionViewModel.exKey(ex, i))
                        if i < viewModel.activity.exercises.count - 1 {
                            Divider()
                        }
                    }

                    RPESelectorView(selectedRPE: $viewModel.selectedRPE)
                        .padding(.top, 4)
                }
                .padding(16)
            }
            submitBar
        }
    }

    private func exerciseRow(_ ex: Exercise, key: String) -> some View {
        let skipped = viewModel.status(for: key) == .skipped
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name)
                    .font(AppFont.bodyRegular())
                    .strikethrough(skipped)
                    .foregroundColor(skipped ? .secondary : .primary)
                let line = planLine(ex)
                if !line.isEmpty {
                    Text(line)
                        .font(AppFont.micro())
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button {
                viewModel.toggleSkip(exerciseId: key)
            } label: {
                Text(skipped
                     ? NSLocalizedString("strength.completion.skipped", comment: "略過")
                     : NSLocalizedString("strength.completion.completed", comment: "已完成"))
                    .font(AppFont.micro())
                    .fontWeight(.semibold)
                    .foregroundColor(skipped ? .secondary : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(skipped ? Color(UIColor.tertiarySystemFill) : RecapPalette.rpe(3))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    private func planLine(_ ex: Exercise) -> String {
        var parts: [String] = []
        if let s = ex.sets { parts.append("\(s) \(NSLocalizedString("training.sets_unit", comment: ""))") }
        if let d = ex.durationSeconds {
            parts.append("\(d) \(NSLocalizedString("training.seconds_unit", comment: ""))")
        } else if let r = ex.reps {
            parts.append("\(r) \(NSLocalizedString("training.reps_unit", comment: ""))")
        }
        return parts.joined(separator: " × ")
    }

    // MARK: - Submit Bar

    private var submitBar: some View {
        Button {
            Task { await viewModel.submit() }
        } label: {
            HStack {
                if case .submitting = viewModel.phase {
                    ProgressView().tint(.white)
                }
                Text(NSLocalizedString("strength.completion.submit", comment: "完成訓練"))
                    .font(AppFont.bodyStrong())
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundColor(.white)
            .background(viewModel.canSubmit ? PacerizColor.blue : Color.gray.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(!viewModel.canSubmit)
        .padding(16)
    }

    // MARK: - Feedback View

    private func feedbackView(_ fb: StrengthCompletionViewModel.Feedback) -> some View {
        VStack(spacing: 16) {
            Spacer()
            if let up = fb.upgrades.first(where: { $0.reason == .upgrade }) {
                Text(NSLocalizedString("strength.completion.upgrade_title", comment: "做得輕鬆漂亮 💪"))
                    .font(AppFont.titleM())
                Text(String(format: NSLocalizedString("strength.completion.upgrade_detail", comment: "%@ 升級 L%d→L%d"),
                            seriesName(up.seriesId), up.previousLevel, up.newLevel))
                    .font(AppFont.bodyRegular())
                    .multilineTextAlignment(.center)
                Text(NSLocalizedString("strength.completion.upgrade_next", comment: "下次課表會幫你進階"))
                    .font(AppFont.micro())
                    .foregroundColor(.secondary)
            } else if let down = fb.upgrades.first(where: { $0.reason == .downgrade }) {
                Text(NSLocalizedString("strength.completion.downgrade_title", comment: "這次偏吃力"))
                    .font(AppFont.titleM())
                Text(String(format: NSLocalizedString("strength.completion.downgrade_detail", comment: "%@ 調整為 L%d，下次回到適合的強度"),
                            seriesName(down.seriesId), down.newLevel))
                    .font(AppFont.bodyRegular())
                    .multilineTextAlignment(.center)
            } else {
                Text("✓")
                    .font(.system(size: 44))
                    .foregroundColor(RecapPalette.rpe(3))
                Text(String(format: NSLocalizedString("strength.completion.done_rpe", comment: "已完成 · RPE %d"), fb.rpe))
                    .font(AppFont.bodyRegular())
            }
            Spacer()
            Button(NSLocalizedString("common.done", comment: "完成")) { onClose() }
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundColor(.white)
                .background(PacerizColor.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(16)
        }
        .padding()
    }

    // MARK: - Helpers

    private func strengthTypeName(_ t: String) -> String {
        NSLocalizedString("training.strength_type.\(t)", comment: "")
    }

    private func seriesName(_ seriesId: String) -> String {
        let key = "strength.series.\(seriesId)"
        let v = NSLocalizedString(key, comment: "")
        return v == key ? NSLocalizedString("strength.series.generic", comment: "力量動作") : v
    }
}
