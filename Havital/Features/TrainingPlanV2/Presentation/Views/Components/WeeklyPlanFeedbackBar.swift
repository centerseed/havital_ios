import SwiftUI

// MARK: - WeeklyPlanFeedbackBar
//
// 課表底部的快速回報條：不太好 / 還可以 / 很好。
// 選「不太好」會展開常見問題（跑量、強度…）讓用戶直接勾選。
// 送出 → FeedbackService（category: weekly_plan；good/fine = suggestion、bad = issue）。

struct WeeklyPlanFeedbackBar: View {
    let userEmail: String
    /// 描述附帶的情境（例如 "Week 3"），方便後台定位。
    let weekContext: String

    private enum Rating {
        case bad, fine, good
    }

    fileprivate enum BadReason: String, CaseIterable, Identifiable {
        case mileageTooHigh, mileageTooLow, intensityTooHigh, intensityTooLow, tooTiring, tooEasy, monotonous
        var id: String { rawValue }
        var label: String {
            switch self {
            case .mileageTooHigh: return NSLocalizedString("weekly_plan_feedback.reason.mileage_too_high", comment: "")
            case .mileageTooLow: return NSLocalizedString("weekly_plan_feedback.reason.mileage_too_low", comment: "")
            case .intensityTooHigh: return NSLocalizedString("weekly_plan_feedback.reason.intensity_too_high", comment: "")
            case .intensityTooLow: return NSLocalizedString("weekly_plan_feedback.reason.intensity_too_low", comment: "")
            case .tooTiring: return NSLocalizedString("weekly_plan_feedback.reason.too_tiring", comment: "")
            case .tooEasy: return NSLocalizedString("weekly_plan_feedback.reason.too_easy", comment: "")
            case .monotonous: return NSLocalizedString("weekly_plan_feedback.reason.monotonous", comment: "")
            }
        }
    }

    @State private var rating: Rating?
    @State private var selectedReasons: Set<BadReason> = []
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var submitError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if didSubmit {
                thanksView
            } else {
                Text(NSLocalizedString("weekly_plan_feedback.title", comment: ""))
                    .font(.system(size: 15, weight: .bold))

                ratingButtons

                if rating == .bad {
                    reasonChips
                    submitButton
                }

                if submitError {
                    Text(NSLocalizedString("weekly_plan_feedback.error", comment: ""))
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .animation(.easeInOut(duration: 0.2), value: rating)
        .animation(.easeInOut(duration: 0.2), value: didSubmit)
    }

    // MARK: - Sub-views

    private var ratingButtons: some View {
        HStack(spacing: 10) {
            ratingButton(.bad, emoji: "😕", label: NSLocalizedString("weekly_plan_feedback.rating.bad", comment: ""))
            ratingButton(.fine, emoji: "🙂", label: NSLocalizedString("weekly_plan_feedback.rating.fine", comment: ""))
            ratingButton(.good, emoji: "😀", label: NSLocalizedString("weekly_plan_feedback.rating.good", comment: ""))
        }
    }

    private func ratingButton(_ value: Rating, emoji: String, label: String) -> some View {
        let isSelected = rating == value
        return Button {
            if value == .bad {
                rating = .bad   // 展開原因，等使用者送出
            } else {
                rating = value
                submit(type: .suggestion)   // good / fine 直接送出
            }
        } label: {
            VStack(spacing: 4) {
                Text(emoji).font(.system(size: 24))
                Text(label).font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? PacerizColor.blue.opacity(0.14) : Color(UIColor.tertiarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? PacerizColor.blue : Color.clear, lineWidth: 1.5)
            )
            .foregroundColor(isSelected ? PacerizColor.blueDeep : .primary)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
    }

    private var reasonChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("weekly_plan_feedback.reasons_prompt", comment: ""))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            FlowChips(reasons: BadReason.allCases, selected: selectedReasons) { reason in
                if selectedReasons.contains(reason) {
                    selectedReasons.remove(reason)
                } else {
                    selectedReasons.insert(reason)
                }
            }
        }
    }

    private var submitButton: some View {
        Button {
            submit(type: .issue)
        } label: {
            HStack {
                if isSubmitting { ProgressView().tint(.white) }
                Text(isSubmitting
                     ? NSLocalizedString("weekly_plan_feedback.submitting", comment: "")
                     : NSLocalizedString("weekly_plan_feedback.submit", comment: ""))
                    .font(.system(size: 14, weight: .heavy))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(PacerizColor.blue)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
    }

    private var thanksView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(PacerizColor.green)
            Text(NSLocalizedString("weekly_plan_feedback.thanks", comment: ""))
                .font(.system(size: 14, weight: .semibold))
            Spacer()
        }
    }

    // MARK: - Submit

    private func submit(type: FeedbackType) {
        guard !isSubmitting else { return }
        isSubmitting = true
        submitError = false

        let description = buildDescription()
        Task {
            do {
                _ = try await FeedbackService.shared.submitFeedback(
                    type: type,
                    category: .weeklyPlan,
                    description: description,
                    email: userEmail,
                    images: nil
                )
                await MainActor.run {
                    isSubmitting = false
                    didSubmit = true
                }
            } catch {
                Logger.error("[WeeklyPlanFeedback] submit failed: \(error.localizedDescription)")
                await MainActor.run {
                    isSubmitting = false
                    submitError = true
                }
            }
        }
    }

    private func buildDescription() -> String {
        let ratingText: String
        switch rating {
        case .good: ratingText = NSLocalizedString("weekly_plan_feedback.rating.good", comment: "")
        case .fine: ratingText = NSLocalizedString("weekly_plan_feedback.rating.fine", comment: "")
        case .bad: ratingText = NSLocalizedString("weekly_plan_feedback.rating.bad", comment: "")
        case .none: ratingText = "-"
        }
        let ratingLabel = NSLocalizedString("weekly_plan_feedback.desc.rating_prefix", comment: "")
        var parts = ["\(ratingLabel)\(ratingText)", "(\(weekContext))"]
        if !selectedReasons.isEmpty {
            let reasons = BadReason.allCases
                .filter { selectedReasons.contains($0) }
                .map(\.label)
                .joined(separator: "、")
            let issueLabel = NSLocalizedString("weekly_plan_feedback.desc.issue_prefix", comment: "")
            parts.append("\(issueLabel)\(reasons)")
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Flow-layout chips

private struct FlowChips: View {
    let reasons: [WeeklyPlanFeedbackBar.BadReason]
    let selected: Set<WeeklyPlanFeedbackBar.BadReason>
    let onTap: (WeeklyPlanFeedbackBar.BadReason) -> Void

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(reasons) { reason in
                let isOn = selected.contains(reason)
                Button {
                    onTap(reason)
                } label: {
                    Text(reason.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isOn ? .white : .primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(isOn ? PacerizColor.blue : Color(UIColor.tertiarySystemGroupedBackground))
                        .cornerRadius(18)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
