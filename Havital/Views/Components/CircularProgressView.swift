import SwiftUI

struct CircularProgressView: View {
    let progress: Double
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: progress)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, height: 80)
        }
    }
}

#Preview {
    HStack {
        CircularProgressView(
            progress: 0.75,
            title: "3/4",
            subtitle: "總進度",
            color: .blue
        )
        CircularProgressView(
            progress: 0.5,
            title: "2/4",
            subtitle: "本週進度",
            color: .green
        )
    }
}
