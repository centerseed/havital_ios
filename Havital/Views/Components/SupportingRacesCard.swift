import SwiftUI

struct SupportingRacesCard: View {
    let supportingTargets: [Target]
    let onAddTap: () -> Void
    let onEditTap: (Target) -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 16) {
                // 標題與添加按鈕
                HStack {
                    SectionHeader(title: "支援賽事", systemImage: "flag.2.crossed")
                    
                    Spacer()
                    
                    Button(action: {
                        onAddTap()
                    }) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                    }
                }
                
                if supportingTargets.isEmpty {
                    HStack {
                        Spacer()
                        Text("暫無支援賽事")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                        Spacer()
                    }
                } else {
                    // 支援賽事列表 - 排序由近到遠
                    ForEach(supportingTargets, id: \.id) { target in
                        SupportingRaceRow(target: target) {
                            onEditTap(target)
                        }
                    }
                }
            }
        }
    }
}

struct SupportingRaceRow: View {
    let target: Target
    let onEditTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: {
            onEditTap()
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 12) {
                    // 賽事名稱
                    Text(target.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // 賽事日期
                    Text(formatDate(target.raceDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // 距離
                    Text("\(target.distanceKm)公里")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.green.opacity(0.15))
                        )
                    
                    // 配速
                    Text("\(target.targetPace)/km")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.opacity(0.15))
                        )
                    
                    // 編輯按鈕 (可選)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // 顯示剩餘天數 (如果小於等於 30 天則顯示)
                let daysRemaining = calculateDaysRemaining(raceDate: target.raceDate)
                if daysRemaining <= 30 {
                    Text("剩餘 \(daysRemaining) 天")
                        .font(.caption)
                        .foregroundColor(daysRemaining <= 7 ? .red : .orange)
                        .padding(.top, 2)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // 格式化日期
    private func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    // 計算賽事日期距今天數
    private func calculateDaysRemaining(raceDate: Int) -> Int {
        let raceDay = Date(timeIntervalSince1970: TimeInterval(raceDate))
        let today = Date()
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: today, to: raceDay)
        
        return max(components.day ?? 0, 0) // 確保不為負數
    }
}
