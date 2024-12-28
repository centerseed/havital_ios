import SwiftUI

struct UserPreferenceView: View {
    let preference: UserPreference?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("基本資料") {
                    InfoRow(title: "姓名", value: preference?.userName ?? "未設定")
                    InfoRow(title: "信箱", value: preference?.userEmail ?? "未設定")
                    InfoRow(title: "年齡", value: "\(preference?.age ?? 0)歲")
                }
                
                Section("身體數據") {
                    InfoRow(title: "身高", value: String(format: "%.1f cm", preference?.bodyHeight ?? 0))
                    InfoRow(title: "體重", value: String(format: "%.1f kg", preference?.bodyWeight ?? 0))
                    InfoRow(title: "體脂率", value: String(format: "%.1f%%", preference?.bodyFat ?? 0))
                }
                
                Section("運動能力評估") {
                    LevelRow(title: "有氧運動能力", level: preference?.aerobicsLevel ?? 0)
                    LevelRow(title: "肌力訓練程度", level: preference?.strengthLevel ?? 0)
                    LevelRow(title: "生活忙碌程度", level: preference?.busyLevel ?? 0)
                    LevelRow(title: "運動主動性", level: preference?.proactiveLevel ?? 0)
                }
                
                Section("可運動時間") {
                    ForEach(0..<7, id: \.self) { weekday in
                        if let workoutDays = preference?.workoutDays, workoutDays.contains(weekday) {
                            HStack {
                                Text(getWeekdayString(weekday: weekday))
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                Section("偏好運動") {
                    if let workouts = preference?.preferredWorkouts {
                        ForEach(Array(workouts), id: \.self) { workout in
                            HStack {
                                Text(getWorkoutDisplayName(workout))
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("個人資料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("完成") {
                    dismiss()
                    if let data = try? JSONEncoder().encode(preference) {
                        print(String(data: data, encoding: .utf8)!)
                    }
                }
            }
        }
    }
    
    private func getWeekdayString(weekday: Int) -> String {
        switch weekday {
        case 0:
            return "星期日"
        case 1:
            return "星期一"
        case 2:
            return "星期二"
        case 3:
            return "星期三"
        case 4:
            return "星期四"
        case 5:
            return "星期五"
        case 6:
            return "星期六"
        default:
            return ""
        }
    }
    
    private func getWorkoutDisplayName(_ name: String) -> String {
        switch name {
        case "runing":
            return "跑步"
        case "jump_rope":
            return "跳繩"
        case "super_slow_run":
            return "超慢跑"
        case "hiit":
            return "高強度間歇訓練"
        case "strength_training":
            return "肌力訓練"
        default:
            return name
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
        }
    }
}

struct LevelRow: View {
    let title: String
    let level: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { index in
                    Rectangle()
                        .fill(index < level ? .primary : Color.gray.opacity(0.3))
                        .frame(height: 8)
                        .cornerRadius(4)
                }
            }
        }
    }
}

#Preview {
    UserPreferenceView(preference: nil)
}
