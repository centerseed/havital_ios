---
type: TEST
id: TEST-subscription-management-and-status-ui
status: Draft
l2_entity: iap-subscription
source_spec: SPEC-subscription-management-and-status-ui
created: 2026-04-13
updated: 2026-04-13
changelog:
  - 2026-04-13: 初版測試設計，對齊 SPEC-subscription-management-and-status-ui
---

# Test Design: 訂閱管理與狀態 UI 矩陣

## 目標

驗證 `SPEC-subscription-management-and-status-ui` 的 11 項需求，重點是：

1. 訂閱狀態映射正確（特別是 `cancelled`、`grace_period`、`revoke`）。
2. Profile / Paywall / 功能閘門 / Restore Purchases 行為一致。
3. Session 內狀態變更不打斷進行中操作。
4. 離線與提醒頻率策略可預期，避免誤導向 Paywall。

## 範圍與非範圍

範圍：App 內 UI、ViewModel、Repository、狀態管理、StoreKit/RevenueCat 整合邊界。

非範圍：
- Apple 系統訂閱頁內部流程。
- App Store Connect 後台配置與審核流程。
- Android 端行為。

## 測試層級策略

| 層級 | 工具 | 目的 | Gate |
|---|---|---|---|
| Unit | XCTest | 驗證 mapper、trigger、提醒頻率邏輯 | P0 必過 |
| Integration | XCTest + Mock Repository | 驗證狀態切換與 session 行為 | P0 必過 |
| UI (Local) | XCUITest + `SKTestSession` | 驗證 Paywall 購買/恢復與核心 UI 互動，不依賴 Sandbox 登入 | P0 必過 |
| UI (Debug 狀態注入) | XCUITest + launch scenario / local override | 驗證 Profile/閘門矩陣（含 cancelled/grace_period） | P0 必過 |
| Manual (Real Device Sandbox) | 真機 + Sandbox tester | 驗證 Apple 帳號登入、系統購買 sheet、真實 Restore 行為 | P1 必跑 |
| Smoke (Prod) | 真機 release + prod 帳號 | 發版前確認核心購買不回歸 | Release gate |

## 測試資料夾具（Fixtures）

| Fixture ID | status | expires_at | billing_issue | 說明 |
|---|---|---|---|---|
| F1 | trial | now + 7d | false | 試用中 |
| F2 | active | now + 30d | false | 正常訂閱 |
| F3 | active | now + 30d | true | active + billing_issue（期望映射為 grace_period） |
| F4 | grace_period | now + 30d | false | 後端直接回 grace_period |
| F5 | cancelled | now + 10d | false | 已取消未到期 |
| F6 | cancelled | now - 1h | false | 已取消且已到期（刷新後應 expired） |
| F7 | expired | now - 1d | false | 已到期 |
| F8 | none | nil | false | 免費版 |
| F9 | revoked | now + 30d | false | Apple 退款事件（期望映射為 expired） |

## 需求追蹤矩陣（Spec → Test）

| Spec 需求 | 對應測試案例 |
|---|---|
| 1) 訂閱管理入口 | P0-S01, P0-S02, P0-S03, P0-S04 |
| 2) cancelled 狀態 UI 顯示 | P0-S05, P0-S06, P0-S07, P0-S08 |
| 3) 完整狀態 UI 矩陣 | P0-S09, P0-S10, P0-S11, P0-S12, P0-S13, P0-S14 |
| 4) Session 中狀態變更 | P0-S15, P0-S16, P0-S17, P0-S18 |
| 5) Revoke 狀態處理 | P0-S19, P0-S20 |
| 6) 離線行為 | P1-S01, P1-S02, P1-S03, P1-S04 |
| 7) 方案升降級 | P1-S05, P1-S06, P1-S07 |
| 8) 購買成功確認體驗 | P1-S08, P1-S09, P1-S10 |
| 9) 試用即將到期提醒 | P1-S11, P1-S12, P1-S13 |
| 10) 到期提醒頻率策略 | P1-S14, P1-S15 |
| 11) 首次用戶訂閱引導 | P2-S01, P2-S02 |

## P0 場景（必須全部通過）

### S1: active 顯示「管理訂閱」入口
層級：UI (Debug 狀態注入)
Given: Fixture F2（active）
When: 進入 Profile 訂閱區域
Then: 顯示 `Subscription_ChangePlanButton` 與 `Subscription_ManageButton`

### S2: cancelled 顯示「重新訂閱 + 管理訂閱」
層級：UI (Debug 狀態注入)
Given: Fixture F5（cancelled，未到期）
When: 進入 Profile 訂閱區域
Then: 顯示 `Subscription_ResubscribeButton` 與 `Subscription_ManageButton`

### S3: trial/expired/none 不顯示「管理訂閱」
層級：UI (Debug 狀態注入)
Given: Fixture F1/F7/F8
When: 進入 Profile 訂閱區域
Then: 不顯示 `Subscription_ManageButton`

### S4: 點擊管理訂閱可跳轉 Apple 訂閱頁
層級：Manual (真機)
Given: Fixture F2 或 F5
When: 點擊「管理訂閱」
Then: 開啟 `https://apps.apple.com/account/subscriptions`

### S5: Mapper 不再吞掉 cancelled
層級：Unit
Given: DTO status = `cancelled`, expires_at > now
When: `SubscriptionMapper.toEntity`
Then: entity.status == `.cancelled`

### S6: cancelled Profile 顯示有效期與剩餘天數
層級：UI (Debug 狀態注入)
Given: Fixture F5
When: 進入 Profile
Then: 顯示「已取消」、「服務有效至」、「剩餘 N 天」

### S7: cancelled 狀態仍可使用 AI 受限功能
層級：Integration + UI
Given: Fixture F5
When: 觸發 AI 受限功能（例如週計畫生成）
Then: 功能放行，不觸發 Paywall

### S8: cancelled 到期後刷新轉為 expired
層級：Integration
Given: Fixture F6（cancelled 但已過期）
When: 呼叫 `refreshStatus()`
Then: 狀態轉為 `.expired`

### S9: Profile 狀態矩陣一致性
層級：UI (Debug 狀態注入)
Given: F1~F8 全部狀態
When: 逐一進入 Profile 訂閱區域
Then: 方案名稱、輔助資訊、主要/次要按鈕符合 Spec 矩陣

### S10: Paywall trigger 語境正確
層級：Unit + UI
Given: 各狀態觸發進入 Paywall
When: 讀取 `PaywallTrigger` 與 header
Then: trial=升級、cancelled=重新訂閱、active=變更方案、expired/none=解鎖功能/到期語境

### S11: 功能閘門矩陣一致性
層級：Integration
Given: F1~F8
When: 觸發受限功能 API
Then: trial/active/grace_period/cancelled 放行，expired/none 阻擋並觸發 Paywall

### S12: Restore 按鈕顯示規則
層級：UI
Given: F7/F8/F5 與 F1/F2/F4
When: 進入 Paywall
Then: expired/none/cancelled 顯示 Restore；trial/active/grace_period 不顯示

### S13: Restore 成功可解鎖並關閉 Paywall
層級：UI (StoreKit Local)
Given: expired 或 none
When: 點擊 `Paywall_RestoreButton` 且有有效交易
Then: 狀態更新為 active/cancelled，Paywall 關閉

### S14: Restore 無記錄顯示錯誤並留在 Paywall
層級：UI (StoreKit Local)
Given: expired 或 none 且無可恢復交易
When: 點擊 Restore
Then: 顯示「找不到有效的訂閱記錄」，Paywall 保持開啟

### S15: Session 內降級不打斷進行中操作
層級：Integration
Given: 目前正在執行 AI 操作，狀態 active/cancelled -> expired
When: 狀態更新事件到達
Then: 當前操作完成；下一次操作才被閘門攔截

### S16: App 回前景會刷新訂閱狀態
層級：Integration + UI
Given: App 在背景期間 Apple 側狀態變更
When: App 回前景
Then: 在合理時間內刷新並更新 Profile 顯示

### S17: 狀態降級顯示非阻斷通知
層級：Integration
Given: `SubscriptionStateManager` 偵測 active/trial/grace/cancelled -> expired/none
When: UI 層觀察到 `recentDowngrade`
Then: 顯示通知，不強制跳轉 Paywall

### S18: 進行中 session 發生 revoke 也不立即中斷
層級：Integration
Given: 進行中的 AI 操作 + revoke 事件
When: 狀態變更被接收
Then: 本次操作完成；下一次受限操作才攔截

### S19: revoke 事件映射為 expired
層級：Unit + Integration
Given: RevenueCat/後端回傳 revoke（曾訂閱者）
When: 狀態映射
Then: entity.status == `.expired`（不是 `.none`）

### S20: revoke 後 Profile 呈現到期狀態
層級：UI
Given: revoke 後狀態為 expired
When: 進入 Profile
Then: 顯示「已到期」與「重新訂閱」按鈕

## P1 場景（應通過）

### S1: 離線時使用最近一次有效快取
層級：Integration
Given: 最後一次狀態 active/trial/cancelled 且離線
When: 呼叫 `getStatus()`
Then: 回傳快取狀態，不誤判 expired

### S2: 網路錯誤不等於訂閱到期
層級：Integration
Given: API failure = network unavailable
When: 觸發狀態刷新
Then: 不觸發 Paywall，顯示網路不可用路徑

### S3: 離線觸發 AI 功能時顯示離線提示而非 Paywall
層級：UI + Integration
Given: 快取 active，當前離線
When: 觸發 AI 功能
Then: 顯示離線提示，不導向 Paywall

### S4: 網路恢復後背景刷新
層級：Integration
Given: 離線後恢復網路
When: 監測網路恢復
Then: 背景刷新狀態並套用 session 降級規則

### S5: active 使用者可進入變更方案流程
層級：UI (StoreKit Local + Manual)
Given: active
When: 點擊「變更方案」
Then: 進入 Paywall，標示目前方案與可切換方案

### S6: 升級（月 -> 年）後立即反映
層級：UI (StoreKit Local)
Given: 目前月訂
When: 完成升級購買
Then: 顯示新方案與更新後到期日

### S7: 降級（年 -> 月）排程資訊顯示
層級：Manual（Sandbox）
Given: 年訂降級申請成功
When: 回到 Profile
Then: 顯示「將於 YYYY/MM/DD 切換至月訂」

### S8: 購買成功顯示成功確認畫面
層級：UI (StoreKit Local)
Given: Paywall 購買成功
When: 收到成功回調
Then: 顯示成功確認 UI（圖示、文案、方案摘要）

### S9: 成功確認 3 秒自動關閉或手動關閉
層級：UI (StoreKit Local)
Given: 成功確認畫面已出現
When: 等待 3 秒或點「開始使用」
Then: 關閉 Paywall 回原頁

### S10: 試用中購買成功文案正確
層級：UI
Given: trial 狀態下購買成功
When: 顯示成功確認
Then: 文案包含「試用結束後啟用付費方案」

### S11: 試用剩餘 <= 3 天顯示提醒
層級：Unit + UI
Given: trial 且剩餘天數 <= 3
When: 冷啟動或回前景
Then: 顯示到期提醒與升級入口

### S12: 試用剩餘 > 3 天不提醒
層級：Unit + UI
Given: trial 且剩餘天數 > 3
When: 開啟 App
Then: 不顯示提醒

### S13: 試用提醒同日最多一次
層級：Unit + UI
Given: 今日已顯示過提醒
When: 同日再次開啟或回前景
Then: 不重複顯示

### S14: expired 冷啟動顯示到期提醒
層級：UI
Given: expired
When: 冷啟動 App
Then: 顯示到期提醒 sheet 與升級入口

### S15: 同一 session 不重複顯示到期提醒
層級：UI
Given: expired 且本 session 已關閉提醒
When: 同 session 回前景
Then: 不再重複彈出

## P2 場景（可選）

### S1: 首次 trial 用戶顯示一次性訂閱引導
層級：UI
Given: 新註冊 trial 用戶首次進入訓練計畫首頁
When: 首次進入核心頁
Then: 顯示非阻斷引導，點擊可進 Paywall

### S2: 引導只出現一次
層級：UI + Unit
Given: 引導已顯示過
When: 再次進入首頁
Then: 不再顯示

## 執行順序（建議）

1. Unit：`SubscriptionMapper`、提醒頻率、trigger 判斷。
2. Integration：`SubscriptionStateManager` 降級與 session 行為。
3. UI Local：StoreKit 本機購買/恢復（不依賴 Sandbox 帳號）。
4. UI Debug 注入：狀態矩陣快掃。
5. 真機 Sandbox：每日 smoke（購買一次、Restore 一次）。

## 進出條件（Done Criteria）

- P0 案例 100% 通過。
- P1 案例 >= 90% 通過，且失敗項需有已立案 bug。
- 每次 release 候選版至少完成一次「真機 Sandbox 購買 + Restore」。
- 回歸失敗必須附：log、螢幕錄影、訂閱狀態快照（status/expires_at/billing_issue）。

## 目前已知測試缺口（需補）

1. `revoke -> expired` 尚未看到現有自動化覆蓋，需新增 mapper/integration 測試。
2. 「管理訂閱 URL 跳轉」目前偏 manual，若要自動化需抽象 `UIApplication.open`。
3. 「購買成功確認畫面」與「到期提醒頻率」若尚未實作，先建 pending 測試並掛到對應 feature ticket。
4. 「降級 pending switch」資訊來源依賴 RevenueCat payload，需先確認欄位後才能完成自動化斷言。
