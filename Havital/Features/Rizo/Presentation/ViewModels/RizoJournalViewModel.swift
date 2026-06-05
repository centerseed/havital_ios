import Foundation
import SwiftUI

// MARK: - RizoJournalViewModel
//
// Rizo「訓練日記」入口的 Presentation 狀態機（SPEC-training-journal-feedback S02）。
//
// 核心設計：資料捕捉與回應「兩步解耦」（AC-TJF-11 / AC-TJF-16 硬要求）：
//   1. 資料捕捉（永遠成功）：先 WorkoutRepository.updateSubjectiveInputs → 成功即切「已記錄」。
//   2. Rizo 回應（可失敗）：再 RizoRepository.sendJournalChat → 成功顯示回應；
//      失敗仍保持「已記錄」（不因回應失敗丟資料、不靜默）。
//
// 架構：
//   - Presentation 層，依賴 RizoRepository / WorkoutRepository **protocol**（DI 解析，不依賴 impl）。
//   - @MainActor + @Published；TaskManageable（deinit cancelAllTasks）。
//   - 不碰 CacheEventBus（事件流屬 View / 上層；本 VM 自管 UI 狀態）。
@MainActor
final class RizoJournalViewModel: ObservableObject, TaskManageable {

    // MARK: - Quota / Conversion State (AC-TJF-09b / 17b / 17c)

    /// 配額 / 轉換提示狀態，驅動 UI 顯示哪種尾段提示。
    enum QuotaState: Equatable {
        /// 尚未送出或正常有回應、未觸發任何轉換提示。
        case none
        /// quota.allowed=false 但 reply 有建議內容（AC-TJF-09b）：顯示建議 + 轉換提示。
        case suggestionWithUpsell
        /// 本月配額用完、無新回應（AC-TJF-17b）：顯示「已記錄」+ 轉換提示。
        case quotaExhausted
        /// 滿額 + 危險（AC-TJF-17c）：後端回 canned 安全訊息，前端以 danger 樣式顯示。
        case safetyCanned
    }

    // MARK: - Published State

    /// 4 類預設（依 category 分組由 View 計算）。
    @Published private(set) var presets: [RizoPreset] = []

    /// 使用者勾選的 preset id。
    @Published var selectedPresetIDs: Set<String> = []

    /// 資料捕捉是否成功（永遠「已記錄」的 SSOT）。
    @Published private(set) var isRecorded = false

    /// Rizo 回應（解耦：可能為 nil 但 isRecorded 仍可為 true）。
    @Published private(set) var reply: RizoReply?

    /// 送出進行中。
    @Published private(set) var isSubmitting = false

    /// 預設載入進行中。
    @Published private(set) var isLoadingPresets = false

    /// 錯誤訊息（資料捕捉失敗 → 可重試；勾選/輸入不丟）。
    @Published private(set) var captureError: String?

    /// 配額 / 轉換提示狀態。
    @Published private(set) var quotaState: QuotaState = .none

    // MARK: - Dependencies

    nonisolated let taskRegistry = TaskRegistry()

    private let rizoRepository: RizoRepository
    private let workoutRepository: WorkoutRepository
    private let workoutId: String

    /// 續談會話 ID（AC-TJF-08）：首回合 nil，之後沿用 reply.sessionId。
    private var sessionId: String?

    // MARK: - Init (DI factory；依賴 protocol)

    init(
        workoutId: String,
        rizoRepository: RizoRepository? = nil,
        workoutRepository: WorkoutRepository? = nil
    ) {
        self.workoutId = workoutId
        let container = DependencyContainer.shared

        if let rizoRepository {
            self.rizoRepository = rizoRepository
        } else {
            if !container.isRegistered(RizoRepository.self) {
                container.registerRizoModule()
            }
            self.rizoRepository = container.resolve() as RizoRepository
        }

        if let workoutRepository {
            self.workoutRepository = workoutRepository
        } else {
            self.workoutRepository = container.resolve() as WorkoutRepository
        }
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Derived

    /// 是否已選任何 preset（決定送出鍵是否可用，搭配自由文字）。
    var hasSelection: Bool { !selectedPresetIDs.isEmpty }

    func toggle(_ presetID: String) {
        if selectedPresetIDs.contains(presetID) {
            selectedPresetIDs.remove(presetID)
        } else {
            selectedPresetIDs.insert(presetID)
        }
    }

    // MARK: - Load Presets (AC-TJF-01)

    func loadPresets() {
        guard presets.isEmpty, !isLoadingPresets else { return }
        isLoadingPresets = true
        Task { [weak self] in
            await self?.performLoadPresets()
        }
    }

    private func performLoadPresets() async {
        let result = await executeTask(id: TaskID("rizo_journal_presets")) { [weak self] () -> [RizoPreset]? in
            guard let self else { return nil }
            do {
                return try await self.rizoRepository.getPresets(scenario: "journal")
            } catch {
                Logger.debug("[RizoJournalViewModel] loadPresets 失敗: \(error.localizedDescription)")
                return nil
            }
        }
        if let presets = result ?? nil {
            self.presets = presets
        }
        isLoadingPresets = false
    }

    // MARK: - Submit (AC-TJF-02 / 05 / 06 / 09b / 11 / 16 / 17b / 17c)

    /// 送出：先資料捕捉（永遠優先成功），再請求 Rizo 回應（解耦，可失敗）。
    /// - Parameter note: 自由文字（選填，與預設一起送）。
    func submit(note: String) {
        guard !isSubmitting else { return }
        isSubmitting = true
        captureError = nil
        Task { [weak self] in
            await self?.performSubmit(note: note)
        }
    }

    private func performSubmit(note: String) async {
        let presetIDs = Array(selectedPresetIDs)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteForCapture: String? = trimmedNote.isEmpty ? nil : trimmedNote

        // STEP 1 — 資料捕捉（永遠優先）。失敗 → 顯示可重試錯誤，勾選/輸入不丟，isRecorded 不變。
        do {
            try await workoutRepository.updateSubjectiveInputs(
                id: workoutId,
                presets: presetIDs,
                note: noteForCapture
            )
            isRecorded = true   // ← 資料已捕捉，UI 永遠「已記錄」
        } catch {
            Logger.debug("[RizoJournalViewModel] 資料捕捉失敗: \(error.localizedDescription)")
            captureError = NSLocalizedString(
                "rizo.journal.captureError",
                comment: "記錄失敗，請重試"
            )
            isSubmitting = false
            return  // 勾選/輸入保留在 @Published state，可直接重試
        }

        // STEP 2 — Rizo 回應（解耦，可失敗）。任何結果都不回頭動 isRecorded。
        let message = buildMessage(presetIDs: presetIDs, note: noteForCapture)
        do {
            let reply = try await rizoRepository.sendJournalChat(
                workoutId: workoutId,
                message: message,
                presetSelections: presetIDs,
                sessionId: sessionId
            )
            applyReply(reply)
        } catch {
            // AC-TJF-11 / 16：回應失敗，資料捕捉仍成功，UI 永遠「已記錄」。
            Logger.debug("[RizoJournalViewModel] Rizo 回應失敗（不影響已記錄）: \(error.localizedDescription)")
            reply = nil
            quotaState = .none
        }

        isSubmitting = false
    }

    /// 依後端回應決定 quotaState（AC-TJF-09b / 17b / 17c）。
    private func applyReply(_ reply: RizoReply) {
        self.reply = reply
        self.sessionId = reply.sessionId   // 續談用（AC-TJF-08）

        let hasContent = !reply.reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if reply.safety.canned {
            // AC-TJF-17c：滿額 + 危險 → 罐頭安全訊息，danger 樣式。
            quotaState = .safetyCanned
        } else if !reply.quota.allowed {
            if hasContent {
                // AC-TJF-09b：不允許但仍有建議內容 → 顯示建議 + 轉換提示。
                quotaState = .suggestionWithUpsell
            } else {
                // AC-TJF-17b：配額用完、無新回應 → 已記錄 + 轉換提示。
                quotaState = .quotaExhausted
            }
        } else {
            quotaState = .none
        }
    }

    /// 把勾選的 preset label + 自由文字組成送給 Rizo 的訊息。
    /// 後端會引用訓練數據 + 這些感受生成回應（AC-TJF-06）。
    private func buildMessage(presetIDs: [String], note: String?) -> String {
        var parts: [String] = []
        let labelByID = Dictionary(uniqueKeysWithValues: presets.map { ($0.id, $0.label) })
        let labels = presetIDs.compactMap { labelByID[$0] }
        if !labels.isEmpty {
            parts.append(labels.joined(separator: "、"))
        }
        if let note, !note.isEmpty {
            parts.append(note)
        }
        return parts.joined(separator: "\n")
    }

    // MARK: - Retry (AC-TJF-05)

    /// 資料捕捉失敗後的重試：勾選/輸入仍在 state，重新送出。
    func retry(note: String) {
        captureError = nil
        submit(note: note)
    }
}
