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
                Section(header: Text(L10n.EditTarget.raceInfo.localized)) {
                    TextField(L10n.EditTarget.raceName.localized, text: $targetModel.raceName)
                        .textContentType(.name)
                    
                    DatePicker(L10n.EditTarget.raceDate.localized,
                              selection: $targetModel.raceDate,
                              in: Date()...,
                              displayedComponents: .date)
                    
                    Text(L10n.EditTarget.remainingWeeks.localized(with: targetModel.remainingWeeks))
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text(L10n.EditTarget.raceDistance.localized)) {
                    Picker(L10n.EditTarget.selectDistance.localized, selection: $targetModel.selectedDistance) {
                        ForEach(Array(targetModel.availableDistances.keys.sorted()), id: \.self) { key in
                            Text(targetModel.availableDistances[key] ?? key)
                                .tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text(L10n.EditTarget.targetTime.localized)) {
                    HStack {
                        Picker(L10n.EditTarget.hoursUnit.localized, selection: $targetModel.targetHours) {
                            ForEach(0...6, id: \.self) { hour in
                                Text("\(hour)")
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        
                        Text(L10n.EditTarget.hoursUnit.localized)
                        
                        Picker(L10n.EditTarget.minutesUnit.localized, selection: $targetModel.targetMinutes) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text("\(minute)")
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        
                        Text(L10n.EditTarget.minutesUnit.localized)
                    }
                    .padding(.vertical, 8)
                    
                    Text(L10n.EditTarget.averagePace.localized(with: targetModel.targetPace))
                        .foregroundColor(.secondary)
                }
                
                if let error = targetModel.error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(L10n.EditTarget.title.localized)
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
    private let originalTrainingWeeks: Int
    private let originalTimezone: String  // 🔧 保存原始時區
    
    // 移動到類別層級的可用距離選項
    var availableDistances: [String: String] {
        [
            "5": L10n.EditTarget.distance5k.localized,
            "10": L10n.EditTarget.distance10k.localized,
            "21.0975": L10n.EditTarget.distanceHalf.localized,
            "42.195": L10n.EditTarget.distanceFull.localized
        ]
    }
    
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
        self.originalTrainingWeeks = target.trainingWeeks
        self.originalTimezone = target.timezone  // 🔧 保存原始時區

        // 初始化當前值
        self.raceName = target.name
        self.raceDate = Date(timeIntervalSince1970: TimeInterval(target.raceDate))
        
        // 創建臨時的可用距離字典來查找匹配的距離
        let distances: [String: String] = [
            "5": L10n.EditTarget.distance5k.localized,
            "10": L10n.EditTarget.distance10k.localized,
            "21.0975": L10n.EditTarget.distanceHalf.localized,
            "42.195": L10n.EditTarget.distanceFull.localized
        ]
        
        // 設置距離並保存原始距離值
        if let distanceStr = distances.keys.first(where: { Int(Double($0) ?? 0) == target.distanceKm }) {
            self.selectedDistance = distanceStr
            self.originalDistance = distanceStr
        } else {
            self.selectedDistance = "42.195" // 預設值
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
                trainingWeeks: remainingWeeks,
                timezone: originalTimezone  // 🔧 保持原始時區設定
            )
            
            // 更新目標賽事
            _ = try await TargetService.shared.updateTarget(id: targetId, target: target)
            
            // 檢查是否有重要變更（距離、完賽時間或訓練週數）
            let currentTargetTime = targetHours * 3600 + targetMinutes * 60
            let currentTrainingWeeks = remainingWeeks
            let hasSignificantChange = (selectedDistance != originalDistance) ||
                                     (currentTargetTime != originalTargetTime) ||
                                     (currentTrainingWeeks != originalTrainingWeeks)
            
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
