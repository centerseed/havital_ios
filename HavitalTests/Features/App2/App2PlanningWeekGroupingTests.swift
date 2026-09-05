import XCTest
@testable import paceriz_dev

/// 規劃下週分頁：Rizo 記下的條目自成一組（T-0434，2026-09-05 使用者裁決）。
///
/// 為什麼要有這一組：兩種來源混在同一張清單裡，使用者答「要／不要」的時候分不出
/// 這一條是系統提的旋鈕，還是自己剛剛跟 Rizo 講的那句話被記了下來。
///
/// 判準兩條 —— **兩組加起來一定等於整張清單**（新來源出現時不得整條消失），
/// **Rizo 那一組只放 `source == .rizo`**。
final class App2PlanningWeekGroupingTests: XCTestCase {

    private func item(_ id: String, _ source: DecisionChainChecklistItem.Source) -> DecisionChainChecklistItem {
        DecisionChainChecklistItem(
            itemId: id,
            source: source,
            field: "weekly_km_pct",
            current: nil,
            proposed: nil,
            title: id,
            reason: "",
            status: .proposed,
            adjustedValue: nil
        )
    }

    private func checklist(_ items: [DecisionChainChecklistItem]) -> DecisionChainChecklist {
        DecisionChainChecklist(
            asOf: "2026-09-05T00:00:00+00:00",
            intentRevision: nil,
            intentLifecycle: nil,
            items: items
        )
    }

    func test_rizoGroupHoldsOnlyWhatRizoRecorded() {
        let list = checklist([
            item("knob", .intentKnob),
            item("rizo-1", .rizo),
            item("override", .overrideProposal),
            item("rizo-2", .rizo)
        ])

        XCTAssertEqual(
            App2WeeklyReviewView.rizoItems(list).map(\.itemId), ["rizo-1", "rizo-2"]
        )
    }

    /// 認不得的來源留在意圖那一組，不會憑空消失。
    func test_theTwoGroupsAlwaysAddUpToTheWholeChecklist() {
        let list = checklist([
            item("knob", .intentKnob),
            item("rizo-1", .rizo),
            item("future", .unknown)
        ])

        let regrouped = App2WeeklyReviewView.rizoItems(list) + App2WeeklyReviewView.intentItems(list)
        XCTAssertEqual(Set(regrouped.map(\.itemId)), Set(list.items.map(\.itemId)))
        XCTAssertEqual(regrouped.count, list.items.count)
    }

    func test_intentGroupExcludesRizoRows() {
        let list = checklist([item("rizo-1", .rizo), item("knob", .intentKnob)])
        XCTAssertEqual(App2WeeklyReviewView.intentItems(list).map(\.itemId), ["knob"])
    }
}
