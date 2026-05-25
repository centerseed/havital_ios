import SwiftUI

struct AchievementDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let badge: AchievementBadge
    let shareable: AchievementShareable?
    let onShare: (AchievementShareable) -> Void

    private var isUnlocked: Bool {
        badge.status == .unlocked
    }

    private var accent: Color {
        AchievementChapterTheme.primaryColor(for: badge.chapter)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroSection
                    storySection
                    if let progress = badge.progress, !isUnlocked {
                        progressSection(progress)
                    }
                    if let source = badge.sourceRef, isUnlocked {
                        sourceSection(source)
                    }
                    if badge.historicalBackfill {
                        historicalChip
                    }
                    actionButtons
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(L10n.Achievements.Detail.title.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.done.localized) { dismiss() }
                        .font(AppFont.label())
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            // Chapter chip
            HStack(spacing: 5) {
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)
                Text(badge.chapter.localizedName)
                    .font(AppFont.chip())
                    .foregroundColor(accent)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(accent.opacity(0.12))
            .clipShape(Capsule())

            // Large badge artwork
            AchievementBadgeImage(
                assetName: AchievementBadgeArtwork.assetName(for: badge),
                status: badge.status,
                size: 140
            )
            .shadow(
                color: isUnlocked ? accent.opacity(0.3) : Color.black.opacity(0.05),
                radius: isUnlocked ? 12 : 3,
                x: 0, y: isUnlocked ? 6 : 1
            )

            // Title
            Text(badge.nameKey.localizedOrFallback(default: L10n.Achievements.Badges.badge.localized))
                .font(AppFont.numberMedium())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            // Status + unlocked-at
            statusLine
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.12), accent.opacity(0.04), Color(UIColor.secondarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }

    private var statusLine: some View {
        Group {
            if let unlockedAtString = badge.unlockedAt,
               let unlockedDate = Self.parseISO(unlockedAtString) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(AppFont.micro())
                        .foregroundColor(accent)
                    Text(Self.formatUnlockedAt(unlockedDate))
                        .font(AppFont.micro())
                        .foregroundColor(.secondary)
                }
            } else {
                Text(badge.status.localizedName)
                    .font(AppFont.micro())
                    .foregroundColor(.secondary)
            }
        }
    }

    private static func parseISO(_ s: String) -> Date? {
        let formatters: [ISO8601DateFormatter] = [
            { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }(),
            { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f }(),
        ]
        for f in formatters {
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    // MARK: - Story

    private var storySection: some View {
        let storyText = badge.storyKey.localizedOrFallback(default: "")
        guard !storyText.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "text.alignleft")
                        .font(AppFont.micro())
                        .foregroundColor(accent)
                    Text(L10n.Achievements.Detail.story.localized)
                        .font(AppFont.chip())
                        .foregroundColor(.primary)
                }
                Text(storyText)
                    .font(AppFont.captionRegular())
                    .foregroundColor(.primary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                if let reasonKey = badge.unlockReasonKey {
                    let reasonText = reasonKey.localizedOrFallback(default: "")
                    if !reasonText.isEmpty {
                        Text(reasonText)
                            .font(AppFont.micro())
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(14)
        )
    }

    // MARK: - Progress

    private func progressSection(_ progress: AchievementProgress) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(AppFont.micro())
                    .foregroundColor(accent)
                Text(L10n.Achievements.Detail.progress.localized)
                    .font(AppFont.chip())
            }
            if let current = progress.current, let target = progress.target, target > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatNumber(current))
                        .font(AppFont.numberMedium().monospacedDigit())
                        .foregroundColor(accent)
                    Text("/ \(formatNumber(target))")
                        .font(AppFont.label())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(min(current / target, 1) * 100))%")
                        .font(AppFont.chip().monospacedDigit())
                        .foregroundColor(accent)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.tertiarySystemGroupedBackground))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(min(current / target, 1)))
                    }
                }
                .frame(height: 8)
            }
            if let summaryKey = progress.summaryKey {
                let summary = summaryKey.achievementLocalized(params: progress.summaryParams)
                if !summary.isEmpty && summary != summaryKey {
                    Text(summary)
                        .font(AppFont.captionRegular())
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }

    // MARK: - Source

    private func sourceSection(_ source: AchievementSourceRef) -> some View {
        let label = Self.localizeSourceLabel(source)
        let summary = source.summaryKey.flatMap { key -> String? in
            let v = key.achievementLocalized(params: source.summaryParams)
            return (v.isEmpty || v == key) ? nil : v
        }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(AppFont.micro())
                    .foregroundColor(.secondary)
                Text(L10n.Achievements.Detail.source.localized)
                    .font(AppFont.chip())
            }
            Text(label)
                .font(AppFont.label())
                .foregroundColor(.primary)
            if let summary {
                Text(summary)
                    .font(AppFont.captionRegular())
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }

    private var historicalChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(AppFont.chip())
                .foregroundColor(.secondary)
            Text(L10n.Achievements.Detail.historical.localized)
                .font(AppFont.micro())
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        HStack(spacing: 10) {
            if let shareable {
                Button {
                    onShare(shareable)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                        Text(L10n.Achievements.Share.action.localized)
                    }
                    .font(AppFont.chip())
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundColor(.white)
                    .background(accent)
                    .cornerRadius(12)
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Formatters

    private static func formatUnlockedAt(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let f = DateFormatter()
            f.locale = Locale.current
            f.dateFormat = "HH:mm"
            return String(format: NSLocalizedString("achievements.detail.unlocked_today", value: "今天 %@ 解鎖", comment: "Unlocked today"), f.string(from: date))
        }
        if calendar.isDateInYesterday(date) {
            return NSLocalizedString("achievements.detail.unlocked_yesterday", value: "昨天解鎖", comment: "Unlocked yesterday")
        }
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "yyyy/MM/dd"
        return String(format: NSLocalizedString("achievements.detail.unlocked_on", value: "%@ 解鎖", comment: "Unlocked on date"), f.string(from: date))
    }

    private func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    /// Localize source label with sensible fallback so raw i18n keys don't leak.
    private static func localizeSourceLabel(_ source: AchievementSourceRef) -> String {
        if let key = source.labelKey {
            let v = NSLocalizedString(key, comment: "")
            if v != key && !v.isEmpty { return v }
        }
        // Friendly fallback by source type
        switch source.type.lowercased() {
        case "weekly_summary", "weekly":
            return NSLocalizedString("achievements.source.fallback.weekly", value: "週摘要", comment: "Weekly summary source")
        case "workout":
            return NSLocalizedString("achievements.source.fallback.workout", value: "訓練紀錄", comment: "Workout source")
        case "plan", "plan_overview":
            return NSLocalizedString("achievements.source.fallback.plan", value: "訓練計畫", comment: "Plan source")
        case "pb", "personal_best":
            return NSLocalizedString("achievements.source.fallback.pb", value: "個人最佳", comment: "PB source")
        default:
            return source.type
        }
    }
}

private extension String {
    func localizedOrFallback(default fallback: String) -> String {
        let value = NSLocalizedString(self, comment: "")
        return value == self ? fallback : value
    }
}
