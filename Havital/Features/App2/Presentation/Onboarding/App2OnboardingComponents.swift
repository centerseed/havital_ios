import SwiftUI

// MARK: - 為什麼不沿用 1.x 的 onboarding 元件
//
// 動手前查過 `Havital/Views/Onboarding/Components/`：
//
// | 1.x 既有 | 狀況 |
// |---|---|
// | `OnboardingPageTemplate` / `OnboardingBottomCTA` | 有，但用 1.x token（`AppFont`、系統色、`OnboardingLayout`） |
// | `OnboardingProgressBar` | 有，但是單條 0…1，沒有分段、沒有段名 |
// | `StageOptionCard`（在 `StartStageSelectionView` 內）/ `DistanceFilterChip`（在 `RaceEventListView` 內） | 有，但綁在各自的畫面裡、也是 1.x 樣式 |
// | 三段式進度、時:分:秒 欄位 | **完全沒有** |
//
// 與 `App2Theme` 同一個理由（見那支檔頭）：2.0 用的是另一組刻度，硬套 1.x 會處處差
// 2–4pt，且三段式進度的語意 1.x 那條表達不了。**1.x 那批不動**——它們是 `main`
// 發版線在用的，本票不合回 main。

// MARK: - App2OnboardingSegment
/// 設計的三段：你的目標 → 你的訓練 → 你的計畫。
enum App2OnboardingSegment: Int, CaseIterable {
    case goal = 1
    case training = 2
    case plan = 3

    var titleKey: String {
        switch self {
        case .goal:     return L10n.App2.Onboarding.segGoal
        case .training: return L10n.App2.Onboarding.segTraining
        case .plan:     return L10n.App2.Onboarding.segPlan
        }
    }
}

// MARK: - App2OnboardingHeader
/// 頁首：返回鍵 ＋ 目前段名 ＋「第 N / 3 段」＋ 三條進度。
///
/// `progressWithinSegment` 是**目前這一段**已走完的比例（0…1）；已走完的段填滿、
/// 還沒到的段留空（設計 frame-31→38 的頁首逐張變化就是這條規則）。
struct App2OnboardingHeader: View {
    let segment: App2OnboardingSegment
    let progressWithinSegment: Double
    /// nil ＝ 這一頁沒有上一步。
    let onBack: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                backButton

                Text(segment.titleKey.localized)
                    .font(.system(size: 14, weight: .black))
                    .tracking(0.5)
                    .foregroundStyle(App2Theme.inkPrimary)
                    .padding(.leading, 12)

                Spacer(minLength: 8)

                Text(String(
                    format: L10n.App2.Onboarding.stepFormat.localized,
                    segment.rawValue,
                    App2OnboardingSegment.allCases.count
                ))
                .font(.app2Mono(12, weight: .bold))
                .foregroundStyle(App2Theme.inkMuted)
                // 頁首的標記掛在「第 N / 3 段」這一個葉節點上。
                // **不要掛在外層容器**：SwiftUI 的 `accessibilityIdentifier` 會往下傳給
                // 所有子節點，掛在頁面或區塊容器上會把裡面每一顆按鈕的 identifier
                // 全部蓋掉（2026-08-25 實走：整條 onboarding 的 id 都查不到）。
                .accessibilityIdentifier("App2_OnboardingHeader")
            }
            .padding(.bottom, 14)

            HStack(spacing: 8) {
                ForEach(App2OnboardingSegment.allCases, id: \.rawValue) { seg in
                    segmentColumn(seg)
                }
            }
        }
        .padding(.horizontal, 22)
    }

    @ViewBuilder
    private var backButton: some View {
        let enabled = onBack != nil
        Button { onBack?() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(App2Theme.inkSubtle)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(App2Theme.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Color(hex: "#0F172A").opacity(0.08), lineWidth: 1)
                )
                .opacity(enabled ? 1 : 0.35)
        }
        .disabled(!enabled)
        .accessibilityLabel(L10n.App2.Onboarding.back.localized)
        .accessibilityIdentifier("App2_OnboardingBack")
    }

    private func segmentColumn(_ seg: App2OnboardingSegment) -> some View {
        let fill: Double = {
            if seg.rawValue < segment.rawValue { return 1 }
            if seg.rawValue > segment.rawValue { return 0 }
            return min(max(progressWithinSegment, 0), 1)
        }()
        let isCurrent = seg == segment

        return VStack(alignment: .leading, spacing: 7) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "#D9E0E8"))
                    Capsule()
                        .fill(App2Theme.accentBlue)
                        .frame(width: max(0, geo.size.width * fill))
                }
            }
            .frame(height: 5)

            Text(seg.titleKey.localized)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.3)
                .foregroundStyle(isCurrent ? App2Theme.accentBlueDeep : Color(hex: "#B4BCC6"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - App2OnboardingPage
/// 頁殼：漸層底 ＋（可選）頁首 ＋ 捲動內容 ＋ 底部主 CTA ＋（可選）skip。
struct App2OnboardingPage<Content: View>: View {
    var segment: App2OnboardingSegment?
    var progressWithinSegment: Double = 0
    var onBack: (() -> Void)?

    let ctaTitle: String
    var ctaEnabled: Bool = true
    var ctaBusy: Bool = false
    let ctaIdentifier: String
    let ctaAction: () -> Void

    var skipTitle: String?
    var skipAction: (() -> Void)?

    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            if let segment {
                App2OnboardingHeader(
                    segment: segment,
                    progressWithinSegment: progressWithinSegment,
                    onBack: onBack
                )
                .padding(.top, 8)
                .padding(.bottom, 18)
            }

            ScrollView {
                content()
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }

            VStack(spacing: 12) {
                App2OnboardingPrimaryButton(
                    title: ctaTitle,
                    enabled: ctaEnabled,
                    busy: ctaBusy,
                    identifier: ctaIdentifier,
                    action: ctaAction
                )

                if let skipTitle, let skipAction {
                    Button(action: skipAction) {
                        Text(skipTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(App2Theme.inkMuted)
                    }
                    .accessibilityIdentifier("App2_OnboardingSkip")
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(App2Theme.pageGradient.ignoresSafeArea())
    }
}

// MARK: - App2OnboardingPrimaryButton
/// 設計的主 CTA：`padding:15px;border-radius:15px;background:#1890ff;` ＋ 藍光暈。
struct App2OnboardingPrimaryButton: View {
    let title: String
    var enabled: Bool = true
    var busy: Bool = false
    var trailingArrow: Bool = false
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if busy {
                    ProgressView().tint(.white)
                }
                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                if trailingArrow && !busy {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .black))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(App2Theme.accentBlue)
            )
            .shadow(color: App2Theme.accentBlue.opacity(0.45), radius: 11, x: 0, y: 10)
            .opacity(enabled && !busy ? 1 : 0.45)
        }
        .disabled(!enabled || busy)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - App2OnboardingIconTile
/// 選項卡左側的 46×46 圓角圖示格（設計 frame-31）。
struct App2OnboardingIconTile: View {
    let systemName: String
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isSelected ? App2Theme.accentBlue : Color(hex: "#EEF2F7"))
            .frame(width: 46, height: 46)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : App2Theme.inkSubtle)
            )
            .shadow(
                color: isSelected ? App2Theme.accentBlue.opacity(0.5) : .clear,
                radius: 7, x: 0, y: 6
            )
    }
}

// MARK: - App2OnboardingOptionCard
/// 三選一／方法論的選項卡（設計 frame-31／36）。
struct App2OnboardingOptionCard: View {
    let title: String
    var subtitle: String?
    var badge: String?
    var iconSystemName: String?
    let isSelected: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let iconSystemName {
                    App2OnboardingIconTile(systemName: iconSystemName, isSelected: isSelected)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(App2Theme.inkPrimary)
                            .multilineTextAlignment(.leading)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(App2Theme.accentBlue))
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isSelected ? App2Theme.inkSecondary : App2Theme.inkSubtle)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                selectionMark
            }
            .padding(16)
            .background(background)
            .overlay(border)
            .shadow(
                color: isSelected ? App2Theme.accentBlue.opacity(0.28) : App2Theme.shadowInk.opacity(0.04),
                radius: isSelected ? 12 : 1,
                x: 0,
                y: isSelected ? 10 : 1
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var selectionMark: some View {
        Group {
            if isSelected {
                Circle()
                    .fill(App2Theme.accentBlue)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.white)
                    )
            } else {
                Circle()
                    .strokeBorder(Color(hex: "#D0D7E0"), lineWidth: 2)
                    .frame(width: 24, height: 24)
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(App2Theme.accentCardGradient(strength: 0.10))
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(App2Theme.cardBackground)
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(
                isSelected ? App2Theme.accentBlue : Color(hex: "#0F172A").opacity(0.08),
                lineWidth: isSelected ? 2 : 1
            )
    }
}

// MARK: - App2OnboardingChip
/// 距離／星期用的實心膠囊選擇鈕（設計 frame-32／35／37）。
struct App2OnboardingChip: View {
    let title: String
    let isSelected: Bool
    var fillsWidth: Bool = true
    var cornerRadius: CGFloat = 14
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(isSelected ? Color.white : App2Theme.inkPrimary)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .padding(.horizontal, fillsWidth ? 6 : 16)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isSelected ? App2Theme.accentBlue : App2Theme.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.clear : Color(hex: "#0F172A").opacity(0.07),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - App2OnboardingOutlineChip
/// 「一年內／一年前」「差不多／我想調整」這類淺色選中態（設計 frame-35／38）。
struct App2OnboardingOutlineChip: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage, isSelected {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .black))
                }
                Text(title)
                    .font(.system(size: 15, weight: .heavy))
            }
            .foregroundStyle(isSelected ? App2Theme.accentBlueDeep : App2Theme.inkPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isSelected ? App2Theme.accentBlue.opacity(0.08) : App2Theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(
                        isSelected ? App2Theme.accentBlue : Color(hex: "#0F172A").opacity(0.07),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - App2OnboardingTitleBlock
/// 每頁的大標＋副標（設計：26px w900 ＋ 14px w600）。
///
/// **每一頁的 identifier 掛在這裡，不掛在頁面容器上。** SwiftUI 的
/// `accessibilityIdentifier` 會往下傳給所有子節點；掛在頁面外層會把頁內每一顆
/// 按鈕的 identifier 全部覆蓋掉，UI 測試就只找得到頁面本身
/// （2026-08-25 模擬器實走踩到）。這一塊只有兩顆 Text，覆蓋沒有副作用。
struct App2OnboardingTitleBlock: View {
    let title: String
    var subtitle: String?
    var identifier: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(App2Theme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(App2Theme.inkSubtle)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 22)
        .accessibilityIdentifier(identifier ?? "")
    }
}

// MARK: - App2OnboardingFieldLabel
struct App2OnboardingFieldLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy))
            .tracking(0.5)
            .foregroundStyle(App2Theme.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - App2OnboardingNumberWheel
/// 心率頁的滾輪（設計 frame-33）。
struct App2OnboardingNumberWheel: View {
    let range: ClosedRange<Int>
    @Binding var value: Int
    let identifier: String

    var body: some View {
        Picker("", selection: $value) {
            ForEach(Array(range), id: \.self) { n in
                Text("\(n)")
                    .font(.app2Mono(28, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                    .tag(n)
            }
        }
        .labelsHidden()
        .pickerStyle(.wheel)
        .frame(height: 138)
        .clipped()
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - App2OnboardingTimeField
/// 時／分／秒三欄的單欄（設計 frame-32／35）。
/// 1.x 只有「分鐘輪盤」（`WorkTimeWheelPicker`），沒有時:分:秒 的欄位組。
struct App2OnboardingTimeField: View {
    let unit: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let identifier: String

    @FocusState private var focused: Bool
    /// 綁字串而不是 `TextField(value:format:)`：後者在編輯途中會把不完整的輸入
    /// 直接寫回 `Int`，配上夾值就會出現「想打 3，欄位跳成 23」。
    /// 字串在這裡只是輸入緩衝，`value` 仍是唯一的真值。
    @State private var text: String = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            TextField("", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.app2Mono(28, weight: .black))
                .foregroundStyle(App2Theme.inkPrimary)
                .focused($focused)
                .frame(minWidth: 40)
                // identifier 掛在 TextField 本體，不掛外框：掛外框的話 UI 測試找到的
                // 是容器，`eraseText` 找不到真正的輸入元件（會靜默失敗，然後新輸入
                // 直接接在舊值後面）。
                .accessibilityIdentifier(identifier)
                .onAppear { text = String(value) }
                .onChange(of: text) { _, newText in
                    let digits = String(newText.filter(\.isNumber).prefix(2))
                    if digits != newText { text = digits }
                    // 空字串＝正在改（剛全刪），這時不要寫回 `value`——寫回會讓
                    // 下面的同步立刻把 `0` 填進輸入框，使用者再打一碼就變成 `03`。
                    guard let parsed = Int(digits) else { return }
                    value = min(max(parsed, range.lowerBound), range.upperBound)
                }
                .onChange(of: value) { _, newValue in
                    // 只在**沒有焦點**時從外部值回填（例如選了一場賽事帶入目標時間）。
                    // 編輯中回填 ＝ 跟使用者搶輸入框。
                    guard !focused, Int(text) != newValue else { return }
                    text = String(newValue)
                }
                .onChange(of: focused) { _, isFocused in
                    guard !isFocused else { return }
                    // 離開欄位時正規化緩衝（`03` → `3`、空白 → 下限）。
                    if Int(text) == nil { value = range.lowerBound }
                    text = String(value)
                }
            Text(unit)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(App2Theme.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(App2Theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    focused ? App2Theme.accentBlue : Color(hex: "#0F172A").opacity(0.07),
                    lineWidth: focused ? 2 : 1
                )
        )
        // 整格可點就聚焦：identifier 掛在外框，點擊點常常落在單位字（`時`）上而不是
        // 輸入框本體，沒有這一條的話 UI 測試「點欄位再輸入」會打進上一個欄位。
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }
}

// MARK: - App2OnboardingNotice
/// 底部的灰／綠說明條（設計 frame-34／37／38）。
/// 1.x 的 `InlineWarningBanner` 只有橘色警告一種調性、且是 title+message 兩段式。
struct App2OnboardingNotice: View {
    let systemImage: String
    let text: String
    var tone: Tone = .neutral

    enum Tone { case neutral, positive }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tone == .positive ? App2Theme.accentGreenDot : App2Theme.inkMuted)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tone == .positive ? App2Theme.inkSecondary : App2Theme.inkSubtle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tone == .positive
                      ? App2Theme.accentGreenBright.opacity(0.09)
                      : Color(hex: "#E6EBF1").opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    tone == .positive
                        ? App2Theme.accentGreenBright.opacity(0.35)
                        : Color(hex: "#0F172A").opacity(0.05),
                    lineWidth: 1
                )
        )
    }
}
