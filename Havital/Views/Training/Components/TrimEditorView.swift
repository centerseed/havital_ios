import SwiftUI

// MARK: - Trim Editor View
/// 運動紀錄裁剪輸入介面（sheet）。
/// 在 duration 軸 [0, totalDurationS] 上以雙把手滑桿指定保留區間，送出後後端重算所有指標。
///
/// 時間軸語義：keep_start_s / keep_end_s 後端以「原始未編輯時間軸」為基準。
/// 已裁剪的紀錄其 detail 的 totalDurationS 已是裁剪後值，因此滑桿值需加上 baseOffsetS
/// （= 既有 trim 的 keepStartS）才是原始時間軸座標。首次裁剪 baseOffsetS = 0，等價直接送滑桿值。
struct TrimEditorView: View {

    // MARK: - Dependencies

    /// 目前 detail 顯示的總時長（秒）= 滑桿上限
    let totalDurationS: Double
    /// 既有 trim 的 keepStartS（原始時間軸偏移）；首次裁剪為 0
    let baseOffsetS: Double
    /// 是否已裁剪過（顯示提示）
    let isAlreadyTrimmed: Bool
    /// 顯示時間軸（rebase 至 0）對應的累積距離取樣點，用於把手旁的里程輔助顯示。
    /// 切割本身仍依時間；距離只是讓使用者知道「保留了哪一段里程」（空陣列 = 不顯示距離）。
    let distanceSamples: [TrimDistanceSample]
    /// 送出原始時間軸的 (keepStartS, keepEndS)，回傳裁剪結果
    let onApply: (Double, Double) async -> WorkoutDetailViewModelV2.TrimApplyResult

    @Environment(\.dismiss) private var dismiss

    // MARK: - Constants

    /// 後端要求的最小保留時長（秒）
    private let minWindowS: Double = 60

    // MARK: - State

    @State private var keepStartS: Double
    @State private var keepEndS: Double

    @State private var isApplying: Bool = false
    @State private var errorMessage: String?
    @State private var resultMessage: String?
    @State private var resultWasSuccess: Bool = false
    @State private var showResultAlert: Bool = false

    // MARK: - Init

    init(
        totalDurationS: Double,
        baseOffsetS: Double,
        isAlreadyTrimmed: Bool,
        distanceSamples: [TrimDistanceSample] = [],
        onApply: @escaping (Double, Double) async -> WorkoutDetailViewModelV2.TrimApplyResult
    ) {
        self.totalDurationS = totalDurationS
        self.baseOffsetS = baseOffsetS
        self.isAlreadyTrimmed = isAlreadyTrimmed
        self.distanceSamples = distanceSamples
        self.onApply = onApply
        // 預設保留全部目前區間（= 不再進一步裁剪）
        _keepStartS = State(initialValue: 0)
        _keepEndS = State(initialValue: totalDurationS)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(L10n.WorkoutDetail.trimDescription.localized)
                            .font(AppFont.bodySmall())
                            .foregroundColor(.secondary)

                        // 區間數值（時間 + 對應里程）
                        HStack(alignment: .top) {
                            timeReadout(
                                title: L10n.WorkoutDetail.trimKeepStart.localized,
                                value: keepStartS,
                                distanceMeters: distanceMeters(at: keepStartS)
                            )
                            Spacer()
                            timeReadout(
                                title: L10n.WorkoutDetail.trimKeepEnd.localized,
                                value: keepEndS,
                                distanceMeters: distanceMeters(at: keepEndS),
                                alignment: .trailing
                            )
                        }

                        // 雙把手滑桿
                        TrimRangeSlider(
                            totalDurationS: totalDurationS,
                            keepStartS: $keepStartS,
                            keepEndS: $keepEndS,
                            minWindowS: minWindowS
                        )
                        .frame(height: 44)
                        .onChange(of: keepStartS) { _, _ in errorMessage = nil }
                        .onChange(of: keepEndS) { _, _ in errorMessage = nil }

                        // 保留時長（+ 保留里程）
                        HStack {
                            Text(L10n.WorkoutDetail.trimKeepDuration.localized)
                                .font(AppFont.bodySmall())
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(keptDurationText)
                                .font(AppFont.headline())
                                .fontWeight(.semibold)
                        }

                        if let err = errorMessage {
                            Text(err)
                                .font(AppFont.captionSmall())
                                .foregroundColor(.red)
                        }

                        if isAlreadyTrimmed {
                            Text(L10n.WorkoutDetail.trimAlreadyTrimmedHint.localized)
                                .font(AppFont.captionSmall())
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }

                // 固定底部 CTA
                Button {
                    Task { await submit() }
                } label: {
                    if isApplying {
                        HStack {
                            ProgressView().scaleEffect(0.8)
                            Text(L10n.Common.loading.localized)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text(L10n.WorkoutDetail.trimApply.localized)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isApplying)
                .padding()
            }
            .navigationTitle(L10n.WorkoutDetail.trimTitle.localized)
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
                    if resultWasSuccess {
                        dismiss()
                    }
                    resultMessage = nil
                }
            }
        }
    }

    // MARK: - Subviews

    private func timeReadout(
        title: String,
        value: Double,
        distanceMeters: Double?,
        alignment: HorizontalAlignment = .leading
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title)
                .font(AppFont.captionSmall())
                .foregroundColor(.secondary)
            Text(formatDuration(value))
                .font(AppFont.title3())
                .fontWeight(.semibold)
                .monospacedDigit()
            if let meters = distanceMeters {
                Text(formatDistance(meters))
                    .font(AppFont.captionSmall())
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }

    /// 「保留時長」顯示文字：時間（+ 對應里程，若可計算）
    private var keptDurationText: String {
        let duration = formatDuration(keepEndS - keepStartS)
        guard let startM = distanceMeters(at: keepStartS),
              let endM = distanceMeters(at: keepEndS),
              endM - startM > 0 else {
            return duration
        }
        return "\(duration) · \(formatDistance(endM - startM))"
    }

    // MARK: - Helpers

    /// 秒 → m:ss（或 h:mm:ss）
    private func formatDuration(_ s: Double) -> String {
        let total = Int(max(0, s).rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let sec = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%d:%02d", m, sec)
    }

    /// 公尺 → 顯示字串（≥1km 用 km 兩位小數，否則用 m）
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }

    /// 在「顯示時間軸」位置 t（秒，rebase 至 0）查累積距離（公尺，rebase 至 0）。
    /// 線性內插；無取樣資料則回 nil（不顯示里程）。
    private func distanceMeters(at t: Double) -> Double? {
        guard let first = distanceSamples.first,
              let last = distanceSamples.last else { return nil }
        if t <= first.t { return first.d }
        if t >= last.t { return last.d }
        var lo = 0
        var hi = distanceSamples.count - 1
        while lo + 1 < hi {
            let mid = (lo + hi) / 2
            if distanceSamples[mid].t <= t { lo = mid } else { hi = mid }
        }
        let a = distanceSamples[lo]
        let b = distanceSamples[hi]
        guard b.t > a.t else { return a.d }
        let frac = (t - a.t) / (b.t - a.t)
        return a.d + (b.d - a.d) * frac
    }

    // MARK: - Submit

    @MainActor
    private func submit() async {
        let windowS = keepEndS - keepStartS
        guard windowS >= minWindowS else {
            errorMessage = L10n.WorkoutDetail.trimWindowTooShortError.localized
            return
        }

        isApplying = true
        defer { isApplying = false }

        // 滑桿（目前時間軸）→ 原始時間軸
        let originalStart = baseOffsetS + keepStartS
        let originalEnd = baseOffsetS + keepEndS

        let result = await onApply(originalStart, originalEnd)
        switch result {
        case .success:
            resultMessage = L10n.WorkoutDetail.trimSuccess.localized
            resultWasSuccess = true
            showResultAlert = true
        case .cannotTrim:
            resultMessage = L10n.WorkoutDetail.trimCannotTrimError.localized
            resultWasSuccess = false
            showResultAlert = true
        case .failure:
            resultMessage = L10n.WorkoutDetail.trimError.localized
            resultWasSuccess = false
            showResultAlert = true
        case .cancelled:
            break  // 取消不顯示錯誤
        }
    }
}

// MARK: - Trim Distance Sample

/// 顯示時間軸（rebase 至 0）對應的累積距離取樣點。
/// 由呼叫端從 workout time-series 預先計算，供裁剪編輯器把手旁的里程查表。
struct TrimDistanceSample {
    let t: Double   // 顯示時間軸秒數（rebase 至 0）
    let d: Double   // 累積距離公尺（rebase 至 0）
}

// MARK: - Trim Range Slider

/// 雙把手保留區間滑桿，覆蓋 [0, totalDurationS]。
/// 兩把手分別綁定 keepStartS / keepEndS，並強制 keepEnd - keepStart >= minWindowS。
private struct TrimRangeSlider: View {

    let totalDurationS: Double
    @Binding var keepStartS: Double
    @Binding var keepEndS: Double
    let minWindowS: Double

    private let handleSize: CGFloat = 28
    private let trackHeight: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let usable = max(1, geo.size.width - handleSize)
            let total = max(1, totalDurationS)
            let startX = CGFloat(keepStartS / total) * usable
            let endX = CGFloat(keepEndS / total) * usable

            ZStack(alignment: .leading) {
                // 底層軌道
                Capsule()
                    .fill(Color(.systemGray4))
                    .frame(height: trackHeight)
                    .padding(.horizontal, handleSize / 2)

                // 選取區間
                Capsule()
                    .fill(Color.blue)
                    .frame(width: max(0, endX - startX), height: trackHeight)
                    .offset(x: startX + handleSize / 2)

                // 起點把手
                handleView
                    .offset(x: startX)
                    .gesture(dragGesture(isStart: true, usable: usable, total: total))

                // 終點把手
                handleView
                    .offset(x: endX)
                    .gesture(dragGesture(isStart: false, usable: usable, total: total))
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private var handleView: some View {
        Circle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
    }

    private func dragGesture(isStart: Bool, usable: CGFloat, total: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let clampedX = max(0, min(usable, value.location.x - handleSize / 2))
                let raw = Double(clampedX / usable) * total
                if isStart {
                    keepStartS = max(0, min(raw, keepEndS - minWindowS))
                } else {
                    keepEndS = min(total, max(raw, keepStartS + minWindowS))
                }
            }
    }
}
