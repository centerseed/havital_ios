import SwiftUI

// MARK: - Treadmill Correction View
/// 跑步機里程校正輸入介面（sheet）
/// 只在 activityType == "running" 且 sportType == "treadmill_running" 時由呼叫端顯示。
struct TreadmillCorrectionView: View {

    // MARK: - Dependencies

    let currentCorrection: TreadmillCorrection?
    /// 呼叫端預計算：當前訓練是否已完成過跑步機校正
    let isAlreadyCorrected: Bool

    /// 校正成功後由呼叫端執行（回傳是否成功）
    let onApply: (Double, Double?, String?) async -> Bool

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var actualDistanceText: String = ""
    @State private var avgInclineText: String = ""
    @State private var notesText: String = ""

    @State private var isApplying: Bool = false
    @State private var resultMessage: String?
    @State private var showResultAlert: Bool = false

    // MARK: - Validation error state

    @State private var distanceErrorMessage: String?
    @State private var inclineErrorMessage: String?
    @State private var notesErrorMessage: String?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(L10n.WorkoutDetail.treadmillCorrectionDescription.localized)
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)
                }

                if isAlreadyCorrected, let dist = currentCorrection?.actualDistanceM {
                    Section(L10n.WorkoutDetail.treadmillCorrectionApplied.localized) {
                        Text(String(format: L10n.WorkoutDetail.treadmillCorrectionAppliedDistance.localized, dist))
                            .font(AppFont.bodySmall())
                    }
                }

                Section(L10n.WorkoutDetail.treadmillCorrectionActualDistance.localized) {
                    TextField(
                        L10n.WorkoutDetail.treadmillCorrectionDistancePlaceholder.localized,
                        text: $actualDistanceText
                    )
                    .keyboardType(.decimalPad)
                    .onChange(of: actualDistanceText) { _, _ in
                        distanceErrorMessage = nil
                    }

                    if let err = distanceErrorMessage {
                        Text(err)
                            .font(AppFont.captionSmall())
                            .foregroundColor(.red)
                    }
                }

                Section(L10n.WorkoutDetail.treadmillCorrectionIncline.localized) {
                    TextField(
                        L10n.WorkoutDetail.treadmillCorrectionInclinePlaceholder.localized,
                        text: $avgInclineText
                    )
                    .keyboardType(.decimalPad)
                    .onChange(of: avgInclineText) { _, _ in
                        inclineErrorMessage = nil
                    }

                    if let err = inclineErrorMessage {
                        Text(err)
                            .font(AppFont.captionSmall())
                            .foregroundColor(.red)
                    }
                }

                Section(L10n.WorkoutDetail.treadmillCorrectionNotes.localized) {
                    TextField(
                        L10n.WorkoutDetail.treadmillCorrectionNotesPlaceholder.localized,
                        text: $notesText,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .onChange(of: notesText) { _, _ in
                        notesErrorMessage = nil
                    }

                    if let err = notesErrorMessage {
                        Text(err)
                            .font(AppFont.captionSmall())
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            await submitCorrection()
                        }
                    } label: {
                        if isApplying {
                            HStack {
                                ProgressView().scaleEffect(0.8)
                                Text(L10n.Common.loading.localized)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Text(L10n.WorkoutDetail.treadmillCorrectionApply.localized)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isApplying)
                }
            }
            .navigationTitle(L10n.WorkoutDetail.treadmillCorrectionTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.WorkoutDetail.cancel.localized) {
                        dismiss()
                    }
                }
            }
            .alert(resultMessage ?? "", isPresented: $showResultAlert) {
                Button(L10n.WorkoutDetail.confirm.localized) {
                    if resultMessage == L10n.WorkoutDetail.treadmillCorrectionSuccess.localized {
                        dismiss()
                    }
                    resultMessage = nil
                }
            }
        }
        .onAppear {
            prefillFromExistingCorrection()
        }
    }

    // MARK: - Prefill

    private func prefillFromExistingCorrection() {
        guard isAlreadyCorrected, let c = currentCorrection else { return }
        if let dist = c.actualDistanceM {
            actualDistanceText = String(format: "%.0f", dist)
        }
        if let incline = c.avgInclinePercent {
            avgInclineText = String(format: "%.1f", incline)
        }
        notesText = c.notes ?? ""
    }

    // MARK: - Validation

    /// Returns (actualDistanceM, avgInclinePercent?, notes?) or nil if validation fails.
    private func validate() -> (Double, Double?, String?)? {
        // Distance: required, 100..100000
        guard let dist = Double(actualDistanceText.trimmingCharacters(in: .whitespaces)),
              (100...100000).contains(dist) else {
            distanceErrorMessage = L10n.WorkoutDetail.treadmillCorrectionDistanceError.localized
            return nil
        }

        // Incline: optional, if provided must be -10..25
        var incline: Double?
        let inclineTrimmed = avgInclineText.trimmingCharacters(in: .whitespaces)
        if !inclineTrimmed.isEmpty {
            guard let val = Double(inclineTrimmed), (-10...25).contains(val) else {
                inclineErrorMessage = L10n.WorkoutDetail.treadmillCorrectionInclineError.localized
                return nil
            }
            incline = val
        }

        // Notes: optional, max 500
        let notesTrimmed = notesText.trimmingCharacters(in: .whitespaces)
        if notesTrimmed.count > 500 {
            notesErrorMessage = L10n.WorkoutDetail.treadmillCorrectionNotesError.localized
            return nil
        }

        return (dist, incline, notesTrimmed.isEmpty ? nil : notesTrimmed)
    }

    // MARK: - Submit

    @MainActor
    private func submitCorrection() async {
        guard let (dist, incline, notes) = validate() else { return }

        isApplying = true
        defer { isApplying = false }

        let success = await onApply(dist, incline, notes)

        resultMessage = success
            ? L10n.WorkoutDetail.treadmillCorrectionSuccess.localized
            : L10n.WorkoutDetail.treadmillCorrectionError.localized
        showResultAlert = true
    }
}
