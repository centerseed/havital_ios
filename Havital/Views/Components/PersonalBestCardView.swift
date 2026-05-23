import SwiftUI

struct PersonalBestCardView: View {
    let personalBestData: [String: [PersonalBestRecordV2]]?
    @State private var selectedItem: PersonalBestDetailItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 標題
            SectionTitleWithInfo(
                title: L10n.MyAchievement.PersonalBest.title.localized,
                explanation: L10n.MyAchievement.PersonalBest.explanation.localized
            )
            .padding(.horizontal)
            .padding(.top, 12)

            // 內容
            if let data = personalBestData, !data.isEmpty {
                personalBestGrid(data: data)
            } else {
                emptyStateView
            }
        }
        .cardStyle()
        .padding(.horizontal)
        .sheet(item: $selectedItem) { item in
            PersonalBestDetailView(distance: item.distance, records: item.records)
        }
    }

    // MARK: - Personal Best Grid

    private func personalBestGrid(data: [String: [PersonalBestRecordV2]]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(sortedDistances(data: data), id: \.self) { distance in
                    if let records = data[distance.rawValue],
                       let bestRecord = records.first {
                        personalBestItemCard(distance: distance, record: bestRecord)
                            .frame(width: 128)
                            .onTapGesture {
                                selectedItem = PersonalBestDetailItem(distance: distance, records: records)
                            }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .padding()
    }

    // MARK: - Personal Best Item Card (簡化版：只顯示距離和時間)

    private func personalBestItemCard(
        distance: RaceDistanceV2,
        record: PersonalBestRecordV2
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(distance.shortName)
                .font(AppFont.captionSmall())
                .foregroundColor(.secondary)

            Text(record.formattedTime())
                .font(AppFont.systemScaled(size: 20, weight: .bold))
                .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 60)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(AppFont.dataMedium())
                .foregroundColor(.secondary)

            Text(L10n.MyAchievement.PersonalBest.noData.localized)
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Helper Methods

    /// 排序距離（公里數由大到小）
    private func sortedDistances(data: [String: [PersonalBestRecordV2]]) -> [RaceDistanceV2] {
        RaceDistanceV2.allCases
            .filter { data[$0.rawValue] != nil }
            .sorted { lhs, rhs in
                (Double(lhs.rawValue) ?? 0) > (Double(rhs.rawValue) ?? 0)
            }
    }
}

// MARK: - Sheet Item Model

struct PersonalBestDetailItem: Identifiable {
    let id = UUID()
    let distance: RaceDistanceV2
    let records: [PersonalBestRecordV2]
}

// MARK: - Personal Best Detail View (Dialog)

struct PersonalBestDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let distance: RaceDistanceV2
    let records: [PersonalBestRecordV2]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.MyAchievement.PersonalBest.topRecords.localized)
                        .font(AppFont.micro())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, 4)

                    ForEach(Array(records.prefix(3).enumerated()), id: \.element.workoutId) { index, record in
                        recordCard(rank: index + 1, record: record)
                    }
                }
                .padding(16)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(distance.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.done.localized) {
                        dismiss()
                    }
                    .font(AppFont.label())
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Record Card

    private func recordCard(rank: Int, record: PersonalBestRecordV2) -> some View {
        let isBest = rank == 1

        return HStack(spacing: 14) {
            // Rank medal
            ZStack {
                Circle()
                    .fill(rankColor(rank).opacity(0.16))
                    .frame(width: 46, height: 46)
                Text(rankEmoji(rank: rank))
                    .font(AppFont.titleL())
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(record.formattedTime())
                        .font(AppFont.numberMedium().monospacedDigit())
                        .foregroundColor(isBest ? PacerizColor.blueDeep : .primary)
                    if isBest {
                        Text("最佳")
                            .font(AppFont.chip())
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(PacerizColor.blue)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 10) {
                    Label {
                        Text(UnitManager.shared.formatPaceString(record.pace))
                            .font(AppFont.micro().monospacedDigit())
                    } icon: {
                        Image(systemName: "speedometer")
                            .font(AppFont.micro())
                    }
                    .foregroundColor(.secondary)

                    Text("·")
                        .foregroundColor(Color(UIColor.tertiaryLabel))

                    Label {
                        Text(formatWorkoutDate(record.workoutDate))
                            .font(AppFont.micro().monospacedDigit())
                    } icon: {
                        Image(systemName: "calendar")
                            .font(AppFont.micro())
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isBest ? PacerizColor.blue.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 0.93, green: 0.70, blue: 0.18)   // gold
        case 2: return Color(red: 0.62, green: 0.65, blue: 0.69)   // silver
        case 3: return Color(red: 0.78, green: 0.51, blue: 0.30)   // bronze
        default: return .secondary
        }
    }

    private func rankEmoji(rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)"
        }
    }

    private func formatWorkoutDate(_ dateString: String) -> String {
        guard let date = DateFormatterHelper.parseDate(from: dateString, format: "yyyy-MM-dd") else {
            return dateString
        }
        return DateFormatterHelper.formatter(dateFormat: "yyyy/MM/dd").string(from: date)
    }
}
