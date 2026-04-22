import SwiftUI

struct AddSupportingTargetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddSupportingTargetViewModel()

    var body: some View {
        NavigationView {
            Form {
                // 從資料庫選擇入口 (AC-TREDIT-01)
                Section {
                    NavigationLink {
                        RaceEventListView(
                            dataSource: TargetEditRacePickerViewModel(
                                initialRaceId: viewModel.raceId,
                                onRaceSelected: { [weak viewModel] race, distance in
                                    viewModel?.applyRaceSelection(race, distance: distance)
                                }
                            )
                        )
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet.rectangle.portrait")
                                .foregroundColor(.accentColor)
                            Text(L10n.EditTarget.browseDatabase.localized)
                        }
                    }
                    .accessibilityIdentifier("AddSupportingTarget_BrowseDatabaseButton")
                }

                Section(header: Text(L10n.EditTarget.raceInfo.localized)) {
                    TextField(L10n.EditTarget.raceName.localized, text: $viewModel.raceName)
                        .textContentType(.name)
                        .accessibilityIdentifier("race_name_input")

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
                    Button(L10n.Common.cancel.localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.save.localized) {
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
