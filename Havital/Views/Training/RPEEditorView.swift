import SwiftUI

struct RPEEditorView: View {
    let initialRPE: Int?
    let onSave: (Int?) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRPE: Int = 5
    @State private var isSaving = false
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(NSLocalizedString(L10n.WorkoutDetail.rpeDescription, comment: ""))
                    .font(AppFont.footnote())
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Picker(NSLocalizedString(L10n.WorkoutDetail.rpePickerTitle, comment: ""), selection: $selectedRPE) {
                    ForEach(1...10, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("rpe_editor_picker")

                Text(String(format: NSLocalizedString(L10n.WorkoutDetail.rpeSelectedFormat, comment: ""), selectedRPE))
                    .font(AppFont.headline())
                    .frame(maxWidth: .infinity, alignment: .center)

                Spacer()
            }
            .padding()
            .navigationTitle(NSLocalizedString(L10n.WorkoutDetail.rpeEditorTitle, comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString(L10n.Common.cancel, comment: "")) {
                        dismiss()
                    }
                    .disabled(isSaving)
                    .accessibilityIdentifier("rpe_editor_cancel_button")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString(L10n.Common.save, comment: "")) {
                        save(selectedRPE)
                    }
                    .disabled(isSaving)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("rpe_editor_save_button")
                }

                if initialRPE != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button(NSLocalizedString(L10n.WorkoutDetail.clearRPE, comment: ""), role: .destructive) {
                            save(nil)
                        }
                        .disabled(isSaving)
                        .accessibilityIdentifier("rpe_editor_clear_button")
                    }
                }
            }
            .overlay {
                if isSaving {
                    ProgressView()
                }
            }
            .alert(NSLocalizedString(L10n.WorkoutDetail.rpeSaveError, comment: ""), isPresented: $showError) {
                Button(NSLocalizedString(L10n.Common.ok, comment: ""), role: .cancel) {}
            }
        }
        .onAppear {
            selectedRPE = initialRPE ?? 5
        }
    }

    private func save(_ rpe: Int?) {
        isSaving = true
        Task {
            let success = await onSave(rpe)
            await MainActor.run {
                isSaving = false
                if success {
                    dismiss()
                } else {
                    showError = true
                }
            }
        }
    }
}

#Preview {
    RPEEditorView(initialRPE: nil) { _ in true }
}
