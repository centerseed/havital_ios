import SwiftUI

struct AddSupportingTargetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddSupportingTargetViewModel()
    
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
            }
            .navigationTitle("添加支援賽事")
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
                            if await viewModel.createTarget() {
                                NotificationCenter.default.post(name: .supportingTargetUpdated, object: nil)
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.raceName.isEmpty || viewModel.isLoading)
                }
            }
        }
    }
}

#Preview {
    AddSupportingTargetView()
}
