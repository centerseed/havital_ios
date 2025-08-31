import SwiftUI
import Combine

struct EditTargetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var targetModel: EditTargetViewModel
    
    init(target: Target) {
        // 將 Target 轉換為 ViewModel
        _targetModel = StateObject(wrappedValue: EditTargetViewModel(target: target))
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
                            if let hasSignificantChange = await targetModel.updateTarget() {
                                // 無論是否有重要變更，都發送通知並關閉視圖
                                NotificationCenter.default.post(
                                    name: .targetUpdated, 
                                    object: nil, 
                                    userInfo: ["hasSignificantChange": hasSignificantChange]
                                )
                                dismiss()
                            }
                            // 如果回傳 nil（更新失敗），則不關閉視圖
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
    
    // 儲存原始值用於變更檢測
    private let originalDistance: String
    private let originalTargetTime: Int
    
    let availableDistances = [
        "5": "5公里",
        "10": "10公里",
        "21.0975": "半程馬拉松",
        "42.195": "全程馬拉松"
    ]
    
    var remainingWeeks: Int {
        let isoFormatter = ISO8601DateFormatter()
        // 設定格式選項以包含日期、時間和時區資訊，以及可選的毫秒數
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let currentDateISO = isoFormatter.string(from: Date())

        // 使用 TrainingDateUtils 中的方法計算週數
        // createdAt 設定為當前時間, now 設定為比賽日期 (raceDate)
        if let calculatedWeeks = TrainingDateUtils.calculateCurrentTrainingWeek(createdAt: currentDateISO, now: self.raceDate) {
            // TrainingDateUtils.calculateCurrentTrainingWeek 已經確保結果至少為 1
            return calculatedWeeks
        } else {
            // 若計算失敗（理論上 currentDateISO 應該總是有效的），提供一個備用值
            // 這裡可以加入日誌記錄錯誤
            print("Error: Could not calculate remaining weeks using TrainingDateUtils. Defaulting to 1.")
            return 1
        }
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
        
        // 先初始化原始值
        self.originalTargetTime = target.targetTime
        
        // 初始化當前值
        self.raceName = target.name
        self.raceDate = Date(timeIntervalSince1970: TimeInterval(target.raceDate))
        
        // 設置距離並保存原始距離值
        if let distanceStr = availableDistances.keys.first(where: { Int(Double($0) ?? 0) == target.distanceKm }) {
            self.selectedDistance = distanceStr
            self.originalDistance = distanceStr
        } else {
            self.originalDistance = "42.195" // 預設值
        }
        
        // 設置目標時間
        self.targetHours = target.targetTime / 3600
        self.targetMinutes = (target.targetTime % 3600) / 60
    }
    
    func updateTarget() async -> Bool? {
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
            
            // 檢查是否有重要變更（距離或完賽時間）
            let currentTargetTime = targetHours * 3600 + targetMinutes * 60
            let hasSignificantChange = (selectedDistance != originalDistance) || (currentTargetTime != originalTargetTime)
            
            print("賽事目標已更新，重要變更: \(hasSignificantChange)")
            isLoading = false
            return hasSignificantChange
        } catch {
            self.error = error.localizedDescription
            print("更新賽事目標失敗: \(error.localizedDescription)")
            isLoading = false
            return nil
        }
    }
}
