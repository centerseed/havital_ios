import Foundation

// MARK: - 下週規劃清單的 domain 形狀
//
// 端點形狀：root `docs/designs/DESIGN-app2-decision-chain-api.md` §4.1／§4.1b。
// 行為：`Docs/specs/SPEC-training-hub-and-weekly-plan-lifecycle.md` AC-TRAIN-HUB-12。
//
// **這一組是 2.0 唯一接 `/v2/decision-chain/*` 的地方**（2026-09-03 前全 repo 零命中）。
// 舊的 `apply-items` 建議清單（`TrainingPlanV2RemoteDataSource:387`）仍活著，服務的是
// 沒有 decision-chain 內容可用時的 fail-open 路徑（AC-TRAIN-HUB-10），不與這一組並列。

// MARK: - DecisionChainValue
/// 清單一條的 `current`／`proposed`。**後端不保證同一個型別**（dev 2026-09-03 實測：
/// `weekly_km_pct` 是 `0.0`／`15.0`、`pace_sec_per_km_delta` 是 `0`／`-5`、
/// `rest_ratio` 是 `"1:1"`、`interval_reps` 的 `current` 是 `null`），
/// 所以照 JSON 的型別收，不硬轉成一種。
///
/// **整數與小數分開存**：`adjusted_value` 要送回去（後端收
/// `StrictInt | StrictFloat | StrictStr`，`cloud/api_service/api/v2/decision_chain.py:71`），
/// 整數條目送出去就該是整數。`JSONDecoder` 分不出 `15` 與 `15.0`，所以判準是
/// **有沒有小數部分**，不是後端寫了哪一種。
enum DecisionChainValue: Equatable {
    case int(Int)
    case double(Double)
    case text(String)

    /// 這一條可不可以「調整」。**判準是這一條自己的值是不是數**，不是欄位名字——
    /// 用欄位名列白名單等於在 app 這一層重寫一份旋鈕語意（設計 §4.1「app 不解讀旋鈕」）。
    var isNumeric: Bool {
        switch self {
        case .int, .double: return true
        case .text:         return false
        }
    }

    /// 數值形態（`text` 回 nil）。輪盤只吃得下數。
    var numericValue: Double? {
        switch self {
        case .int(let value):    return Double(value)
        case .double(let value): return value
        case .text:              return nil
        }
    }

    /// 把輪盤選到的數收回原本的型別：整數條目仍是整數。
    static func matchingKind(of template: DecisionChainValue?, number: Double) -> DecisionChainValue {
        switch template {
        case .int:
            return .int(Int(number.rounded()))
        default:
            // 小數條目與型別不明時都當小數；後端的 union 兩種都收。
            return number == number.rounded() ? .int(Int(number)) : .double(number)
        }
    }
}

// MARK: - DecisionChainChecklistItem
/// 下週規劃清單上的一條（§4.1b）。
///
/// `title`／`reason` 是後端已經翻好的人話（`title` 每次讀都重翻、`reason` 是 L0 席位寫的），
/// app **不重組也不解讀**這兩欄。
struct DecisionChainChecklistItem: Identifiable, Equatable {

    /// 使用者對這一條的答案。**沒答就是 `proposed` ＝不生效**（§4.1b 第 8 條）。
    enum Status: String, Equatable {
        case proposed
        case accepted
        case declined
        case adjusted
    }

    /// 這一條是誰提的。app 只拿它做呈現，不拿它決定能不能答。
    enum Source: String, Equatable {
        case intentKnob = "intent_knob"
        case overrideProposal = "override_proposal"
        case rizo
        /// 後端長出新的來源時不要讓整張清單解不開（訓練流程一律 fail-open）。
        case unknown
    }

    let itemId: String
    let source: Source
    let field: String
    let current: DecisionChainValue?
    let proposed: DecisionChainValue?
    let title: String
    let reason: String
    let status: Status
    let adjustedValue: DecisionChainValue?

    var id: String { itemId }

    /// 「調整」這個動作在不在。數值型才給——離散代號（`rest_ratio` 的 `1:1`、
    /// `recovery_kind` 的 `jog`）沒有輪盤可以轉，硬給一個會讓使用者送出後端不收的值。
    var allowsAdjust: Bool { proposed?.isNumeric ?? false }

    /// 換一個狀態的同一條（樂觀更新與回滾用；其餘欄位是後端的投影，不動）。
    func with(status: Status, adjustedValue: DecisionChainValue?) -> DecisionChainChecklistItem {
        DecisionChainChecklistItem(
            itemId: itemId,
            source: source,
            field: field,
            current: current,
            proposed: proposed,
            title: title,
            reason: reason,
            status: status,
            adjustedValue: adjustedValue
        )
    }
}

// MARK: - DecisionChainChecklist
/// 一週一份（§4.1b）。**`items` 空陣列是合法狀態**：那一輪 L0 一顆旋鈕都沒轉，
/// 使用者沒有東西可勾，按下「產生下週課表」就是答完（§4.1b 第 7 條）。
struct DecisionChainChecklist: Equatable {
    let asOf: String
    let intentRevision: String?
    let intentLifecycle: String?
    var items: [DecisionChainChecklistItem]
}

// MARK: - DecisionChainIntentCard
/// 清單頂端的唯讀說明（§4.1「這張卡是清單頂端的唯讀說明」，2026-09-02 晚裁決）。
/// **卡片上沒有任何動作**——接受與否逐條做在清單上，意圖的 lifecycle 由清單推導。
struct DecisionChainIntentCard: Equatable {

    struct Expression: Equatable {
        /// 這一段追什麼。
        let pursuing: String?
        /// 維持什麼。`nil` ＝ 這一段沒有，畫面不畫那一列。
        let maintaining: String?
        /// 放棄／延後什麼。`nil` 同上。
        let abandoning: String?
        /// 為什麼（一句，L0 寫的）。
        let rationale: String?
    }

    struct Hypothesis: Equatable, Identifiable {
        let hypothesisId: String
        /// 「所以想讓你做——」（§4.1a）。
        let interventionDescription: String?
        /// 「應該會看到——」（§4.1a）。
        let predictionDescription: String?
        var id: String { hypothesisId }
    }

    let lifecycle: String?
    let revision: String?
    let expression: Expression
    let hypotheses: [Hypothesis]

    /// 說明區有沒有東西可講。全空就整段不畫——不畫一張只有標題的卡。
    var hasContent: Bool {
        let lines = [expression.pursuing, expression.maintaining, expression.abandoning, expression.rationale]
        if lines.contains(where: { !($0 ?? "").isEmpty }) { return true }
        return hypotheses.contains { !($0.interventionDescription ?? "").isEmpty || !($0.predictionDescription ?? "").isEmpty }
    }
}

// MARK: - DecisionChainWeekRun
/// `POST …/week/{as_of}/run` 的回應。`generated` 與 `already_exists` 都是成功
/// （AC-TRAIN-HUB-12）——app 不因為「已經跑過」走不同的路。
struct DecisionChainWeekRun: Equatable {
    let asOf: String
    let status: String
}
