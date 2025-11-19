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
                
                Section {
                    Button(L10n.EditTarget.deleteRace.localized) {
                        viewModel.showDeleteConfirmation = true
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle(L10n.EditTarget.editTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Common.cancel.localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.save.localized) {
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
            .alert(L10n.EditTarget.deleteConfirmTitle.localized, isPresented: $viewModel.showDeleteConfirmation) {
                Button(L10n.Common.cancel.localized, role: .cancel) { }
                Button(L10n.Common.delete.localized, role: .destructive) {
                    Task {
                        if await viewModel.deleteTarget() {
                            NotificationCenter.default.post(name: .supportingTargetUpdated, object: nil)
                            dismiss()
                        }
                    }
                }
            } message: {
                Text(L10n.EditTarget.deleteConfirmMessage.localized)
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
