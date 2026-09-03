import Foundation

// MARK: - 值（`current` / `proposed` / `adjusted_value`）
/// 型別註記寫的是 `StrictInt | StrictFloat | StrictStr | null`
/// （`cloud/api_service/api/v2/decision_chain.py:71`），但**實際會收到陣列與布林**：
/// Rizo 記下的條目（`source == "rizo"`）帶的是
/// `{"field":"blocked_day_indices","proposed":[3]}`；休息週提案
/// （`source == "override_proposal"`）帶的是
/// `{"field":"is_manual_rest_week","current":false,"proposed":true}`
/// （後端 `domains/decision_chain/intent/overrides.py:171`）——兩者都是 dev 2026-09-03 實測。
/// 所以 DTO 這一層照 JSON 的型別收，**不在解碼時就把它壓成一種**，
/// 也不對認不得的形狀丟錯——丟錯的代價是整張清單消失。
struct DecisionChainValueDTO: Codable, Equatable {
    let value: DecisionChainValue

    init(_ value: DecisionChainValue) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // **布林要先試**。Foundation 的 `JSONDecoder` 不會把 JSON `true` 解成 `Int`
        // （所以順序反過來其實也不會被 `Int` 吃掉），但依賴那個實作細節等於把
        // 「休息週提案看不看得到」押在一個沒有寫下來的行為上——布林是比數更窄的型別，
        // 就擺在最前面。
        if let boolValue = try? container.decode(Bool.self) {
            value = .bool(boolValue)
        }
        // 再試整數：`JSONDecoder` 分不出 `15` 與 `15.0`（兩者都解得成 `Int`，實測見
        // `App2WeeklyReviewDecisionChainTests.test_decodesRealDevChecklistPayload`），
        // 所以**整數值一律收成 `.int`**，帶小數的才是 `.double`。這樣送回去的
        // `adjusted_value` 不會平白多一個小數點；後端的 union 兩種都收。
        else if let intValue = try? container.decode(Int.self) {
            value = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            value = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            value = .text(stringValue)
        } else if let listValue = try? container.decode([DecisionChainValueDTO].self) {
            // 陣列（`blocked_day_indices` 的 `[3]`）。內容不解讀，原樣收。
            value = .list(listValue.map(\.value))
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "checklist value must be a number, a string, a bool, or an array"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case .int(let intValue):       try container.encode(intValue)
        case .double(let doubleValue): try container.encode(doubleValue)
        case .text(let stringValue):   try container.encode(stringValue)
        case .bool(let boolValue):     try container.encode(boolValue)
        case .list(let values):        try container.encode(values.map(DecisionChainValueDTO.init))
        }
    }
}

// MARK: - Checklist
struct DecisionChainChecklistItemDTO: Codable {
    let itemId: String
    let source: String?
    let field: String?
    let current: DecisionChainValueDTO?
    let proposed: DecisionChainValueDTO?
    let title: String?
    let reason: String?
    let status: String?
    let adjustedValue: DecisionChainValueDTO?

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case source, field, current, proposed, title, reason, status
        case adjustedValue = "adjusted_value"
    }
}

/// **`items` 是必填**（不是 `?`）。全欄可選的 DTO 會被
/// `ResponseProcessor.extractData` 的第四次嘗試（`parser.tryParse(T.self, from: rawData)`，
/// `Havital/Services/Core/UnifiedAPIResponse.swift:319`）拿**外層信封**
/// `{"success":…,"data":…}` 解成一份「每一欄都是 nil」的清單——真正的解碼失敗
/// 於是變成一張空清單（畫面顯示「這一輪沒有要改的」），而不是 fail-open 回既有路徑。
/// 2026-09-03 的 `blocked_day_indices: [3]` 就是這樣把使用者已經答過的條目吃掉的。
/// `items` 必填 ⇒ 信封解不成 ⇒ 解碼失敗照實丟出去。
struct DecisionChainChecklistDTO: Codable {
    let asOf: String?
    let intentRevision: String?
    let intentLifecycle: String?
    let items: [DecisionChainChecklistItemDTO]

    enum CodingKeys: String, CodingKey {
        case asOf = "as_of"
        case intentRevision = "intent_revision"
        case intentLifecycle = "intent_lifecycle"
        case items
    }
}

/// `POST …/checklist/{item_id}` 的回應：那一條表態後的樣子 ＋ 意圖現在在哪。
struct DecisionChainChecklistStanceResponseDTO: Codable {
    let item: DecisionChainChecklistItemDTO
    let intentLifecycle: String?

    enum CodingKeys: String, CodingKey {
        case item
        case intentLifecycle = "intent_lifecycle"
    }
}

struct DecisionChainChecklistStanceRequestDTO: Codable {
    let status: String
    let adjustedValue: DecisionChainValueDTO?

    enum CodingKeys: String, CodingKey {
        case status
        case adjustedValue = "adjusted_value"
    }
}

// MARK: - Intent card（§4.1）
struct DecisionChainIntentCardDTO: Codable {
    let lifecycle: String?
    let intent: IntentDTO?
    let expression: ExpressionDTO?
    let hypotheses: [HypothesisDTO]?

    struct IntentDTO: Codable {
        let revision: String?
    }

    struct ExpressionDTO: Codable {
        let pursuing: String?
        let maintaining: String?
        let abandoning: String?
        let rationale: String?
    }

    struct HypothesisDTO: Codable {
        let hypothesisId: String?
        let intervention: TextDTO?
        let prediction: TextDTO?

        enum CodingKeys: String, CodingKey {
            case hypothesisId = "hypothesis_id"
            case intervention, prediction
        }

        struct TextDTO: Codable {
            let description: String?
        }
    }
}

// MARK: - Run（§4.2）
struct DecisionChainWeekRunDTO: Codable {
    let asOf: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case asOf = "as_of"
        case status
    }
}

// MARK: - DTO → Domain
/// **投影住在 Data 層**（與 `StrengthCompletionMapper` 同一個分工）：Presentation
/// 拿到的是已經判過的 domain 值，不必再認 `nil`／字串值域。
enum DecisionChainWeekMapper {

    static func toEntity(_ dto: DecisionChainChecklistDTO, asOf: String) -> DecisionChainChecklist {
        DecisionChainChecklist(
            asOf: dto.asOf ?? asOf,
            intentRevision: dto.intentRevision,
            intentLifecycle: dto.intentLifecycle,
            items: dto.items.map(toEntity)
        )
    }

    static func toEntity(_ dto: DecisionChainChecklistItemDTO) -> DecisionChainChecklistItem {
        DecisionChainChecklistItem(
            itemId: dto.itemId,
            // 認不得的來源不讓整張清單解不開（訓練流程一律 fail-open）。
            source: DecisionChainChecklistItem.Source(rawValue: dto.source ?? "") ?? .unknown,
            field: dto.field ?? "",
            current: dto.current?.value,
            proposed: dto.proposed?.value,
            title: dto.title ?? "",
            reason: dto.reason ?? "",
            // 認不得的狀態一律當「還沒答」——把未知讀成 accepted 就是替使用者答了。
            status: DecisionChainChecklistItem.Status(rawValue: dto.status ?? "") ?? .proposed,
            adjustedValue: dto.adjustedValue?.value
        )
    }

    static func toEntity(_ dto: DecisionChainIntentCardDTO) -> DecisionChainIntentCard {
        DecisionChainIntentCard(
            lifecycle: dto.lifecycle,
            revision: dto.intent?.revision,
            expression: DecisionChainIntentCard.Expression(
                pursuing: nonEmpty(dto.expression?.pursuing),
                maintaining: nonEmpty(dto.expression?.maintaining),
                abandoning: nonEmpty(dto.expression?.abandoning),
                rationale: nonEmpty(dto.expression?.rationale)
            ),
            hypotheses: (dto.hypotheses ?? []).enumerated().map { index, hypothesis in
                DecisionChainIntentCard.Hypothesis(
                    hypothesisId: hypothesis.hypothesisId ?? "hypothesis-\(index)",
                    interventionDescription: nonEmpty(hypothesis.intervention?.description),
                    predictionDescription: nonEmpty(hypothesis.prediction?.description)
                )
            }
        )
    }

    static func toEntity(_ dto: DecisionChainWeekRunDTO, asOf: String) -> DecisionChainWeekRun {
        DecisionChainWeekRun(asOf: dto.asOf ?? asOf, status: dto.status ?? "")
    }

    /// 空字串與 `null` 是同一件事：那一列不畫（設計 §4.1 第 4 條）。
    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
}
