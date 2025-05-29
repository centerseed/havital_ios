import SwiftUI

struct TargetRaceCard: View {
    let target: Target
    let onEditTap: () -> Void  // 添加一個回調函數
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 16) {
                // 標題與編輯按鈕
                HStack {
                    SectionHeader(title: "目標賽事", systemImage: "flag.filled.and.flag.crossed")
                    
                    Spacer()
                    
                    Button(action: {
                        onEditTap()
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                }
                
                // 賽事基本資訊
                VStack(alignment: .leading, spacing: 10) {
                    // 名稱
                    HStack(alignment: .center, spacing: 12) {
                        Text(target.name)
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // 計算賽事日期距今天數
                        let daysRemaining = TrainingDateUtils.calculateDaysRemaining(raceDate: target.raceDate)
                        Text("\(daysRemaining)天")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.15))
                            )
                    }
                    
                    // 日期、距離和倒數天數在同一行
                    HStack(alignment: .center, spacing: 12) {
                        // 日期
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            
                            Text(formatDate(target.raceDate))
                                .font(.subheadline)
                        }
                        
                        Spacer()
                        
                        // 距離
                        Text("\(target.distanceKm) 公里")
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.green.opacity(0.15))
                            )
                        
                    }
                    
                    // 目標完賽時間與配速
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("目標完賽時間")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(formatTime(target.targetTime))
                                .font(.headline)
                        }
                        
                        Divider()
                            .frame(height: 30)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("目標配速")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(target.targetPace) /公里")
                                .font(.headline)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(UIColor.systemGray5) : Color(UIColor.systemGray6).opacity(0.5))
                    )
                }
            }
        }
    }

    // 格式化日期
    private func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
    
    // 格式化時間
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
    

}
