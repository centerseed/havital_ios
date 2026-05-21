import SwiftUI

// MARK: - RecapConfettiCannon
//
// 標準撒花：彩片從畫面頂端均勻灑落，邊落邊左右輕擺 + 旋轉，最後淡出（不留殘留）。
// 每片用 KeyframeAnimator 各自跑「延遲 → 下落 + 擺動 + 旋轉 + 淡出」，onAppear 自動播一次。
// 各片 delay 錯開形成連續灑落感。
// （型別名沿用 Cannon 僅為相容呼叫點，行為已改為頂部灑落。）

struct RecapConfettiCannon: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let color: Color
        let w: CGFloat
        let h: CGFloat
        let isCircle: Bool
        let xRatio: CGFloat   // 起始水平位置（佔寬度 0...1）
        let drift: CGFloat    // 下落時左右擺動幅度
        let delay: Double     // 錯開起始時間
        let duration: Double  // 下落總時長
        let spin: Double
    }

    private struct Vals {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var opacity: Double = 1
        var rot: Double = 0
    }

    private static let palette: [Color] = [
        PacerizColor.blue,
        Color(red: 1.0, green: 0.84, blue: 0.0),
        Color(red: 1.0, green: 0.55, blue: 0.0),
        Color(red: 0.30, green: 0.78, blue: 0.47),
        Color(red: 0.95, green: 0.36, blue: 0.55),
        Color.cyan
    ]

    private let pieces: [Piece]

    init(count: Int = 80) {
        pieces = (0..<count).map { _ in
            Piece(
                color: Self.palette.randomElement() ?? .blue,
                w: CGFloat.random(in: 6...11),
                h: CGFloat.random(in: 9...16),
                isCircle: Bool.random(),
                xRatio: CGFloat.random(in: 0.02...0.98),
                drift: CGFloat.random(in: 8...22) * (Bool.random() ? 1 : -1),
                delay: Double.random(in: 0...0.5),
                duration: Double.random(in: 1.8...2.4),
                spin: Double.random(in: 180...540) * (Bool.random() ? 1 : -1)
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    let startX = geo.size.width * piece.xRatio
                    shape(for: piece)
                        .position(x: startX, y: 12)
                        // repeating: false → 只灑落一次，不循環（預設 true 會落完彈回頂端重跑，看起來像原地一直轉）
                        .keyframeAnimator(initialValue: Vals(), repeating: false) { view, value in
                            view
                                .offset(x: value.x, y: value.y)
                                .rotationEffect(.degrees(value.rot))
                                .opacity(value.opacity)
                        } keyframes: { _ in
                            // 下落：延遲後等速落到畫面外
                            KeyframeTrack(\.y) {
                                LinearKeyframe(0, duration: piece.delay)
                                LinearKeyframe(geo.size.height + 60, duration: piece.duration)
                            }
                            // 左右輕擺（三段 wobble）
                            KeyframeTrack(\.x) {
                                LinearKeyframe(0, duration: piece.delay)
                                CubicKeyframe(piece.drift, duration: piece.duration * 0.33)
                                CubicKeyframe(-piece.drift, duration: piece.duration * 0.34)
                                CubicKeyframe(piece.drift * 0.5, duration: piece.duration * 0.33)
                            }
                            // 持續旋轉
                            KeyframeTrack(\.rot) {
                                LinearKeyframe(0, duration: piece.delay)
                                LinearKeyframe(piece.spin, duration: piece.duration)
                            }
                            // 最後 20% 淡出
                            KeyframeTrack(\.opacity) {
                                LinearKeyframe(1, duration: piece.delay + piece.duration * 0.8)
                                LinearKeyframe(0, duration: piece.duration * 0.2)
                            }
                        }
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func shape(for piece: Piece) -> some View {
        if piece.isCircle {
            Circle()
                .fill(piece.color)
                .frame(width: piece.w, height: piece.w)
        } else {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(piece.color)
                .frame(width: piece.w, height: piece.h)
        }
    }
}
