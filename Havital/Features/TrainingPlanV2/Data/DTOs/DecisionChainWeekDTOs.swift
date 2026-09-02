import Foundation

// MARK: - 值（`current` / `proposed` / `adjusted_value`）
/// 後端這三欄是 `StrictInt | StrictFloat | StrictStr | null`
/// （`cloud/api_service/api/v2/decision_chain.py:71`），所以 DTO 這一層照 JSON
/// 的型別收，**不在解碼時就把它壓成一種**。
struct DecisionChainValueDTO: Codable, Equatable {
    let value: DecisionChainValue

    init(_ value: DecisionChainValue) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // 先試整數：`JSONDecoder` 分不出 `15` 與 `15.0`（兩者都解得成 `Int`，實測見
        // `App2WeeklyReviewDecisionChainTests.test_decodesRealDevChecklistPayload`），
        // 所以**整數值一律收成 `.int`**，帶小數的才是 `.double`。這樣送回去的
        // `adjusted_value` 不會平白多一個小數點；後端的 union 兩種都收。
        if let intValue = try? container.decode(Int.self) {
            value = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            value = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            value = .text(stringValue)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "checklist value must be a number or a string"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case .int(let intValue):       try container.encode(intValue)
        case .double(let doubleValue): try container.encode(doubleValue)
        case .text(let stringValue):   try container.encode(stringValue)
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

struct DecisionChainChecklistDTO: Codable {
    let asOf: String?
    let intentRevision: String?
    let intentLifecycle: String?
    let items: [DecisionChainChecklistItemDTO]?

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
            items: (dto.items ?? []).map(toEntity)
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
