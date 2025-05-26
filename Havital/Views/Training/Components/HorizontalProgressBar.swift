import SwiftUI

// 水平進度條
struct HorizontalProgressBar: View {
    var progress: Double
    var color: Color
    var height: CGFloat = 8
    var showDashed: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景
                RoundedRectangle(cornerRadius: height / 2)
                    .frame(width: geometry.size.width, height: height)
                    .foregroundColor(color.opacity(0.1))
                
                if showDashed {
                    // 虛線樣式
                    HStack(spacing: 2) {
                        ForEach(0..<Int(geometry.size.width / 6), id: \.self) { i in
                            Rectangle()
                                .frame(width: 4, height: height)
                                .foregroundColor(color.opacity(0.6))
                        }
                    }
                    .frame(width: geometry.size.width, alignment: .leading)
                } else {
                    // 實線樣式
                    RoundedRectangle(cornerRadius: height / 2)
                        .frame(width: min(progress * geometry.size.width, geometry.size.width), height: height)
                        .foregroundColor(color)
                        .animation(.linear, value: progress)
                }
            }
        }
        .frame(height: height)
    }
}

#Preview {
    VStack(spacing: 20) {
        HorizontalProgressBar(progress: 0.7, color: .blue)
        HorizontalProgressBar(progress: 0.4, color: .green)
        HorizontalProgressBar(progress: 0.9, color: .orange, showDashed: true)
    }
    .padding()
}
