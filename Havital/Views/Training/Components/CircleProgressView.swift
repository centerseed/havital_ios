import SwiftUI

// 跑量圓環元件
struct CircleProgressView: View {
    let progress: Double
    var distanceInfo: String
    var title: String
    var unit: String?
    
    init(progress: Double, distanceInfo: String, title: String = "", unit: String? = nil) {
        self.progress = progress
        self.distanceInfo = distanceInfo
        self.title = title
        self.unit = unit
    }
    
    var body: some View {
        ZStack {
            // 背景環
            Circle()
                .stroke(lineWidth: 10)
                .opacity(0.2)
                .foregroundColor(.blue)
            
            // 進度環
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                .foregroundColor(.blue)
                .rotationEffect(Angle(degrees: -90))
                .animation(.linear, value: progress)
            
            // 跑量資訊和標題
            VStack(spacing: 4) {
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 0) {
                    Text(distanceInfo)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        
                    Text(unit ?? "km")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        CircleProgressView(
            progress: 0.7,
            distanceInfo: "35/50",
            title: "本週跑量"
        )
        .frame(width: 100, height: 100)
        
        CircleProgressView(
            progress: 0.4,
            distanceInfo: "4/10",
            title: "訓練進度",
            unit: "週"
        )
        .frame(width: 100, height: 100)
    }
    .padding()
}
