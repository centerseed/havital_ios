import SwiftUI

struct DebugFailedWorkoutsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date = Date()
    @State private var failureStats: (totalFailed: Int, permanentlyFailed: Int) = (0, 0)
    @State private var refreshTrigger = 0

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("失敗統計"), footer: Text("顯示失敗的運動上傳記錄")) {
                    HStack {
                        Text("總失敗")
                        Spacer()
                        Text("\(failureStats.totalFailed)")
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("永久失敗 (達最大重試)")
                        Spacer()
                        Text("\(failureStats.permanentlyFailed)")
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                }

                Section(header: Text("按日期搜尋")) {
                    DatePicker(
                        "選擇日期",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )

                    Button(action: {
                        WorkoutUploadTracker.shared.debugFindFailedWorkoutsOnDate(selectedDate)
                        refreshTrigger += 1
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("搜尋此日期的失敗記錄")
                        }
                    }
                }

                Section(header: Text("全部記錄")) {
                    Button(action: {
                        WorkoutUploadTracker.shared.debugPrintAllFailedWorkouts()
                        refreshTrigger += 1
                    }) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                            Text("打印所有失敗記錄")
                        }
                    }

                    Button(action: {
                        WorkoutUploadTracker.shared.clearAllFailureRecords()
                        updateStats()
                    }, label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("清除所有失敗記錄")
                        }
                        .foregroundColor(.red)
                    })
                }

                Section(header: Text("其他功能")) {
                    Button(action: {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        print("🔍 [DEBUG] 搜尋日期: \(dateFormatter.string(from: selectedDate))")
                        UIPasteboard.general.string = dateFormatter.string(from: selectedDate)
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("複製日期格式")
                        }
                    }
                }
            }
            .navigationTitle("調試 - 失敗運動")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
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
