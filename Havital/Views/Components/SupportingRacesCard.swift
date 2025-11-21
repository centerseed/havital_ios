import SwiftUI

struct SupportingRacesCard: View {
    let supportingTargets: [Target]
    let onAddTap: () -> Void
    let onEditTap: (Target) -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 16) {
                // 標題與添加按鈕
                HStack {
                    SectionHeader(title: L10n.SupportingRacesCard.title.localized, systemImage: "flag.2.crossed")
                    
                    Spacer()
                    
                    Button(action: {
                        onAddTap()
                    }) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                    }
                }
                
                if supportingTargets.isEmpty {
                    HStack {
                        Spacer()
                        Text(L10n.SupportingRacesCard.noRaces.localized)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                        Spacer()
                    }
                } else {
                    // 分組：未來賽事與過去賽事
                    let nowTS = Int(Date().timeIntervalSince1970)
                    let upcoming = supportingTargets.filter { $0.raceDate >= nowTS }
                    let past = supportingTargets.filter { $0.raceDate < nowTS }
                    // 未來賽事
                    if !upcoming.isEmpty {
                        ForEach(upcoming, id: \.id) { target in
                            SupportingRaceRow(target: target) {
                                onEditTap(target)
                            }
                        }
                    }
                    // 分隔標題：之前的賽事
                    if !past.isEmpty {
                        Divider()
                        Text(L10n.SupportingRacesCard.pastRaces.localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                        ForEach(past, id: \.id) { target in
                            SupportingRaceRow(target: target) {
                                onEditTap(target)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct SupportingRaceRow: View {
    let target: Target
    let onEditTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            onEditTap()
        }) {
            VStack(alignment: .leading, spacing: 6) {
                // 第一行：賽事名稱 + 編輯按鈕
                HStack {
                    Text(target.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                // 第二行：日期、距離、配速（使用自適應排列）
                HStack(spacing: 8) {
                    // 賽事日期
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatDate(target.raceDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 距離
                    HStack(spacing: 4) {
                        Text("\(target.distanceKm)" + L10n.SupportingRacesCard.kmUnit.localized)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(4)
                    }

                    // 配速
                    HStack(spacing: 4) {
                        Text(target.targetPace + L10n.SupportingRacesCard.paceUnit.localized)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }

                // 倒數天數（30天內顯示）
                let nowTS = Int(Date().timeIntervalSince1970)
                if target.raceDate >= nowTS {
                    let daysRemaining = TrainingDateUtils.calculateDaysRemaining(raceDate: target.raceDate)
                    if daysRemaining <= 30 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                                .foregroundColor(daysRemaining <= 7 ? .red : .orange)
                            Text(L10n.SupportingRacesCard.daysRemaining.localized(with: daysRemaining))
                                .font(.caption)
                                .foregroundColor(daysRemaining <= 7 ? .red : .orange)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // 格式化日期
    private func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        // ✅ 使用統一的日期格式化工具，確保使用用戶設定的時區
        return DateFormatterHelper.formatShortDate(date)
    }


}
