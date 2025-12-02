import SwiftUI

/// 訓練類型選擇 Menu
struct TrainingTypeMenu: View {
    @Binding var selectedType: String
    let onChanged: () -> Void

    var body: some View {
        Menu {
            Section("輕鬆訓練") {
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

            Section("強度訓練") {
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

            Section("其他") {
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
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption2)
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

    private let easyTypes: [DayType] = [.easyRun, .easy, .recovery_run, .lsd]
    private let intensityTypes: [DayType] = [.tempo, .threshold, .interval, .progression, .combination, .longRun]
    private let otherTypes: [DayType] = [.rest, .crossTraining, .strength, .yoga, .hiking, .cycling]
}
