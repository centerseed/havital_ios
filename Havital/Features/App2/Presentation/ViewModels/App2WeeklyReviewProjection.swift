import Foundation

// MARK: - App2WeeklyReviewProjection
/// Presentation Layer — 2.0 週回顧的純投影
/// （設計 **frame-18「回顧本週」** / **frame-19「規劃下週」**，dc.html 同名畫面）。
///
/// **沒有第二條資料路徑。** 資料是既有的 `WeeklySummaryV2`
/// （`GET /v2/summary/weekly`，1.4 的 `WeeklySummaryCoordinator` 載的那一份），
/// 建議項的採納也是既有的 `POST /v2/summary/weekly/apply-items`。查過了：全 repo
/// 沒有第二個把 `WeeklySummaryV2` 攤成顯示字串的地方，也沒有第二條 apply-items 路徑；
/// `Views/Training/WeeklySummaryView.swift` 是 V1 deprecated，吃的是另一個 entity。
///
/// 這個檔案沒有 I/O，可以直接單元測試。
///
/// **設計稿上有、payload 沒有的欄位一律不出現**，不用假資料補：
/// - 「總時間」「總爬升」：`TrainingCompletionV2` 只有 km 與次數。
/// - 「近 6 週里程」長條圖：週摘要沒有跨週序列（`HistoricalComparisonSummary`
///   只給「與第 N 週相比」的單一差值）。
/// - 建議項的「調整」（三態）：後端 `apply-items` 是二元的 `applied_indices`，
///   沒有 per-item 的調整值。
struct App2WeeklyReviewProjection: Equatable {

    // MARK: - 回顧本週（frame-18）

    /// `第 5 週`
    let weekKicker: String
    /// 敘事卡的內文（`weekly_story.text`）。設計稿的大標沒有對應欄位——
    /// `weekly_story.thread` 是機器分類 key（`campaign` 之類），不是顯示文字，
    /// 1.4 也只渲染 `text`。沒有就沒有大標，不拿 key 充數。
    let storyBody: String?
    /// 本週成績格（總距離／跑次／完成率）。
    let stats: [Stat]
    /// 本週亮點（`weekly_highlights.highlights` ＋ `achievements`）。
    let highlights: [String]
    /// Rizo 觀察到的事實（`observations`）。
    let observations: [String]
    /// 訓練分析的逐項評語（配速／心率／距離／強度分配／能力進展）。
    let analysisNotes: [AnalysisNote]

    // MARK: - 規劃下週（frame-19）

    /// `強化期 W1`。組不出來就沒有這顆 chip。
    let phaseLabel: String?
    /// 下週規劃的總結（`next_week_adjustments.summary`）。
    let nextWeekSummary: String?
    /// 建議項。空陣列 ＝ 這週沒有建議（畫面顯示空狀態，不是載入中）。
    let suggestions: [Suggestion]

    // MARK: - 型別

    struct Stat: Equatable, Identifiable {
        var id: String { key }
        let key: String
        let label: String
        let value: String
        let unit: String?
        /// 右側的補充（`計畫 48.0 km`／`/ 5`）。
        let footnote: String?
    }

    struct AnalysisNote: Equatable, Identifiable {
        var id: String { key }
        let key: String
        let title: String
        let body: String
    }

    struct Suggestion: Equatable, Identifiable {
        /// 送回後端的 `applied_indices` 就是這個 index —— **不要重新排序這個陣列**，
        /// 順序即身分。
        let index: Int
        var id: Int { index }
        let content: String
        let reason: String
        let impact: String
        /// `high`／`medium`／`low`（後端既有值）。
        let priority: String
        /// 後端建議的預設採納與否（`item.apply`）。使用者可覆寫。
        let defaultApply: Bool
    }
}

// MARK: - 組裝

extension App2WeeklyReviewProjection {

    static func make(_ summary: WeeklySummaryV2) -> App2WeeklyReviewProjection {
        App2WeeklyReviewProjection(
            weekKicker: String(
                format: L10n.App2.WeeklyReview.weekKicker.localized,
                summary.weekOfTraining
            ),
            // `weekly_story` 是 LLM 產的敘事，沒有時退成完成度評語 —— 那也是後端寫的
            // 句子，不是 client 端拼的。
            storyBody: summary.weeklyStory?.text?.app2NonEmpty
                ?? summary.trainingCompletion.evaluation.app2NonEmpty,
            stats: stats(summary.trainingCompletion),
            highlights: highlights(summary.weeklyHighlights),
            observations: (summary.observations ?? []).compactMap(\.app2NonEmpty),
            analysisNotes: analysisNotes(summary),
            phaseLabel: phaseLabel(summary.planContext),
            nextWeekSummary: summary.nextWeekAdjustments.summary.app2NonEmpty,
            suggestions: suggestions(summary.nextWeekAdjustments.items)
        )
    }

    /// 本週成績。設計有四格（總距離／總時間／跑次／總爬升），payload 只給得出兩個
    /// 加一個完成率 —— 少兩格，不用 `--` 補。
    static func stats(_ completion: TrainingCompletionV2) -> [Stat] {
        [
            Stat(
                key: "distance",
                label: NSLocalizedString("workout.metrics.distance", comment: "距離"),
                value: String(format: "%.1f", completion.completedKm),
                unit: "km",
                footnote: completion.plannedKm > 0
                    ? String(
                        format: L10n.App2.WeeklyReview.plannedKmFootnote.localized,
                        completion.plannedKm
                    )
                    : nil
            ),
            Stat(
                key: "sessions",
                label: L10n.App2.WeeklyReview.sessions.localized,
                value: "\(completion.completedSessions)",
                unit: nil,
                footnote: completion.plannedSessions > 0 ? "/ \(completion.plannedSessions)" : nil
            ),
            Stat(
                key: "completion",
                label: L10n.App2.WeeklyReview.completionRate.localized,
                value: String(format: "%.0f", completion.percentage),
                unit: "%",
                footnote: nil
            )
        ]
    }

    /// 亮點 ＝ `highlights` ＋ `achievements`。兩個都是自由文字陣列；設計那三張卡
    /// （新 PB／最長跑／課表達成）是設計期樣本，payload 沒有那個結構。
    static func highlights(_ highlights: WeeklyHighlightsV2) -> [String] {
        (highlights.highlights + highlights.achievements).compactMap(\.app2NonEmpty)
    }

    static func analysisNotes(_ summary: WeeklySummaryV2) -> [AnalysisNote] {
        var notes: [AnalysisNote] = []
        func append(_ key: String, _ title: String, _ body: String?) {
            guard let body = body?.app2NonEmpty else { return }
            notes.append(AnalysisNote(key: key, title: title, body: body))
        }
        let analysis = summary.trainingAnalysis
        append("pace", NSLocalizedString("performance.avg_pace", comment: "配速"), analysis.pace?.evaluation)
        append(
            "heart_rate",
            NSLocalizedString("workout.detail.heart_rate_data", comment: "心率"),
            analysis.heartRate?.evaluation
        )
        append(
            "distance",
            NSLocalizedString("workout.metrics.distance", comment: "距離"),
            analysis.distance?.evaluation
        )
        append(
            "intensity",
            L10n.App2.WeeklyReview.intensityDistribution.localized,
            analysis.intensityDistribution?.evaluation
        )
        append(
            "capability",
            L10n.App2.WeeklyReview.capability.localized,
            summary.capabilityProgression?.evaluation
        )
        return notes
    }

    /// `基礎期 W2`。
    ///
    /// `current_phase` 後端**有時給識別字**（dev 實查 `base`，畫面上就長出
    /// 「base W2」＝把識別字印給用戶，2026-08-28 走查 D22）、**有時給自由文字**。
    /// 認得出來的識別字走全 App 同一份期別譯名（`training.stage.*`，2026-08-26
    /// chip 譯名裁決用的也是這一份）；認不出來的原樣留著，不猜也不分類。
    static func phaseLabel(_ context: PlanContextSummary?) -> String? {
        guard let context, let raw = context.currentPhase.app2NonEmpty else { return nil }
        let phase = PlanGenerationContext.localizationKey(forStageId: raw)?.localized ?? raw
        guard context.phaseWeek > 0 else { return phase }
        return "\(phase) W\(context.phaseWeek)"
    }

    /// 建議項。**index 是身分**（送回 `applied_indices` 用），所以帶著原始順序的
    /// offset，不重排也不過濾。
    static func suggestions(_ items: [AdjustmentItemV2]) -> [Suggestion] {
        items.enumerated().map { offset, item in
            Suggestion(
                index: offset,
                content: item.content,
                reason: item.reason,
                impact: item.impact,
                priority: item.priority,
                defaultApply: item.apply
            )
        }
    }
}
