import SwiftUI

// 加載動畫視圖修飾器
struct LoadingAnimationModifier: ViewModifier {
    @Binding var isLoading: Bool
    let messages: [String]
    let totalDuration: Double
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 3 : 0)
            
            if isLoading {
                LoadingAnimationView(messages: messages, totalDuration: totalDuration)
                    .transition(.opacity)
            }
        }
    }
}

extension View {
    func loadingAnimation(isLoading: Binding<Bool>, messages: [String], totalDuration: Double = 25) -> some View {
        self.modifier(LoadingAnimationModifier(isLoading: isLoading, messages: messages, totalDuration: totalDuration))
    }
}
