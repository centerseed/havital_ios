import SwiftUI

struct WeeklyDistanceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @Binding var distance: Int
    @State private var editingDistance: Int
    let onSave: (Int) -> Void
    
    init(distance: Binding<Int>, onSave: @escaping (Int) -> Void) {
        self._distance = distance
        self.onSave = onSave
        self._editingDistance = State(initialValue: distance.wrappedValue)
        print("初始化週跑量編輯器，傳入值: \(distance.wrappedValue)")
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
                            Text("週跑量：\(editingDistance) 公里")
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
                    
                    Text("當週跑量的修改會在下一週的課表生效")
                        .font(.body)
                }
            }
            .navigationTitle("編輯週跑量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("儲存") {
                        DispatchQueue.main.async {
                            distance = editingDistance
                            onSave(editingDistance)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    struct Preview: View {
        @State private var distance = 30
        
        var body: some View {
            WeeklyDistanceEditorView(distance: $distance) { _ in }
        }
    }
    
    return Preview()
}
