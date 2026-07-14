import SwiftUI

/// 分享卡的可切換比例。兩張分享卡（運動回顧卡、成就卡）共用。
///
/// 4:5 是預設，也是既有版面 —— 切比例是「新增」而不是「取代」，所以 `.portrait45`
/// 必須渲染出跟改版前一模一樣的卡片。
enum ShareCardAspect: String, CaseIterable, Identifiable {
    case portrait45
    case story916

    var id: String { rawValue }

    /// width / height。用除的（不是乘）才能直接餵給 `.aspectRatio(_:contentMode:)`。
    var ratio: CGFloat {
        switch self {
        case .portrait45: return 4.0 / 5.0
        case .story916:   return 9.0 / 16.0
        }
    }

    /// 顯示用標籤。數字比例本身跨語言通用，不進 i18n。
    var label: String {
        switch self {
        case .portrait45: return "4:5"
        case .story916:   return "9:16"
        }
    }

    /// 匯出圖尺寸（實際像素由 `ImageRenderer.scale` 再乘上去）。
    func exportSize(width: CGFloat) -> CGSize {
        CGSize(width: width, height: (width / ratio).rounded())
    }
}

/// 卡片下方的比例切換器。
struct ShareCardAspectPicker: View {
    @Binding var selection: ShareCardAspect

    var body: some View {
        Picker(selection: $selection) {
            ForEach(ShareCardAspect.allCases) { aspect in
                Text(aspect.label).tag(aspect)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 200)
        .accessibilityIdentifier("share-card-aspect-picker")
    }
}
