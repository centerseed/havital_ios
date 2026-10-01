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
        var itemId: String? = nil
        var asOf: String? = nil
        var estimatorVersion: String? = nil
        var displayValue: Double? = nil
        let deliveryStatus: String?
        let envelope: Envelope?

        enum CodingKeys: String, CodingKey {
            case day, envelope
            case itemId = "item_id"
            case asOf = "as_of"
            case estimatorVersion = "estimator_version"
            case displayValue = "display_value"
            case deliveryStatus = "delivery_status"
        }

        /// 指標序列 envelope。圖表消費 index 與 `channels.acwr`；完賽預估另讀
        /// `channels` 的 race_projection raw 秒數與 status。
        typealias Envelope = AthleteStateMetricEnvelope
    }
}
