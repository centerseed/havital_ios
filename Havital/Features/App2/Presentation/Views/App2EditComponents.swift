import SwiftUI

// MARK: - App2EditComponents
/// 「修改課表」整條（設計 frame-03～frame-09）共用的零件。
///
/// 這些零件隱藏的設計決定是「**編輯模式**長什麼樣」——斜紋底、握把、齒輪鈕、
/// 欄位方塊、stepper、虛線新增列；瀏覽情境的卡片語彙仍在 `App2CardComponents`，
/// 兩邊不重疊。
///
/// 既有的私有 helper 一併收進來，避免同一顆鈕在 repo 裡有第二個定義：
/// `App2HeartRateZoneSettingsView.stepperButton`（52×46）與
/// `App2RaceManagementView.dashedButton`（白底 16/22 圓角）現在都走
/// `App2StepperButton`／`App2DashedAddButton`，尺寸差異用參數表達。

// MARK: - 斜紋底（編輯模式的視覺訊號）
/// `repeating-linear-gradient(135deg,#eef3f8 0 22px,#eaeff5 22px 44px)`。
/// **不可換成純色**——它是「現在在編輯」唯一的整頁訊號（設計 §0）。
struct App2EditStripeBackground: View {
    private let base = Color(hex: "#EEF3F8")
    private let stripe = Color(hex: "#EAEFF5")
    private let band: CGFloat = 22

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
            var x = -size.height
            while x < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + band, y: 0))
                path.addLine(to: CGPoint(x: x + band + size.height, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .color(stripe))
                x += band * 2
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - 編輯頁的 top bar
/// 左「取消」藍字 ／ 中標題 17/900 ／ 右「配速表」白鈕（可省）＋「儲存」藍實心鈕。
/// 肌力日與休息日沒有配速，所以 `onPaceTable` 傳 nil 時整顆不出現（設計 §16／§17）。
struct App2EditTopBar: View {
    let title: String
    let onCancel: () -> Void
    var onPaceTable: (() -> Void)?
    var isSaving: Bool = false
    var saveEnabled: Bool = true
    let onSave: () -> Void
    var identifierPrefix: String

    var body: some View {
        HStack(spacing: 8) {
            Text(L10n.EditSchedule.cancel.localized)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(App2Theme.accentBlue)
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("\(identifierPrefix)Cancel")

            Spacer(minLength: 4)

            Text(title)
                .font(.system(size: 17, weight: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(App2Theme.inkPrimary)
                .accessibilityIdentifier("\(identifierPrefix)Title")

            Spacer(minLength: 4)

            HStack(spacing: 8) {
                if let onPaceTable {
                    HStack(spacing: 4) {
                        Image(systemName: "tablecells")
                            .font(.system(size: 12, weight: .bold))
                        Text(L10n.App2.PlanEdit.paceTable.localized)
                            .font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundStyle(App2Theme.accentBlueDeep)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(App2Theme.cardBorder, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onPaceTable)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("\(identifierPrefix)PaceTable")
                }

                Group {
                    if isSaving {
                        ProgressView().frame(width: 44, height: 28)
                    } else {
                        Text(L10n.EditSchedule.save.localized)
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(saveEnabled ? App2Theme.accentBlue : App2Theme.chevron)
                            )
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard saveEnabled, !isSaving else { return }
                    onSave()
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(L10n.EditSchedule.save.localized)
                .accessibilityIdentifier("\(identifierPrefix)Save")
            }
        }
        .padding(.horizontal, App2Theme.pagePadding)
        .padding(.vertical, 10)
    }
}

// MARK: - Hero（編輯單日頁頂端，非卡片）
/// kicker 膠囊 → 課型名 34/900（課型色） → 說明段 14/600。
struct App2EditHero: View {
    let kicker: String
    let title: String
    let accent: Color
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(kicker)
                .font(.system(size: 12, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(accent.app2Darkened)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(accent.opacity(0.13)))

            Text(title)
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(accent.app2Darkened)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 14, weight: .semibold))
                    .lineSpacing(3)
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("App2_DayEditHero")
    }
}

// MARK: - 欄位方塊
/// 11px 圓角 `#f7f9fc` 底的等寬欄位（「配速 5:10/km」「距離 8.0km」）。
///
/// 內容本體是既有的 `App2FieldColumn`（標籤在上、mono 值在下），這裡只加編輯情境
/// 才有的東西：淺底方塊 ＋ 可點的 `›`。
struct App2EditFieldBlock: View {
    let label: String
    let value: String
    var accent: Color = App2Theme.inkPrimary
    var onTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            App2FieldColumn(label: label, value: value, valueColor: accent, valueSize: 15)
            Spacer(minLength: 2)
            if onTap != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(App2Theme.chevron)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(App2Theme.insetBackgroundCool)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}

// MARK: - 值列（卡片內「配速 → 4:20/km ›」）
struct App2EditValueRow: View {
    let label: String
    let value: String
    var onTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(App2Theme.inkSecondary)
            Spacer(minLength: 6)
            Text(value)
                .font(.app2Mono(18, weight: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(App2Theme.inkPrimary)
            if onTap != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(App2Theme.chevron)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}

// MARK: - Stepper 的單顆鈕
/// 設計刻意讓兩顆鈕不一定同色：間歇頁的重複次數是「灰−／藍＋」（§14），
/// 肌力頁的組數是「兩顆都灰」（§16），心率設定頁是 52×46 的大鈕。
/// 差異全部由參數表達，形狀只有這一份。
struct App2StepperButton: View {
    let systemImage: String
    var filled: Bool = false
    var width: CGFloat = 34
    var height: CGFloat = 34
    var cornerRadius: CGFloat = 10
    var glyphSize: CGFloat = 14
    var fillColor: Color = App2Theme.accentBlue
    var identifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(filled ? fillColor : App2Theme.insetBackground)
                .frame(width: width, height: height)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.system(size: glyphSize, weight: .black))
                        .foregroundStyle(filled ? Color.white : App2Theme.inkSubtle)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier ?? "")
    }
}

// MARK: - Stepper（−／值／＋）
struct App2EditStepper: View {
    let value: Int
    var unit: String?
    var size: CGFloat = 34
    var valueSize: CGFloat = 24
    var plusFilled: Bool = true
    var identifier: String?
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            App2StepperButton(
                systemImage: "minus",
                width: size,
                height: size,
                cornerRadius: size * 0.29,
                glyphSize: size * 0.4,
                identifier: identifier.map { "\($0)Minus" },
                action: onMinus
            )
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(value)")
                    .font(.app2Mono(valueSize, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                if let unit {
                    Text(unit)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(App2Theme.inkTertiary)
                }
            }
            .accessibilityIdentifier(identifier.map { "\($0)Value" } ?? "")
            App2StepperButton(
                systemImage: "plus",
                filled: plusFilled,
                width: size,
                height: size,
                cornerRadius: size * 0.29,
                glyphSize: size * 0.4,
                identifier: identifier.map { "\($0)Plus" },
                action: onPlus
            )
        }
    }
}

// MARK: - 開關列
struct App2EditToggleRow: View {
    let label: String
    @Binding var isOn: Bool
    var identifier: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(App2Theme.inkSecondary)
            Spacer(minLength: 6)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(App2Theme.accentBlue)
                .accessibilityIdentifier(identifier ?? "")
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 虛線新增鈕
/// 兩種用法：編輯頁的「＋ 新增分段／新增動作」（tint 淡底、14px 圓角），
/// 賽事管理頁的「＋ 新增賽事」（白底半透、16／22px 圓角、可帶副標）。
struct App2DashedAddButton: View {
    let title: String
    var subtitle: String?
    var tint: Color
    var border: Color?
    var background: Color?
    var cornerRadius: CGFloat = 14
    var verticalPadding: CGFloat = 12
    var identifier: String?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .black))
                Text(title)
                    .font(.system(size: 15, weight: .heavy))
            }
            .foregroundStyle(tint)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(App2Theme.inkMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(background ?? tint.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    border ?? tint.opacity(0.75),
                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier ?? "")
    }
}

// MARK: - 拖曳握把
/// 28×36 圓角 8、`#eef1f6` 底、2×3 共 6 個 `#8a97a6` 小圓點（設計 §12）。
/// 課型選單的錨點日卡上改成無底色的小點陣（§13），用 `filled: false`。
struct App2DragHandle: View {
    var width: CGFloat = 28
    var height: CGFloat = 36
    var filled: Bool = true

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(filled ? Color(hex: "#EEF1F6") : Color.clear)
            .frame(width: width, height: height)
            .overlay {
                VStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: 4) {
                            ForEach(0..<2, id: \.self) { _ in
                                Circle()
                                    .fill(filled ? Color(hex: "#8A97A6") : Color(hex: "#CBD3DD"))
                                    .frame(width: 3, height: 3)
                            }
                        }
                    }
                }
            }
    }
}

// MARK: - 齒輪鈕（開單日進階編輯）
struct App2GearButton: View {
    var identifier: String?
    let action: () -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Color(hex: "#F4F6FA"))
            .frame(width: 32, height: 32)
            .overlay {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(App2Theme.inkSubtle)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(identifier ?? "")
    }
}

// MARK: - 卡片小標（9×9 圓點 ＋ 標題）
struct App2EditCardHeader: View {
    let dotColor: Color
    let title: String
    var trailing: String?

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(dotColor).frame(width: 9, height: 9)
            Text(title)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(App2Theme.inkPrimary)
            Spacer(minLength: 6)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(App2Theme.inkTertiary)
            }
        }
    }
}

// MARK: - 內縮分隔線
struct App2EditDivider: View {
    var inset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(App2Theme.insetBorder)
            .frame(height: 1)
            .padding(.leading, inset)
    }
}

// MARK: - 可拖曳排序的清單
/// 設計 §12 的拖曳中狀態：**落點佔位**（2px 虛線藍框 ＋ 說明字）＋ **被拖起的卡**
/// （藍邊、重陰影、`rotate(-1.6deg)`）。這三件事在 SwiftUI 的 `List` + `onMove` 裡
/// 一件都做不到（系統自帶的重排把手在右側、沒有佔位框、沒有傾角），所以自己畫。
///
/// 兩個呼叫點：編輯週課表的日卡（放開＝與目的日**對調**）與組合訓練的分段清單
/// （放開＝**移動**到該位置）。差別由 `onCommit` 決定，這裡只管手勢與畫面。
struct App2DragReorderList<Content: View>: View {
    let count: Int
    var spacing: CGFloat = 12
    /// 落點佔位要寫的字（參數是目的地 index）。回傳 nil 就只畫虛線框。
    var placeholderText: (Int) -> String?
    /// (來源 index, 目的 index)
    let onCommit: (Int, Int) -> Void
    @ViewBuilder let row: (Int) -> Content

    @State private var dragIndex: Int?
    @State private var targetIndex: Int?
    @State private var translationY: CGFloat = 0
    @State private var heights: [Int: CGFloat] = [:]

    private struct HeightKey: PreferenceKey {
        static var defaultValue: [Int: CGFloat] { [:] }
        static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
            value.merge(nextValue()) { _, new in new }
        }
    }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { index in
                row(index)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: HeightKey.self, value: [index: geo.size.height])
                        }
                    )
                    .overlay {
                        if let targetIndex, let dragIndex, targetIndex == index, targetIndex != dragIndex {
                            placeholder(for: index)
                        }
                    }
                    .rotationEffect(.degrees(dragIndex == index ? -1.6 : 0))
                    .shadow(
                        color: dragIndex == index
                            ? App2Theme.shadowInk.opacity(0.5)
                            : .clear,
                        radius: dragIndex == index ? 16 : 0,
                        x: 0,
                        y: dragIndex == index ? 18 : 0
                    )
                    .offset(y: dragIndex == index ? translationY : 0)
                    .zIndex(dragIndex == index ? 10 : 0)
                    .simultaneousGesture(gesture(for: index))
            }
        }
        .onPreferenceChange(HeightKey.self) { heights = $0 }
    }

    private func placeholder(for index: Int) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(App2Theme.accentBlue.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        App2Theme.accentBlue.opacity(0.55),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
            )
            .overlay {
                if let text = placeholderText(index) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 12, weight: .black))
                        Text(text)
                            .font(.system(size: 13, weight: .heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(App2Theme.accentBlueDeep)
                    .padding(.horizontal, 10)
                }
            }
            .accessibilityIdentifier("App2_DragPlaceholder")
    }

    private func gesture(for index: Int) -> some Gesture {
        LongPressGesture(minimumDuration: 0.28)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                if dragIndex == nil {
                    dragIndex = index
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                translationY = drag.translation.height
                targetIndex = nearestIndex(from: index, offsetBy: drag.translation.height)
            }
            .onEnded { _ in
                if let dragIndex, let targetIndex, dragIndex != targetIndex {
                    onCommit(dragIndex, targetIndex)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                self.dragIndex = nil
                self.targetIndex = nil
                self.translationY = 0
            }
    }

    /// 從來源列的中心加上位移，找最近的那一列。
    private func nearestIndex(from source: Int, offsetBy dy: CGFloat) -> Int {
        let target = center(of: source) + dy
        return (0..<count).min {
            abs(center(of: $0) - target) < abs(center(of: $1) - target)
        } ?? source
    }

    private func center(of index: Int) -> CGFloat {
        var y: CGFloat = 0
        for i in 0..<index { y += (heights[i] ?? 72) + spacing }
        return y + (heights[index] ?? 72) / 2
    }
}

// MARK: - 下拉 chip（課型／力量類型）
struct App2EditDropdownChip: View {
    let text: String
    var foreground: Color
    var background: Color
    var border: Color?
    var chevronUp: Bool = false
    var glow: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Text(text)
                .font(.system(size: 13, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Image(systemName: chevronUp ? "chevron.up" : "chevron.down")
                .font(.system(size: 9, weight: .black))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(border ?? .clear, lineWidth: border == nil ? 0 : 1.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    glow ? App2Theme.accentOrangeSoft.opacity(0.18) : .clear,
                    lineWidth: glow ? 3 : 0
                )
                .padding(-3)
        )
    }
}
