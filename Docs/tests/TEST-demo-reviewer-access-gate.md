---
type: TEST
id: TEST-demo-reviewer-access-gate
status: Draft
ontology_entity: demo-reviewer-access-gate
source_spec: SPEC-demo-reviewer-access-gate
created: 2026-04-16
updated: 2026-04-16
---

# Test Design: Reviewer Demo Account Activation Gate

## 目標

驗證 `SPEC-demo-reviewer-access-gate` 的 reviewer access flow 與安全邊界，重點是：

1. 一般使用者看不到 demo 入口
2. reviewer 能依文件穩定啟用 demo 帳號
3. passcode 驗證、失敗鎖定、session 清理與 backend guardrail 行為正確
4. demo session 進入後仍維持 prod parity，而不是切到特製 debug 路徑

## 測試層級策略

| 層級 | 工具 | 目的 | Gate |
|---|---|---|---|
| Unit | XCTest | 驗證長按計時、鎖定視窗、grant 清理等純邏輯 | P0 必過 |
| Integration | XCTest + Mock Backend | 驗證 passcode 驗證、grant、logout 清理與 demo login 串接 | P0 必過 |
| UI | XCUITest | 驗證隱藏入口、sheet、錯誤狀態與成功登入主流程 | P0 必過 |
| Manual | Release build + App Review notes | 驗證 reviewer 依提交說明可實際完成流程 | Release gate |

## 覆蓋矩陣（Spec → Test）

| Spec AC | 對應案例 |
|---|---|
| AC-DEMO-01 | P0-S01 |
| AC-DEMO-02 | P0-S02, P0-S03 |
| AC-DEMO-03 | P0-S04 |
| AC-DEMO-04 | P0-S05 |
| AC-DEMO-05 | P0-S06 |
| AC-DEMO-06 | P0-S07 |
| AC-DEMO-07 | P0-S08, P1-S01 |
| AC-DEMO-08 | P0-S09 |
| AC-DEMO-09 | P0-S10 |
| AC-DEMO-10 | P0-S11 |
| AC-DEMO-11 | P0-S12 |
| AC-DEMO-12 | P0-S13 |
| AC-DEMO-13 | P1-S02 |

## P0 場景（必須全部通過）

### S1: Login 畫面不顯示公開 Demo Login
層級：UI
Given: 全新安裝、未登入狀態
When: 開啟 `LoginView`
Then: 只看到 Google / Apple 正式登入入口，看不到 `Login_DemoButton` 或等效 demo CTA

### S2: 長按未達 5 秒不得開啟 reviewer sheet
層級：UI
Given: `LoginView`
When: 對 logo 長按 1 至 4 秒後放開
Then: reviewer access sheet 不出現，畫面保持原狀

### S3: 長按滿 5 秒會開啟 reviewer sheet
層級：UI
Given: `LoginView`
When: 對 logo 持續長按 5 秒
Then: 顯示 reviewer access sheet

### S4: 長按過程可見進度回饋
層級：UI
Given: `LoginView`
When: reviewer 正在執行長按手勢
Then: 畫面可見進度狀態，完成時有成功回饋

### S5: Reviewer sheet 不暴露固定憑證
層級：UI
Given: reviewer access sheet 已開啟
When: reviewer 尚未輸入 passcode
Then: 畫面只顯示 passcode 輸入與 activate/cancel 動作，沒有 demo 帳密提示

### S6: 啟用請求必須走 server 驗證
層級：Integration
Given: reviewer 送出 passcode
When: app 發起啟用
Then: 必須呼叫 reviewer activation API，且 client 端沒有離線比對成功路徑

### S7: 正確 passcode 會直接登入 demo session
層級：Integration + UI
Given: backend 回應 activation success
When: 啟用流程完成
Then: app 直接進入已登入主流程，不需再額外點擊 demo login 按鈕

### S8: Demo session 進入後仍是正式 app shell
層級：UI Smoke
Given: reviewer 已登入 demo session
When: 進入主畫面與主要 tab
Then: 看到與正式 prod session 相同的 app shell 與主要入口，而不是 debug 專用頁

### S9: 錯誤 passcode 顯示泛化錯誤
層級：UI + Integration
Given: backend 回應 invalid passcode
When: 啟用失敗
Then: 顯示泛化錯誤訊息，不回傳可猜測 passcode 的細節

### S10: 連續 3 次失敗後進入暫時鎖定
層級：Unit + Integration
Given: 同一安裝在 15 分鐘內連續 3 次輸入錯誤 passcode
When: 第 4 次再提交
Then: app 顯示鎖定狀態，不送出新的啟用請求

### S11: 離線時不得啟用 demo access
層級：Integration + UI
Given: 裝置離線
When: reviewer 送出任意 passcode
Then: 顯示需要網路的錯誤，且 session 仍維持未登入

### S12: 登出會清除 reviewer grant
層級：Integration
Given: 使用者透過 reviewer gate 進入 demo session
When: 使用者登出
Then: reviewer grant 與 demo session 一併清除，下次需重新啟用

### S13: 無 grant 直接打 demo login 會被拒絕
層級：Integration
Given: client 沒有有效 reviewer grant
When: 直接呼叫 demo login endpoint
Then: backend 回傳拒絕結果，app 不得進入 demo session

## P1 場景（應通過）

### S1: Demo session 的主要 guardrail 與正式付費帳號一致
層級：Manual + Smoke
Given: reviewer 已登入 demo session
When: 檢查 onboarding、主 tab、付費功能與主要限制
Then: 行為與正式 prod 帳號一致，沒有 reviewer-only 特例 UI

### S2: App Review notes 足夠讓陌生 reviewer 完成啟用
層級：Manual
Given: 一位不知道內部背景的人，只看 App Review information
When: 照步驟操作
Then: 能在合理時間內完成 reviewer demo 啟用並登入
