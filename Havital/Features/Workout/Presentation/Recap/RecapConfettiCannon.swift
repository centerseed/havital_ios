import SwiftUI

// MARK: - RecapConfettiCannon
//
// 禮炮式撒花：從底部左右兩側往中上方噴射，拋物線散開後自動淡出（不留殘留）。
// 每片用 KeyframeAnimator 各自跑「上拋 → 下墜 + 旋轉 + 淡出」，onAppear 自動播一次。

struct RecapConfettiCannon: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let color: Color
        let w: CGFloat
        let h: CGFloat
        let isCircle: Bool
        let fromLeft: Bool
        let dx: CGFloat       // 水平噴射距離（左側為正、右側為負）
        let peakY: CGFloat    // 上拋最高點（負值）
        let fallY: CGFloat    // 最終下墜（正值）
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

    init(count: Int = 90) {
        pieces = (0..<count).map { i in
            let fromLeft = i % 2 == 0
            let spread = CGFloat.random(in: 70...300)
            return Piece(
                color: Self.palette.randomElement() ?? .blue,
                w: CGFloat.random(in: 6...12),
                h: CGFloat.random(in: 8...16),
                isCircle: Bool.random(),
                fromLeft: fromLeft,
                dx: fromLeft ? spread : -spread,
                peakY: -CGFloat.random(in: 220...480),
                fallY: CGFloat.random(in: 240...560),
                spin: Double.random(in: 360...1080) * (Bool.random() ? 1 : -1)
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    let origin = CGPoint(
                        x: piece.fromLeft ? geo.size.width * 0.06 : geo.size.width * 0.94,
                        y: geo.size.height * 0.96
                    )
                    shape(for: piece)
                        .position(origin)
                        .keyframeAnimator(initialValue: Vals()) { view, value in
                            view
                                .offset(x: value.x, y: value.y)
                                .rotationEffect(.degrees(value.rot))
                                .opacity(value.opacity)
                        } keyframes: { _ in
                            KeyframeTrack(\.x) {
                                LinearKeyframe(piece.dx, duration: 2.0)
                            }
                            KeyframeTrack(\.y) {
                                SpringKeyframe(piece.peakY, duration: 0.55, spring: .bouncy)
                                CubicKeyframe(piece.fallY, duration: 1.45)
                            }
                            KeyframeTrack(\.rot) {
                                LinearKeyframe(piece.spin, duration: 2.0)
                            }
                            KeyframeTrack(\.opacity) {
                                LinearKeyframe(1.0, duration: 1.4)
                                LinearKeyframe(0.0, duration: 0.6)
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
