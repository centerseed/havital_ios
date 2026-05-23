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
    /// 持久化鍵：每份課表（plan + 週）唯一。已回報過就不再顯示（跨重啟）。
    let persistKey: String

    private static let storageKey = "weekly_plan_feedback_submitted_keys"

    private static func hasSubmitted(_ key: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: storageKey) ?? []).contains(key)
    }

    private static func markSubmitted(_ key: String) {
        var keys = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        guard !keys.contains(key) else { return }
        keys.append(key)
        if keys.count > 200 { keys.removeFirst(keys.count - 200) }
        UserDefaults.standard.set(keys, forKey: storageKey)
    }

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
    @State private var showBadReasons = false
    @State private var isHidden = false

    var body: some View {
        Group {
            if !isHidden {
                VStack(alignment: .leading, spacing: 14) {
                    if didSubmit {
                        thanksView
                    } else {
                        Text(NSLocalizedString("weekly_plan_feedback.title", comment: ""))
                            .font(AppFont.bodyStrong())

                        ratingButtons

                        if submitError {
                            Text(NSLocalizedString("weekly_plan_feedback.error", comment: ""))
                                .font(AppFont.captionRegular())
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(14)
                .transition(.opacity)
                // 「不太好」→ 底部 sheet 選原因，避免在長頁面底部就地展開要捲動。
                .sheet(isPresented: $showBadReasons) {
                    badReasonsSheet
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: didSubmit)
        .animation(.easeOut(duration: 0.4), value: isHidden)
        .onAppear {
            // 這份課表已回報過 → 不再顯示（跨重啟持久化）。
            if Self.hasSubmitted(persistKey) { isHidden = true }
        }
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
            rating = value
            if value == .bad {
                showBadReasons = true   // 開 sheet 選原因
            } else {
                submit(type: .suggestion)   // good / fine 直接送出
            }
        } label: {
            VStack(spacing: 4) {
                Text(emoji).font(AppFont.titleL())
                Text(label).font(AppFont.micro())
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

    // MARK: - Bad reasons sheet

    private var badReasonsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("weekly_plan_feedback.reasons_prompt", comment: ""))
                        .font(AppFont.label())
                        .foregroundColor(.secondary)

                    FlowChips(reasons: BadReason.allCases, selected: selectedReasons) { reason in
                        if selectedReasons.contains(reason) {
                            selectedReasons.remove(reason)
                        } else {
                            selectedReasons.insert(reason)
                        }
                    }

                    if submitError {
                        Text(NSLocalizedString("weekly_plan_feedback.error", comment: ""))
                            .font(AppFont.captionRegular())
                            .foregroundColor(.red)
                    }

                    submitButton
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(NSLocalizedString("weekly_plan_feedback.rating.bad", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.close", comment: "")) {
                        showBadReasons = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
                    .font(AppFont.chip())
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
                .font(AppFont.label())
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
                Self.markSubmitted(persistKey)
                await MainActor.run {
                    isSubmitting = false
                    showBadReasons = false   // 關閉原因 sheet（若有）
                    didSubmit = true         // bar 顯示感謝
                }
                // 感謝訊息顯示 3 秒後自動淡出整個 bar，不長留。
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run { isHidden = true }
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
                        .font(AppFont.micro())
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
