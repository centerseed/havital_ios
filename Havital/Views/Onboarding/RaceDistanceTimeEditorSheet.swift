//
//  RaceDistanceTimeEditorSheet.swift
//  Havital
//
//  距離與目標完賽時間編輯器（Sheet 模式）
//  用於 Onboarding 流程中的賽事設定
//

import SwiftUI

struct RaceDistanceTimeEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    // 綁定的屬性
    @Binding var selectedDistance: String
    @Binding var targetHours: Int
    @Binding var targetMinutes: Int

    // 可用距離選項
    let availableDistances: [String: String]

    // 計算當前配速
    private var currentPace: String {
        let totalSeconds = (targetHours * 3600 + targetMinutes * 60)
        let distanceKm = Double(selectedDistance) ?? 42.195

        guard totalSeconds > 0, distanceKm > 0 else {
            return "0:00"
        }

        let paceSeconds = Int(Double(totalSeconds) / distanceKm)
        let paceMinutes = paceSeconds / 60
        let paceRemainingSeconds = paceSeconds % 60
        return String(format: "%d:%02d", paceMinutes, paceRemainingSeconds)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 主要內容區域
                Form {
                    // 距離選擇
                    Section(header: Text(NSLocalizedString("onboarding.race_distance", comment: "Race Distance"))) {
                        Picker(NSLocalizedString("onboarding.select_distance", comment: "Select Distance"),
                               selection: $selectedDistance) {
                            ForEach(Array(availableDistances.keys.sorted()), id: \.self) { key in
                                Text(availableDistances[key] ?? key)
                                    .tag(key)
                            }
                        }
                        .pickerStyle(.inline)
                        .accessibilityIdentifier("RaceSetup_DistancePicker")
                    }

                    // 目標完賽時間
                    Section(
                        header: Text(NSLocalizedString("onboarding.target_finish_time", comment: "Target Finish Time")),
                        footer: Text(String(format: NSLocalizedString("onboarding.average_pace", comment: "Average pace: %@"), currentPace))
                            .foregroundColor(.secondary)
                    ) {
                        HStack(spacing: 20) {
                            // 小時選擇器
                            VStack {
                                Text(NSLocalizedString("onboarding.hours", comment: "hours"))
                                    .font(AppFont.caption())
                                    .foregroundColor(.secondary)

                                Picker("", selection: $targetHours) {
                                    ForEach(0...6, id: \.self) { hour in
                                        Text("\(hour)").tag(hour)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80)
                            }

                            // 分鐘選擇器
                            VStack {
                                Text(NSLocalizedString("onboarding.minutes", comment: "minutes"))
                                    .font(AppFont.caption())
                                    .foregroundColor(.secondary)

                                Picker("", selection: $targetMinutes) {
                                    ForEach(0..<60, id: \.self) { minute in
                                        Text("\(minute)").tag(minute)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }

                    // 常見完賽時間參考
                    Section(header: Text(NSLocalizedString("onboarding.common_times_reference", comment: "參考時間"))) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let distance = Double(selectedDistance) {
                                ForEach(getCommonTimes(for: distance), id: \.self) { timeInfo in
                                    HStack {
                                        Text(timeInfo)
                                            .font(AppFont.caption())
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("onboarding.edit_distance_time", comment: "編輯距離與時間"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("common.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.done", comment: "Done")) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("RaceSetup_DoneButton")
                }
            }
        }
    }

    // MARK: - Helper Methods

    /// 根據距離提供常見完賽時間參考
    private func getCommonTimes(for distance: Double) -> [String] {
        switch distance {
        case 5:
            return [
                "15-20 分鐘 (精英跑者)",
                "20-30 分鐘 (進階跑者)",
                "30-40 分鐘 (休閒跑者)"
            ]
        case 10:
            return [
                "30-40 分鐘 (精英跑者)",
                "45-60 分鐘 (進階跑者)",
                "60-75 分鐘 (休閒跑者)"
            ]
        case 21.0975:
            return [
                "1:05-1:30 (精英跑者)",
                "1:30-2:00 (進階跑者)",
                "2:00-2:30 (休閒跑者)"
            ]
        case 42.195:
            return [
                "2:30-3:30 (精英跑者)",
                "3:30-4:30 (進階跑者)",
                "4:30-6:00 (休閒跑者)"
            ]
        default:
            return []
        }
    }
}

// MARK: - Preview
struct RaceDistanceTimeEditorSheet_Previews: PreviewProvider {
    static var previews: some View {
        RaceDistanceTimeEditorSheet(
            selectedDistance: .constant("42.195"),
            targetHours: .constant(4),
            targetMinutes: .constant(0),
            availableDistances: [
                "5": "5K",
                "10": "10K",
                "21.0975": "半程馬拉松",
                "42.195": "全程馬拉松"
            ]
        )
    }
}
