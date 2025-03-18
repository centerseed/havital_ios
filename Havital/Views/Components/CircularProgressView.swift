import SwiftUI

struct OldCircularProgressView: View {
    let progress: Double
    let currentWeek: Int
    let totalWeeks: Int
    
    var body: some View {
        ZStack {
            // Background Circle
            Circle()
                .stroke(
                    Color.gray.opacity(0.3),
                    lineWidth: 8
                )
            
            // Progress Circle
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.6)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(
                        lineWidth: 8,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: progress)
            
            // Text in the center
            VStack(spacing: 2) {
                Text("\(currentWeek)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("/ \(totalWeeks)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("週")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct CircularProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            CircularProgressView(
                progress: 0.25,
                currentWeek: 2,
                totalWeeks: 8
            )
            .frame(width: 100, height: 100)
        }
    }
}
