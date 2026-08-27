import Foundation

// MARK: - 計畫結束態（設計 frame-00g／frame-00g2）
//
// 觸發只有一個事實：`GET /v2/plan/status` 的 `next_action == "training_completed"`
// （後端 `domains/plan_week/service.py:1218`，判準是 `current_week > total_weeks`，
// **以週界為準不是賽事日**）。client 不重算週界、不看裝置日期。
//
// **兩個 backend 缺口在型別上是看得見的**（`DESIGN-app2-weekly-review-and-plan-end-
// inventory.md` §B.3 的缺口列）：
// - `actualFinish`：賽事實際成績沒有綁定機制（無「這場就是目標賽事」的關聯），
//   所以 producer 一律交 nil → hero 退成「目標＋當時預估」並隱藏差值。
// - `narrative`：整期總結敘事是還沒落地的 LLM 端點（`SPEC-plan-period-summary.md`
//   status=Draft）→ 首頁的 Rizo 敘事子卡整卡隱藏、總結頁掛降級 chip 走數字版。
//
// 兩個欄位都保留在型別上而不是刪掉：降級規則要寫得出來、測得到，缺口才不會在
// 端點落地那天被重新發明一次。

/// 結束語意的兩種變體（frame-00g（b））。
///
/// 分岔的來源是 **overview 的 `target_type`**（`race_run`／`beginner`／`maintenance`），
/// 不是有沒有賽事日期 —— 後端一律以計畫週數走完為準，賽事日期只是 race 變體的內容。
enum App2PlanEndKind: String, Equatable {
    /// `target_type == "race_run"`：深藍「備賽完成」，聚焦賽事（目標／預估／成績）。
    case race
    /// 其餘（`maintenance`／`beginner`／未知）：綠「訓練期完成」，聚焦維持成果，
    /// **不提賽事成績**。
    case maintenance
}
// 配色（race 深藍／maintenance 深綠）掛在 `App2Theme` 的 extension 上 ——
// 顏色住在 Presentation，不進 Domain（同 `App2Insight.tint` 的分工）。

/// 首頁結束態卡（frame-00g（a）（b））—— `training_completed` 時取代目標卡＋今日課表卡。
struct App2PlanEndCard: Equatable {
    let kind: App2PlanEndKind
    /// 賽名。maintenance 沒有賽事 → nil（大標改用「N 週維持計畫」）。
    let raceName: String?
    /// 已格式化的賽事當地日期（`2026-12-06`）。
    let raceDate: String?
    /// `全馬`／`半馬`…（走既有的 `race_filter.*`，不印 `distance_km`）。
    let distanceLabel: String?
    /// 整期週數（`total_weeks`）。缺席時大標不寫週數。
    let totalWeeks: Int?
    /// `2:34:00`。目標未設成績就是 nil。
    let targetTime: String?
    /// 當時的完賽預估（readiness 流的 `race_fitness.estimated_race_time`）。
    ///
    /// **標的是「當時的預估」語意**：計畫已經走完，這個量講的是這段備賽把預估推到哪，
    /// 不是「現在你能跑幾分」。它與 decision-chain 的指標分屬兩條流
    /// （`AGENTS.md`「兩條資料流」），畫面上要標來源，不得與 decision-chain 互相佐證。
    let estimatedFinish: String?
    /// 賽事實際完賽成績 —— **目前恆為 nil**（無綁定機制，見檔頭）。
    let actualFinish: String?
    /// LLM 整期敘事 —— **目前恆為 nil**（端點未落地，見檔頭）。
    let narrative: String?

    /// 目標與實際成績都在時才有差值可講（frame-00g（a）那個 `+1:42`）。
    /// 實際成績沒有 producer → 恆 false → 畫面隱藏差值那一格。
    var showsFinishDelta: Bool { targetTime != nil && actualFinish != nil }

    /// hero 兩欄的右欄要顯示什麼：有實際成績就是它，否則退「當時預估」。
    /// 兩者都沒有 → nil，整組兩欄不出現（不畫一排「—」）。
    var heroSecondaryValue: String? { actualFinish ?? estimatedFinish }

    /// 右欄顯示的是降級值（當時預估）而不是實際成績。
    var isFinishDegraded: Bool { actualFinish == nil }
}

// MARK: - 整期總結

/// 整期總結頁的確定性數字版（frame-00g（c）＝frame-00g2（b）的降級態）。
///
/// 每一格都來自活端點，缺就是 nil → 畫「–」。**不編數字、不用樣本補**。
struct App2PeriodSummary: Equatable {
    let kind: App2PlanEndKind
    let raceName: String?
    let totalWeeks: Int?

    // hero：無實際成績 → 目標＋當時預估、隱藏差值（同 `App2PlanEndCard`）。
    let targetTime: String?
    let estimatedFinish: String?
    /// 恆 nil（無綁定機制）。
    let actualFinish: String?

    // hero 三磚：總跑量 / VDOT 增量 / 完成率
    let totalDistanceKm: Double?
    let vdotDelta: Double?
    /// 0…100。逐週回顧一份都讀不到時是 nil。
    let completionRate: Double?

    // 統計磚 2×2：訓練次數 / 總時間 / 最長單次 / 峰值週
    let sessionCount: Int?
    let plannedSessionCount: Int?
    /// 讀得到週回顧的週數。次數／完成率的分母只有這幾週（沒生成回顧的週拿不出
    /// 數字），小於 `totalWeeks` 時畫面要標覆蓋範圍——同一張卡上總跑量是全 N 週、
    /// 完成率卻只有 1 週，不標會被讀成同一個分母（dev QA D4）。
    let summaryWeekCount: Int?
    let totalDurationSeconds: Int?
    let longestRunKm: Double?
    let peakWeekKm: Double?

    /// 每週跑量柱狀圖（舊→新）。峰值週由畫面依 `peakWeekKm` 高亮。
    let bars: [App2WeeklyBar]

    // 能力變化：VDOT 起點 → 終點
    let vdotStart: Double?
    let vdotEnd: Double?
    let vdotSeries: [App2MetricPoint]

    var showsFinishDelta: Bool { targetTime != nil && actualFinish != nil }
    var heroSecondaryValue: String? { actualFinish ?? estimatedFinish }
    var isFinishDegraded: Bool { actualFinish == nil }

    /// 課表 tab 結束態要的那幾格（frame-00g2（c））。
    ///
    /// **同一份投影的子集，不另算一份** —— 兩個畫面上的「完成率 91%」必須是同一個字。
    var strip: App2PlanEndStrip {
        App2PlanEndStrip(
            kind: kind,
            raceName: raceName,
            totalWeeks: totalWeeks,
            bars: bars,
            plannedSessionCount: plannedSessionCount,
            completionRate: completionRate,
            peakWeekKm: peakWeekKm
        )
    }
}

/// 課表 tab 結束態的「✓ 計畫完成」卡（frame-00g2（c））。
struct App2PlanEndStrip: Equatable {
    let kind: App2PlanEndKind
    /// 大標上方的賽名：race＝賽名，maintenance＝nil。
    let raceName: String?
    let totalWeeks: Int?
    /// 週量迷你柱。
    let bars: [App2WeeklyBar]
    let plannedSessionCount: Int?
    let completionRate: Double?
    let peakWeekKm: Double?
}

// MARK: - 故事版（frame-00g2（a））

/// 整期總結頁的故事版 —— **LLM 敘事**。
///
/// 欄位形狀照 `cloud/api_service/docs/01-specs/decision-chain/
/// SPEC-plan-period-summary.md` §5.2 的 `plan_period_summary` 模型：
/// `hero{line,subline}` ＋ `chapters[]{week_label,title,quote?,rizo_line?}`。
///
/// **這份規格 status=Draft、端點不存在**，所以 production 路徑永遠拿不到值
/// （producer 只有 DEBUG 的 fixture）。型別先按規格落下來，是為了讓「敘事在／不在」
/// 的分岔現在就能寫、能測，而不是等端點落地時再造一次。
struct App2PeriodStory: Equatable {
    /// 「22 週，你把自己重新跑了一遍」
    let heroLine: String
    /// 從報名到起跑線的那一句副標。
    let heroSubline: String?
    /// 完賽數字卡。`finish` 引用的是 race-result-binding 的讀口（同樣未落地）→ 可缺席。
    let finish: Finish?
    /// 章節時間軸（規格 §5.2：3–6 章，含起點與最終章）。
    let chapters: [Chapter]

    struct Finish: Equatable {
        /// `2:35:42`
        let time: String
        /// `距目標 +1:42`；目標未設成績時 nil。
        let deltaLabel: String?
        /// `目標 2:34:00`
        let targetLabel: String?
    }

    struct Chapter: Identifiable, Equatable {
        let id: Int
        /// `第 1 週 · 起點`
        let weekLabel: String
        /// 章節標題（LLM）。
        let title: String
        /// 用戶訓練心得原話。**規格 §5.2：MUST 是 `training_notes` 的逐字摘句**
        /// （MAY 截斷，MUST NOT 改寫）—— 原話是這個功能的情感核心。
        let quote: Quote?
        /// R 圓章那一行 Rizo 評語（LLM 依 `ai_summary` 改寫）。
        let rizoLine: String?

        struct Quote: Equatable {
            let text: String
            /// `第 1 週 · 輕鬆跑 8.0 km`
            let sessionSummary: String?
        }
    }
}
