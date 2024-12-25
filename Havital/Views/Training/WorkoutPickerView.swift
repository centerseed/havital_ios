import SwiftUI
import HealthKit

struct WorkoutPickerView: View {
    let day: TrainingDay
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWorkoutType: HKWorkoutActivityType = .running
    @State private var duration: TimeInterval = 1800 // 30分鐘
    @State private var distance: Double = 3.0 // 3公里
    
    var body: some View {
        NavigationView {
            Form {
                Section("運動類型") {
                    Picker("運動類型", selection: $selectedWorkoutType) {
                        Text("跑步").tag(HKWorkoutActivityType.running)
                        Text("步行").tag(HKWorkoutActivityType.walking)
                        Text("騎行").tag(HKWorkoutActivityType.cycling)
                    }
                }
                
                Section("時長") {
                    Picker("時長", selection: $duration) {
                        Text("15分鐘").tag(TimeInterval(900))
                        Text("30分鐘").tag(TimeInterval(1800))
                        Text("45分鐘").tag(TimeInterval(2700))
                        Text("60分鐘").tag(TimeInterval(3600))
                    }
                }
                
                Section("距離") {
                    Picker("距離", selection: $distance) {
                        Text("2公里").tag(2.0)
                        Text("3公里").tag(3.0)
                        Text("5公里").tag(5.0)
                        Text("10公里").tag(10.0)
                    }
                }
                
                Section {
                    Button("新增運動") {
                        addWorkout()
                    }
                }
            }
            .navigationTitle("新增運動")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addWorkout() {
        let startDate = Date(timeIntervalSince1970: TimeInterval(day.startTimestamp))
        let endDate = startDate.addingTimeInterval(duration)
        
        // 創建運動記錄
        let workout = HKWorkout(
            activityType: selectedWorkoutType,
            start: startDate,
            end: endDate,
            duration: duration,
            totalEnergyBurned: nil,
            totalDistance: HKQuantity(unit: .meter(), doubleValue: distance * 1000),
            metadata: nil
        )
        
        // 保存到 HealthKit
        let healthStore = HKHealthStore()
        healthStore.save(workout) { success, error in
            if success {
                print("成功保存運動記錄")
            } else if let error = error {
                print("保存運動記錄失敗：\(error)")
            }
            dismiss()
        }
    }
}
