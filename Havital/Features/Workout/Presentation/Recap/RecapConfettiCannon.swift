import SwiftUI

// MARK: - RecapConfettiCannon
//
// 標準撒花：彩片從頂端灑落、邊落邊旋轉與飄動，落出畫面外即消失。
// 用 TimelineView(.animation) + Canvas 逐幀自繪 —— 不依賴 SwiftUI 隱式/keyframe 動畫
// （那兩者在 sheet overlay 內不會啟動，導致彩片卡住不動 = 撒花失效）。

struct RecapConfettiCannon: View {
    private struct Piece {
        let color: Color
        let w: CGFloat
        let h: CGFloat
        let isCircle: Bool
        let xRatio: CGFloat   // 起始水平位置（佔寬度 0...1）
        let drift: CGFloat    // 水平飄移幅度
        let delay: Double     // 錯開起始時間
        let duration: Double  // 下落總時長
        let spin: Double      // 每秒旋轉度數
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
    @State private var start = Date()

    // 全程約 5 秒；最後 2 秒（t=3→5）整體淡出。
    private let totalDuration: Double = 5.0
    private let fadeStart: Double = 3.0

    init(count: Int = 120) {
        pieces = (0..<count).map { _ in
            Piece(
                color: Self.palette.randomElement() ?? .blue,
                w: CGFloat.random(in: 6...11),
                h: CGFloat.random(in: 9...16),
                isCircle: Bool.random(),
                xRatio: CGFloat.random(in: 0.02...0.98),
                drift: CGFloat.random(in: 16...44) * (Bool.random() ? 1 : -1),
                delay: Double.random(in: 0...1.0),
                duration: Double.random(in: 3.6...5.0),
                spin: Double.random(in: 120...320) * (Bool.random() ? 1 : -1)
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSince(start)
                // 整體淡出：t < fadeStart 全顯，fadeStart→totalDuration 線性淡出。
                let globalFade = t < fadeStart ? 1.0 : max(0.0, 1.0 - (t - fadeStart) / (totalDuration - fadeStart))
                Canvas { ctx, size in
                    if globalFade <= 0 { return }
                    for piece in pieces {
                        let lt = t - piece.delay
                        if lt <= 0 { continue }
                        let prog = lt / piece.duration
                        if prog >= 1 { continue }

                        let eased = pow(prog, 1.3)          // 略微加速下落
                        let y = -24 + eased * (size.height + 140)
                        let x = size.width * piece.xRatio + sin(lt * 3 + Double(piece.xRatio) * 6) * piece.drift

                        ctx.drawLayer { layer in
                            layer.opacity = globalFade
                            layer.translateBy(x: x, y: y)
                            layer.rotate(by: .degrees(lt * piece.spin))
                            let rect = CGRect(x: -piece.w / 2, y: -piece.h / 2, width: piece.w, height: piece.h)
                            let path = piece.isCircle
                                ? Path(ellipseIn: CGRect(x: -piece.w / 2, y: -piece.w / 2, width: piece.w, height: piece.w))
                                : Path(roundedRect: rect, cornerRadius: 1.5)
                            layer.fill(path, with: .color(piece.color))
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { start = Date() }
    }
}
