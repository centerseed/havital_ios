import SwiftUI

struct EditSupportingTargetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EditSupportingTargetViewModel
    
    init(target: Target) {
        _viewModel = StateObject(wrappedValue: EditSupportingTargetViewModel(target: target))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("賽事資訊")) {
                    TextField("賽事名稱", text: $viewModel.raceName)
                        .textContentType(.name)
                    
                    DatePicker("賽事日期",
                              selection: $viewModel.raceDate,
                              in: Date()...,
                              displayedComponents: .date)
                }
                
                Section(header: Text("比賽距離")) {
                    Picker("選擇距離", selection: $viewModel.selectedDistance) {
                        ForEach(Array(viewModel.availableDistances.keys.sorted()), id: \.self) { key in
                            Text(viewModel.availableDistances[key] ?? key)
                                .tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("目標完賽時間")) {
                    HStack {
                        Picker("時", selection: $viewModel.targetHours) {
                            ForEach(0...6, id: \.self) { hour in
                                Text("\(hour)")
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        
                        Text("時")
                        
                        Picker("分", selection: $viewModel.targetMinutes) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text("\(minute)")
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        
                        Text("分")
                    }
                    .padding(.vertical, 8)
                    
                    Text("平均配速：\(viewModel.targetPace) /公里")
                        .foregroundColor(.secondary)
                }
                
                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button("刪除賽事") {
                        viewModel.showDeleteConfirmation = true
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("編輯支援賽事")
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
                            if await viewModel.updateTarget() {
                                NotificationCenter.default.post(name: .supportingTargetUpdated, object: nil)
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.raceName.isEmpty || viewModel.isLoading)
                }
            }
            .alert("確認刪除", isPresented: $viewModel.showDeleteConfirmation) {
                Button("取消", role: .cancel) { }
                Button("刪除", role: .destructive) {
                    Task {
                        if await viewModel.deleteTarget() {
                            NotificationCenter.default.post(name: .supportingTargetUpdated, object: nil)
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("確定要刪除這個支援賽事嗎？此操作無法復原。")
            }
        }
    }
}

#Preview {
    // 為預覽創建一個範例 Target
    let sampleTarget = Target(
        id: "preview-id",
        type: "race_run",
        name: "支援半馬",
        distanceKm: 21,
        targetTime: 7200, // 2小時
        targetPace: "5:40",
        raceDate: Int(Date().timeIntervalSince1970) + 30*24*60*60, // 30天後
        isMainRace: false,
        trainingWeeks: 8
    )
    
    return EditSupportingTargetView(target: sampleTarget)
}
