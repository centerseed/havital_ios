import Foundation

// MARK: - StateCardDTO
/// Wire DTO for `GET /v2/state/today` 的 data payload。
/// envelope `{success,data}` 已由 APICallHelper 拆掉，此 DTO 僅代表 data。
/// Data Layer — snake_case 對映 via CodingKeys。
struct StateCardDTO: Codable {
    let lens: String
    let source: String?
    let headline: String
    let factType: String?
    let narrativeText: String?
    let chips: [String]?
    let causeChips: [String]?
    let mileageProgression: String?
    let action: ActionDTO?
    let divergence: DivergenceDTO?
    let access: AccessDTO

    enum CodingKeys: String, CodingKey {
        case lens, source, headline, chips, action, divergence, access
        case factType = "fact_type"
        case narrativeText = "narrative_text"
        case causeChips = "cause_chips"
        case mileageProgression = "mileage_progression"
    }

    struct ActionDTO: Codable {
        let kind: String
        let sessionRef: SessionRefDTO?
        let rizoHandoff: RizoHandoffDTO?
        enum CodingKeys: String, CodingKey {
            case kind
            case sessionRef = "session_ref"
            case rizoHandoff = "rizo_handoff"
        }
        struct SessionRefDTO: Codable {
            let runType: String?
            let distanceKm: Double?
            let pace: String?
            enum CodingKeys: String, CodingKey {
                case runType = "run_type"
                case distanceKm = "distance_km"
                case pace
            }
        }
        struct RizoHandoffDTO: Codable { let scenario: String? }
    }

    struct DivergenceDTO: Codable {
        let present: Bool
        let flagText: String?
        let suggestedRizoScenario: String?
        enum CodingKeys: String, CodingKey {
            case present
            case flagText = "flag_text"
            case suggestedRizoScenario = "suggested_rizo_scenario"
        }
    }

    struct AccessDTO: Codable {
        let isPaid: Bool
        let locked: Bool
        let upsell: UpsellDTO?
        enum CodingKeys: String, CodingKey {
            case isPaid = "is_paid"
            case locked, upsell
        }
        struct UpsellDTO: Codable { let reason: String? }
    }
}
