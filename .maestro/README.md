# Havital Maestro UI Guardrail Suite

這套 Maestro 的定位是訓練計畫 UI 的最後防線，不重做 backend / domain 邏輯驗證。權威規格見 [Docs/specs/SPEC-maestro-ui-final-guardrail.md](/Users/wubaizong/havital/apps/ios/Havital/Docs/specs/SPEC-maestro-ui-final-guardrail.md)。

## 執行方式

```bash
~/.maestro/bin/maestro test .maestro/flows/
~/.maestro/bin/maestro test --include-tags critical .maestro/flows/
~/.maestro/bin/maestro test --include-tags boundary .maestro/flows/
~/.maestro/bin/maestro test --include-tags layer-c .maestro/flows/
~/.maestro/bin/maestro test --include-tags i18n .maestro/flows/
.maestro/scripts/run-maestro-with-artifact-cleanup.sh test .maestro/flows/onboarding-race-paceriz.yaml
.maestro/scripts/run-maestro-with-artifact-cleanup.sh cleanup-existing
.maestro/scripts/run-iap-regression.sh all
.maestro/scripts/run-iap-regression.sh R6
.maestro/scripts/run-iap-regression.sh R8
.maestro/scripts/run-iap-regression.sh R9
.maestro/scripts/run-maestro-categories.sh list
.maestro/scripts/run-maestro-categories.sh CAT-IAP
.maestro/scripts/run-maestro-categories.sh CAT-EDT
.maestro/scripts/run-maestro-categories.sh FULL-REGRESSION
# 可選：分類前置 flow（例如讓 WKY/EDT 先進入穩定起點）
MAESTRO_PREP_WKY=onboarding-race-paceriz.yaml MAESTRO_PREP_WKY_MODE=once \
  .maestro/scripts/run-maestro-categories.sh CAT-WKY
```

## 大分類前綴

| Prefix | 類別 |
|---|---|
| `CAT-IAP` | IAP 現役回歸 |
| `CAT-ONB` | Onboarding 核心/變體 |
| `CAT-BND` | Boundary matrix |
| `CAT-WKY` | Weekly/Overview/Summary/Preview |
| `CAT-EDT` | Edit Schedule 專項 |
| `CAT-REG` | Regression 單項 |
| `CAT-SUITE` | Regression 套件集合 |
| `CAT-UTL` | Utility/Reset/Smoke |
| `CAT-DBG` | Debug/Tmp |
| `CAT-ARC-IAP` | IAP 封存歷史測項 |
| `FULL-REGRESSION` | 全量 active 測項（`CAT-IAP + CAT-ONB + CAT-BND + CAT-WKY + CAT-EDT + CAT-REG`） |

註：
- `CAT-IAP` / `FULL-REGRESSION` 內的 IAP 段落會自動走 `.maestro/scripts/run-iap-regression.sh all`（含 backend precondition），不是裸跑 IAP flow。
- `FULL-REGRESSION` 會把各分類都跑完再回傳整體結果，不會在第一個失敗就中止。

## 測試層級

| Layer | 目的 | 代表 flow |
|---|---|---|
| A | PR smoke gate | `onboarding-race-paceriz.yaml`, `onboarding-beginner.yaml`, `onboarding-maintenance.yaml`, `regression-settings-profile.yaml` |
| B | 邊界 UI matrix | `boundary-race-paceriz-7days.yaml`, `boundary-race-paceriz-2days.yaml`, `boundary-beginner-24weeks-7days.yaml`, `boundary-maintenance-4weeks-2days.yaml`, `onboarding-race-start-from-build.yaml` |
| C | stateful recovery / consistency | `weekly-plan-delete-and-regenerate.yaml`, `overview-weekly-consistency.yaml` |
| D | localization parity | `regression-i18n-english.yaml`, `regression-i18n-japanese.yaml` |

## Shared Guardrails

| Helper | 用途 |
|---|---|
| `subflows/assert-onboarding-branch.yaml` | onboarding 分支必須顯式驗證，不用大量 `optional` 盲跳 |
| `subflows/assert-preference-persistence.yaml` | 儲存訓練日偏好後，overview 與 weekly plan 必須成功生成 |
| `subflows/assert-plan-overview-integrity.yaml` | overview 必須顯示總週數 / 生成入口 / 方法論標記 |
| `subflows/assert-weekly-plan-7days.yaml` | weekly plan 必須完整渲染 7 天 |
| `subflows/assert-workout-card-structure.yaml` | interval 類卡片至少要驗證結構未壞 |
| `subflows/assert-coach-sanity-relationships.yaml` | UI 層的教練合理性最後防線 |
| `subflows/assert-weekly-state-transition.yaml` | delete / regenerate 後不能殘留舊週資料 |
| `subflows/assert-training-plan-i18n.yaml` | i18n 驗證必須進入訓練計畫核心區 |
| `subflows/ensure-goal-type-screen.yaml` | 從 login / main app / onboarding 中間頁推進到 Goal Type，對齊真實 onboarding 狀態機 |

## Artifact Policy

- 預設保留 `ai-*`、`ai-report-*`、`commands-*`、`maestro.log`
- 通過的 run 不保留 `screenshot-*.png`
- 失敗的 run 只保留 `screenshot-❌-*.png`
- 使用 `.maestro/scripts/run-maestro-with-artifact-cleanup.sh` 執行，可自動套用以上規則

## 設計原則

- 不用 `optional` 把 `GoalType`、`Methodology`、`TrainingWeeks`、`StartStage`、`TrainingPreference` 這些核心分支沖掉。
- `assertNotVisible` 不能只在頂部 viewport 下結論；需要先掃完整週。
- 方法論驗證只補 UI mapping 與 coach-sanity 風險，不重做 backend 公式。
- i18n flow 至少覆蓋 weekly plan 與 overview，不只驗 profile/settings。

## 當前重構範圍

- 已建立 shared guardrail helper 並接入核心 onboarding / i18n / stateful recovery flow。
- 已補 `2-day / 7-day / 4-week / 24-week / start-from-build` 的 boundary 入口。
- 其餘舊 regression suite 仍可執行，但應逐步改接新的 `assert-*` subflows。
