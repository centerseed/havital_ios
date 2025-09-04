import SwiftUI

struct GoalWheelView: View {
    let goalType: String
    @Binding var value: Int
    @Environment(\.dismiss) private var dismiss
    
    init(goalType: String, value: Binding<Int>) {
        print("GoalWheelView init - goalType: \(goalType), value: \(value.wrappedValue)")
        self.goalType = goalType
        self._value = value
    }
    
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
            Text(goalType == "heart_rate" ? NSLocalizedString("goal_wheel.target_heart_rate", comment: "Target Heart Rate") : NSLocalizedString("goal_wheel.target_pace", comment: "Target Pace"))
                .font(.title2)
            
            Picker("", selection: $value) {
                ForEach(wheelValues, id: \.self) { val in
                    Text(formatValue(val))
                        .tag(val)
                }
            }
            .pickerStyle(.wheel)
            .onAppear {
                print("GoalWheelView Picker onAppear - wheelValues count: \(wheelValues.count)")
                print("GoalWheelView Picker onAppear - current value: \(value)")
                print("GoalWheelView Picker onAppear - wheelValues: \(wheelValues)")
            }
            
            if goalType == "pace" {
                Text(NSLocalizedString("goal_wheel.per_kilometer", comment: "Per Kilometer"))
            } else if goalType == "heart_rate" {
                Text(NSLocalizedString("goal_wheel.bpm", comment: "BPM"))
            }
            
            Spacer()
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(NSLocalizedString("goal_wheel.done", comment: "Done")) {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button(NSLocalizedString("goal_wheel.cancel", comment: "Cancel")) {
                    dismiss()
                }
            }
        }
        .task {
            // Ensure initial value is within valid range
            if !wheelValues.contains(value) {
                value = wheelValues[wheelValues.count / 2]
            }
        }
    }
}

struct GoalWheelContainer: View {
    let goalType: String
    @Binding var value: Int
    
    init(goalType: String, value: Binding<Int>) {
        print("GoalWheelContainer init - goalType: \(goalType), value: \(value.wrappedValue)")
        self.goalType = goalType
        self._value = value
    }
    
    var body: some View {
        NavigationStack {
            GoalWheelView(goalType: goalType, value: $value)
                .onAppear {
                    print("GoalWheelContainer onAppear")
                }
        }
    }
}

#Preview {
    GoalWheelContainer(goalType: "heart_rate", value: .constant(120))
}
