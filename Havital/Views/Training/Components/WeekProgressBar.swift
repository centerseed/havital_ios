import SwiftUI

// 週進度條元件
struct WeekProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景
                Capsule()
                    .fill(Color.blue.opacity(0.2))
                    .frame(height: 12)
                
                // 進度條
                Capsule()
                    .fill(Color.blue)
                    .frame(width: max(geometry.size.width * CGFloat(min(progress, 1.0)), 0))
                
                // 指示箭頭
                if progress > 0.03 && progress < 0.97 {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.blue, lineWidth: 2)
                        )
                        .offset(x: geometry.size.width * CGFloat(min(progress, 1.0)) - 4)
                }
            }
        }
        .frame(height: 12)
    }
}

#Preview {
    VStack(spacing: 20) {
        WeekProgressBar(progress: 0.3)
        WeekProgressBar(progress: 0.7)
    }
    .padding()
}
