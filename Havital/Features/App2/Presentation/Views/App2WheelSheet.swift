import SwiftUI

// MARK: - App2WheelSheet
/// 2.0 的輪盤 sheet（設計 **frame-09**）。
///
/// **為什麼不沿用 1.4 的 `PaceWheelPicker`／`DistanceWheelPicker`**：那兩支是
/// `NavigationView` ＋ 系統 `Picker(.wheel)`，整片系統灰底與導覽列，跟 2.0 的
/// 白 sheet／藍高亮帶／放大選中項完全是兩種語彙。1.4 那兩支**不刪**——1.0 殼還在用。
///
/// 值的形狀與寫回路徑沒有變：配速仍是 `m:ss` 字串、距離仍是公里 `Double`，
/// 由呼叫端寫進 `MutableTrainingDay`，最後仍走 `EditScheduleV2ViewModel.saveEdits()`。

// MARK: - 單欄輪盤
/// 中央高亮帶固定不動，內容捲動並吸附（`.viewAligned`）。
/// 選中項放大到 **2.05 倍**——設計明說這個倍率是刻意的。
struct App2WheelColumn: View {
    let options: [Double]
    @Binding var selection: Double?
    let label: (Double) -> String
    var width: CGFloat = 70
    var itemHeight: CGFloat = 46
    var visibleHeight: CGFloat = 230
    var identifier: String?

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection.map { abs($0 - option) < 0.0001 } ?? false
                    Text(label(option))
                        .font(.app2Mono(26, weight: .black))
                        .foregroundStyle(
                            isSelected
                                ? App2Theme.inkPrimary
                                : Color(hex: "#94A0AD").opacity(0.5)
                        )
                        .scaleEffect(isSelected ? 2.05 : 1)
                        .frame(width: width, height: itemHeight)
                        .id(option)
                }
            }
            .scrollTargetLayout()
        }
        .frame(width: width, height: visibleHeight)
        .contentMargins(.vertical, (visibleHeight - itemHeight) / 2, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $selection, anchor: .center)
        .scrollIndicators(.hidden)
        .animation(.easeOut(duration: 0.15), value: selection)
        .accessibilityIdentifier(identifier ?? "")
    }
}

// MARK: - Sheet 外殼
/// 抓握條 → 三欄標題列（取消／標題／完成）→ 配速表建議條（可省）→ 輪盤本體。
struct App2WheelSheetChrome<Content: View>: View {
    let title: String
    /// `配速表建議 I 強度 4:18–4:25／km`。**算不出區間就整列不出現**，不編一個。
    var suggestion: String?
    let onCancel: () -> Void
    let onDone: () -> Void
    var identifierPrefix: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(App2Theme.shadowInk.opacity(0.14))
                .frame(width: 38, height: 5)
                .padding(.top, 9)

            HStack {
                Text(L10n.EditSchedule.cancel.localized)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(App2Theme.inkSubtle)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onCancel)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("\(identifierPrefix)Cancel")

                Spacer(minLength: 6)

                Text(title)
                    .font(.system(size: 17, weight: .black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(App2Theme.inkPrimary)
                    .accessibilityIdentifier("\(identifierPrefix)Title")

                Spacer(minLength: 6)

                Text(L10n.Common.done.localized)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(App2Theme.accentBlue)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDone)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("\(identifierPrefix)Done")
            }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.top, 14)

            if let suggestion {
                HStack(spacing: 5) {
                    Image(systemName: "tablecells")
                        .font(.system(size: 11, weight: .bold))
                    Text(suggestion)
                        .font(.system(size: 13, weight: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .foregroundStyle(App2Theme.accentBlueDeep)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(App2Theme.accentBlue.opacity(0.08))
                )
                .padding(.top, 14)
                .accessibilityIdentifier("\(identifierPrefix)Suggestion")
            }

            Spacer(minLength: 8)

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(App2Theme.accentBlue.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(App2Theme.accentBlue.opacity(0.35), lineWidth: 1)
                    )
                    .frame(height: 56)
                    .padding(.horizontal, App2Theme.pagePadding)
                content()
            }

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

// MARK: - 配速輪盤（frame-09）
struct App2PaceWheelSheet: View {
    let title: String
    /// `nil` ＝ 這個課型／VDOT 給不出建議區間，該提示列整條省略。
    var suggestion: String?
    let initialPace: String
    let onDone: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var minutes: Double?
    @State private var seconds: Double?

    /// 分鐘欄。設計畫的是 2–6，但 app 自己的暖身／緩和預設就是 `7:55`——
    /// 只給 2–6 會讓輪盤表達不出 app 產生的值。取兩者的聯集 2–9。
    private let minuteOptions: [Double] = (2...9).map(Double.init)
    /// 秒欄以 5 為級距（設計 §18）。
    private let secondOptions: [Double] = stride(from: 0, to: 60, by: 5).map(Double.init)

    init(
        title: String,
        suggestion: String?,
        initialPace: String,
        onDone: @escaping (String) -> Void
    ) {
        self.title = title
        self.suggestion = suggestion
        self.initialPace = initialPace
        self.onDone = onDone
        let parsed = Self.parse(initialPace)
        _minutes = State(initialValue: parsed.minutes)
        _seconds = State(initialValue: parsed.seconds)
    }

    var body: some View {
        App2WheelSheetChrome(
            title: title,
            suggestion: suggestion,
            onCancel: { dismiss() },
            onDone: {
                onDone(Self.format(minutes: minutes, seconds: seconds, fallback: initialPace))
                dismiss()
            },
            identifierPrefix: "App2_PaceWheel"
        ) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                App2WheelColumn(
                    options: minuteOptions,
                    selection: $minutes,
                    label: { String(format: "%.0f", $0) },
                    identifier: "App2_PaceWheelMinutes"
                )
                Text(verbatim: ":")
                    .font(.app2Mono(30, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                    .frame(width: 16)
                App2WheelColumn(
                    options: secondOptions,
                    selection: $seconds,
                    label: { String(format: "%02.0f", $0) },
                    identifier: "App2_PaceWheelSeconds"
                )
                Text(verbatim: "/km")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(App2Theme.inkTertiary)
                    .frame(width: 42, alignment: .leading)
                    .padding(.leading, 8)
                Spacer(minLength: 0)
            }
        }
        .accessibilityIdentifier("App2_PaceWheelSheet")
    }

    // MARK: - `m:ss` ↔ 輪盤

    static func parse(_ pace: String) -> (minutes: Double, seconds: Double) {
        let parts = pace.split(separator: ":")
        guard parts.count == 2,
              let m = Double(parts[0]),
              let s = Double(parts[1]) else {
            return (5, 0)
        }
        // 秒欄只有 5 的倍數，落在中間的值吸到最近的一格。
        return (m, (s / 5).rounded() * 5 == 60 ? 55 : (s / 5).rounded() * 5)
    }

    static func format(minutes: Double?, seconds: Double?, fallback: String) -> String {
        guard let minutes, let seconds else { return fallback }
        return String(format: "%.0f:%02.0f", minutes, seconds)
    }
}

// MARK: - 單值輪盤（距離／趟數／休息秒數）
/// 設計只畫了配速輪盤，但編輯頁裡「距離」「重複次數」「休息時間」點下去也要開輪盤；
/// 同一個 sheet 外殼、同一顆高亮帶，只是一欄。
struct App2ValueWheelSheet: View {
    let title: String
    let options: [Double]
    let label: (Double) -> String
    /// 右側的單位小字（`km`／`m`／`次`／`秒`）。
    var unit: String?
    let initialValue: Double
    let onDone: (Double) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var value: Double?

    init(
        title: String,
        options: [Double],
        label: @escaping (Double) -> String,
        unit: String? = nil,
        initialValue: Double,
        onDone: @escaping (Double) -> Void
    ) {
        self.title = title
        self.options = options
        self.label = label
        self.unit = unit
        self.initialValue = initialValue
        self.onDone = onDone
        let nearest = options.min { abs($0 - initialValue) < abs($1 - initialValue) } ?? initialValue
        _value = State(initialValue: nearest)
    }

    var body: some View {
        App2WheelSheetChrome(
            title: title,
            suggestion: nil,
            onCancel: { dismiss() },
            onDone: {
                onDone(value ?? initialValue)
                dismiss()
            },
            identifierPrefix: "App2_ValueWheel"
        ) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                App2WheelColumn(
                    options: options,
                    selection: $value,
                    label: label,
                    width: 110,
                    identifier: "App2_ValueWheelColumn"
                )
                if let unit {
                    Text(unit)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(App2Theme.inkTertiary)
                        .frame(width: 44, alignment: .leading)
                        .padding(.leading, 8)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityIdentifier("App2_ValueWheelSheet")
    }

    // MARK: - 既有編輯器用得到的幾組刻度
    // 刻度與 1.4 的 `DistanceWheelPicker`／`RepeatsWheelPicker` 對齊，
    // 只是這裡另外收了間歇的公尺制與休息秒數。

    static let runDistanceOptions: [Double] = stride(from: 1.0, through: 42.0, by: 0.5).map { $0 }
    static let intervalDistanceOptions: [Double] = stride(from: 100.0, through: 3000.0, by: 100.0).map { $0 }
    static let repeatsOptions: [Double] = (1...30).map(Double.init)
    static let restSecondsOptions: [Double] = stride(from: 10.0, through: 600.0, by: 5.0).map { $0 }
    static let strengthMinutesOptions: [Double] = stride(from: 5.0, through: 120.0, by: 5.0).map { $0 }
}
