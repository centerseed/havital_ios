import SwiftUI

// MARK: - App2GeneratingView
/// 2.0 的「系統正在生成」等待區塊（SPEC-training-hub-and-weekly-plan-lifecycle
/// AC-TRAIN-HUB-11）。
///
/// **不是通用 spinner。** 週回顧要跑數十秒的 LLM，一顆轉圈只說得出「在忙」，說不出
/// 「正在幫你分析這週的訓練」——使用者實機回報 2.0 的等待畫面「很沒有感覺」（T-0341）。
///
/// **動畫語彙與文案沿用 1.4 的 `LoadingAnimationView`**：同一組跑鞋彈跳 ＋ 輪播文案 ＋
/// 進度條，文案直接取 `LoadingAnimationView.LoadingType` 已有的三語字串
/// （`training.loading.*`），不新增 i18n key、不引入第三方依賴。
///
/// **為什麼不是直接重用 `LoadingAnimationView`**：那一支是蓋住整個 app 的全螢幕層
/// （`Color(.systemBackground).ignoresSafeArea()` ＋ `UIScreen.main.bounds` 算進度條寬），
/// 而 2.0 的畫面架構是每一頁自己的載入態，沒有跨頁的全螢幕載入層（使用者裁決：不要求
/// 恢復全螢幕形態，但畫面裡要有動畫）。把它改成兩種形態通吃，等於在 1.4 仍在用的
/// onboarding／V1 生成路徑上動刀換一顆 P2 的視覺——這裡只共用素材，不共用容器。
struct App2GeneratingView: View {

    private let messages: [String]
    private let messageInterval: TimeInterval
    private let identifier: String

    @State private var messageIndex = 0
    @State private var isBouncing = false
    @State private var isSweeping = false

    /// - Parameters:
    ///   - messages: 輪播文案。傳既有的 `LoadingAnimationView.LoadingType.….messages`，
    ///     不要在呼叫端另外拼一組字串。
    ///   - identifier: 掛在輪播文案那個 `Text`（葉節點）上，不是掛在外層容器——
    ///     `.accessibilityIdentifier` 加在 `VStack` 這種容器上不會產生可查詢的元素。
    ///
    ///     **這個抓手目前沒有被自動化 UI 測試驗證過。** 2026-08-31 在模擬器上，maestro
    ///     對生成中畫面查 `App2_WeeklyReviewGenerating` 兩種掛法都找不到；但那幾次
    ///     assert 的時間窗也可能根本沒有生成在跑（快取命中就直接出內容），所以「查不到」
    ///     不足以判定是掛法的錯。**別把它當成已驗證的 UI gate 來用**——本票鎖住
    ///     「生成中 → 動畫元件存在」的是 `App2WeeklyReviewGeneratingTests` 的單元測試，
    ///     視覺證據是 `STATUS/evidence/T-0341/ios-0*.png`。
    ///   - messageInterval: 每則文案停留幾秒。1.4 是「總時長 ÷ 則數」，那需要事先知道
    ///     總時長；這裡等多久由後端決定，所以改成固定節奏。
    init(
        messages: [String],
        identifier: String = "App2_GeneratingMessage",
        messageInterval: TimeInterval = 4
    ) {
        self.messages = messages
        self.identifier = identifier
        self.messageInterval = messageInterval
    }

    var body: some View {
        VStack(spacing: 22) {
            shoe
            Text(currentMessage)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(App2Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .id(messageIndex)
                .transition(.opacity)
                .accessibilityIdentifier(identifier)
            progressBar
                .frame(maxWidth: 220)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, App2Theme.pagePadding)
        .animation(.easeInOut(duration: 0.35), value: messageIndex)
        .onAppear {
            isBouncing = true
            isSweeping = true
        }
        // **輪播綁在 view 的生命週期，不是綁在 `body` 的每一次重畫。** 用
        // `Timer.publish` ＋ `onReceive` 的話，publisher 在 `init` 產生，而父層只要有任何
        // `@Published` 變動就會重建這個 struct、換一個 publisher，訂閱重來、四秒重新數 ——
        // 文案於是可能永遠停在第一則。`.task` 只跟著 view 的身分走，重畫不會重啟它。
        .task {
            guard messages.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(messageInterval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                messageIndex = (messageIndex + 1) % messages.count
            }
        }
        // **不要 `.accessibilityElement(children: .combine)`。** 它把子元素併成一顆，連帶
        // 把 `App2_GeneratingMessage` 與呼叫端掛在外層的 identifier 一起吃掉——實測
        // （2026-08-31 模擬器）maestro 因此找不到 `App2_WeeklyReviewGenerating`，
        // UI 測試等於沒有抓手。輪播文案本來就是 `Text`，VoiceOver 讀得到，不需要合併。
    }

    // MARK: - Parts

    /// 1.4 的跑鞋（`shoe.2`）彈跳，換成 2.0 的藍與圓底。
    private var shoe: some View {
        ZStack {
            Circle()
                .fill(App2Theme.accentBlue.opacity(0.10))
                .frame(width: 78, height: 78)
            Image(systemName: "shoe.2")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(App2Theme.accentBlue)
                .offset(y: isBouncing ? -7 : 7)
                .animation(
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: isBouncing
                )
        }
    }

    /// 不確定長度的進度條。
    ///
    /// **刻意不畫百分比。** 1.4 那條是照固定 25 秒線性推進的假進度，實際生成比它久時
    /// 進度條會停在滿格不動——那比沒有進度條更像壞掉。這裡只表達「還在跑」。
    private var progressBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(App2Theme.accentBlue.opacity(0.12))
                Capsule()
                    .fill(App2Theme.accentBlue)
                    .frame(width: max(width * 0.34, 1))
                    .offset(x: isSweeping ? width : -width * 0.34)
                    .animation(
                        .easeInOut(duration: 1.4).repeatForever(autoreverses: false),
                        value: isSweeping
                    )
            }
            .clipShape(Capsule())
        }
        .frame(height: 6)
    }

    private var currentMessage: String {
        guard !messages.isEmpty else { return "" }
        return messages[messageIndex % messages.count]
    }
}
