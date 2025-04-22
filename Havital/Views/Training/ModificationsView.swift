import SwiftUI

struct ModificationsView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var showAddForm = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("描述")) {
                    if viewModel.modDescription.isEmpty {
                        Text("無描述").foregroundColor(.secondary)
                    } else {
                        Text(viewModel.modDescription).foregroundColor(.primary)
                    }
                }
                Section(header: HStack {
                    Text("修改項目")
                    Spacer()
                    Button("清空") {
                        Task { await viewModel.clearAllModifications() }
                    }
                }) {
                    ForEach(Array(viewModel.modifications.enumerated()), id: \.element.content) { index, element in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(element.content)
                                if let expires = element.expiresAt {
                                    Text("到期: \(expires)").font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Toggle("", isOn: Binding(get: { element.applied }, set: { _ in
                                Task { await viewModel.toggleModificationApplied(at: index) }
                            }))
                            .labelsHidden()
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("修改課表")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddForm = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddForm) {
                AddModificationView(viewModel: viewModel)
            }
            .onAppear {
                Task {
                    await viewModel.loadModificationsDescription()
                    await viewModel.loadModifications()
                }
            }
        }
    }
}

struct AddModificationView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var expiresAt = ""
    @State private var isOneTime = false
    @State private var priority = 1

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("內容")) {
                    TextField("請輸入內容", text: $content)
                }
                Section(header: Text("到期時間 (ISO8601 或留空)")) {
                    TextField("YYYY-MM-DDThh:mm:ssZ", text: $expiresAt)
                        .keyboardType(.default)
                }
                Section {
                    Toggle("一次性項目", isOn: $isOneTime)
                    Stepper("優先度: \(priority)", value: $priority, in: 1...10)
                }
            }
            .navigationTitle("新增修改項目")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("新增") {
                        Task {
                            let exp = expiresAt.isEmpty ? nil : expiresAt
                            await viewModel.addModification(content: content, expiresAt: exp, isOneTime: isOneTime, priority: priority)
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
