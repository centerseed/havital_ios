import Foundation

// MARK: - AthleteStateSeriesResponse
/// Wire DTO for `GET /v2/athlete-state/metrics/series` 的 data payload。
/// envelope `{success,data}` 已由 `APICallHelper` 拆掉，此型別僅代表 data。
///
/// **一項一天一列**（SPEC-athlete-state §4.10.1）：每一天帶自己的 `delivery_status`
/// 與自己的 envelope，沒有區間層級的狀態。算不出來的那天就是沒有 envelope ——
/// **不得拿鄰日的值補**（§4.10.7 明令禁止 LOCF），畫面就少那一個點。
struct AthleteStateSeriesResponse: Codable {
    let startDay: String?
    let endDay: String?
    /// key ＝ 指標（`aerobic_endurance`／`speed_endurance`／…）。
    let series: [String: [Day]]

    enum CodingKeys: String, CodingKey {
        case series
        case startDay = "start_day"
        case endDay = "end_day"
    }

    struct Day: Codable {
        let day: String
        let deliveryStatus: String?
        let envelope: Envelope?

        enum CodingKeys: String, CodingKey {
            case day, envelope
            case deliveryStatus = "delivery_status"
        }

        /// 這一頁只吃 0–100 的位置量尺。envelope 其餘欄（confidence／limits／raw）
        /// 是評級層與監控的東西，畫線不需要，也不該在 app 端重新解讀。
        struct Envelope: Codable {
            let index: Double?
            let levelIndex: Double?

            enum CodingKeys: String, CodingKey {
                case index
                case levelIndex = "level_index"
            }
        }
    }
}
