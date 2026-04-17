---
type: SPEC
id: SPEC-demo-reviewer-access-gate
status: Draft
ontology_entity: demo-reviewer-access-gate
created: 2026-04-16
updated: 2026-04-16
---

# Feature Spec: Reviewer Demo Account Activation Gate

## 背景與動機

目前 `LoginView` 直接暴露 `Demo Login` 入口。這對 Apple 審查是方便的，但也等於把可用的 demo 帳號入口放在所有安裝者面前，容易造成資源濫用、帳號外流與不受控的 prod 資源消耗。

同時，這個 demo 帳號仍有產品價值：
- Apple 審查人員需要一條可重現、可操作的登入路徑
- 審查過程應看到與正式產品一致的主要功能與 guardrail
- 我們不希望為審查另外維護一套與 prod 分岔的 review build

本規格的目標是把 demo 帳號改成「可被審查員使用、但不對一般使用者顯示」的受控入口。

## 目標

- 公開登入畫面只保留正式登入入口，不直接暴露 demo 帳號
- Apple 審查人員可依明確指示啟用 demo 帳號
- demo 帳號登入後走與 prod 相同的 app shell、功能路徑與主要 guardrail
- 安全控制點放在受控啟用與後端驗證，不靠 obscurity 當唯一防線

## 範圍

- `LoginView` 的隱藏 reviewer 入口與啟用交互
- reviewer passcode 驗證、失敗處理、鎖定策略
- demo session 的啟用、登出與清除規則
- App Review submission 時需提供的操作說明

## 明確不包含

- 另外維護 review-only build、review-only 功能開關、或假的 mock 資料流程
- 一般使用者可見的 demo login CTA
- 把 reviewer passcode 硬編碼在 client 內
- 重新設計 Google / Apple 正式登入流程

## Spec 相容性

- 本 spec 補充 `SPEC-authentication-and-session-entry`
- `SPEC-authentication-and-session-entry` 定義「登入入口與 session entry 的主流程」
- 本 spec 定義「reviewer demo access 的受控例外入口」
- 若兩份文件衝突，以本 spec 對 reviewer demo gate 的定義為準，並同步回寫 auth spec

## 核心決策

### D1. 隱藏入口放在 Login Logo

- 入口放在 `LoginView` 的品牌 logo（目前為 `paceriz_light`）
- 觸發方式為持續長按 5 秒
- 原因：不新增可見按鈕、不污染正式登入版面，也不需要 reviewer 進入其他頁面找入口

### D2. 長按必須有可感知回饋

- 長按期間必須顯示進度回饋（例如 ring / bar / fill）
- 5 秒完成後給成功 haptic，再彈出 reviewer access sheet
- 若沒有回饋，reviewer 很容易判定功能壞掉或沒觸發

### D3. 驗證成功後直接登入 demo 帳號

- reviewer 輸入正確 passcode 後，app 直接完成 demo 帳號登入
- 不再額外露出持久的 `Demo Login` 按鈕
- 原因：減少審查操作步驟，也避免一旦啟用後留下可重複濫用的明顯 CTA

### D4. 安全控制必須在後端，不在 client

- client 只負責收集 passcode 與顯示結果
- passcode 驗證、grant 簽發、demo login 授權與 rate limit 必須在 server
- 既有 `/login/demo` 類型入口若保留，必須改為沒有有效 reviewer grant 就拒絕

## 需求

### AC-DEMO-01: Login 畫面預設不得顯示 demo 入口

Given 使用者位於未登入狀態的 `LoginView`，  
When 畫面載入完成，  
Then 系統必須只顯示正式登入入口（Google / Apple），不得顯示 `Demo Login` 按鈕、提示文案或等效 CTA。

### AC-DEMO-02: Reviewer 入口只能由隱藏手勢觸發

Given 使用者位於未登入狀態的 `LoginView`，  
When 使用者在 app logo 上持續長按 5 秒，  
Then 系統必須顯示 reviewer access sheet；若按壓未達 5 秒就放開，則不得出現 reviewer 入口。

### AC-DEMO-03: 長按過程必須提供進度回饋

Given 使用者正在對 app logo 進行 reviewer 手勢，  
When 長按尚未完成，  
Then 系統必須顯示清楚的進度回饋；完成 5 秒時必須給出明確成功回饋（例如 haptic 或視覺完成狀態）。

### AC-DEMO-04: Reviewer access sheet 僅收集必要資訊

Given reviewer access sheet 已開啟，  
When reviewer 準備啟用 demo 帳號，  
Then 畫面必須只要求輸入 passcode 與執行 `Activate` / `Cancel`，不得預先顯示 demo 帳號、固定密碼提示、或任何能被一般人直接抄走的憑證資訊。

### AC-DEMO-05: Passcode 驗證必須由 server 決定

Given reviewer 送出 passcode，  
When app 發起啟用請求，  
Then passcode 驗證結果必須由後端回應決定，client 不得內建可離線比對的 passcode、magic string、或可被逆向提取的 bypass flag。

### AC-DEMO-06: 驗證成功後必須直接進入 demo session

Given reviewer 提供有效 passcode，  
When 後端確認啟用成功，  
Then app 必須直接登入 demo 帳號，並進入與 prod 相同的主流程，不得再要求 reviewer 回到登入頁手動找第二個 demo 按鈕。

### AC-DEMO-07: Demo session 必須維持 prod parity

Given 使用者已透過 reviewer gate 進入 demo session，  
When reviewer 瀏覽主要功能，  
Then app shell、功能入口、權限閘門與主要付費／onboarding 判斷必須與正式 prod session 一致；不得因為 reviewer 模式而切到假資料頁、縮水頁或 debug-only UI。

### AC-DEMO-08: 啟用失敗不得暴露多餘資訊

Given reviewer 輸入錯誤 passcode，  
When 啟用失敗，  
Then app 必須顯示泛化錯誤訊息，並停留在 reviewer access sheet；不得顯示「正確格式」、「剩餘字元規則」、或任何可幫助猜測 passcode 的細節。

### AC-DEMO-09: 連續失敗必須有鎖定策略

Given 同一安裝實例在 15 分鐘內連續 3 次啟用失敗，  
When reviewer 再次提交 passcode，  
Then app 必須拒絕新的啟用請求並顯示暫時鎖定狀態，直到鎖定視窗結束。

### AC-DEMO-10: 離線時不得啟用 demo access

Given 裝置目前無法連到啟用服務，  
When reviewer 嘗試啟用 demo access，  
Then app 必須顯示需要網路的錯誤，且不得離線放行 demo session。

### AC-DEMO-11: 登出後必須清除 reviewer grant

Given 使用者是透過 reviewer gate 登入的 demo session，  
When 使用者登出或 app 明確清除 session，  
Then 本次 reviewer grant 必須一併清除；下次若要再進入 demo 帳號，必須重新走隱藏手勢與 passcode 驗證。

### AC-DEMO-12: 未持有有效 grant 時不得直登 demo 帳號

Given client 沒有有效 reviewer activation grant，  
When 它直接呼叫 demo login API 或等效入口，  
Then 後端必須拒絕請求，不得僅因為知道 endpoint 就能登入 demo 帳號。

### AC-DEMO-13: App Review submission 必須附完整操作說明

Given 版本要提交 Apple App Review，  
When release owner 填寫 App Review information，  
Then 必須提供 reviewer 入口手勢、passcode、必要測試說明與注意事項，且該組 reviewer 憑證在活躍審查期間不得失效。

## AC ID Index

本 spec 已採用穩定 AC-ID；以下索引作為派工、review 與測試引用入口。

| AC ID | 對應需求 |
|------|----------|
| AC-DEMO-01 | Login 畫面預設不顯示 demo 入口 |
| AC-DEMO-02 | Reviewer 入口僅能由 logo 長按 5 秒觸發 |
| AC-DEMO-03 | 長按過程提供進度回饋 |
| AC-DEMO-04 | Reviewer sheet 只收必要資訊 |
| AC-DEMO-05 | Passcode 由 server 驗證 |
| AC-DEMO-06 | 驗證成功後直接登入 demo session |
| AC-DEMO-07 | Demo session 維持 prod parity |
| AC-DEMO-08 | 啟用失敗不暴露多餘資訊 |
| AC-DEMO-09 | 連續失敗有鎖定策略 |
| AC-DEMO-10 | 離線時不得啟用 |
| AC-DEMO-11 | 登出時清除 reviewer grant |
| AC-DEMO-12 | 無有效 grant 時不得直登 demo 帳號 |
| AC-DEMO-13 | App Review submission 必須附完整操作說明 |

## 技術約束（給 Architect 參考）

- `LoginView` 現況已有公開 `Demo Login` 區塊；實作時需移除公開按鈕並替換為隱藏手勢入口
- 現有 demo login 仍透過 backend `/login/demo` 類型流程；需補 reviewer activation gate，不能只改 UI
- reviewer passcode 不得寫進 `Localizable.strings`、常數、feature flag 預設值、或 build setting
- reviewer grant 應綁定 server 驗證結果，並具短生命週期或明確可撤銷性
- 安全保護以 server 驗證、審計紀錄、rate limit 為主；不要把「藏按鈕」當成唯一防線
- 若 demo 帳號需要固定資料狀態，應由後端 reset/job 維持，不應讓 client 走與 prod 不一致的假流程

## 操作與提交規則

1. App Store Connect 的 App Review information 必須填 reviewer 操作步驟，而不是只寫「有 demo account」。
2. 操作步驟至少包含：
   - 從登入頁長按 logo 5 秒
   - 看到 reviewer access sheet
   - 輸入 passcode
   - 成功後直接進入 demo session
3. reviewer 用的 passcode 與 demo 帳號必須在該次審查期間有效，不得提交後立即輪替失效。
4. 若 passcode 因安全事件需要輪替，必須同步更新 App Review information，不能只更新內部文件。

## 開放問題

- reviewer passcode 的輪替策略要以「每次送審一組」還是「固定一組、緊急時輪替」為準
- 後端 reviewer grant 是否綁定裝置指紋、bundle version、或純短期 token 即可
- demo 帳號若存在高成本 AI 操作，後端要如何在不破壞 prod parity 的前提下做額度保護與重置
