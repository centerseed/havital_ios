//
//  RaceDistanceSelectionSheet.swift
//  Havital
//
//  多距離賽事的距離選擇 Sheet
//  當用戶點選具有多個距離的賽事時彈出，點選即選中並自動 dismiss
//

import SwiftUI

/// 賽事距離選擇 Sheet
///
/// 當賽事有多個可選距離時，以 Sheet 方式彈出讓使用者選擇。
/// 選擇後自動 dismiss，不跳轉至新頁面（符合 AC6）。
struct RaceDistanceSelectionSheet: View {

    @Environment(\.dismiss) private var dismiss

    let race: RaceEvent
    let onDistanceSelected: (RaceDistance) -> Void

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                // 賽事名稱副標題
                Text(race.name)
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                Divider()

                // 距離選項列表
                VStack(spacing: 0) {
                    ForEach(race.distances.sorted(by: { $0.distanceKm < $1.distanceKm })) { distance in
                        Button(action: {
                            onDistanceSelected(distance)
                            dismiss()
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: "circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(.accentColor)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(distance.name)
                                        .font(AppFont.headline())
                                        .foregroundColor(.primary)

                                    Text(String(format: "%.3g km", distance.distanceKm))
                                        .font(AppFont.caption())
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.plain)

                        if distance.id != race.distances.sorted(by: { $0.distanceKm < $1.distanceKm }).last?.id {
                            Divider()
                                .padding(.leading, 24)
                        }
                    }
                }

                Spacer()
            }
            .navigationTitle(NSLocalizedString("onboarding.select_race_distance_title", comment: "選擇比賽距離"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.cancel", comment: "取消")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents(race.distances.count <= 3 ? [.height(280)] : [.medium])
    }
}

// MARK: - Preview

#Preview {
    let sampleRace = RaceEvent(
        raceId: "tw_2026_台北馬拉松",
        name: "台北馬拉松",
        region: "tw",
        eventDate: Date().addingTimeInterval(60 * 60 * 24 * 90),
        city: "台北市",
        location: "市政府廣場",
        distances: [
            RaceDistance(distanceKm: 42.195, name: "全程馬拉松"),
            RaceDistance(distanceKm: 21.0975, name: "半程馬拉松")
        ],
        entryStatus: "open",
        isCurated: true,
        courseType: "road",
        tags: ["AIMS認證"]
    )

    RaceDistanceSelectionSheet(race: sampleRace) { _ in }
}
