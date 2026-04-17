---
type: SPEC
id: SPEC-heart-rate-and-training-readiness-surfaces
status: Draft
ontology_entity: heart-rate-training-readiness-surfaces
created: 2026-04-15
updated: 2026-04-15
---

# Feature Spec: 心率設定與 Training Readiness Surface

## 背景與動機

目前 app 已有兩塊與生理數據直接相關的產品面：一是 onboarding / profile 裡的心率區間設定，二是 `MyAchievementView` 裡的 training readiness 卡與相關圖表。這些功能已實作，但還缺少一份對齊現況的產品規格。

## 相容性

- onboarding 中的心率步驟遵循 `Docs/specs/SPEC-onboarding-redesign.md`
- 表現頁整體布局遵循 `Docs/specs/SPEC-performance-insights-dashboard.md`

## 需求

### AC-HR-01: onboarding 模式必須提供可直接採用的預設心率值

Given 使用者在 onboarding 進入心率設定步驟，  
When 系統載入完成，  
Then 畫面必須提供可直接使用的最大心率與靜息心率預設值，並明確提示使用者可先用預設值、日後再更新。

### AC-HR-02: onboarding 模式必須把心率設定當作流程內的一步，而不是孤立頁

Given 使用者在 onboarding 心率頁，  
When 使用者前進或返回，  
Then 系統必須沿用 onboarding 導航模型，而不是跳出流程；儲存後需正確接到 personal best 或 backfill 後續步驟。

### AC-HR-03: profile 模式必須支援檢視、編輯與儲存心率設定

Given 使用者從 profile 打開心率設定，  
When 進入 profile 模式，  
Then 畫面必須支援查看目前設定、切換到編輯狀態並儲存更新，不得只顯示靜態資訊。

### AC-HR-04: Training Readiness 卡必須顯示最後更新時間與手動刷新入口

Given 使用者位於表現資料頁，  
When training readiness 已有同步結果或正在重新計算，  
Then 畫面必須顯示最後更新時間與刷新按鈕，刷新中需有明確 loading feedback。

### AC-HR-05: 表現頁必須把 readiness、PB、負荷與心率趨勢放在同一分析面

Given 使用者打開表現資料頁，  
When 內容載入完成，  
Then 系統必須在同一可捲動 dashboard 中提供 training readiness、personal best、訓練負荷、週跑量與心率相關圖表，讓使用者可交叉查看恢復與負荷訊號。

### AC-HR-06: readiness 資料必須在進頁時自動載入，且支援事件驅動回饋

Given 使用者打開表現資料頁，  
When 頁面 onAppear 或收到 personal best 更新事件，  
Then 系統必須自動載入 readiness 資料，並在收到 PB 更新事件時顯示慶祝回饋。

## 明確不包含

- 心率區間演算法與 readiness 計算公式
- HealthKit 原始樣本解析與同步機制
- 月曆與 monthly stats 補資料規則
