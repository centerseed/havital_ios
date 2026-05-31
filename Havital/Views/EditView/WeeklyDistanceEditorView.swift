import SwiftUI

struct WeeklyDistanceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var editingDistance: Int
    let onSave: (Int) -> Void

    init(initial: Int, onSave: @escaping (Int) -> Void) {
        self._editingDistance = State(initialValue: initial)
        self.onSave = onSave
    }
    
    
    var body: some View {
        NavigationView {
            Form {
                VStack {
                    Section {
                        // 使用Stepper或Slider控制週跑量
                        Stepper(value: Binding(
                            get: { editingDistance },
                            set: { newValue in
                                DispatchQueue.main.async {
                                    editingDistance = newValue
                                }
                            }
                        ), in: 5...120 ) {
                            Text(L10n.WeeklyDistanceEditor.weeklyDistance.localized(with: editingDistance))
                        }
                        
                        // 可選：添加滑塊以便更直觀地調整
                        Slider(value: Binding<Double>(
                            get: { Double(editingDistance) },
                            set: { newValue in
                                DispatchQueue.main.async {
                                    editingDistance = Int(newValue)
                                }
                            }
                        ), in: 1...100, step: 1)
                        .padding(.vertical)
                    }
                    
                    Text(L10n.WeeklyDistanceEditor.nextWeekNotice.localized)
                        .font(AppFont.body())
                }
            }
            .navigationTitle(L10n.WeeklyDistanceEditor.title.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Common.cancel.localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.save.localized) {
                        onSave(editingDistance)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    WeeklyDistanceEditorView(initial: 30) { _ in }
}
