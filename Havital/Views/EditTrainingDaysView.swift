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
                Section(header: Text("選擇一般訓練日")) {
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

                Section(header: Text("長跑日（建議週末）").padding(.top, 10)) {
                    Picker("長跑日", selection: $viewModel.selectedLongRunDay) {
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
            .navigationTitle("編輯訓練日")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
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
        case 1: return "週一"
        case 2: return "週二"
        case 3: return "週三"
        case 4: return "週四"
        case 5: return "週五"
        case 6: return "週六"
        case 7: return "週日"
        default: return ""
        }
    }
}
