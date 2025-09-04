import SwiftUI

struct AddSupportingTargetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddSupportingTargetViewModel()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(L10n.EditTarget.raceInfo.localized)) {
                    TextField(L10n.EditTarget.raceName.localized, text: $viewModel.raceName)
                        .textContentType(.name)
                    
                    DatePicker(L10n.EditTarget.raceDate.localized,
                              selection: $viewModel.raceDate,
                              in: Date()...,
                              displayedComponents: .date)
                }
                
                Section(header: Text(L10n.EditTarget.raceDistance.localized)) {
                    Picker(L10n.EditTarget.selectDistance.localized, selection: $viewModel.selectedDistance) {
                        ForEach(Array(viewModel.availableDistances.keys.sorted()), id: \.self) { key in
                            Text(viewModel.availableDistances[key] ?? key)
                                .tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text(L10n.EditTarget.targetTime.localized)) {
                    HStack {
                        Picker(L10n.EditTarget.hoursUnit.localized, selection: $viewModel.targetHours) {
                            ForEach(0...6, id: \.self) { hour in
                                Text("\(hour)")
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        
                        Text(L10n.EditTarget.hoursUnit.localized)
                        
                        Picker(L10n.EditTarget.minutesUnit.localized, selection: $viewModel.targetMinutes) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text("\(minute)")
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        
                        Text(L10n.EditTarget.minutesUnit.localized)
                    }
                    .padding(.vertical, 8)
                    
                    Text(L10n.EditTarget.averagePace.localized(with: viewModel.targetPace))
                        .foregroundColor(.secondary)
                }
                
                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(L10n.EditTarget.addTitle.localized)
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
