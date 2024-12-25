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
            }
            .navigationTitle("個人資料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("完成") {
                    dismiss()
                }
            }
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
