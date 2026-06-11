# 指標跑體驗弧線 iOS UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓用戶在 app 端完整體感「我選擇跑指標跑 → 跑完成果回饋到訓練流程 → 訓練數據更精準」——把後端 v2 已接好的 benchmark 機制在 iOS 用四張專屬畫面呈現（執行確認卡 / 校準成果卡 / 課表 benchmark 日份量 / readiness 歸因），並補後端 typed 對比欄位。

**Architecture:** 後端 v2 機制已 merged main（merge `6fbd9fbc`）——同意閘走既有 `next_week_adjustments.items` toggle、校準走 `benchmark_confirmed_runs` registry + 加權 VDOT。本計畫**不碰** toggle / `apply` 預設 / `applied_indices` 同意閘機制，只在三處下手：(1) 後端把既有效益句計算抽成 typed field 塞進 item `value`；(2) iOS 三層寬鬆解碼（DTO union → Entity typed payload → Mapper 分流），未知/缺欄位一律 fallback 普通卡；(3) 渲染層 switch 出專屬卡。分層交付，每層獨立可驗、可單獨上線。

**Tech Stack:** Backend = Python / FastAPI（`cloud/api_service`，`conda activate api`）。iOS = SwiftUI / Swift（`apps/ios/Havital`，scheme `Havital`，測試 target 模組名 `paceriz_dev`）。UI 驗收 = Maestro（iPhone 17 Pro、zh-TW、不用 `--no-window`）。

**來源 spec:** `apps/ios/Havital/Docs/superpowers/specs/2026-06-11-benchmark-ios-ui-design.md`

---

## 跨 repo 分支與前置（開工前必讀）

- **iOS 主線是 `main`**（記憶 [[project_ios_branch_topology]]，2026-06-11 用戶再確認；spec §跨 repo 內「主線是 ui_revamp」那段**已過時**，勿信）。當前 working tree 停在 `feature/rizo-plan-change-buttons`（與 benchmark 無關），**不可**把本工作堆在上面。
- **iOS 開工**：`cd apps/ios/Havital && git checkout main && git pull && git checkout -b feature/benchmark-ios-ui`（已有一條 7 天前的 `feature/benchmark-ios`，不沿用，從 main 重切乾淨線）。spec 檔 `Docs/superpowers/specs/2026-06-11-benchmark-ios-ui-design.md` 目前 untracked，第一個 commit 一併納入。
- **後端開工**：`cd cloud/api_service && git checkout main && git checkout -b feature/benchmark-ios-fields`。**白名單 commit**——main 上有用戶未提交的 trim/treadmill 工作（[[project_two_workout_write_paths]]），只 `git add` 本計畫碰的檔，**絕不** `git add -A`。
- **後端 Python 一律先** `conda activate api`。
- **後端跑 benchmark/replay/emulator 測試一律帶** `GRPC_DNS_RESOLVER=native`（[[feedback_grpc_dns_resolver]]）與 `FIRESTORE_EMULATOR_HOST=localhost:8080`（emulator-gated 測試沒這個會靜默 skip 假綠，[[feedback_emulator_gated_replay_tests]]）。
- **commit message 標 role**（[[feedback_agent_commit_marker]]）：後端 `Backend Developer:`、iOS `iOS Developer:`。
- **部署是用戶的事**（[[feedback_never_manual_cloud_run.md]]）——本計畫只到「dev 驗證 + 本機測試綠」，不部署不 push。

---

## 資料契約（跨層 SSOT，先看這個）

兩種 benchmark adjustment item 的 `value` JSON 形狀。Layer 1 後端產出、iOS 消費，後面各層都依此契約：

**`execute_benchmark` item.value**（既有 `overview_id`/`week`/`distance_km` + 新增 `scheduled_weekday`）：
```json
{
  "overview_id": "abc_5",
  "week": 2,
  "distance_km": 5.0,
  "scheduled_weekday": 6
}
```
- `scheduled_weekday`：ISO 8601，1=週一 … 7=週日；**optional**，無法判定時省略 → iOS 用通用文案「下週的長跑」。

**`adjust_vdot` item.value**（既有欄位 + 新增 `calibration_preview` 物件）：
```json
{
  "suggested_vdot": 44.2, "source_workout_id": "w123",
  "benchmark_distance_m": 5000.0, "benchmark_duration_s": 1320.0,
  "residual_pct": 3.1, "suggested_change_rounded": 1.5,
  "should_hedge": false, "workout_date": "2026-06-18", "overview_id": "abc_5",
  "calibration_preview": {
    "pace_before_s_per_km": 330, "pace_after_s_per_km": 322,
    "race_distance_label": "半馬", "race_distance_km": 21.0975,
    "race_time_before_s": 6750, "race_time_after_s": 6490,
    "vdot_before": 42.5, "vdot_after": 44.0
  }
}
```
- `calibration_preview` **整塊 optional**；任一換算失敗 → 後端整塊省略 → iOS 校準卡降級（只顯示成績 + VDOT 變化）。
- 慣例（與既有 `benchmark_confirmation_section` 效益句一致）：`*_after` 一律以 `vdot_after = prior_vdot + suggested_change_rounded` 換算；`vdot_before = prior_vdot`。

**readiness response 新增**（只在用戶有 confirmed benchmark 且還在 28 天加權窗內時帶；§E 用）：
```json
{ "vdot_source": "benchmark", "benchmark_date": "2026-06-18" }
```

向後相容：以上**全為新增 optional**，舊 client 全忽略。

---

## Layer 1 — 資料地基（後端 typed field + iOS 三層解碼 + fallback）

### Task 1.1: 後端 `_build_calibration_preview` helper + 單元測試

**Files:**
- Modify: `cloud/api_service/domains/summary/services/weekly_summary_v2_service.py`（新增 helper method，注入點在 Task 1.2）
- Test: `cloud/api_service/tests/unit/domains/summary/test_benchmark_calibration_preview.py`（新建）

- [ ] **Step 1: 寫失敗測試**

新建 `tests/unit/domains/summary/test_benchmark_calibration_preview.py`：
```python
"""calibration_preview 換算正確性（純函式，無 IO/LLM mock）。"""
import math
import pytest

from domains.summary.services.weekly_summary_v2_service import (
    weekly_summary_v2_service as svc,
)
from domains.training_plan.train_utils import get_speed_zones
from domains.training_plan.services.readiness.v2.vdot_utils import vdot_to_race_time


def _expected_easy_pace_s(vdot: float) -> int:
    z = get_speed_zones(vdot)["easy"]
    mid = (z[0] + z[1]) / 2.0
    return round(1000.0 / mid)


def test_calibration_preview_pace_and_race_time_before_after():
    prior_vdot = 42.5
    suggested_change_rounded = 1.5
    out = svc._build_calibration_preview(
        prior_vdot=prior_vdot,
        suggested_change_rounded=suggested_change_rounded,
        target_distance_km=21.0975,
        race_distance_label="半馬",
    )
    assert out is not None
    # 配速：before=prior，after=prior+rounded
    assert out["pace_before_s_per_km"] == _expected_easy_pace_s(prior_vdot)
    assert out["pace_after_s_per_km"] == _expected_easy_pace_s(prior_vdot + suggested_change_rounded)
    # after 比 before 快（秒/km 較小）
    assert out["pace_after_s_per_km"] < out["pace_before_s_per_km"]
    # 完賽時間：after 比 before 短
    assert out["race_time_before_s"] == round(vdot_to_race_time(prior_vdot, 21.0975))
    assert out["race_time_after_s"] == round(vdot_to_race_time(prior_vdot + suggested_change_rounded, 21.0975))
    assert out["race_time_after_s"] < out["race_time_before_s"]
    # VDOT 輔助小字
    assert out["vdot_before"] == 42.5
    assert out["vdot_after"] == 44.0
    assert out["race_distance_label"] == "半馬"
    assert out["race_distance_km"] == 21.0975


def test_calibration_preview_returns_none_when_prior_missing():
    assert svc._build_calibration_preview(
        prior_vdot=None, suggested_change_rounded=1.5,
        target_distance_km=21.0975, race_distance_label="半馬",
    ) is None


def test_calibration_preview_omits_race_when_no_target_distance():
    out = svc._build_calibration_preview(
        prior_vdot=42.5, suggested_change_rounded=1.5,
        target_distance_km=None, race_distance_label=None,
    )
    assert out is not None  # 配速段仍可算
    assert out["pace_before_s_per_km"] is not None
    assert "race_time_before_s" not in out or out.get("race_time_before_s") is None
```

- [ ] **Step 2: 跑測試確認 FAIL**

Run: `conda activate api && GRPC_DNS_RESOLVER=native python -m pytest tests/unit/domains/summary/test_benchmark_calibration_preview.py -v`
Expected: FAIL，`AttributeError: ... has no attribute '_build_calibration_preview'`

- [ ] **Step 3: 實作 helper**

在 `weekly_summary_v2_service.py` 的 `WeeklySummaryV2Service` class 內、`_apply_benchmark_review_adjustment`（行 2965）上方加 method：
```python
    @staticmethod
    def _build_calibration_preview(
        *,
        prior_vdot: Optional[float],
        suggested_change_rounded: Optional[float],
        target_distance_km: Optional[float],
        race_distance_label: Optional[str],
    ) -> Optional[dict]:
        """把 benchmark 校準效益抽成 typed 對比欄位（spec §A.1 calibration_preview）。

        慣例與 benchmark_confirmation_section._easy_pace_shift_s_per_km 一致：
        after 以 vdot_after = prior_vdot + suggested_change_rounded 換算。
        任何失敗回 None（卡片可降級不可顯示假數字）。配速可算但賽事段缺 →
        只省略 race_* 欄位（回 dict 但不含 race_time_*）。
        """
        try:
            if not prior_vdot or prior_vdot <= 0 or suggested_change_rounded is None:
                return None
            from domains.training_plan.train_utils import get_speed_zones

            vdot_after = float(prior_vdot) + float(suggested_change_rounded)

            def _easy_pace_s(vdot: float) -> Optional[int]:
                z = get_speed_zones(vdot).get("easy")
                if not z:
                    return None
                mid = (z[0] + z[1]) / 2.0
                return round(1000.0 / mid) if mid > 0 else None

            pace_before = _easy_pace_s(float(prior_vdot))
            pace_after = _easy_pace_s(vdot_after)
            if pace_before is None or pace_after is None:
                return None

            preview: dict = {
                "pace_before_s_per_km": pace_before,
                "pace_after_s_per_km": pace_after,
                "vdot_before": round(float(prior_vdot), 1),
                "vdot_after": round(vdot_after, 1),
            }

            # 賽事完賽預測段（缺目標距離就跳過，不讓整塊失敗）。
            if target_distance_km and target_distance_km > 0:
                from domains.training_plan.services.readiness.v2.vdot_utils import (
                    vdot_to_race_time,
                )
                t_before = vdot_to_race_time(float(prior_vdot), float(target_distance_km))
                t_after = vdot_to_race_time(vdot_after, float(target_distance_km))
                if t_before and t_after:
                    preview["race_distance_km"] = float(target_distance_km)
                    if race_distance_label:
                        preview["race_distance_label"] = race_distance_label
                    preview["race_time_before_s"] = round(t_before)
                    preview["race_time_after_s"] = round(t_after)
            return preview
        except Exception as exc:  # noqa: BLE001 — 效益欄位可缺不可錯
            logger.warning("_build_calibration_preview failed: %s", exc)
            return None
```

- [ ] **Step 4: 跑測試確認 PASS**

Run: `conda activate api && GRPC_DNS_RESOLVER=native python -m pytest tests/unit/domains/summary/test_benchmark_calibration_preview.py -v`
Expected: 3 passed

- [ ] **Step 5: Commit**
```bash
git add tests/unit/domains/summary/test_benchmark_calibration_preview.py \
        domains/summary/services/weekly_summary_v2_service.py
git commit -m "Backend Developer: add _build_calibration_preview typed-field helper for benchmark card"
```

---

### Task 1.2: 把 `calibration_preview` 與 `scheduled_weekday` 塞進 item.value

**Files:**
- Modify: `cloud/api_service/domains/summary/services/weekly_summary_v2_service.py:3009-3019`（ADJUST_VDOT value）
- Modify: `cloud/api_service/domains/summary/services/weekly_summary_v2_service.py:3216-3228`（EXECUTE_BENCHMARK value）
- Test: `cloud/api_service/tests/unit/domains/summary/test_benchmark_item_value_fields.py`（新建）

- [ ] **Step 1: 寫失敗測試**

新建 `tests/unit/domains/summary/test_benchmark_item_value_fields.py`：
```python
"""驗 ADJUST_VDOT item.value 帶 calibration_preview、EXECUTE_BENCHMARK 帶 scheduled_weekday。
真實 service method，最小 stub context（無 LLM、無 Firestore 寫入）。"""
from types import SimpleNamespace

from data_models.weekly_summary_v2 import (
    AdjustmentItemType, NextWeekAdjustmentsV2, WeeklySummaryV2LLMOutput,
)
from domains.summary.services.benchmark_review import BenchmarkReviewSuggestion
from domains.summary.services.weekly_summary_v2_service import weekly_summary_v2_service as svc


def _ctx(**kw):
    base = dict(
        uid="u1", week_of_training=1, training_overview_id="ov_1",
        plan_context=SimpleNamespace(target_distance_km=21.0975),
        benchmark_review=None, next_week_benchmark=None,
    )
    base.update(kw)
    return SimpleNamespace(**base)


def test_adjust_vdot_value_has_calibration_preview():
    review = BenchmarkReviewSuggestion(
        source_workout_id="w1", benchmark_distance_m=5000.0, benchmark_duration_s=1320.0,
        benchmark_vdot=44.0, prior_vdot=42.5, suggested_change=1.5,
        suggested_change_rounded=1.5, residual_pct=3.0, should_hedge=False,
        workout_date="2026-06-18",
    )
    ctx = _ctx(benchmark_review=review)
    out = svc._apply_benchmark_review_adjustment(
        context=ctx, llm_output=WeeklySummaryV2LLMOutput(next_week_adjustments=None),
    )
    item = out.next_week_adjustments.items[0]
    assert item.type == AdjustmentItemType.ADJUST_VDOT
    cp = item.value["calibration_preview"]
    assert cp["pace_after_s_per_km"] < cp["pace_before_s_per_km"]
    assert cp["race_time_after_s"] < cp["race_time_before_s"]
    assert cp["vdot_before"] == 42.5 and cp["vdot_after"] == 44.0


def test_execute_benchmark_value_has_scheduled_weekday_optional():
    ctx = _ctx(next_week_benchmark={"milestone_type": "time_trial_5k", "week": 2})
    out = svc._apply_benchmark_confirm_item(
        context=ctx, llm_output=WeeklySummaryV2LLMOutput(next_week_adjustments=None), lang="zh-TW",
    )
    item = out.next_week_adjustments.items[0]
    assert item.type == AdjustmentItemType.EXECUTE_BENCHMARK
    # scheduled_weekday 為 optional：無法判定時不在 value（不可崩、不可塞錯值）
    assert "scheduled_weekday" not in item.value or isinstance(item.value["scheduled_weekday"], int)
```

- [ ] **Step 2: 跑測試確認 FAIL**

Run: `conda activate api && GRPC_DNS_RESOLVER=native python -m pytest tests/unit/domains/summary/test_benchmark_item_value_fields.py -v`
Expected: FAIL（`KeyError: 'calibration_preview'`）

- [ ] **Step 3a: 改 ADJUST_VDOT value（行 3009-3019）**

在 `_apply_benchmark_review_adjustment` 內，把 value dict 組裝改為先算 preview 再併入：
```python
            # value 載荷：apply-items endpoint 在用戶 apply 時用來寫 confirmed registry。
            # 全取 suggestion 既有欄位，不重算。
            value = {
                "suggested_vdot": suggestion.benchmark_vdot,
                "source_workout_id": suggestion.source_workout_id,
                "benchmark_distance_m": suggestion.benchmark_distance_m,
                "benchmark_duration_s": suggestion.benchmark_duration_s,
                "residual_pct": suggestion.residual_pct,
                "suggested_change_rounded": suggestion.suggested_change_rounded,
                "should_hedge": suggestion.should_hedge,
                "workout_date": suggestion.workout_date,
                "overview_id": getattr(context, "training_overview_id", None) or "",
            }
            # spec §A.1：typed 對比欄位（卡片 before/after 主角）。算不出就不塞 → 卡片降級。
            _target_km = (
                context.plan_context.target_distance_km
                if getattr(context, "plan_context", None) else None
            )
            _race_label = self._benchmark_race_distance_label(_target_km)
            preview = self._build_calibration_preview(
                prior_vdot=suggestion.prior_vdot,
                suggested_change_rounded=suggestion.suggested_change_rounded,
                target_distance_km=_target_km,
                race_distance_label=_race_label,
            )
            if preview is not None:
                value["calibration_preview"] = preview
```

並在 class 內（`_build_calibration_preview` 旁）加賽事距離 label helper：
```python
    @staticmethod
    def _benchmark_race_distance_label(distance_km: Optional[float]) -> Optional[str]:
        """目標賽事距離 → i18n 標籤（半馬/全馬/10K/5K）。不對齊已知距離回 None。

        注意：此處回繁中固定字串供卡片即時顯示；iOS 端 race_distance_label 直接渲染。
        若要三語，後端應改吃 lang——本期先繁中（卡片其餘文字 iOS 端 i18n）。
        """
        if not distance_km:
            return None
        table = [(42.195, "全馬"), (21.0975, "半馬"), (10.0, "10K"), (5.0, "5K"), (3.0, "3K")]
        for d, label in table:
            if abs(distance_km - d) <= 0.5:
                return label
        return f"{distance_km:g}K"
```

- [ ] **Step 3b: 改 EXECUTE_BENCHMARK value（行 3216-3228）**

在 `_apply_benchmark_confirm_item` 組 `item` 的 `value={...}` 內加 `scheduled_weekday`：
```python
        item = AdjustmentItemV2(
            content=_benchmark_confirm_item_text(lang, distance_km),
            category="general",
            apply=True,   # 預設執行（spec D2）
            type=AdjustmentItemType.EXECUTE_BENCHMARK,
            reason=_benchmark_confirm_item_reason(lang),
            impact=_benchmark_confirm_item_impact(lang),
            priority="high",
            value={
                "overview_id": getattr(context, "training_overview_id", None) or "",
                "week": int(milestone.get("week") or 0),
                "distance_km": distance_km,
                # spec §A.1：optional，讓卡片寫「下週X的長跑換成…」。
                # 取 milestone 既有 scheduled_weekday（排程 SSOT 寫入時帶），無則省略。
                **(
                    {"scheduled_weekday": int(milestone["scheduled_weekday"])}
                    if isinstance(milestone.get("scheduled_weekday"), int)
                    else {}
                ),
            },
            description="Next-week benchmark execution confirm",
        )
```

> 註：`milestone` 是否帶 `scheduled_weekday` 取決於排程 SSOT（`benchmark_scheduling.decide_benchmark_week` / `_ensure_next_week_benchmark_milestone`）。**先做 optional 讀取**——若 milestone 目前無此欄位，`scheduled_weekday` 自然不出現、iOS 用通用文案，不阻塞。若要補齊，後續在 `decide_benchmark_week` 寫 milestone 時加 long-run weekday（另 follow-up，非本 task 阻塞項）。

- [ ] **Step 4: 跑測試確認 PASS**

Run: `conda activate api && GRPC_DNS_RESOLVER=native python -m pytest tests/unit/domains/summary/test_benchmark_item_value_fields.py tests/unit/domains/summary/test_benchmark_calibration_preview.py -v`
Expected: all passed

- [ ] **Step 5: 跑既有 benchmark 回歸（確認沒打壞同意閘/序列化）**

Run（依 `TESTING_MAP.md` benchmark 段）：
```bash
conda activate api && GRPC_DNS_RESOLVER=native FIRESTORE_EMULATOR_HOST=localhost:8080 \
  python -m pytest tests/unit/domains/summary -k "benchmark" -q
```
Expected: all passed（含既有 EXECUTE_BENCHMARK / ADJUST_VDOT 注入測試）

- [ ] **Step 6: Commit**
```bash
git add tests/unit/domains/summary/test_benchmark_item_value_fields.py \
        domains/summary/services/weekly_summary_v2_service.py
git commit -m "Backend Developer: inject calibration_preview + scheduled_weekday into benchmark item.value"
```

---

### Task 1.3: iOS DTO union（`type` + `value`）+ 解碼測試

**Files:**
- Modify: `apps/ios/Havital/Havital/Features/TrainingPlanV2/Data/DTOs/WeeklySummaryV2DTO.swift:467-486`
- Test: `apps/ios/Havital/HavitalTests/Features/TrainingPlanV2/BenchmarkAdjustmentDecodeTests.swift`（新建）

- [ ] **Step 1: 寫失敗測試**

新建 `HavitalTests/Features/TrainingPlanV2/BenchmarkAdjustmentDecodeTests.swift`：
```swift
import XCTest
@testable import paceriz_dev   // ⚠️ 測試模組名是 paceriz_dev，不是 Havital

final class BenchmarkAdjustmentDecodeTests: XCTestCase {

    private func decode(_ json: String) throws -> AdjustmentItemV2DTO {
        try JSONDecoder().decode(AdjustmentItemV2DTO.self, from: Data(json.utf8))
    }

    func test_executeBenchmark_decodes_type_and_value() throws {
        let dto = try decode(#"""
        {"content":"c","category":"general","apply":true,"reason":"r","impact":"i","priority":"high",
         "type":"execute_benchmark",
         "value":{"overview_id":"ov_5","week":2,"distance_km":5.0,"scheduled_weekday":6}}
        """#)
        XCTAssertEqual(dto.type, "execute_benchmark")
        XCTAssertEqual(dto.value?.distanceKm, 5.0)
        XCTAssertEqual(dto.value?.scheduledWeekday, 6)
    }

    func test_adjustVdot_decodes_calibration_preview() throws {
        let dto = try decode(#"""
        {"content":"c","category":"general","apply":false,"reason":"r","impact":"i","priority":"high",
         "type":"adjust_vdot",
         "value":{"benchmark_distance_m":5000.0,"benchmark_duration_s":1320.0,"should_hedge":false,
           "suggested_change_rounded":1.5,"workout_date":"2026-06-18","overview_id":"ov_5",
           "calibration_preview":{"pace_before_s_per_km":330,"pace_after_s_per_km":322,
             "race_distance_label":"半馬","race_distance_km":21.0975,
             "race_time_before_s":6750,"race_time_after_s":6490,
             "vdot_before":42.5,"vdot_after":44.0}}}
        """#)
        XCTAssertEqual(dto.type, "adjust_vdot")
        XCTAssertEqual(dto.value?.calibrationPreview?.paceAfterSPerKm, 322)
        XCTAssertEqual(dto.value?.calibrationPreview?.raceTimeAfterS, 6490)
    }

    func test_unknownType_and_missingValue_decodes_to_nil_no_crash() throws {
        let dto = try decode(#"""
        {"content":"c","category":"volume","apply":true,"reason":"r","impact":"i","priority":"medium"}
        """#)
        XCTAssertNil(dto.type)
        XCTAssertNil(dto.value)
    }
}
```

- [ ] **Step 2: 跑測試確認 FAIL（編譯失敗：DTO 無 type/value）**

Run:
```bash
cd apps/ios/Havital && xcodebuild test -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4' \
  -only-testing:HavitalTests/BenchmarkAdjustmentDecodeTests -parallel-testing-enabled NO 2>&1 | tail -30
```
Expected: 編譯失敗，`value of type 'AdjustmentItemV2DTO' has no member 'type'`

- [ ] **Step 3: 加 DTO 欄位**

`WeeklySummaryV2DTO.swift:467-486` 的 `AdjustmentItemV2DTO` 加兩個 optional 欄位 + 新 union value DTO。改寫整個 struct：
```swift
struct AdjustmentItemV2DTO: Codable {
    let content: String
    let category: String
    let apply: Bool
    let slotType: String?
    let trainingType: String?
    let reason: String
    let impact: String
    let sourceFlag: String?
    let priority: String
    let type: String?                       // 寬鬆契約：String 不是 enum，未知值不崩
    let value: AdjustmentItemValueDTO?

    enum CodingKeys: String, CodingKey {
        case content, category, apply
        case slotType = "slot_type"
        case trainingType = "training_type"
        case reason, impact
        case sourceFlag = "source_flag"
        case priority, type, value
    }
}

/// 兩種 benchmark payload 的欄位聯集（全 optional，避免 AnyCodable）。
struct AdjustmentItemValueDTO: Codable {
    // execute_benchmark
    let week: Int?
    let distanceKm: Double?
    let scheduledWeekday: Int?
    // adjust_vdot
    let benchmarkDistanceM: Double?
    let benchmarkDurationS: Double?
    let shouldHedge: Bool?
    let suggestedChangeRounded: Double?
    let workoutDate: String?
    let calibrationPreview: CalibrationPreviewDTO?
    // shared
    let overviewId: String?

    enum CodingKeys: String, CodingKey {
        case week
        case distanceKm = "distance_km"
        case scheduledWeekday = "scheduled_weekday"
        case benchmarkDistanceM = "benchmark_distance_m"
        case benchmarkDurationS = "benchmark_duration_s"
        case shouldHedge = "should_hedge"
        case suggestedChangeRounded = "suggested_change_rounded"
        case workoutDate = "workout_date"
        case calibrationPreview = "calibration_preview"
        case overviewId = "overview_id"
    }
}

struct CalibrationPreviewDTO: Codable {
    let paceBeforeSPerKm: Int?
    let paceAfterSPerKm: Int?
    let raceDistanceLabel: String?
    let raceDistanceKm: Double?
    let raceTimeBeforeS: Int?
    let raceTimeAfterS: Int?
    let vdotBefore: Double?
    let vdotAfter: Double?

    enum CodingKeys: String, CodingKey {
        case paceBeforeSPerKm = "pace_before_s_per_km"
        case paceAfterSPerKm = "pace_after_s_per_km"
        case raceDistanceLabel = "race_distance_label"
        case raceDistanceKm = "race_distance_km"
        case raceTimeBeforeS = "race_time_before_s"
        case raceTimeAfterS = "race_time_after_s"
        case vdotBefore = "vdot_before"
        case vdotAfter = "vdot_after"
    }
}
```

- [ ] **Step 4: 跑測試確認 PASS**

Run: 同 Step 2 指令
Expected: 3 tests passed

- [ ] **Step 5: Commit**
```bash
cd apps/ios/Havital && git add Havital/Features/TrainingPlanV2/Data/DTOs/WeeklySummaryV2DTO.swift \
  HavitalTests/Features/TrainingPlanV2/BenchmarkAdjustmentDecodeTests.swift \
  Docs/superpowers/specs/2026-06-11-benchmark-ios-ui-design.md
git commit -m "iOS Developer: add type+value union DTO for benchmark adjustment items"
```

---

### Task 1.4: iOS Entity typed payload + Mapper 分流 + Mapper 測試

**Files:**
- Modify: `apps/ios/Havital/Havital/Features/TrainingPlanV2/Domain/Entities/WeeklySummaryV2.swift:526-545`
- Modify: `apps/ios/Havital/Havital/Features/TrainingPlanV2/Data/Mappers/WeeklySummaryV2Mapper.swift:299-311`
- Test: `apps/ios/Havital/HavitalTests/Features/TrainingPlanV2/BenchmarkAdjustmentMapperTests.swift`（新建）

- [ ] **Step 1: 寫失敗測試**

新建 `HavitalTests/Features/TrainingPlanV2/BenchmarkAdjustmentMapperTests.swift`：
```swift
import XCTest
@testable import paceriz_dev

final class BenchmarkAdjustmentMapperTests: XCTestCase {

    private func entity(from json: String) throws -> AdjustmentItemV2 {
        let dto = try JSONDecoder().decode(AdjustmentItemV2DTO.self, from: Data(json.utf8))
        return WeeklySummaryV2Mapper.testMapAdjustmentItem(dto)
    }

    func test_executeBenchmark_maps_to_execute_payload() throws {
        let e = try entity(from: #"""
        {"content":"c","category":"general","apply":true,"reason":"r","impact":"i","priority":"high",
         "type":"execute_benchmark","value":{"distance_km":5.0,"week":2,"scheduled_weekday":6}}
        """#)
        XCTAssertNotNil(e.benchmarkExecute)
        XCTAssertEqual(e.benchmarkExecute?.distanceKm, 5.0)
        XCTAssertEqual(e.benchmarkExecute?.scheduledWeekday, 6)
        XCTAssertNil(e.benchmarkCalibration)
    }

    func test_adjustVdot_maps_to_calibration_payload() throws {
        let e = try entity(from: #"""
        {"content":"c","category":"general","apply":false,"reason":"r","impact":"i","priority":"high",
         "type":"adjust_vdot","value":{"benchmark_distance_m":5000.0,"benchmark_duration_s":1320.0,
           "should_hedge":false,"workout_date":"2026-06-18",
           "calibration_preview":{"pace_before_s_per_km":330,"pace_after_s_per_km":322,
             "race_distance_label":"半馬","race_time_before_s":6750,"race_time_after_s":6490,
             "vdot_before":42.5,"vdot_after":44.0}}}
        """#)
        XCTAssertNotNil(e.benchmarkCalibration)
        XCTAssertEqual(e.benchmarkCalibration?.distanceKm, 5.0)
        XCTAssertEqual(e.benchmarkCalibration?.durationS, 1320.0)
        XCTAssertEqual(e.benchmarkCalibration?.paceAfterSPerKm, 322)
        XCTAssertFalse(e.benchmarkCalibration?.shouldHedge ?? true)
        XCTAssertNil(e.benchmarkExecute)
    }

    func test_unknownType_maps_to_plain_item_both_nil() throws {
        let e = try entity(from: #"""
        {"content":"c","category":"volume","apply":true,"reason":"r","impact":"i","priority":"medium"}
        """#)
        XCTAssertNil(e.benchmarkExecute)
        XCTAssertNil(e.benchmarkCalibration)
    }

    func test_adjustVdot_missing_calibration_still_maps_payload_with_nil_preview() throws {
        // 校準 preview 缺 → 仍給 payload（卡片降級顯示成績+VDOT），preview 欄位皆 nil
        let e = try entity(from: #"""
        {"content":"c","category":"general","apply":false,"reason":"r","impact":"i","priority":"high",
         "type":"adjust_vdot","value":{"benchmark_distance_m":3000.0,"benchmark_duration_s":780.0,
           "should_hedge":true,"workout_date":"2026-06-18"}}
        """#)
        XCTAssertNotNil(e.benchmarkCalibration)
        XCTAssertEqual(e.benchmarkCalibration?.distanceKm, 3.0)
        XCTAssertTrue(e.benchmarkCalibration?.shouldHedge ?? false)
        XCTAssertNil(e.benchmarkCalibration?.paceAfterSPerKm)
    }
}
```

- [ ] **Step 2: 跑測試確認 FAIL（編譯失敗）**

Run:
```bash
cd apps/ios/Havital && xcodebuild test -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4' \
  -only-testing:HavitalTests/BenchmarkAdjustmentMapperTests -parallel-testing-enabled NO 2>&1 | tail -30
```
Expected: 編譯失敗（`benchmarkExecute` / `testMapAdjustmentItem` 不存在）

- [ ] **Step 3a: Entity 加 typed payload**

`WeeklySummaryV2.swift:526-545` 的 `AdjustmentItemV2` 加兩個 optional payload + 兩個 payload struct。改寫 struct（保留既有欄位，**新增**末尾兩個 let + CodingKeys 不含新欄位因為 Entity 由 Mapper 建非直接解碼——但 Entity 目前是 `Codable`，新增的 payload 非 wire 欄位，需從 CodingKeys 排除）：
```swift
struct AdjustmentItemV2: Codable, Equatable {
    let content: String
    let category: String
    let apply: Bool
    let slotType: String?
    let trainingType: String?
    let reason: String
    let impact: String
    let sourceFlag: String?
    let priority: String
    // benchmark 專屬 payload（非 wire 欄位，由 Mapper 依 type 填；解碼時為 nil）
    var benchmarkExecute: BenchmarkExecutePayload?
    var benchmarkCalibration: BenchmarkCalibrationPayload?

    enum CodingKeys: String, CodingKey {
        case content, category, apply
        case slotType = "slot_type"
        case trainingType = "training_type"
        case reason, impact
        case sourceFlag = "source_flag"
        case priority
        // benchmarkExecute / benchmarkCalibration 不在 CodingKeys：非 wire 欄位
    }
}

struct BenchmarkExecutePayload: Equatable {
    let distanceKm: Double
    let scheduledWeekday: Int?   // ISO 1=Mon..7=Sun；nil → 通用文案
}

struct BenchmarkCalibrationPayload: Equatable {
    let workoutDate: String?
    let distanceKm: Double        // benchmark_distance_m / 1000
    let durationS: Double
    let shouldHedge: Bool
    // calibration_preview（全 optional，缺則卡片降級）
    let paceBeforeSPerKm: Int?
    let paceAfterSPerKm: Int?
    let raceDistanceLabel: String?
    let raceTimeBeforeS: Int?
    let raceTimeAfterS: Int?
    let vdotBefore: Double?
    let vdotAfter: Double?
}
```

> 注意：因為 `benchmarkExecute`/`benchmarkCalibration` 排除在 `CodingKeys` 外，編譯器合成的 `init(from:)` 不會碰它們，但 stored property 需有預設值或在 init 設定。改成 `var ... = nil`：把兩行改為 `var benchmarkExecute: BenchmarkExecutePayload? = nil` 與 `var benchmarkCalibration: BenchmarkCalibrationPayload? = nil`（合成 decodable 對排除欄位要求有預設值）。

- [ ] **Step 3b: Mapper 分流**

`WeeklySummaryV2Mapper.swift:299-311` 的 `toAdjustmentItem` 改寫，依 type 解 payload；並加一個 test-only 暴露入口：
```swift
    private static func toAdjustmentItem(from dto: AdjustmentItemV2DTO) -> AdjustmentItemV2 {
        var item = AdjustmentItemV2(
            content: dto.content,
            category: dto.category,
            apply: dto.apply,
            slotType: dto.slotType,
            trainingType: dto.trainingType,
            reason: dto.reason,
            impact: dto.impact,
            sourceFlag: dto.sourceFlag,
            priority: dto.priority
        )
        switch dto.type {
        case "execute_benchmark":
            if let v = dto.value, let dist = v.distanceKm {
                item.benchmarkExecute = BenchmarkExecutePayload(
                    distanceKm: dist,
                    scheduledWeekday: v.scheduledWeekday
                )
            }
        case "adjust_vdot":
            if let v = dto.value, let distM = v.benchmarkDistanceM, let dur = v.benchmarkDurationS {
                let cp = v.calibrationPreview
                item.benchmarkCalibration = BenchmarkCalibrationPayload(
                    workoutDate: v.workoutDate,
                    distanceKm: distM / 1000.0,
                    durationS: dur,
                    shouldHedge: v.shouldHedge ?? false,
                    paceBeforeSPerKm: cp?.paceBeforeSPerKm,
                    paceAfterSPerKm: cp?.paceAfterSPerKm,
                    raceDistanceLabel: cp?.raceDistanceLabel,
                    raceTimeBeforeS: cp?.raceTimeBeforeS,
                    raceTimeAfterS: cp?.raceTimeAfterS,
                    vdotBefore: cp?.vdotBefore,
                    vdotAfter: cp?.vdotAfter
                )
            }
        default:
            break   // 未知/缺 type → 兩者 nil → 普通卡 fallback
        }
        return item
    }

    #if DEBUG
    /// Test-only：暴露單 item 映射供單元測試（避免測試組整份 summary）。
    static func testMapAdjustmentItem(_ dto: AdjustmentItemV2DTO) -> AdjustmentItemV2 {
        toAdjustmentItem(from: dto)
    }
    #endif
```

- [ ] **Step 4: 跑測試確認 PASS**

Run: 同 Step 2 指令
Expected: 4 tests passed

- [ ] **Step 5: Build gate（Layer 1 完成必過 clean build）**

Run:
```bash
cd apps/ios/Havital && xcodebuild clean build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**
```bash
cd apps/ios/Havital && git add Havital/Features/TrainingPlanV2/Domain/Entities/WeeklySummaryV2.swift \
  Havital/Features/TrainingPlanV2/Data/Mappers/WeeklySummaryV2Mapper.swift \
  HavitalTests/Features/TrainingPlanV2/BenchmarkAdjustmentMapperTests.swift
git commit -m "iOS Developer: map benchmark item type to typed payload, fallback to plain card"
```

---

## Layer 2 — 展示資料注入工具（G.1，優先做，支撐後面實機驗收）

### Task 2.1: benchmark 狀態注入腳本（dev 寫、prod 唯讀）

**Files:**
- Create: `cloud/api_service/scripts/inject_benchmark_demo_state.py`

注入工具讓一鍵把 dev 帳號設成四種狀態之一，simulator 登入即見對應畫面。**四種狀態**：`execute`（下週有 active milestone → 執行卡）、`plan-day`（本週課表含 benchmark 日 → 詳情頁）、`calibration`（注入一筆全力 workout、三層儲存齊 → 校準卡）、`attributed`（已 apply 校準 → readiness 歸因）。

- [ ] **Step 1: 寫腳本骨架（argparse + 安全閘）**

新建 `scripts/inject_benchmark_demo_state.py`：
```python
"""benchmark 弧線 demo 狀態注入（dev 寫入、prod 唯讀）。

用法：
  conda activate api
  GRPC_DNS_RESOLVER=native python scripts/inject_benchmark_demo_state.py \
      --env dev --uid <DEV_UID> --state execute

state：execute | plan-day | calibration | attributed
參考既有手法：reset-v2-weekly-plan skill、benchmark v2 Task 13 E2E 注入
（workout HR 路徑 basic_metrics.avg_heart_rate_bpm、workouts_v2_index/ 寫入、
用戶時區日期對齊）。prod（--env paceriz）一律拒絕寫入。
"""
import argparse
import logging
import sys

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger(__name__)

VALID_STATES = {"execute", "plan-day", "calibration", "attributed"}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--env", required=True, choices=["dev"],
                    help="只允許 dev；prod 唯讀，本工具拒絕寫入")
    ap.add_argument("--uid", required=True)
    ap.add_argument("--state", required=True, choices=sorted(VALID_STATES))
    args = ap.parse_args()

    if args.env != "dev":
        logger.error("拒絕：注入工具只能寫 dev。prod 唯讀。")
        return 2

    # Firestore client（dev project）。沿用 agent_tools/scripts 既有 init 樣式。
    from google.cloud import firestore
    db = firestore.Client(project="havital-dev")

    dispatch = {
        "execute": _inject_execute,
        "plan-day": _inject_plan_day,
        "calibration": _inject_calibration,
        "attributed": _inject_attributed,
    }
    dispatch[args.state](db, args.uid)
    logger.info("done: uid=%s state=%s (env=dev)", args.uid, args.state)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: 實作 `execute` 狀態（下週 active benchmark milestone）**

加 `_inject_execute(db, uid)`：在 overview doc 寫一顆 `week = current_week + 1` 的 active benchmark milestone（`milestone_type=time_trial_5k`、`status=active`、`materialize_benchmark=True`），並確保 `last_app_version >= "1.4.2"`（版本閘）。實作參考 `_ensure_next_week_benchmark_milestone` 寫回 milestone 的形狀（`weekly_summary_v2_service.py:3076`）與 benchmark v2 plan Task 的 milestone schema。
```python
def _inject_execute(db, uid: str) -> None:
    # 1) 找 active overview doc（users/{uid}/training_overview 最新）
    # 2) milestones[] append/replace 一顆 week=current+1 的 active benchmark milestone
    #    {type:"benchmark", milestone_type:"time_trial_5k", week:<w+1>,
    #     status:"active", materialize_benchmark:True, scheduled_weekday:6}
    # 3) users/{uid} doc 設 last_app_version="1.4.2"（過版本閘）
    # 具體欄位以 benchmark v2 overview milestone schema 為準（讀現有 doc 對齊）。
    raise NotImplementedError("依現有 overview milestone schema 實作；讀一份真 dev doc 對齊欄位")
```

> 實作者：先用 `./agent_tools/fsq --env dev --user <uid>` 讀一份真實 overview doc 對齊 milestone 欄位，再寫入。不要憑空造 schema。

- [ ] **Step 3: 實作 `calibration` 狀態（注入全力 workout，三層儲存齊）**

加 `_inject_calibration(db, uid)`：注入一筆「本週、排定 benchmark 日、全力 5K」workout，三層儲存齊全（Firestore 明細 + `workouts_v2_index/` + Cloud SQL 列表），HR 走 `basic_metrics.avg_heart_rate_bpm`，日期對齊用戶時區。參考 [[reference_demo_account_workout_setup]] 的 `copy_real_workouts_to_demo.py` 與 benchmark v2 Task 13 E2E 注入手法。
```python
def _inject_calibration(db, uid: str) -> None:
    # workout payload 關鍵欄位：
    #   basic_metrics.total_distance_m = 5000
    #   basic_metrics.total_duration_s = 1320  (22:00，全力配速)
    #   basic_metrics.avg_heart_rate_bpm = <接近 maxHR>
    #   start_time_utc = 本週 benchmark 日（用戶時區→UTC）
    # 三層：Firestore workout doc + workouts_v2_index/ 索引 + Cloud SQL 列表
    # （dev/prod 共用同一 Cloud SQL，注意別污染——見 reference_demo_account_workout_setup）
    raise NotImplementedError("依 copy_real_workouts_to_demo.py 三層寫入手法實作")
```

- [ ] **Step 4: 實作 `plan-day` 與 `attributed`**

`_inject_plan_day`：確保本週課表含一個 `run_type=benchmark` 的日（走官方重產或直接寫 `weekly_plans_v2` doc 某日 `run_type=benchmark`）。`_inject_attributed`：在 `_inject_calibration` 基礎上，再寫 `benchmark_confirmed_runs` registry 一筆（confirmed），模擬已 apply 校準。
```python
def _inject_plan_day(db, uid: str) -> None:
    raise NotImplementedError("寫 weekly_plans_v2 當週某日 run_type=benchmark，或走官方重產腳本")

def _inject_attributed(db, uid: str) -> None:
    _inject_calibration(db, uid)
    # + user_override_service.record_confirmed_benchmark(uid, ...) 等價寫入 registry
    raise NotImplementedError("寫 benchmark_confirmed_runs registry 一筆 confirmed")
```

- [ ] **Step 5: 冒煙驗證（dev，唯讀檢查 + 寫一種狀態）**

Run（先確認 prod 閘擋住）：
```bash
conda activate api && GRPC_DNS_RESOLVER=native \
  python scripts/inject_benchmark_demo_state.py --env paceriz --uid x --state execute; echo "exit=$?"
```
Expected: 印「拒絕：注入工具只能寫 dev」，`exit=2`

Run（dev 寫 execute，再用 fsq 確認 milestone 落地）：
```bash
conda activate api && GRPC_DNS_RESOLVER=native \
  python scripts/inject_benchmark_demo_state.py --env dev --uid <DEV_UID> --state execute
GRPC_DNS_RESOLVER=native ./agent_tools/fsq --env dev --user <DEV_UID> | grep -i benchmark
```
Expected: 看到 week=current+1 的 active benchmark milestone

- [ ] **Step 6: Commit**
```bash
cd cloud/api_service && git add scripts/inject_benchmark_demo_state.py
git commit -m "Backend Developer: benchmark demo-state injection tool (dev-only, prod read-only)"
```

---

## Layer 3 — 執行確認卡（§B）+ Maestro

### Task 3.1: benchmark 設計資產別名（色 token + icon SSOT）

**Files:**
- Modify: `apps/ios/Havital/Havital/Core/Presentation/PacerizDesignSystem.swift`
- Modify: `apps/ios/Havital/Havital/Models/DayType+Extensions.swift:71-72`

- [ ] **Step 1: 加 benchmark 語意別名**

`PacerizDesignSystem.swift` 的 `PacerizColor` 加（沿用既有 `PacerizColor.indigo` #6366F1）：
```swift
    /// benchmark（指標跑）四觸點共用語意色（= indigo #6366F1）。SSOT，勿散落 .indigo。
    static var benchmark: Color { indigo }
```
並在同檔加 benchmark icon SSOT（選 `gauge.with.dots.needle`，四觸點一致）：
```swift
enum PacerizIcon {
    static let benchmark = "gauge.with.dots.needle"
}
```

- [ ] **Step 2: DayType benchmark 色改走別名**

`DayType+Extensions.swift:71-72` 把 `return .indigo` 改 `return PacerizColor.benchmark`。
同步 `PlannedSessionDetailView.swift:94` 的 `case .benchmark: return .indigo` 改 `return PacerizColor.benchmark`。

- [ ] **Step 3: Build 確認**

Run:
```bash
cd apps/ios/Havital && xcodebuild build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4' 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**
```bash
cd apps/ios/Havital && git add Havital/Core/Presentation/PacerizDesignSystem.swift \
  Havital/Models/DayType+Extensions.swift \
  Havital/Features/TrainingPlanV2/Presentation/Views/PlannedSessionDetailView.swift
git commit -m "iOS Developer: add PacerizColor.benchmark + PacerizIcon.benchmark semantic SSOT"
```

### Task 3.2: i18n key（執行卡，三語）

**Files:**
- Modify: `apps/ios/Havital/Havital/Resources/zh-Hant.lproj/Localizable.strings`
- Modify: `apps/ios/Havital/Havital/Resources/en.lproj/Localizable.strings`
- Modify: `apps/ios/Havital/Havital/Resources/ja.lproj/Localizable.strings`

- [ ] **Step 1: 三語加 key（執行卡 §B 元素）**

`zh-Hant.lproj/Localizable.strings` 加：
```
"benchmark.execute.chip" = "下週重點 · 實力校準";
"benchmark.execute.title" = "%@ 公里指標跑";
"benchmark.execute.coach" = "全力跑一次固定距離，我用它把你的配速基準和完賽預測調準。";
"benchmark.execute.schedule_weekday" = "%@的長跑換成指標跑；前一天自動安排休息保體力。";
"benchmark.execute.schedule_generic" = "下週的長跑換成指標跑；前一天自動安排休息保體力。";
"benchmark.execute.toggle" = "安排這次指標跑";
"benchmark.execute.toggle_hint" = "取消＝這週先不排，之後可請 Rizo 重排。";
"benchmark.execute.skipped" = "這週先跳過";
"benchmark.weekday.1" = "下週一"; "benchmark.weekday.2" = "下週二"; "benchmark.weekday.3" = "下週三";
"benchmark.weekday.4" = "下週四"; "benchmark.weekday.5" = "下週五"; "benchmark.weekday.6" = "下週六";
"benchmark.weekday.7" = "下週日";
```
`en.lproj/Localizable.strings` 加對應英文（`benchmark.execute.title` = `"%@ km benchmark run"`，weekday = `"next Monday"`…等）。
`ja.lproj/Localizable.strings` 加對應日文（`"%@ km ベンチマーク走"`，weekday = `"来週月曜"`…等）。

> 三語完整值由 implementer 依 spec §B 元素 + 既有 `training.type.benchmark` 語氣補齊；上面 zh-Hant 是 SSOT 範本。

- [ ] **Step 2: Commit**
```bash
cd apps/ios/Havital && git add Havital/Resources/*.lproj/Localizable.strings
git commit -m "iOS Developer: i18n keys for benchmark execute card (3 locales)"
```

### Task 3.3: 執行確認卡 View + 渲染分流

**Files:**
- Create: `apps/ios/Havital/Havital/Features/TrainingPlanV2/Presentation/Views/Components/BenchmarkExecuteCard.swift`
- Modify: `apps/ios/Havital/Havital/Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift:809-833`（`AdjustmentsSectionV2` 的 ForEach 分流）

- [ ] **Step 1: 寫卡片 View（indigo hero 小卡）**

新建 `BenchmarkExecuteCard.swift`：
```swift
import SwiftUI

/// 執行確認卡（spec §B）：週回顧「下週調整建議」內的 indigo hero 小卡。
/// 底層仍是 adjustment item — toggle 綁同一 binding，取消 → index 不送 → milestone declined。
struct BenchmarkExecuteCard: View {
    let payload: BenchmarkExecutePayload
    let index: Int
    @Binding var isSelected: Bool

    private var weekdayText: String {
        if let wd = payload.scheduledWeekday, (1...7).contains(wd) {
            let label = NSLocalizedString("benchmark.weekday.\(wd)", comment: "")
            return String(format: NSLocalizedString("benchmark.execute.schedule_weekday", comment: ""), label)
        }
        return NSLocalizedString("benchmark.execute.schedule_generic", comment: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: PacerizIcon.benchmark)
                Text(NSLocalizedString("benchmark.execute.chip", comment: ""))
                    .font(AppFont.micro()).tracking(0.04)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(PacerizColor.benchmark))

            Text(String(format: NSLocalizedString("benchmark.execute.title", comment: ""),
                        String(format: "%g", payload.distanceKm)))
                .font(AppFont.title3()).fontWeight(.bold).foregroundColor(.primary)

            Text(NSLocalizedString("benchmark.execute.coach", comment: ""))
                .font(AppFont.subheadline()).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(weekdayText)
                .font(AppFont.caption()).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack {
                Text(NSLocalizedString("benchmark.execute.toggle", comment: ""))
                    .font(AppFont.subheadline()).fontWeight(.medium)
                Spacer()
                Toggle("", isOn: $isSelected).labelsHidden()
                    .accessibilityIdentifier("v2.summary.benchmark_execute_toggle_\(index)")
            }
            Text(isSelected
                 ? NSLocalizedString("benchmark.execute.toggle_hint", comment: "")
                 : NSLocalizedString("benchmark.execute.skipped", comment: ""))
                .font(AppFont.caption()).foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: PacerizRadius.card)
                .stroke(PacerizColor.benchmark.opacity(0.5), lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: PacerizRadius.card)
                        .fill(PacerizColor.benchmark.opacity(0.06))
                )
        )
        .opacity(isSelected ? 1.0 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityIdentifier("v2.summary.benchmark_execute_card_\(index)")
    }
}
```

- [ ] **Step 2: 渲染分流（WeeklySummaryV2View ForEach）**

`WeeklySummaryV2View.swift:809-833` 的 `ForEach` 內，把 `AdjustmentItemCardV2(...)` 包成 switch：
```swift
            ForEach(Array(adjustments.items.enumerated()), id: \.offset) { index, item in
                let binding: Binding<Bool> = showToggles
                    ? Binding(
                        get: { coordinator.adjustmentSelections[index] ?? true },
                        set: { coordinator.adjustmentSelections[index] = $0 })
                    : .constant(true)

                if let exec = item.benchmarkExecute {
                    BenchmarkExecuteCard(payload: exec, index: index, isSelected: binding)
                } else if let calib = item.benchmarkCalibration {
                    BenchmarkCalibrationCard(payload: calib, index: index, isSelected: binding)
                } else {
                    AdjustmentItemCardV2(item: item, index: index, isSelected: binding)
                }
            }
```

> `BenchmarkCalibrationCard` 在 Layer 4 Task 4.2 建立。本 task 為了編譯通過，**先只加 `benchmarkExecute` 分支**，`benchmarkCalibration` 分支留到 Task 4.2 一併加（或先加一個 stub view）。為避免半成品編譯失敗，本 Step 只放 execute 分支：
```swift
                if let exec = item.benchmarkExecute {
                    BenchmarkExecuteCard(payload: exec, index: index, isSelected: binding)
                } else {
                    AdjustmentItemCardV2(item: item, index: index, isSelected: binding)
                }
```

- [ ] **Step 3: Build 確認**

Run:
```bash
cd apps/ios/Havital && xcodebuild build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4' 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: SwiftUI Preview 視覺自驗（用 mock payload）**

在 `BenchmarkExecuteCard.swift` 末尾加 `#Preview`：
```swift
#Preview {
    VStack {
        BenchmarkExecuteCard(
            payload: BenchmarkExecutePayload(distanceKm: 5.0, scheduledWeekday: 6),
            index: 0, isSelected: .constant(true))
        BenchmarkExecuteCard(
            payload: BenchmarkExecutePayload(distanceKm: 3.0, scheduledWeekday: nil),
            index: 1, isSelected: .constant(false))
    }.padding()
}
```
用 Xcode Canvas 或 simulator 確認版型（indigo chip / 標題大字 / toggle 行 / 未選灰化）。

- [ ] **Step 5: Commit**
```bash
cd apps/ios/Havital && git add Havital/Features/TrainingPlanV2/Presentation/Views/Components/BenchmarkExecuteCard.swift \
  Havital/Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift
git commit -m "iOS Developer: benchmark execute card + render branch in adjustments section"
```

### Task 3.4: Maestro flow（執行卡）+ 實機截圖驗收

**Files:**
- Create: `apps/ios/Havital/.maestro/flows/benchmark-execute-card.yaml`

- [ ] **Step 1: 注入 execute 狀態**

Run:
```bash
cd cloud/api_service && conda activate api && GRPC_DNS_RESOLVER=native \
  python scripts/inject_benchmark_demo_state.py --env dev --uid <DEV_UID> --state execute
```

- [ ] **Step 2: 寫 Maestro flow**

新建 `.maestro/flows/benchmark-execute-card.yaml`：
```yaml
appId: com.havital.paceriz
---
- launchApp
# 前置：dev 帳號已注入 execute 狀態（下週 active benchmark milestone）
# 走到本週週回顧 sheet（生成下週課表的必經路徑）
- tapOn: { id: "weekly_summary_entry" }   # 依實際 entry id 調整
- assertVisible: { id: "v2.summary.benchmark_execute_card_0" }
- assertVisible: "安排這次指標跑"
- assertVisible:
    text: ".*公里指標跑"
- takeScreenshot: benchmark-execute-card
```

- [ ] **Step 3: 跑 Maestro（iPhone 17 Pro、zh-TW、不用 --no-window）**

Run:
```bash
adb? 不適用——iOS 用 simulator。先確認 locale=zh-TW，再：
cd apps/ios/Havital && maestro test .maestro/flows/benchmark-execute-card.yaml
```
Expected: PASS + 截圖產出

- [ ] **Step 4: 自驗截圖（Architect 親 Read，不可信 agent 回報）**

Read 截圖檔，逐項確認：indigo chip「下週重點 · 實力校準」、標題「5 公里指標跑」、toggle「安排這次指標跑」預設開、安排說明顯示星期。對照 spec §B 元素層級 1-6。
（[[feedback_verify_screenshot_yourself]]、[[feedback_self_verify_before_user_test]]）

- [ ] **Step 5: Commit**
```bash
cd apps/ios/Havital && git add .maestro/flows/benchmark-execute-card.yaml
git commit -m "iOS Developer: maestro flow + screenshot for benchmark execute card"
```

---

## Layer 4 — 校準成果卡（§C，差異展示為主角）+ Maestro

### Task 4.1: i18n key（校準卡，三語）

**Files:**
- Modify: `apps/ios/Havital/Havital/Resources/{zh-Hant,en,ja}.lproj/Localizable.strings`

- [ ] **Step 1: 三語加 key（校準卡 §C 元素）**

`zh-Hant.lproj` 加（SSOT 範本）：
```
"benchmark.calib.chip" = "指標跑成果 · 實力校準";
"benchmark.calib.headline" = "你 %1$@ 的 %2$@K 指標跑跑出 %3$@，我用它重新校準了你的實力。";
"benchmark.calib.pace_label" = "訓練配速";
"benchmark.calib.pace_delta" = "快了 %@ 秒";
"benchmark.calib.race_label" = "完賽預測";
"benchmark.calib.vdot_label" = "VDOT";
"benchmark.calib.hedge" = "這次測量和你近期狀態有落差，可能是疲勞或設定，我先謹慎調整。";
"benchmark.calib.lag_notice" = "課表配速會在 2-3 週逐步反映（系統刻意不追單週起伏）。";
"benchmark.calib.toggle" = "採用這次校準";
"benchmark.calib.toggle_hint" = "看完差異後主動勾選才套用。";
```
`en.lproj` / `ja.lproj` 加對應三語（headline 三參數順序用 `%1$@ %2$@ %3$@` 保持各語可調序）。

- [ ] **Step 2: Commit**
```bash
cd apps/ios/Havital && git add Havital/Resources/*.lproj/Localizable.strings
git commit -m "iOS Developer: i18n keys for benchmark calibration card (3 locales)"
```

### Task 4.2: 校準成果卡 View（before/after 三欄主角）+ 接上分流

**Files:**
- Create: `apps/ios/Havital/Havital/Features/TrainingPlanV2/Presentation/Views/Components/BenchmarkCalibrationCard.swift`
- Modify: `apps/ios/Havital/Havital/Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift`（ForEach 加 `benchmarkCalibration` 分支）

- [ ] **Step 1: 寫卡片 View**

新建 `BenchmarkCalibrationCard.swift`：
```swift
import SwiftUI

/// 校準成果卡（spec §C）：跑完指標跑那週回顧出現。before/after 差異是視覺主角。
/// 底層仍是 adjustment item — toggle 預設關（confirm gate），勾選 → apply-items 寫 registry。
struct BenchmarkCalibrationCard: View {
    let payload: BenchmarkCalibrationPayload
    let index: Int
    @Binding var isSelected: Bool

    private func mmss(_ s: Int) -> String { "\(s / 60):\(String(format: "%02d", s % 60))" }
    private func hms(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? "\(h):\(String(format: "%02d", m)):\(String(format: "%02d", sec))"
                     : "\(m):\(String(format: "%02d", sec))"
    }

    private var headline: String {
        String(format: NSLocalizedString("benchmark.calib.headline", comment: ""),
               payload.workoutDate ?? "",
               String(format: "%g", payload.distanceKm),
               mmss(Int(payload.durationS)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: PacerizIcon.benchmark)
                Text(NSLocalizedString("benchmark.calib.chip", comment: "")).font(AppFont.micro())
            }
            .foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(PacerizColor.benchmark))

            Text(headline).font(AppFont.subheadline()).fontWeight(.medium)
                .fixedSize(horizontal: false, vertical: true)

            // before/after 主角區（缺 calibration_preview → 整塊不顯示，卡片降級為成績+VDOT）
            if let pb = payload.paceBeforeSPerKm, let pa = payload.paceAfterSPerKm {
                contrastRow(
                    label: NSLocalizedString("benchmark.calib.pace_label", comment: ""),
                    before: "\(mmss(pb))/km", after: "\(mmss(pa))/km",
                    delta: pb > pa ? String(format: NSLocalizedString("benchmark.calib.pace_delta", comment: ""), "\(pb - pa)") : nil)
            }
            if let rb = payload.raceTimeBeforeS, let ra = payload.raceTimeAfterS {
                contrastRow(
                    label: "\(NSLocalizedString("benchmark.calib.race_label", comment: ""))\(payload.raceDistanceLabel.map { " · \($0)" } ?? "")",
                    before: hms(rb), after: hms(ra), delta: nil)
            }
            if let vb = payload.vdotBefore, let va = payload.vdotAfter {
                Text("\(NSLocalizedString("benchmark.calib.vdot_label", comment: "")) \(String(format: "%.1f", vb)) → \(String(format: "%.1f", va))")
                    .font(AppFont.caption()).foregroundColor(.secondary)
            }

            // hedge 謹慎分支 vs 正常預告
            Text(payload.shouldHedge
                 ? NSLocalizedString("benchmark.calib.hedge", comment: "")
                 : NSLocalizedString("benchmark.calib.lag_notice", comment: ""))
                .font(AppFont.caption()).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
            HStack {
                Text(NSLocalizedString("benchmark.calib.toggle", comment: "")).font(AppFont.subheadline()).fontWeight(.medium)
                Spacer()
                Toggle("", isOn: $isSelected).labelsHidden()
                    .accessibilityIdentifier("v2.summary.benchmark_calib_toggle_\(index)")
            }
            Text(NSLocalizedString("benchmark.calib.toggle_hint", comment: ""))
                .font(AppFont.caption()).foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: PacerizRadius.card)
                .stroke(PacerizColor.benchmark.opacity(0.5), lineWidth: 1.5)
                .background(RoundedRectangle(cornerRadius: PacerizRadius.card).fill(PacerizColor.benchmark.opacity(0.06))))
        .accessibilityIdentifier("v2.summary.benchmark_calib_card_\(index)")
    }

    private func contrastRow(label: String, before: String, after: String, delta: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(AppFont.caption()).foregroundColor(.secondary)
            HStack(spacing: 8) {
                Text(before).font(AppFont.subheadline()).foregroundColor(.secondary).strikethrough()
                Image(systemName: "arrow.right").font(AppFont.caption()).foregroundColor(.secondary)
                Text(after).font(AppFont.headline()).fontWeight(.bold).foregroundColor(.primary)
                if let delta {
                    Text(delta).font(AppFont.caption()).foregroundColor(.green)
                }
            }
        }
    }
}

#Preview {
    BenchmarkCalibrationCard(
        payload: BenchmarkCalibrationPayload(
            workoutDate: "2026-06-18", distanceKm: 5.0, durationS: 1320, shouldHedge: false,
            paceBeforeSPerKm: 330, paceAfterSPerKm: 322, raceDistanceLabel: "半馬",
            raceTimeBeforeS: 6750, raceTimeAfterS: 6490, vdotBefore: 42.5, vdotAfter: 44.0),
        index: 0, isSelected: .constant(false)).padding()
}
```

- [ ] **Step 2: 接上分流（補回 Task 3.3 Step 2 預留的 calibration 分支）**

`WeeklySummaryV2View.swift` ForEach 改成完整三分支：
```swift
                if let exec = item.benchmarkExecute {
                    BenchmarkExecuteCard(payload: exec, index: index, isSelected: binding)
                } else if let calib = item.benchmarkCalibration {
                    BenchmarkCalibrationCard(payload: calib, index: index, isSelected: binding)
                } else {
                    AdjustmentItemCardV2(item: item, index: index, isSelected: binding)
                }
```

- [ ] **Step 3: Build 確認**

Run:
```bash
cd apps/ios/Havital && xcodebuild build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4' 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**
```bash
cd apps/ios/Havital && git add Havital/Features/TrainingPlanV2/Presentation/Views/Components/BenchmarkCalibrationCard.swift \
  Havital/Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift
git commit -m "iOS Developer: benchmark calibration card (before/after hero) + wire calibration branch"
```

### Task 4.3: Maestro flow（校準卡）+ 實機截圖驗收

**Files:**
- Create: `apps/ios/Havital/.maestro/flows/benchmark-calibration-card.yaml`

- [ ] **Step 1: 注入 calibration 狀態 + 跑 flow**

Run:
```bash
cd cloud/api_service && conda activate api && GRPC_DNS_RESOLVER=native \
  python scripts/inject_benchmark_demo_state.py --env dev --uid <DEV_UID> --state calibration
```
新建 `.maestro/flows/benchmark-calibration-card.yaml`：
```yaml
appId: com.havital.paceriz
---
- launchApp
- tapOn: { id: "weekly_summary_entry" }
- assertVisible: { id: "v2.summary.benchmark_calib_card_0" }
- assertVisible: "採用這次校準"
- assertVisible: "完賽預測"
- takeScreenshot: benchmark-calibration-card
```
Run: `cd apps/ios/Havital && maestro test .maestro/flows/benchmark-calibration-card.yaml`
Expected: PASS

- [ ] **Step 2: 自驗截圖**

Read 截圖，確認：before/after 三欄是視覺重心（配速 strikethrough→粗體、完賽預測、VDOT 角落小字）、toggle「採用這次校準」**預設關**、教練肯定開頭句帶日期/距離/成績。對照 spec §C。

- [ ] **Step 3: Commit**
```bash
cd apps/ios/Havital && git add .maestro/flows/benchmark-calibration-card.yaml
git commit -m "iOS Developer: maestro flow + screenshot for benchmark calibration card"
```

---

## Layer 5 — 課表 benchmark 日份量（§D，詳情頁 hero）+ Maestro

### Task 5.1: PlannedSessionDetailView benchmark 分支增強

**Files:**
- Modify: `apps/ios/Havital/Havital/Features/TrainingPlanV2/Presentation/Views/PlannedSessionDetailView.swift:116`（chip 弱化配速）
- Modify: `apps/ios/Havital/Havital/Features/TrainingPlanV2/Presentation/Views/PlannedSessionDetailView.swift`（加「為什麼這天特別」說明卡）
- Modify: `apps/ios/Havital/Havital/Resources/{zh-Hant,en,ja}.lproj/Localizable.strings`

- [ ] **Step 1: i18n（詳情頁說明卡，三語）**

`zh-Hant.lproj` 加：
```
"benchmark.detail.why_title" = "為什麼這天特別";
"benchmark.detail.why_body" = "這是一次實力測量。全力跑完這 %@K，我會用你的成績重新校準訓練配速和完賽預測——所以盡力跑。前一天已自動安排休息，讓你保持新鮮。";
"benchmark.detail.loop_hint" = "跑完後，下次週回顧會給你校準成果。";
"benchmark.detail.all_out" = "全力跑、不用追配速";
"training.type.benchmark.chip" = "BENCHMARK · 全力測量";
```
en / ja 對應補齊。

- [ ] **Step 2: chip 弱化配速（行 116）**

`PlannedSessionDetailView.swift:116` 把 `case .benchmark: return ("BENCHMARK · Z4-Z5", ...)` 改為強調全力、移除 Z4-Z5 配速誘導：
```swift
            case .benchmark:        return (NSLocalizedString("training.type.benchmark.chip", comment: ""),
                                            NSLocalizedString("training.type.benchmark", comment: ""))
```
並在配速目標呈現處（detail body）對 `day.type == .benchmark` 隱藏/弱化區間配速，改顯示 `benchmark.detail.all_out`（「全力跑、不用追配速」）。實作者讀 detail body 配速顯示段（搜尋 `segmentPaceLabel` / `easyPaceRange` 使用處）對 benchmark 分支條件化。

- [ ] **Step 3: 加「為什麼這天特別」說明卡**

在 `PlannedSessionDetailView` body（hero 之下）對 `day.type == .benchmark` 加一張說明卡（借既有 `SectionCard` 或子卡樣式），內容用 `benchmark.detail.why_body`（帶距離）+ `benchmark.detail.loop_hint`，icon 用 `PacerizIcon.benchmark`、色用 `PacerizColor.benchmark`。

- [ ] **Step 4: Build 確認**

Run:
```bash
cd apps/ios/Havital && xcodebuild build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4' 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**
```bash
cd apps/ios/Havital && git add Havital/Features/TrainingPlanV2/Presentation/Views/PlannedSessionDetailView.swift \
  Havital/Resources/*.lproj/Localizable.strings
git commit -m "iOS Developer: benchmark plan-day detail hero (why-special card + de-emphasize pace)"
```

### Task 5.2: Maestro flow（詳情頁）+ 截圖驗收

**Files:**
- Create: `apps/ios/Havital/.maestro/flows/benchmark-plan-day.yaml`

- [ ] **Step 1: 注入 plan-day + 跑 flow + 自驗截圖**

Run:
```bash
cd cloud/api_service && conda activate api && GRPC_DNS_RESOLVER=native \
  python scripts/inject_benchmark_demo_state.py --env dev --uid <DEV_UID> --state plan-day
```
新建 `.maestro/flows/benchmark-plan-day.yaml`：
```yaml
appId: com.havital.paceriz
---
- launchApp
- tapOn: { text: ".*指標跑" }     # 點到課表 benchmark 日
- assertVisible: "為什麼這天特別"
- assertVisible: "全力跑、不用追配速"
- takeScreenshot: benchmark-plan-day
```
Run: `cd apps/ios/Havital && maestro test .maestro/flows/benchmark-plan-day.yaml`
Read 截圖確認：indigo hero + benchmark icon、說明卡、閉環埋線句、配速區間已弱化（無 Z4-Z5 誘導）。

- [ ] **Step 2: Commit**
```bash
cd apps/ios/Havital && git add .maestro/flows/benchmark-plan-day.yaml
git commit -m "iOS Developer: maestro flow + screenshot for benchmark plan-day detail"
```

---

## Layer 6 — readiness 歸因標記（§E）

### Task 6.1: 後端 readiness response 加歸因欄位 + 單元測試

**Files:**
- Modify: `cloud/api_service/domains/training_plan/services/readiness/metrics/race_fitness.py`（surface benchmark_confirmed 命中 → vdot_source/benchmark_date）
- Modify: readiness response 組裝處（implementer 定位：`grep -rn "current_vdot" domains/training_plan/services/readiness/`）
- Test: `cloud/api_service/tests/unit/domains/training_plan/services/readiness/test_benchmark_attribution.py`（新建）

- [ ] **Step 1: 定位 readiness response 組裝**

Run: `cd cloud/api_service && grep -rn "current_vdot\|race_fitness\|def compute" domains/training_plan/services/readiness/metrics/race_fitness.py | head`
找出 `current_vdot` 進入 readiness response 的 metric 出口（`_apply_benchmark_boost` 在 `race_fitness.py:758` 已對命中 entry 設 `entry["benchmark_confirmed"]=True`，沿這條把「有命中 + 命中日期」帶出來）。

- [ ] **Step 2: 寫失敗測試**

新建 `test_benchmark_attribution.py`：當 vdot_data 內有 `benchmark_confirmed=True` 的 entry → metric 輸出帶 `vdot_source="benchmark"` + `benchmark_date=<該 entry date>`；無 confirmed → 兩欄位皆 None/不帶。用真實 `RaceFitnessMetric` + stub vdot_data（不 mock Firestore，純計算路徑）。

- [ ] **Step 3: 跑測試確認 FAIL**

Run: `conda activate api && GRPC_DNS_RESOLVER=native python -m pytest tests/unit/domains/training_plan/services/readiness/test_benchmark_attribution.py -v`
Expected: FAIL

- [ ] **Step 4: 實作（surface 歸因欄位）**

在 `_apply_benchmark_boost` 命中後，把最近一筆 `benchmark_confirmed` 的日期記到 metric 結果；readiness response 組裝加兩個 optional 欄位：`vdot_source`（命中時 `"benchmark"`，否則沿用既有來源/省略）、`benchmark_date`。**不改 VDOT 計算本身**（加權池已保證 current_vdot 反映新值）。

- [ ] **Step 5: 跑測試確認 PASS + benchmark readiness 回歸**

Run:
```bash
conda activate api && GRPC_DNS_RESOLVER=native FIRESTORE_EMULATOR_HOST=localhost:8080 \
  python -m pytest tests/unit/domains/training_plan/services/readiness/test_benchmark_attribution.py \
  tests/unit/domains/training_plan/services/readiness/test_benchmark_weight_boost.py -v
```
Expected: all passed

- [ ] **Step 6: Commit**
```bash
cd cloud/api_service && git add domains/training_plan/services/readiness/metrics/race_fitness.py \
  <readiness response 組裝檔> \
  tests/unit/domains/training_plan/services/readiness/test_benchmark_attribution.py
git commit -m "Backend Developer: surface vdot_source=benchmark + benchmark_date in readiness response"
```

### Task 6.2: iOS readiness DTO 加歸因欄位 + 歸因標記 UI

**Files:**
- Modify: `apps/ios/Havital/Havital/Features/TrainingPlanV2/Data/DTOs/WeeklyPlanV2DTO.swift`（readiness DTO 加 `vdotSource` / `benchmarkDate`）
- Modify: `apps/ios/Havital/Havital/Features/TrainingPlanV2/Domain/Entities/WeeklyPlanV2.swift`（Entity 對應）
- Modify: readiness mapper + 顯示 `current_vdot` 的 readiness view（implementer 定位）
- Modify: `apps/ios/Havital/Havital/Resources/{zh-Hant,en,ja}.lproj/Localizable.strings`
- Test: iOS decode 測試（DTO 缺欄位 → nil 不崩）

- [ ] **Step 1: DTO/Entity 加 optional 欄位**

readiness DTO 加：
```swift
    let vdotSource: String?
    let benchmarkDate: String?
    // CodingKeys: case vdotSource = "vdot_source"; case benchmarkDate = "benchmark_date"
```
Entity 對應加 camelCase 欄位 + Mapper 帶過去。

- [ ] **Step 2: i18n + 歸因標記 UI**

`zh-Hant.lproj` 加：
```
"benchmark.readiness.attributed" = "實力評估已由你 %@ 的指標跑校準";
```
en/ja 補齊。在顯示 `current_vdot` 的 readiness 位置：`vdotSource == "benchmark"` 且 `benchmarkDate != nil` → 加小標記（indigo、`PacerizIcon.benchmark`），文案帶日期；欄位缺 → 不顯示（不報錯）。

- [ ] **Step 3: 解碼測試（缺欄位 fallback）**

加 XCTest：readiness JSON 無 `vdot_source` → DTO `vdotSource == nil`，不崩。
Run（`-only-testing:` 指向新測試）+ Expected PASS。

- [ ] **Step 4: Build + Commit**
```bash
cd apps/ios/Havital && xcodebuild build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4' 2>&1 | tail -3
# BUILD SUCCEEDED
git add Havital/Features/TrainingPlanV2/Data/DTOs/WeeklyPlanV2DTO.swift \
  Havital/Features/TrainingPlanV2/Domain/Entities/WeeklyPlanV2.swift \
  Havital/Features/TrainingPlanV2/Data/Mappers/WeeklyPlanV2Mapper.swift \
  Havital/Resources/*.lproj/Localizable.strings \
  HavitalTests/Features/TrainingPlanV2/BenchmarkReadinessAttributionTests.swift \
  <readiness view 檔>
git commit -m "iOS Developer: readiness benchmark attribution marker (vdot_source=benchmark)"
```

### Task 6.3: Maestro flow（歸因標記）+ 截圖驗收

**Files:**
- Create: `apps/ios/Havital/.maestro/flows/benchmark-readiness-attribution.yaml`

- [ ] **Step 1: 注入 attributed + 跑 flow + 自驗截圖**

Run:
```bash
cd cloud/api_service && conda activate api && GRPC_DNS_RESOLVER=native \
  python scripts/inject_benchmark_demo_state.py --env dev --uid <DEV_UID> --state attributed
```
新建 flow：launchApp → 走到 readiness/current_vdot 顯示處 → `assertVisible: "實力評估已由你.*的指標跑校準"` → takeScreenshot。
Run: `maestro test .maestro/flows/benchmark-readiness-attribution.yaml`
Read 截圖確認歸因標記顯示且有歸屬感。

- [ ] **Step 2: Commit**
```bash
cd apps/ios/Havital && git add .maestro/flows/benchmark-readiness-attribution.yaml
git commit -m "iOS Developer: maestro flow + screenshot for readiness benchmark attribution"
```

---

## Layer 7 — 設計資產收斂 + 後端 dev E2E + 對照組

### Task 7.1: 後端 dev E2E（calibration_preview / scheduled_weekday / 歸因 數字正確）

**Files:**
- Create/Extend: 延續 benchmark v2 後端 E2E（dev 帳號，真排課 + 真偵測），加驗新欄位

- [ ] **Step 1: dev E2E 驗 calibration_preview 數字**

用 dev 帳號 Cv5（[[reference_paceriz_envs_accounts]]）注入 calibration 狀態 → 打 `/v2/summary/weekly` → 確認 response 內 `adjust_vdot` item.value 帶 `calibration_preview`，且：
- `pace_after_s_per_km < pace_before_s_per_km`（VDOT 升 → 配速變快）
- `race_time_after_s < race_time_before_s`
- `vdot_after == vdot_before + suggested_change_rounded`
記錄真實 HTTP response 片段為證據（[[feedback_own_all_verification]]，不可只看單元測試）。

- [ ] **Step 2: dev E2E 驗 readiness 歸因 + execute scheduled_weekday**

attributed 狀態 → readiness response 帶 `vdot_source="benchmark"` + 正確 `benchmark_date`。
execute 狀態 → `execute_benchmark` item.value 帶（或正確省略）`scheduled_weekday`。

- [ ] **Step 3: 記錄 E2E 結果（依 delivery gate 格式）**

格式：`E2E verification: <真實 test>` / `Observed output: <response 片段>` / `Unit tests: all pass`。

### Task 7.2: 設計資產統一收斂 + 對照組回歸

**Files:**
- 全域 grep 確認 benchmark 色/icon SSOT 無散落

- [ ] **Step 1: 色 token SSOT 掃描**

Run:
```bash
cd apps/ios/Havital && grep -rn "\.indigo" Havital/Features/TrainingPlanV2 Havital/Models/DayType+Extensions.swift Havital/Features/TrainingPlanV2/Presentation/Views/PlannedSessionDetailView.swift --include="*.swift"
```
Expected: benchmark 相關處全走 `PacerizColor.benchmark`（非裸 `.indigo`）。散落的收斂掉。

- [ ] **Step 2: 對照組回歸（非 benchmark 帳號零變化）**

注入工具清掉 benchmark 狀態（或換無 benchmark 的 dev 帳號）→ 跑既有週回顧 Maestro flow → 確認普通 adjustment 卡照舊渲染、toggle/apply 機制不變。
Run iOS 全 benchmark 相關單元測試：
```bash
cd apps/ios/Havital && xcodebuild test -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4' \
  -only-testing:HavitalTests/BenchmarkAdjustmentDecodeTests \
  -only-testing:HavitalTests/BenchmarkAdjustmentMapperTests \
  -parallel-testing-enabled NO 2>&1 | tail -5
```
Expected: all passed

- [ ] **Step 3: 後端整體回歸（依 TESTING_MAP benchmark + summary 段）**

Run:
```bash
cd cloud/api_service && conda activate api && GRPC_DNS_RESOLVER=native FIRESTORE_EMULATOR_HOST=localhost:8080 \
  python -m pytest tests/unit/domains/summary -k "benchmark" \
  tests/unit/domains/training_plan/services/readiness -k "benchmark" -q
python scripts/analyze_import_shadowing.py
```
Expected: all passed + no shadowing

- [ ] **Step 4: 最終 iOS clean build gate**

Run:
```bash
cd apps/ios/Havital && xcodebuild clean build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 更新 TESTING_MAP + Commit**

`cloud/api_service/TESTING_MAP.md` 加新測試檔條目（benchmark calibration_preview / item value / attribution）。
```bash
cd cloud/api_service && git add TESTING_MAP.md
git commit -m "Backend Developer: TESTING_MAP entries for benchmark iOS-field tests"
```

---

## Self-Review（plan vs spec 覆蓋）

| spec 段 | 對應 Task | 覆蓋 |
|---|---|---|
| §A.1 後端 typed field（calibration_preview / scheduled_weekday / readiness 歸因） | 1.1, 1.2, 6.1 | ✅ |
| §A.2 iOS 三層解碼 + fallback | 1.3, 1.4 | ✅ |
| §A.3 不動同意閘 | 全程（binding 機制不碰） | ✅ |
| §B 執行確認卡 | 3.1–3.4 | ✅ |
| §C 校準成果卡（before/after 主角） | 4.1–4.3 | ✅ |
| §D 課表 benchmark 日份量 | 5.1–5.2 | ✅ |
| §E readiness 歸因 | 6.1–6.3 | ✅ |
| §F 設計資產（色/icon/i18n） | 3.1, 各層 i18n, 7.2 | ✅ |
| §G.1 注入工具 | 2.1 | ✅ |
| §G.2 Maestro e2e（每觸點） | 3.4, 4.3, 5.2, 6.3 | ✅ |
| §G.3 後端 dev E2E | 7.1 | ✅ |
| §G.4 SwiftUI Preview | 3.3, 4.2 | ✅ |
| 錯誤處理（寬鬆解碼 fallback / 缺欄位降級） | 1.4（unknown type / 缺 calibration），4.2（降級顯示） | ✅ |
| 對照組（非 benchmark 零變化） | 7.2 Step 2 | ✅ |

**已知殘留 / follow-up（非阻塞，計畫內已標註）：**
- `scheduled_weekday` 來源：milestone 目前可能無此欄位 → Task 1.2 先做 optional 讀取，補齊排程 SSOT 寫入是後續 follow-up。
- `race_distance_label` 後端先回繁中固定字串（Task 1.2 helper 註解已標）；要三語需後端吃 lang，本期未做。
- 注入工具四狀態 schema 需 implementer 讀真 dev doc 對齊（Task 2.1 已標 `NotImplementedError` + 對齊指示，禁止憑空造 schema）。

---

## Execution Handoff

詳見技能尾段：建議 **Subagent-Driven**（每 task 一個 fresh subagent + 兩階段審查），地基層（Layer 1）跑完先讓用戶看一次 DTO/Mapper 測試綠 + 後端欄位 E2E，再續做卡片層。
