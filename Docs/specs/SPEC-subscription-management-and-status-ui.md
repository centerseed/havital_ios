---
type: SPEC
id: SPEC-subscription-management-and-status-ui
status: Draft
l2_entity: iap-subscription
created: 2026-04-13
updated: 2026-04-13
changelog:
  - 2026-04-13: 初稿
  - 2026-04-13: 回應 Challenger 7 項挑戰，新增 grace_period 狀態、離線策略、升級路徑、Restore Purchases 矩陣、revoke 狀態映射、session 中狀態變更行為
---

# Feature Spec: 訂閱管理與狀態 UI 矩陣

## 背景與動機

Paceriz 目前的訂閱體驗存在一個關鍵斷層：用戶付費後，無法在 App 內管理訂閱或看到取消後的狀態。具體問題：

1. **cancelled 狀態被吞掉**：後端 API 會回傳 `cancelled`（已取消但尚未到期），但 `SubscriptionMapper` 將其映射為 `active`。用戶取消訂閱後，App 顯示「Premium」而非「已取消，X 日到期」，造成認知混亂。
2. **無管理訂閱入口**：App 內沒有任何地方可以引導用戶前往 Apple 系統訂閱管理頁面。用戶想取消或變更方案時，必須自己找到系統設定路徑。
3. **購買成功無確認**：購買完成後 Paywall 直接 dismiss，用戶沒有收到明確的成功確認回饋。
4. **狀態 UI 不一致**：不同頁面（Profile、Paywall、功能閘門）對同一訂閱狀態的顯示行為沒有統一規格。
5. **缺少到期前提醒**：trial 或訂閱即將到期時，沒有提前通知機制。

本 Spec 補齊 `SPEC-iap-paywall-pricing-and-trial-protection` 未涵蓋的訂閱管理面，形成完整的付費體驗閉環。

## 目標用戶

- **已訂閱用戶**：想管理（取消、變更方案）自己的訂閱
- **已取消用戶**：需要知道「取消已生效，服務將在 X 日後結束」
- **試用中用戶**：需要知道試用剩餘天數，並在到期前收到提醒
- **到期用戶**：需要清楚知道當前狀態並有明確的續訂入口
- **剛完成購買的用戶**：需要購買成功的確認回饋

## 需求

### P0（必須有）

#### 1) 訂閱管理入口

- **描述**：已訂閱或已取消的用戶，可以在 Profile 頁的訂閱區域找到「管理訂閱」按鈕，點擊後跳轉至 Apple 系統的訂閱管理頁面。
- **Acceptance Criteria**：
  - Given 用戶訂閱狀態為 active，When 用戶查看 Profile 訂閱區域，Then 顯示「管理訂閱」按鈕。
  - Given 用戶訂閱狀態為 cancelled（已取消未到期），When 用戶查看 Profile 訂閱區域，Then 顯示「管理訂閱」按鈕。
  - Given 用戶點擊「管理訂閱」按鈕，When 系統處理點擊事件，Then 跳轉至 Apple 系統訂閱管理頁面（`https://apps.apple.com/account/subscriptions`）。
  - Given 用戶訂閱狀態為 trial / expired / none，When 用戶查看 Profile 訂閱區域，Then 不顯示「管理訂閱」按鈕（改為顯示「升級」或「重新訂閱」按鈕，依矩陣定義）。

#### 2) cancelled 狀態的 UI 顯示

- **描述**：當後端回傳 `cancelled` 狀態時，App 必須將其視為獨立狀態呈現，讓用戶明確知道「訂閱已取消，但服務在到期日前仍可使用」。
- **Acceptance Criteria**：
  - Given 後端回傳 status = "cancelled" 且 expires_at 為未來時間，When App 解析訂閱狀態，Then 狀態應為 `cancelled`（不再映射為 `active`）。
  - Given 用戶狀態為 cancelled，When 用戶查看 Profile 訂閱區域，Then 方案名稱顯示為「已取消」（而非「Premium」），且顯示「服務有效至 YYYY/MM/DD」和剩餘天數。
  - Given 用戶狀態為 cancelled，When 用戶使用 AI 受限功能（Rizo、AI coach 等），Then 功能正常可用（因為尚未到期）。
  - Given 用戶狀態為 cancelled 且到期日已過，When App 刷新狀態，Then 狀態應轉為 expired，觸發到期流程。
  - Given 用戶狀態為 cancelled，When 用戶查看 Profile 訂閱區域，Then 顯示「重新訂閱」按鈕（導向 Paywall）及「管理訂閱」按鈕。

#### 3) 完整訂閱狀態 UI 矩陣

- **描述**：統一定義每個訂閱狀態在各頁面的顯示行為，確保全 App 一致。以下矩陣為規格定義。

**Profile 訂閱區域**

| 狀態 | 方案名稱 | 輔助資訊 | 主要按鈕 | 次要按鈕 |
|------|---------|---------|---------|---------|
| trial | 「試用中」 | 「剩餘 N 天」（橘色） | 升級 | -- |
| active | 方案名稱（如 Premium） | 「續訂日 YYYY/MM/DD」+「剩餘 N 天」 | 變更方案 | 管理訂閱 |
| active + billing_issue | 方案名稱 | 到期日 + 帳務異常警告（紅色） | 管理訂閱 | -- |
| grace_period | 方案名稱 | 「帳務處理中，服務不受影響」（黃色） | 管理訂閱 | -- |
| cancelled | 「已取消」 | 「服務有效至 YYYY/MM/DD」+「剩餘 N 天」 | 重新訂閱 | 管理訂閱 |
| expired | 「已到期」 | -- | 重新訂閱 | -- |
| none | 「免費版」 | -- | 升級 | -- |

**Paywall 頁面**

| 狀態 | 是否顯示 Paywall | 標題語境 | 特殊元素 |
|------|----------------|---------|---------|
| trial | 可進入（主動升級） | 「升級」 | 試用剩餘天數 banner |
| active | 可進入（主動變更方案） | 「變更方案」 | 顯示當前方案、標記升/降級 |
| active + billing_issue | 不可進入（已訂閱） | -- | -- |
| grace_period | 不可進入（視為 active） | -- | -- |
| cancelled | 可進入（重新訂閱） | 「重新訂閱」 | 「目前服務有效至 YYYY/MM/DD」banner |
| expired | 可進入（被動觸發） | 「訂閱已到期」 | -- |
| none | 可進入（被動觸發） | 「解鎖功能」 | -- |

**功能閘門（AI 受限功能）**

| 狀態 | 是否放行 | 閘門行為 |
|------|---------|---------|
| trial | 放行 | -- |
| active | 放行 | -- |
| active + billing_issue | 放行 + 非阻斷帳務提示 | -- |
| grace_period | 放行 + 非阻斷帳務處理中提示 | -- |
| cancelled | 放行（未到期） | -- |
| expired | 阻擋 → 顯示 Paywall | -- |
| none | 阻擋 → 顯示 Paywall | -- |

**Restore Purchases 行為**

| 狀態 | Restore 按鈕位置 | 成功行為 | 無購買記錄行為 |
|------|----------------|---------|--------------|
| expired | Paywall 底部 | 狀態更新為 active/cancelled（依 Apple 實際狀態），關閉 Paywall | 顯示「找不到有效的訂閱記錄」提示 |
| none | Paywall 底部 | 同上 | 同上 |
| cancelled | Paywall 底部 | 同上（用戶可能在其他裝置重新訂閱） | 顯示「找不到有效的訂閱記錄」提示 |
| trial / active / grace_period | 不顯示（已有有效訂閱） | -- | -- |

- **Acceptance Criteria**：
  - Given 用戶狀態為上述矩陣中任一狀態，When 用戶進入 Profile 訂閱區域，Then 顯示內容符合「Profile 訂閱區域」矩陣定義。
  - Given 用戶狀態為 active 且無 billing_issue，When 用戶查看 Profile 訂閱區域，Then 日期欄位文案必須為「續訂日」等值語意，不得顯示為「到期日」。
  - Given 用戶狀態為 active 且無 billing_issue，When 用戶在 Profile 點擊「變更方案」，Then 進入 Paywall 且顯示當前方案與可切換方案。
  - Given 用戶狀態為 cancelled，When 嘗試進入 Paywall，Then Paywall 顯示且標題語境為「重新訂閱」，包含目前到期日 banner。
  - Given 用戶狀態為 cancelled，When 觸發 AI 受限功能，Then 功能正常執行不被阻擋。
  - Given 用戶狀態為 active + billing_issue，When 觸發 AI 受限功能，Then 功能執行，同時顯示非阻斷的帳務異常提示。
  - Given 用戶狀態為 grace_period，When 用戶使用 AI 受限功能，Then 功能正常執行，同時顯示非阻斷的「帳務處理中」提示。
  - Given 用戶狀態為 grace_period，When 用戶查看 Profile 訂閱區域，Then 顯示方案名稱 + 「帳務處理中，服務不受影響」黃色提示。
  - Given 用戶狀態為 expired 且在 Paywall 點擊「Restore Purchases」，When Apple 找到有效訂閱記錄，Then 狀態更新為對應狀態，Paywall 關閉。
  - Given 用戶狀態為 expired 且在 Paywall 點擊「Restore Purchases」，When Apple 找不到有效訂閱記錄，Then 顯示「找不到有效的訂閱記錄」提示，Paywall 保持開啟。

#### 4) Session 中狀態變更行為

- **描述**：用戶在使用 App 的過程中，訂閱狀態可能因為到期、Apple 側取消、退款等原因發生變更。App 需要定義何時檢查狀態、狀態變更時如何通知用戶、進行中的操作是否中斷。
- **Acceptance Criteria**：
  - Given 用戶狀態為 cancelled 且到期日在本次 session 中到達，When App 偵測到狀態變更為 expired，Then 不中斷用戶正在進行的操作（如正在查看 AI 建議），而是在下一次功能閘門觸發時才阻擋。
  - Given 用戶在 Apple 系統設定取消訂閱後切回 App，When App 回到前景，Then 在合理時間內刷新訂閱狀態（具體刷新機制由 Architect 決定），Profile 顯示更新後的狀態。
  - Given 用戶正在使用 AI 功能（如 Rizo 對話中）且訂閱在此刻到期，When 功能操作完成，Then 該次操作正常完成不中斷；下一次新操作觸發閘門檢查。
  - Given 後端回傳的訂閱狀態與本地快取不同，When App 偵測到狀態降級（如 active → expired），Then 顯示非阻斷通知告知用戶狀態已變更，不強制跳轉 Paywall。

#### 5) Revoke（Apple 退款）狀態處理

- **描述**：Apple 退款會導致訂閱立即失效（revoke），狀態從 active 直接變為無訂閱。App 需要正確反映此狀態變更，而非讓用戶停留在「已訂閱」的錯覺中。
- **Acceptance Criteria**：
  - Given 用戶的訂閱被 Apple 退款（revoke），When App 刷新狀態，Then 狀態映射為 `expired`（而非 `none`，因為用戶曾經是訂閱者）。
  - Given 用戶狀態因 revoke 從 active 變為 expired，When 用戶查看 Profile，Then 顯示「已到期」狀態與「重新訂閱」按鈕（與一般到期行為一致）。
  - Given revoke 發生在 session 中，When App 偵測到狀態變更，Then 遵循「Session 中狀態變更行為」規則（不中斷進行中操作）。

### P1（應該有）

#### 6) 離線時的訂閱狀態行為

- **描述**：跑步 App 的用戶經常在離線環境使用（跑步途中、山區、飛航模式）。離線時無法刷新訂閱狀態，App 必須有明確的降級策略，避免誤判導致功能被錯誤封鎖或錯誤導向 Paywall。
- **Acceptance Criteria**：
  - Given 用戶在有網路時最後一次狀態為 active/trial/cancelled（未到期），When 用戶進入離線狀態，Then 使用本地快取的訂閱狀態，功能閘門依快取狀態放行。
  - Given 用戶處於離線狀態，When API 呼叫因網路失敗回傳錯誤，Then 錯誤應被識別為「網路不可用」而非「訂閱過期」，不得觸發 Paywall。
  - Given 用戶離線且本地快取狀態為 active，When 用戶觸發 AI 受限功能，Then 顯示「目前離線，部分功能暫時無法使用」提示（因 AI 功能本身需要網路），而非導向 Paywall。
  - Given 用戶從離線恢復網路，When App 偵測到網路可用，Then 在背景刷新訂閱狀態，若狀態有變更則按「Session 中狀態變更行為」處理。

#### 7) 方案升降級

- **描述**：已訂閱的用戶應能在 App 內發起方案變更（月訂升年訂、年訂降月訂），而非只能透過 Apple 系統設定。升降級後的 UI 需正確反映過渡狀態。
- **Acceptance Criteria**：
  - Given 用戶狀態為 active（月訂方案），When 用戶在 Profile 點擊「變更方案」，Then 進入 Paywall，顯示可切換的方案選項，並標示哪個是「升級」哪個是「降級」。
  - Given 用戶完成升級（月→年），When 購買成功，Then 立即反映新方案名稱與到期日。
  - Given 用戶完成降級（年→月），When Apple 確認降級排程，Then Profile 顯示「目前方案：年訂 Premium，將於 YYYY/MM/DD 切換至月訂」。
  - Given 用戶處於「等待降級」狀態，When 用戶查看 Profile，Then 主要按鈕仍為「管理訂閱」，功能閘門完全放行（降級尚未生效）。

#### 8) 購買成功確認體驗

- **描述**：用戶完成購買後，不應直接 dismiss Paywall，而是先顯示成功確認畫面，讓用戶感受到明確的「購買已完成」回饋。
- **Acceptance Criteria**：
  - Given 用戶在 Paywall 點擊購買且購買成功，When 系統收到成功回調，Then 顯示購買成功確認畫面（包含成功圖示、確認文案、方案摘要）。
  - Given 購買成功確認畫面已顯示，When 用戶點擊「開始使用」按鈕或等待 3 秒，Then 關閉 Paywall 並回到原頁面。
  - Given 用戶在試用期間購買成功，When 成功確認畫面顯示，Then 文案需包含「付費方案將在試用結束後啟用」的權益說明。
  - Given 購買成功但後端同步尚未完成，When 成功確認畫面顯示，Then 仍顯示成功回饋（不因同步延遲而顯示錯誤），狀態同步在背景繼續進行。

#### 9) 試用即將到期提醒

- **描述**：試用用戶在到期前收到提醒，避免突然失去功能存取權的驚訝感。
- **Acceptance Criteria**：
  - Given 用戶狀態為 trial 且剩餘天數 <= 3 天，When 用戶開啟 App 或 App 回到前景，Then 顯示「試用即將到期」提醒（banner 或 sheet），包含剩餘天數與升級入口。
  - Given 用戶狀態為 trial 且剩餘天數 > 3 天，When 用戶開啟 App，Then 不顯示到期提醒。
  - Given 到期提醒已顯示過一次，When 同一天內再次開啟 App 或回到前景，Then 不重複顯示（每日最多顯示一次）。
  - Given 用戶在提醒中點擊「升級」，When 系統處理，Then 導向 Paywall。
  - Given 用戶在提醒中點擊「稍後再說」或關閉提醒，When 系統處理，Then 提醒消失，用戶可正常使用 App。

#### 10) 到期提醒頻率策略

- **描述**：訂閱到期後的提醒應有合理頻率，避免過度騷擾但確保用戶知悉。
- **Acceptance Criteria**：
  - Given 用戶狀態為 expired，When 用戶開啟 App（非從背景回前景），Then 顯示到期提醒 sheet 與升級入口。
  - Given 用戶狀態為 expired 且已在本次 session 中關閉過到期提醒，When 用戶在同一 session 中回到前景，Then 不再重複顯示提醒。
  - Given 用戶狀態為 expired，When 用戶觸發 AI 受限功能，Then 直接導向 Paywall（此為功能閘門行為，不受提醒頻率限制）。

### P2（可以有）

#### 11) 首次用戶訂閱引導

- **描述**：新註冊用戶在首次體驗核心功能後，適時引導其了解付費方案，降低試用轉換摩擦。
- **Acceptance Criteria**：
  - Given 用戶為新註冊（trial 狀態）且已完成 Onboarding 流程，When 用戶首次進入訓練計畫主頁，Then 以非阻斷方式顯示訂閱引導提示（如 banner 或 tooltip），簡要說明 Premium 權益。
  - Given 引導提示已顯示過一次，When 用戶再次進入主頁，Then 不再顯示（僅首次一次）。
  - Given 用戶點擊引導提示，When 系統處理，Then 導向 Paywall。
  - Given 用戶忽略引導提示，When 提示自動消失或用戶關閉，Then 不影響任何功能使用。

## AC ID Index

本 spec 的原始結構以需求章節編排；以下 AC ID 為正式引用索引，供派工、review 與 QA 使用。

| AC ID | 對應需求 |
|------|----------|
| AC-SUB-01a | active 用戶在 Profile 顯示管理訂閱 |
| AC-SUB-01b | cancelled 用戶在 Profile 顯示管理訂閱 |
| AC-SUB-01c | 點擊管理訂閱跳轉 Apple 訂閱頁 |
| AC-SUB-01d | trial / expired / none 不顯示管理訂閱 |
| AC-SUB-02a | 後端 `cancelled` 不再映射為 `active` |
| AC-SUB-02b | cancelled 在 Profile 顯示到期日與剩餘天數 |
| AC-SUB-02c | cancelled 未到期前功能照常可用 |
| AC-SUB-02d | cancelled 到期後轉為 expired |
| AC-SUB-02e | cancelled 顯示重新訂閱 + 管理訂閱 |
| AC-SUB-03a | Profile 區塊遵循訂閱狀態矩陣 |
| AC-SUB-03a-1 | active / grace_period 在 Profile 以續訂日語意顯示日期 |
| AC-SUB-03b | active 可從 Profile 進入變更方案 |
| AC-SUB-03c | cancelled 進入 Paywall 為重新訂閱語境 |
| AC-SUB-03d | cancelled 觸發 AI 功能時仍放行 |
| AC-SUB-03e | active + billing_issue 放行並提示 |
| AC-SUB-03f | grace_period 放行並提示 |
| AC-SUB-03g | grace_period 在 Profile 顯示帳務處理中 |
| AC-SUB-03h | expired Restore 成功後更新狀態並關閉 Paywall |
| AC-SUB-03i | expired Restore 找不到記錄時顯示提示並保留 Paywall |
| AC-SUB-04a | session 中 cancelled 到期不打斷當前操作 |
| AC-SUB-04b | 從 Apple 取消後回前景需刷新狀態 |
| AC-SUB-04c | AI 使用中到期不打斷當前操作 |
| AC-SUB-04d | 狀態降級時顯示非阻斷通知 |
| AC-SUB-05a | revoke 映射為 expired |
| AC-SUB-05b | revoke 後 Profile 顯示已到期與重新訂閱 |
| AC-SUB-05c | revoke 在 session 中遵循狀態降級規則 |
| AC-SUB-06a | 離線時使用快取中的有效訂閱狀態 |
| AC-SUB-06b | 網路錯誤不得誤判為訂閱過期 |
| AC-SUB-06c | 離線且 active 時 AI 不導向 Paywall，而顯示離線提示 |
| AC-SUB-06d | 恢復網路後在背景刷新並處理狀態變更 |
| AC-SUB-07a | active 用戶可進入變更方案並看到升降級選項 |
| AC-SUB-07b | 升級成功後立即反映新方案 |
| AC-SUB-07c | 降級排程後顯示待切換資訊 |
| AC-SUB-07d | 等待降級期間功能完全放行 |
| AC-SUB-08a | 購買成功先顯示確認畫面 |
| AC-SUB-08b | 確認畫面 3 秒或手動後關閉 |
| AC-SUB-08c | 試用中購買成功顯示權益說明 |
| AC-SUB-08d | 後端同步延遲不影響成功回饋 |
| AC-SUB-09a | trial 剩餘 <= 3 天時顯示到期提醒 |
| AC-SUB-09b | trial 剩餘 > 3 天時不顯示提醒 |
| AC-SUB-09c | 同一天 trial 提醒最多顯示一次 |
| AC-SUB-09d | 從 trial 提醒點擊升級導向 Paywall |
| AC-SUB-09e | 關閉 trial 提醒後不影響使用 |
| AC-SUB-10a | expired 開 app 時顯示到期提醒 |
| AC-SUB-10b | 同一 session 不重複顯示 expired 提醒 |
| AC-SUB-10c | expired 觸發 AI 功能直接導向 Paywall |
| AC-SUB-11a | 新 trial 用戶首次進入主頁顯示引導提示 |
| AC-SUB-11b | 首次引導只顯示一次 |
| AC-SUB-11c | 點擊引導提示導向 Paywall |
| AC-SUB-11d | 忽略引導提示不影響功能 |

## 明確不包含

- 不定義 Apple 訂閱管理頁面內的行為（那是 Apple 系統 UI）
- 不定義 RevenueCat / StoreKit 的技術整合細節
- 不定義後端 API 的欄位變更（後端已支援 cancelled 狀態，只需前端正確處理）
- 不定義退款申請流程（Apple 退款申請由系統處理。但 revoke 後的狀態映射和 UI 反映屬於本 Spec 範圍，見需求 5）
- 不定義推播通知提醒（本 Spec 範圍限於 App 內提醒）
- 不定義 Android 端行為
- 不定義多方案定價策略（具體有哪些方案、定價多少屬於 `SPEC-iap-paywall-pricing-and-trial-protection`）
- 不定義 Family Sharing 行為（目前不支援）

## 技術約束（給 Architect 參考）

- **SubscriptionStatus enum 需擴充**：目前只有 active/expired/trial/none。需新增 `cancelled` 和 `grace_period` 兩個 case。`SubscriptionMapper` 需停止將 cancelled 映射為 active。此變更影響所有讀取訂閱狀態的 ViewModel，需全面排查。
- **Apple 訂閱管理跳轉**：iOS 提供 `URL(string: "https://apps.apple.com/account/subscriptions")` 可跳轉至系統訂閱管理。無需額外權限。
- **狀態矩陣需單一真相源**：所有頁面的閘門判斷應引用同一份狀態規則，不可各頁面自行判斷。建議在 Domain 層建立統一的權限判斷邏輯。
- **提醒頻率需本地持久化**：「每日一次」的提醒抑制需要在本地記錄上次顯示時間，建議使用 UserDefaults 或等效輕量儲存。
- **PaywallTrigger enum 需擴充**：目前只有 apiGated / trialExpired / featureLocked 三個 case。cancelled 的「重新訂閱」語境、active 用戶的「變更方案」語境，都需要新的 trigger case。同時 `TrainingPlanV2ViewModel`、`WeeklySummaryViewModel`、`UserProfileView.paywallEntryTrigger` 都需要配合更新。
- **購買成功確認不依賴後端同步**：成功回饋應基於 Apple/RevenueCat 的購買回調，不等待後端狀態更新。
- **離線判斷不可與訂閱到期混淆**：API 呼叫失敗時，需先判斷是「網路不可用」還是「403 訂閱過期」。網路不可用時使用本地快取狀態，不得觸發 Paywall。`SubscriptionLocalDataSource` 已存在，可作為離線快取基礎。
- **前景恢復時需刷新狀態**：App 從背景回到前景時，需觸發訂閱狀態刷新。刷新機制（頻率、防抖）由 Architect 決定。
- **grace_period 來源**：Apple billing retry / grace period 最長可達 60 天。後端可能回傳 `billing_issue` 或 `grace_period`，Architect 需確認後端實際回傳的欄位名稱並做對應映射。
- **Revoke 事件處理**：Apple 退款後 RevenueCat 會發送 revoke 事件。前端需能正確接收此狀態變更並映射為 expired。
- **升降級狀態**：Apple 的升級立即生效，降級在當期結束後生效。降級期間 Apple 回傳的可能仍是原方案 + pending downgrade 資訊，Architect 需確認如何從 RevenueCat 取得此資訊。

## 與既有 Spec 的關係

| 既有文件 | 關係 |
|---------|------|
| SPEC-iap-paywall-pricing-and-trial-protection | 互補。該 Spec 定義定價顯示、試用保護、購買同步、到期閘門。本 Spec 補齊訂閱管理、cancelled 狀態、UI 矩陣、確認體驗、提醒策略。 |
| ADR-001 訂閱服務架構 | 一致。本 Spec 不改變架構決策，僅要求新增 cancelled 狀態。 |
| ADR-002 RevenueCat 整合 | 一致。訂閱管理跳轉不涉及 RevenueCat SDK。 |
| ADR-003 Paywall 觸發與錯誤處理 | 擴充。本 Spec 新增 cancelled 觸發語境，需擴充 PaywallTrigger。 |

## 開放問題

1. **cancelled 狀態的到期日顯示格式**：顯示「服務有效至 2026/05/13」還是「剩餘 30 天」？目前 Spec 定義為兩者皆顯示，是否需要簡化？
2. **billing_issue 的非阻斷提示形式**：使用 banner、toast、還是 inline 文字？需要 Designer 決定具體 UI 形式。
3. **購買成功確認畫面的停留時間**：Spec 定義 3 秒自動關閉 + 手動按鈕。是否需要調整？
4. **試用到期提醒的天數閾值**：Spec 定義為 <= 3 天。是否需要兩階段（如 7 天一次 + 3 天開始每日提醒）？
5. **cancelled 用戶是否在功能閘門處顯示額外提示**：目前定義為正常放行不提示。是否需要在閘門處也提示「訂閱即將到期」？
6. **到期提醒頻率**：本 Spec 以「每日一次 + session 內不重複」為建議，待確認。
7. **grace_period 後端欄位確認**：後端是否已支援 grace_period 狀態回傳？欄位名稱為何？需與後端確認。若後端尚未支援，grace_period 相關需求降為 P2。
8. **離線快取的有效期限**：本地快取的訂閱狀態應信任多久？（如：快取 7 天內有效、超過 7 天視為需要重新驗證）需 PM + Architect 共同決定。
9. **降級過渡期的資訊來源**：RevenueCat SDK 是否提供 pending downgrade 資訊？若無法取得，降級過渡狀態的 UI 顯示可能需要簡化。
10. **Paceriz 目前是否有多個訂閱方案**：如果只有一個方案，需求 7（方案升降級）可暫時降為 P2 或移出本 Spec。
