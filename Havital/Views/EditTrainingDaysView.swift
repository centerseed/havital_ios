import SwiftUI

@MainActor
class EditTrainingDaysViewModel: ObservableObject {
    @Published var selectedWeekdays: Set<Int>
    @Published var selectedLongRunDay: Int
    @Published var error: String?

    init(initialWeekdays: Set<Int>, initialLongRunDay: Int) {
        self.selectedWeekdays = initialWeekdays
        self.selectedLongRunDay = initialLongRunDay
    }

    func updatePreferences() async {
        do {
            let apiWeekdays = Array(selectedWeekdays)
            let preferences: [String: Any] = [
                "prefer_week_days": apiWeekdays,
                "prefer_week_days_longrun": [selectedLongRunDay]
            ]
            try await UserService.shared.updateUserData(preferences)
        } catch let err {
            self.error = err.localizedDescription
        }
    }
}

struct EditTrainingDaysView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var viewModel: EditTrainingDaysViewModel
    let onSave: () -> Void

    init(initialWeekdays: Set<Int>, initialLongRunDay: Int, onSave: @escaping () -> Void) {
        _viewModel = ObservedObject(wrappedValue: EditTrainingDaysViewModel(initialWeekdays: initialWeekdays,
                                                                            initialLongRunDay: initialLongRunDay))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(NSLocalizedString("training_days.select_general_days", comment: "Select General Training Days"))) {
                    ForEach(1..<8) { weekday in
                        let isSelected = viewModel.selectedWeekdays.contains(weekday)
                        Button(action: {
                            if isSelected {
                                viewModel.selectedWeekdays.remove(weekday)
                            } else {
                                viewModel.selectedWeekdays.insert(weekday)
                            }
                        }) {
                            HStack {
                                Text(getWeekdayName(weekday))
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }

                Section(header: Text(NSLocalizedString("training_days.long_run_day_weekend", comment: "Long Run Day (Recommend Weekend)")).padding(.top, 10)) {
                    Picker(NSLocalizedString("training_days.long_run_day", comment: "Long Run Day"), selection: $viewModel.selectedLongRunDay) {
                        ForEach(1..<8) { weekday in
                            Text(getWeekdayName(weekday)).tag(weekday)
                        }
                    }
                }

                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("training_days.edit_title", comment: "Edit Training Days"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("training_days.save", comment: "Save")) {
                        Task {
                            await viewModel.updatePreferences()
                            onSave()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    // Helper for weekday name
    private func getWeekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return NSLocalizedString("date.monday", comment: "Monday")
        case 2: return NSLocalizedString("date.tuesday", comment: "Tuesday")
        case 3: return NSLocalizedString("date.wednesday", comment: "Wednesday")
        case 4: return NSLocalizedString("date.thursday", comment: "Thursday")
        case 5: return NSLocalizedString("date.friday", comment: "Friday")
        case 6: return NSLocalizedString("date.saturday", comment: "Saturday")
        case 7: return NSLocalizedString("date.sunday", comment: "Sunday")
        default: return ""
        }
    }
}
