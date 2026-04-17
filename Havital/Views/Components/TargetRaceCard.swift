import SwiftUI

struct TargetRaceCard: View {
    let target: Target
    let onEditTap: () -> Void  // Add a callback function
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 16) {
                // Title and edit button
                HStack {
                    SectionHeader(title: NSLocalizedString("target_race_card.title", comment: "Target Race"), systemImage: "flag.filled.and.flag.crossed")

                    Spacer()

                    Button(action: {
                        onEditTap()
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                }

                // 賽事名稱
                Text(target.name)
                    .font(AppFont.title2())
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 🎯 英雄式倒數卡片（置中突出）
                VStack(spacing: 8) {
                    // Calculate days remaining
                    let daysRemaining = TrainingDateUtils.calculateDaysRemaining(raceDate: target.raceDate, timezone: target.timezone)

                    HStack(spacing: 8) {
                        Image(systemName: "target")
                            .font(AppFont.title2())
                            .foregroundColor(.blue)

                        Text(NSLocalizedString("target_race_card.days_remaining", comment: "還有"))
                            .font(AppFont.title3())
                            .foregroundColor(.primary)

                        Text("\(daysRemaining)")
                            .font(AppFont.systemScaled(size: 40, weight: .bold))
                            .foregroundColor(.blue)

                        Text(NSLocalizedString("target_race_card.days_unit", comment: "天"))
                            .font(AppFont.title3())
                            .foregroundColor(.primary)
                    }

                    // 賽事日期
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(AppFont.bodySmall())
                            .foregroundColor(.secondary)
                        Text(formatDate(target.raceDate))
                            .font(AppFont.bodySmall())
                            .foregroundColor(.secondary)
                    }

                    // 距離標籤
                    Text("\(target.distanceKm) \(NSLocalizedString("target_race_card.distance_unit", comment: "公里"))")
                        .font(AppFont.bodySmall())
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .cornerRadius(8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )

                // ╔═══╗ 目標時間和配速卡片（強調）
                HStack(spacing: 0) {
                    // 目標時間
                    VStack(spacing: 8) {
                        Text(formatTime(target.targetTime))
                            .font(AppFont.systemScaled(size: 28, weight: .bold))
                            .foregroundColor(.primary)

                        Text(NSLocalizedString("target_race_card.target_finish_time", comment: "目標時間"))
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(UIColor.systemGray5) : Color(UIColor.systemGray6).opacity(0.5))
                    )

                    Spacer()
                        .frame(width: 12)

                    // 目標配速
                    VStack(spacing: 8) {
                        Text(target.targetPace)
                            .font(AppFont.systemScaled(size: 28, weight: .bold))
                            .foregroundColor(.primary)

                        Text(NSLocalizedString("target_race_card.target_pace", comment: "目標配速"))
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(UIColor.systemGray5) : Color(UIColor.systemGray6).opacity(0.5))
                    )
                }
            }
        }
    }

    // Format date with timezone
    private func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale.current

        // 使用目標的時區
        if let timeZone = TimeZone(identifier: target.timezone) {
            formatter.timeZone = timeZone
        }

        return formatter.string(from: date)
    }
    
    // Format time
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
    

}
