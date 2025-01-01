import SwiftUI

struct GoalWheelView: View {
    let goalType: String
    @Binding var value: Int
    @Environment(\.dismiss) private var dismiss
    
    private var minValue: Int {
        switch goalType {
        case "heart_rate":
            return 80
        case "pace":
            return 3 * 60  // 3分鐘/公里
        default:
            return 0
        }
    }
    
    private var maxValue: Int {
        switch goalType {
        case "heart_rate":
            return 200
        case "pace":
            return 10 * 60  // 10分鐘/公里
        default:
            return 0
        }
    }
    
    private var stepValue: Int {
        switch goalType {
        case "heart_rate":
            return 1
        case "pace":
            return 5  // 5秒
        default:
            return 1
        }
    }
    
    private var wheelValues: [Int] {
        Array(stride(from: minValue, through: maxValue, by: stepValue))
    }
    
    private func formatValue(_ value: Int) -> String {
        switch goalType {
        case "heart_rate":
            return "\(value)"
        case "pace":
            let minutes = value / 60
            let seconds = value % 60
            return String(format: "%d:%02d", minutes, seconds)
        default:
            return "\(value)"
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(goalType == "heart_rate" ? "目標心率" : "目標配速")
                .font(.title2)
            
            Picker("", selection: $value) {
                ForEach(wheelValues, id: \.self) { val in
                    Text(formatValue(val))
                        .tag(val)
                }
            }
            .pickerStyle(.wheel)
            
            if goalType == "pace" {
                Text("/公里")
            } else if goalType == "heart_rate" {
                Text("bpm")
            }
            
            Spacer()
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") {
                    dismiss()
                }
            }
        }
        .task {
            // 確保初始值在有效範圍內
            if !wheelValues.contains(value) {
                value = wheelValues[wheelValues.count / 2]
            }
        }
    }
}

struct GoalWheelContainer: View {
    let goalType: String
    @Binding var value: Int
    
    var body: some View {
        NavigationStack {
            GoalWheelView(goalType: goalType, value: $value)
        }
    }
}

#Preview {
    GoalWheelContainer(goalType: "heart_rate", value: .constant(120))
}
