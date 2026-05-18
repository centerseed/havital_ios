import SwiftUI

/// 訓練類型選擇 Menu
struct TrainingTypeMenu: View {
    @Binding var selectedType: String
    let onChanged: () -> Void

    var body: some View {
        Menu {
            Section(L10n.EditSchedule.easyTrainingSection.localized) {
                ForEach(easyTypes, id: \.rawValue) { type in
                    Button {
                        selectedType = type.rawValue
                        onChanged()
                    } label: {
                        Label {
                            Text(type.localizedName)
                        } icon: {
                            if type.rawValue == selectedType {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Section(L10n.EditSchedule.intensityTrainingSection.localized) {
                ForEach(intensityTypes, id: \.rawValue) { type in
                    Button {
                        selectedType = type.rawValue
                        onChanged()
                    } label: {
                        Label {
                            Text(type.localizedName)
                        } icon: {
                            if type.rawValue == selectedType {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Section(L10n.EditSchedule.longDistanceTrainingSection.localized) {
                ForEach(longDistanceTypes, id: \.rawValue) { type in
                    Button {
                        selectedType = type.rawValue
                        onChanged()
                    } label: {
                        Label {
                            Text(type.localizedName)
                        } icon: {
                            if type.rawValue == selectedType {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Section(L10n.EditSchedule.otherTrainingSection.localized) {
                ForEach(otherTypes, id: \.rawValue) { type in
                    Button {
                        selectedType = type.rawValue
                        onChanged()
                    } label: {
                        Label {
                            Text(type.localizedName)
                        } icon: {
                            if type.rawValue == selectedType {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(currentType.localizedName)
                    .font(AppFont.bodySmall())
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(AppFont.captionSmall())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(currentType.backgroundColor)
            .foregroundColor(currentType.labelColor)
            .cornerRadius(8)
        }
        .contentShape(Rectangle())  // 確保整個區域可點擊
    }

    private var currentType: DayType {
        DayType(rawValue: selectedType) ?? .rest
    }

    private let easyTypes: [DayType] = [.easyRun, .easy, .recovery_run]
    private let intensityTypes: [DayType] = [
        .tempo, .threshold, .interval,
        // 新增間歇訓練類型
        .strides, .hillRepeats, .cruiseIntervals, .shortInterval, .longInterval, .norwegian4x4, .yasso800,
        // 新增組合訓練類型（法特雷克）
        .fartlek,
        // 新增比賽配速訓練
        .racePace, .combination
    ]
    private let longDistanceTypes: [DayType] = [
        .lsd, .longRun, .progression, .fastFinish
    ]
    private let otherTypes: [DayType] = [.strength, .rest]
}
