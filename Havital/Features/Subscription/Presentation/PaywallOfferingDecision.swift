import Foundation

// MARK: - PaywallOfferingDecision
/// 純決策：Paceriz paywall 要呈現哪個 offering、是否套早鳥樣式。
///
/// 抽成純函式（無 RC SDK / 無 singleton）讓「graduate eb1 / 公開早鳥 / 標準」三態選擇
/// 可被單元測試完整覆蓋——避免上線後的顯示邏輯 bug（尤其 6/30 公開早鳥退場後）。
///
/// **Fail-safe 鐵則：非 eb1-eligible 的用戶永遠不會被導到 graduate offering**，即使該
/// offering 存在——杜絕「人人永久早鳥」的營收漏洞。資格不明 / offering 不存在 →
/// 退回 RC current / default，絕不誤給 eb1。
enum PaywallOfferingDecision {
    struct Inputs {
        /// 後端權威：此 UID 有 active Starter 買斷（status.canOfferPacerizEb1）。
        let isEb1Eligible: Bool
        /// 目前已載入的所有 offering id。
        let availableOfferingIds: Set<String>
        /// RevenueCat 回報的 current offering id（公開早鳥窗口期內=早鳥；6/30 後=default）。
        let rcCurrentOfferingId: String?
        /// RevenueCat current 是否為早鳥（repository.isEarlyBirdOffering）。
        let rcIsEarlyBird: Bool
        let graduateId: String
        let defaultId: String
    }

    struct Result: Equatable {
        let offeringId: String
        let isEarlyBirdDisplay: Bool
    }

    static func decide(_ i: Inputs) -> Result {
        // 畢業生路徑：有買斷資格 AND graduate offering 真的存在 → 用 graduate（含 eb1），套早鳥樣式。
        if i.isEb1Eligible && i.availableOfferingIds.contains(i.graduateId) {
            return Result(offeringId: i.graduateId, isEarlyBirdDisplay: true)
        }
        // 否則：用 RC current（公開早鳥窗口期內 or 標準）。
        // Fail-safe：非 eligible 一律走這條、永不選 graduate；current 不明 → 退 default。
        let id = i.rcCurrentOfferingId ?? i.defaultId
        return Result(offeringId: id, isEarlyBirdDisplay: i.rcIsEarlyBird)
    }
}
