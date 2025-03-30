import SwiftUI

struct ClickableCircularProgressView: View {
    let progress: Double
    let currentWeek: Int
    let totalWeeks: Int
    var action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // 背景圓環
                Circle()
                    .stroke(lineWidth: 10)
                    .opacity(0.3)
                    .foregroundColor(.gray)
                
                // 進度圓環
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                    .foregroundColor(.blue)
                    .rotationEffect(Angle(degrees: 270.0))
                
                // 小圓點指示器（在進度條的末端）
                if progress > 0.05 && progress < 0.99 {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                        .offset(
                            x: cos(2 * .pi * progress - .pi / 2) * 35,
                            y: sin(2 * .pi * progress - .pi / 2) * 35
                        )
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                }
                
                // 中心文字
                VStack(spacing: 2) {
                    Text("\(currentWeek)")
                        .font(.system(size: 22, weight: .bold))
                    
                    Text("/ \(totalWeeks)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text("週")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
            .contentShape(Circle()) // 確保整個圓形區域都可點擊
        }
        .buttonStyle(PlainButtonStyle())
        .pressAction(
            onPress: { withAnimation { isPressed = true } },
            onRelease: { withAnimation { isPressed = false } }
        )
    }
}

// 用於處理按壓效果的修飾器
struct PressActionModifier: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

extension View {
    func pressAction(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressActionModifier(onPress: onPress, onRelease: onRelease))
    }
}

// 預覽
struct ClickableCircularProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ClickableCircularProgressView(
            progress: 0.65,
            currentWeek: 13,
            totalWeeks: 20,
            action: {}
        )
        .frame(width: 100, height: 100)
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
