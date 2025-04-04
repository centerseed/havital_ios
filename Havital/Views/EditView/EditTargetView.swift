import SwiftUI

struct EditTargetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var targetModel: EditTargetViewModel
    
    init(target: Target) {
        // 將 Target 轉換為 ViewModel
        _targetModel = State(initialValue: EditTargetViewModel(target: target))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("賽事資訊")) {
                    TextField("賽事名稱", text: $targetModel.raceName)
                        .textContentType(.name)
                    
                    DatePicker("賽事日期",
                              selection: $targetModel.raceDate,
                              in: Date()...,
                              displayedComponents: .date)
                    
                    Text("距離比賽還有 \(targetModel.remainingWeeks) 週")
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("比賽距離")) {
                    Picker("選擇距離", selection: $targetModel.selectedDistance) {
                        ForEach(Array(targetModel.availableDistances.keys.sorted()), id: \.self) { key in
                            Text(targetModel.availableDistances[key] ?? key)
                                .tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("目標完賽時間")) {
                    HStack {
                        Picker("時", selection: $targetModel.targetHours) {
                            ForEach(0...6, id: \.self) { hour in
                                Text("\(hour)")
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        
                        Text("時")
                        
                        Picker("分", selection: $targetModel.targetMinutes) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text("\(minute)")
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        
                        Text("分")
                    }
                    .padding(.vertical, 8)
                    
                    Text("平均配速：\(targetModel.targetPace) /公里")
                        .foregroundColor(.secondary)
                }
                
                if let error = targetModel.error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("編輯賽事目標")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("儲存") {
                        Task {
                            await targetModel.updateTarget()
                            dismiss()
                        }
                    }
                    .disabled(targetModel.raceName.isEmpty || targetModel.isLoading)
                }
            }
        }
    }
}

@MainActor
class EditTargetViewModel: ObservableObject {
    @Published var raceName = ""
    @Published var raceDate = Date()
    @Published var selectedDistance = "42.195" // 預設全馬
    @Published var targetHours = 4
    @Published var targetMinutes = 0
    @Published var isLoading = false
    @Published var error: String?
    
    private let targetId: String
    
    let availableDistances = [
        "5": "5公里",
        "10": "10公里",
        "21.0975": "半程馬拉松",
        "42.195": "全程馬拉松"
    ]
    
    var remainingWeeks: Int {
        let calendar = Calendar.current
        let weeks = calendar.dateComponents([.weekOfYear],
                                          from: Date(),
                                          to: raceDate).weekOfYear ?? 0
        return max(weeks, 1) // 至少返回1週
    }
    
    var targetPace: String {
        let totalSeconds = (targetHours * 3600 + targetMinutes * 60)
        let distanceKm = Double(selectedDistance) ?? 42.195
        let paceSeconds = Int(Double(totalSeconds) / distanceKm)
        let paceMinutes = paceSeconds / 60
        let paceRemainingSeconds = paceSeconds % 60
        return String(format: "%d:%02d", paceMinutes, paceRemainingSeconds)
    }
    
    init(target: Target) {
        self.targetId = target.id
        self.raceName = target.name
        self.raceDate = Date(timeIntervalSince1970: TimeInterval(target.raceDate))
        
        // 設置距離
        if let distanceStr = availableDistances.keys.first(where: { Int(Double($0) ?? 0) == target.distanceKm }) {
            self.selectedDistance = distanceStr
        }
        
        // 設置目標時間
        self.targetHours = target.targetTime / 3600
        self.targetMinutes = (target.targetTime % 3600) / 60
    }
    
    func updateTarget() async {
        isLoading = true
        error = nil
        
        do {
            let target = Target(
                id: targetId,
                type: "race_run",
                name: raceName,
                distanceKm: Int(Double(selectedDistance) ?? 42.195),
                targetTime: targetHours * 3600 + targetMinutes * 60,
                targetPace: targetPace,
                raceDate: Int(raceDate.timeIntervalSince1970),
                isMainRace: true,
                trainingWeeks: remainingWeeks
            )
            
            // 更新目標賽事
            _ = try await TargetService.shared.updateTarget(id: targetId, target: target)
            print("賽事目標已更新")
        } catch {
            self.error = error.localizedDescription
            print("更新賽事目標失敗: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
}
