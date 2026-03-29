# Paceriz iOS Regression Test Suite

## 快速開始

```bash
# 安裝 Maestro CLI（一次性）
curl -Ls "https://get.maestro.mobile.dev" | bash

# 跑全部 regression
~/.maestro/bin/maestro test .maestro/flows/

# 只跑 P0（上線前必測）
~/.maestro/bin/maestro test --include-tags critical .maestro/flows/

# 只跑 onboarding
~/.maestro/bin/maestro test --include-tags onboarding .maestro/flows/

# 只跑編輯課表
~/.maestro/bin/maestro test --include-tags edit .maestro/flows/
```

## 注意：每個 onboarding 測試前必須 reset

```bash
# 手動重啟 + reset（onboarding 測試前）
maestro test .maestro/flows/restart-app.yaml
maestro test .maestro/flows/reset-goal.yaml
maestro test .maestro/flows/onboarding-xxx.yaml
```

---

## Regression 測試項目

### A. Onboarding — Plan Overview + Weekly Plan 產生

驗證每種 Target Type × Methodology 組合都能成功完成 onboarding、產生 plan overview、產生 weekly plan。

| # | Flow | Target | Methodology | Start Stage | 優先級 | 課表驗證 |
|---|------|--------|-------------|-------------|--------|---------|
| T1 | `onboarding-race-paceriz.yaml` | race_run | paceriz | 預設 | P0 | 有輕鬆跑 |
| T2 | `onboarding-race-norwegian.yaml` | race_run | norwegian | 預設 | P1 | 有輕鬆跑、無間歇 |
| T3 | `onboarding-race-hansons.yaml` | race_run | hansons | 預設 | P1 | 有輕鬆跑 |
| T4 | `onboarding-race-polarized.yaml` | race_run | polarized | 預設 | P1 | 有輕鬆跑、無節奏跑 |
| T5 | `onboarding-beginner.yaml` | beginner | complete_5k | — | P0 | 有輕鬆跑、無間歇/節奏/巡航 |
| T6 | `onboarding-maintenance.yaml` | maintenance | aerobic_endurance | — | P0 | 有輕鬆跑、無間歇 |
| T7 | `onboarding-race-start-from-base.yaml` | race_run | paceriz | base | P1 | 有輕鬆跑、無節奏跑 |
| T8 | `onboarding-race-start-from-build.yaml` | race_run | paceriz | build | P2 | 有輕鬆跑、**有間歇** |

每個 flow 驗證鏈：PB → 週跑量 → 目標選擇 → (賽事/週數/方法論) → 訓練偏好 → **plan overview 產生** → **weekly plan 產生** → 7 天課表可見 → 有休息日 → 課表合理性 assertion

### B. 週課表顯示

| # | Flow | 驗證內容 | 優先級 |
|---|------|---------|--------|
| W1 | `weekly-plan-display.yaml` | 每日訓練、星期一、休息日、間歇/肌力訓練可見 | P0 |

### C. 編輯課表

| # | Flow | 驗證內容 | 優先級 |
|---|------|---------|--------|
| E1-E3 | `edit-schedule-full-test.yaml` | 進出不破壞 + 改訓練類型→儲存→主畫面更新 + 改配速→儲存 | P0 |
| E4 | `edit-interval-rest-type.yaml` | 間歇訓練休息段改「原地休息」→ 儲存 → 主畫面顯示正常 | P0 |

### D. 週回顧 + 課表重新產生

| # | Flow | 驗證內容 | 優先級 |
|---|------|---------|--------|
| S1 | `weekly-summary-generate.yaml` | Debug 產生週回顧 → 訓練完成度/亮點/分析/建議 | P0 |
| R1 | `weekly-plan-delete-and-regenerate.yaml` | 刪除課表+回顧 → 重新產生 → 7 天課表完整 | P0 |

### E. 需手動測試（自動化無法覆蓋）

| # | 測試項目 | 原因 | 優先級 |
|---|--------|------|--------|
| M1 | 拖動換天（帶力量訓練的日）| SwiftUI List .onMove 需長按+拖動，Maestro 無法觸發 | P1 |
| M2 | 修改距離（stepper）| 距離 stepper 不是 accessibility element | P1 |

---

## 檔案結構

```
.maestro/
├── README.md                              # 本文件
├── reports/
│   └── edit-schedule-test-report.md       # 編輯測試報告
├── subflows/
│   ├── pass-pb-step.yaml                  # 共用：通過 PB 頁
│   ├── pass-weekly-distance.yaml          # 共用：通過週跑量頁
│   └── verify-plan-generated.yaml         # 共用：驗證 overview + weekly plan + 合理性
└── flows/
    ├── restart-app.yaml                   # 工具：重啟 app
    ├── reset-goal.yaml                    # 前置：重新設定目標進入 onboarding
    ├── weekly-plan-display.yaml           # W1：週課表顯示驗證
    ├── edit-schedule-full-test.yaml       # E1-E3：編輯課表完整測試
    ├── onboarding-beginner.yaml           # T5：新手入門
    ├── onboarding-maintenance.yaml        # T6：維持訓練
    ├── onboarding-race-paceriz.yaml       # T1：賽事 + Paceriz
    ├── onboarding-race-norwegian.yaml     # T2：賽事 + Norwegian
    ├── onboarding-race-hansons.yaml       # T3：賽事 + Hansons
    ├── onboarding-race-polarized.yaml     # T4：賽事 + Polarized
    ├── onboarding-race-start-from-base.yaml   # T7：從基礎期開始
    └── onboarding-race-start-from-build.yaml  # T8：從強化期開始
```

---

## Target Type × Methodology 映射

| Target | 預設 Methodology | 可選 |
|--------|-----------------|------|
| race_run | paceriz | polarized, hansons, norwegian |
| beginner | complete_5k | complete_10k |
| maintenance | aerobic_endurance | balanced_fitness |

## 三種 Target Type 的 Onboarding 流程差異

| 步驟 | beginner | maintenance | race_run |
|------|----------|-------------|----------|
| PB | ✅ | ✅ | ✅ |
| 週跑量 | ✅ | ✅ | ✅ |
| 目標類型 | ✅ | ✅ | ✅ |
| 訓練週數 | ✅ | ❌ 跳過 | ❌ 跳過 |
| 賽事設定 | ❌ | ❌ | ✅ |
| 起始階段 | ❌ 可能出現 | ❌ | ✅ |
| 方法論 | ❌ | ✅ | ✅ |
| 訓練偏好 | ✅ | ✅ | ✅ |

---

## 課表合理性驗證規則

### 按 Methodology × Phase

| 方法論 | 第一週階段 | 必須有 | 不能有 |
|--------|-----------|--------|--------|
| Paceriz (conversion) | 轉換期 | 輕鬆跑, 休息 | 間歇, 節奏, 閾值, LSD |
| Paceriz (base) | 基礎期 | 輕鬆跑, LSD | 間歇, 節奏, 閾值 (strides 允許) |
| Paceriz (build) | 強化期 | 輕鬆跑, 間歇, cruise_intervals | race_pace |
| Norwegian (aerobic_foundation) | 有氧基礎 | 輕鬆跑, LSD | 間歇 |
| Hansons (foundation) | 基礎 | 輕鬆跑 | — |
| Polarized (base) | 基礎 | 輕鬆跑 (80%+低強度) | 節奏跑 |
| Beginner | conversion/base | 輕鬆跑, 休息 | 任何高強度 |
| Maintenance | maintenance | 輕鬆跑, LSD | 過多高強度 |

### 通用規則
- 每週至少 1 天休息
- 高強度之間至少隔 1 天
- 連續跑步不超過 5 天
- 配速 3:00-8:00/km（異常：<2:30 或 >9:00）
- 長跑不超過週跑量 45%

---

## Maestro 2.x 踩坑指南

### 語法限制
| 不支援 | 替代方案 |
|--------|---------|
| `timeout:` | 移除，Maestro 預設等 7 秒 |
| `regex: true` | 移除，用精確文字匹配 |
| `retryTapIfNoChange:` | 移除 |
| `textRegex:` | 改用 `text:` |

合法屬性：`text`, `id`, `index`, `optional`, `point`

### 關鍵技巧
- **文字匹配必須精確**：`"星期一"` 不是 `"星期"`
- **螢幕外元素**：用 `scrollUntilVisible` 不是 `assertVisible`
- **restart-app assert**：用 `"每日訓練"` 不是 `"我的訓練目標"`
- **SwiftUI dropdown**：Maestro `tapOn: "輕鬆跑"` 可選，選項用文字 tap
- **Drag & drop**：Maestro 無法觸發 SwiftUI List `.onMove`，需手動測
- **非 accessibility element**：距離 stepper、齒輪圖示需用 `point:` 座標
