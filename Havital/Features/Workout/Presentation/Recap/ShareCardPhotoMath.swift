import CoreGraphics
import UIKit

/// 分享卡使用者照片的平移／縮放夾制。
///
/// 這段算法原本在 `WorkoutRecapView.clampedOffset` 與 `RecapShareCard.clampedPhotoOffset`
/// 各寫了一份。預覽用前者、匯出用後者 —— 兩份只要有一份沒跟上（例如只在其中一邊納入
/// photoScale），使用者就會看到「預覽好好的、分享出去的圖偏掉」。改成單一來源。
enum ShareCardPhotoMath {

    /// 允許的縮放範圍。min = 1.0：scaledToFill 在 1.0 就已填滿卡片，再縮小就會露白。
    static let minScale: CGFloat = 1.0
    static let maxScale: CGFloat = 4.0

    static func clampScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minScale), maxScale)
    }

    /// `scaledToFill` 的填滿倍率：取較大的一邊才填得滿。
    static func fillScale(image: CGSize, card: CGSize) -> CGFloat {
        guard image.width > 0, image.height > 0 else { return 1 }
        return max(card.width / image.width, card.height / image.height)
    }

    /// 照片在卡片上實際渲染出來的尺寸（含使用者的 pinch 縮放）。
    static func renderedSize(image: CGSize, card: CGSize, photoScale: CGFloat) -> CGSize {
        let fill = fillScale(image: image, card: card) * clampScale(photoScale)
        return CGSize(width: image.width * fill, height: image.height * fill)
    }

    /// 把 offset 夾在「不露白」的範圍內。
    ///
    /// 每軸可偏移量 = 溢出卡片的量的一半。不溢出的軸 → 0 → 強制置中，否則會露出卡片外的空白。
    /// 縮放變大 → 溢出變多 → 可偏移範圍跟著變大；縮回去時 offset 會被夾回界內。
    static func clampOffset(
        _ offset: CGSize,
        image: CGSize,
        card: CGSize,
        photoScale: CGFloat
    ) -> CGSize {
        guard image.width > 0, image.height > 0 else { return .zero }

        let rendered = renderedSize(image: image, card: card, photoScale: photoScale)
        let maxX = max(0, (rendered.width - card.width) / 2)
        let maxY = max(0, (rendered.height - card.height) / 2)

        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    /// 拖曳中：從手勢起點 + 位移算出夾制後的 offset。
    static func clampOffset(
        base: CGSize,
        translation: CGSize,
        image: CGSize,
        card: CGSize,
        photoScale: CGFloat
    ) -> CGSize {
        clampOffset(
            CGSize(width: base.width + translation.width,
                   height: base.height + translation.height),
            image: image,
            card: card,
            photoScale: photoScale
        )
    }
}
