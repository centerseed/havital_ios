import SwiftUI

struct DebugFailedWorkoutsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date = Date()
    @State private var failureStats: (totalFailed: Int, permanentlyFailed: Int) = (0, 0)
    @State private var refreshTrigger = 0

    var body: some View {
        NavigationView {
            List {
                Section(header: Text(NSLocalizedString("debugfailedworkouts.text_0", comment: "")), footer: Text(NSLocalizedString("debugfailedworkouts.text_1", comment: ""))) {
                    HStack {
                        Text(NSLocalizedString("debugfailedworkouts.text_2", comment: ""))
                        Spacer()
                        Text("\(failureStats.totalFailed)")
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text(NSLocalizedString("debugfailedworkouts.text_3", comment: ""))
                        Spacer()
                        Text("\(failureStats.permanentlyFailed)")
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                }

                Section(header: Text(NSLocalizedString("debugfailedworkouts.text_4", comment: ""))) {
                    DatePicker(
                        NSLocalizedString("debugfailedworkouts.text_4", comment: ""),
                        selection: $selectedDate,
                        displayedComponents: .date
                    )

                    Button(action: {
                        WorkoutUploadTracker.shared.debugFindFailedWorkoutsOnDate(selectedDate)
                        refreshTrigger += 1
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text(NSLocalizedString("debugfailedworkouts.text_5", comment: ""))
                        }
                    }
                }

                Section(header: Text(NSLocalizedString("debugfailedworkouts.text_6", comment: ""))) {
                    Button(action: {
                        WorkoutUploadTracker.shared.debugPrintAllFailedWorkouts()
                        refreshTrigger += 1
                    }) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                            Text(NSLocalizedString("debugfailedworkouts.text_7", comment: ""))
                        }
                    }

                    Button(action: {
                        WorkoutUploadTracker.shared.clearAllFailureRecords()
                        updateStats()
                    }, label: {
                        HStack {
                            Image(systemName: "trash")
                            Text(NSLocalizedString("debugfailedworkouts.text_8", comment: ""))
                        }
                        .foregroundColor(.red)
                    })
                }

                Section(header: Text(NSLocalizedString("debugfailedworkouts.text_9", comment: ""))) {
                    Button(action: {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        print("🔍 [DEBUG] 搜尋日期: \(dateFormatter.string(from: selectedDate))")
                        UIPasteboard.general.string = dateFormatter.string(from: selectedDate)
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text(NSLocalizedString("debugfailedworkouts.text_10", comment: ""))
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("debugfailedworkouts.text_12", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.done", comment: "")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                updateStats()
            }
            .onChange(of: refreshTrigger) { _ in
                updateStats()
            }
        }
    }

    private func updateStats() {
        let stats = WorkoutUploadTracker.shared.getFailureStats()
        self.failureStats = stats
    }
}

#Preview {
    DebugFailedWorkoutsView()
}
