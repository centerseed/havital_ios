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
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            ForEach(sortedDistances(data: data), id: \.self) { distance in
                if let records = data[distance.rawValue],
                   let bestRecord = records.first {
                    personalBestItemCard(distance: distance, record: bestRecord)
                        .onTapGesture {
                            selectedItem = PersonalBestDetailItem(distance: distance, records: records)
                        }
                }
            }
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
                .font(.system(size: 20, weight: .bold))
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

    /// 排序距離（按優先級降序）
    private func sortedDistances(data: [String: [PersonalBestRecordV2]]) -> [RaceDistanceV2] {
        RaceDistanceV2.allCases
            .filter { data[$0.rawValue] != nil }
            .sorted { $0.priority > $1.priority }
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
        NavigationView {
            List {
                // 紀錄列表
                Section(header: Text(L10n.MyAchievement.PersonalBest.topRecords.localized)) {
                    ForEach(Array(records.prefix(3).enumerated()), id: \.element.workoutId) { index, record in
                        HStack {
                            Text(rankEmoji(rank: index + 1))
                                .font(AppFont.title3())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.formattedTime())
                                    .font(AppFont.headline())

                                HStack(spacing: 12) {
                                    Text(UnitManager.shared.formatPaceString(record.pace))
                                        .font(AppFont.caption())
                                        .foregroundColor(.secondary)

                                    Text(formatWorkoutDate(record.workoutDate))
                                        .font(AppFont.caption())
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(distance.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.done.localized) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
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
        return DateFormatterHelper.formatShortDate(date)
    }
}
