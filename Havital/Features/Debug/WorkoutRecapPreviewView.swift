#if DEBUG
import SwiftUI

// MARK: - WorkoutRecapPreviewView (DEBUG harness)
//
// 從 UserProfile 的 debug 區進入：抓「最近一筆」真實訓練（含 detail 的 AI 分析），
// 直接渲染 WorkoutRecapView，方便 design / 測試反覆看版，不需 env 變數、不走 InterruptCoordinator。
// 可切「模擬未付費」預覽 AI teaser + 升級 gating。

struct WorkoutRecapPreviewView: View {
    @State private var latestWorkout: WorkoutV2?
    @State private var latestAI: String?
    @State private var latestRPE: Double?
    @State private var loading = true
    @State private var errorText: String?
    @State private var showRecap = false
    @State private var forceFreeTier = false

    private var workoutRepository: WorkoutRepository {
        DependencyContainer.shared.resolve()
    }

    var body: some View {
        List {
            Section {
                Toggle("模擬未付費（AI teaser + 升級）", isOn: $forceFreeTier)
            } footer: {
                Text("DEBUG only. 抓你最近一筆訓練的真實資料（含 detail 的 AI 分析）渲染 Recap。")
            }

            Section("最近一筆") {
                if loading {
                    HStack { ProgressView(); Text("載入中…") }
                } else if let content = makeContent() {
                    LabeledContent("類型", value: content.trainingTypeName ?? "-")
                    LabeledContent("距離", value: content.distanceText)
                    LabeledContent("配速", value: content.paceText)
                    LabeledContent("時間", value: content.durationText)
                    LabeledContent("AI 分析", value: content.hasAIAnalysis ? "有" : "無")
                } else {
                    Text(errorText ?? "找不到訓練紀錄").foregroundColor(.secondary)
                }
            }

            Section("Actions") {
                Button {
                    showRecap = true
                } label: {
                    Label("顯示訓練回顧 Recap", systemImage: "sparkles")
                }
                .disabled(latestWorkout == nil)

                Button {
                    Task { await reload() }
                } label: {
                    Label("重新抓最近一筆", systemImage: "arrow.clockwise")
                }
            }
        }
        .navigationTitle("訓練回顧 Preview")
        .task { await reload() }
        .sheet(isPresented: $showRecap) {
            if let content = makeContent() {
                WorkoutRecapView(content: content)
            }
        }
    }

    private func makeContent() -> WorkoutRecapContent? {
        guard let workout = latestWorkout else { return nil }
        let premium = forceFreeTier ? false : SubscriptionStateManager.shared.hasPremiumAccess
        return WorkoutRecapContent.make(
            from: workout,
            isPremium: premium,
            aiAnalysisOverride: latestAI,
            rpeOverride: latestRPE
        )
    }

    @MainActor
    private func reload() async {
        loading = true
        errorText = nil
        defer { loading = false }
        do {
            guard let workout = try await workoutRepository.getWorkouts(limit: 1, offset: nil).first else {
                latestWorkout = nil
                errorText = "沒有訓練紀錄"
                return
            }
            latestWorkout = workout
            let detail = try? await workoutRepository.getWorkoutDetail(id: workout.id)
            latestAI = detail?.aiSummary?.analysis
            latestRPE = detail?.advancedMetrics?.rpe
        } catch {
            latestWorkout = nil
            errorText = error.localizedDescription
        }
    }
}
#endif
