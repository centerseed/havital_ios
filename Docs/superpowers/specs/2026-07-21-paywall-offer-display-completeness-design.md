# Paywall 訂閱優惠顯示完整化 — Design Spec

- 日期：2026-07-21
- 範圍：iOS `SubscriptionRepositoryImpl` 的 paywall 優惠顯示
- 方案：B（事實兜底）— 有 offer 就顯示，用 `customerInfo` 事實判斷擋曾訂閱者，資格最終交 Apple 購買時強制

## 1. 問題（實證）

Paywall 自動顯示三種訂閱優惠：試賣(intro)、促銷(promotional)、舊客戶(win-back)。現況：

- **intro 壞（真 regression）**：T-0236（commit `8febd3b9`）用 `checkTrialOrIntroDiscountEligibility`（RevenueCat 對 Apple 資格的**預測**）當顯示閘門，`shouldDisplayIntroDiscount` 只在 `.eligible` 放行、`.unknown` 隱藏（有單元測試鎖死此行為）。但該 API 對真實新用戶常回 `.unknown`。
  - **鐵證**：測試 sandbox 帳號刪除購買紀錄（事實上已合格）後，intro 仍被隱藏 → 證明 API 回的是 `.unknown` 而非 `.eligible`，被 T-0236 當不合格藏掉。
  - **production 影響**：真新客（剛裝、anonymous、尚未與 App Store 同步）同樣回 `.unknown` → 上架後看不到 intro 特價 → 新客轉換受損。
- **促銷 / 舊客戶（路徑正確、未驗證）**：走 `eligiblePromotionalOffers()` / `eligibleWinBackOffers()`（Apple 回傳的**實際合格清單**＝事實源），邏輯正確；但從未經 sandbox/真機系統性驗證。
- **可驗證性缺口**：開發者只能用 sandbox 測，而 intro 的預測閘門在 sandbox 恆回 `.unknown` → 恆隱藏 → **無法驗證任何 intro 顯示**。這是為何此 bug 一路發到創辦人手上都沒被抓到。

## 2. 第一性原理根因

1. intro 資格的**唯一權威是 Apple，在購買當下強制**：不合格者按下購買會被自動收原價。app 顯示層無權、也不需預判。
2. 「此用戶是否已用過 intro」是**已發生的事實**（記在購買歷史），不是需要**預測**的東西。
3. T-0236 兩層錯：(a) 用**預測 API** 回答**事實問題** → 不可靠、對新客回 unknown → 誤擋；(b) 把「資格強制」這件屬於 **Apple 購買流程**的責任，搬到 **app 顯示層**去猜。

促銷/舊客戶正確，正因它們用「Apple 回傳的實際合格清單」（事實），不是預測。intro 該回到同樣的「事實」模式。

## 3. 目標（範圍 B）

三種自動優惠在 paywall 正確顯示且 sandbox 可驗：

- intro：改為事實化顯示（本 spec 核心改動）
- 促銷、舊客戶：**驗證確認**正確（邏輯不動，除非驗出問題）
- 優惠碼：已完成，不在本範圍

## 4. 設計（方案 B：事實兜底）

### 4.1 intro 顯示邏輯（核心改動）

移除 T-0236 的預測閘門，改為 customerInfo 事實判斷：

- 產品有 `introductoryDiscount` → 預設列入顯示候選。
- **用事實源 `customerInfo` 擋曾訂閱者**：若 `customerInfo` 顯示此用戶曾在該 subscription group 有過購買 / entitlement（含已過期 inactive），則隱藏 intro（他不合格，Apple 也不會給）。
- 其餘（新客、無歷史、資格不確定）→ 顯示。
- **傾向顯示原則**：任何不確定都顯示，因為 Apple 購買時是最終安全網；誤擋的傷害（新客流失）> 誤顯示（曾訂閱者看到假折扣、Apple 購買時收原價）。

資料源：`customerInfo`（實作時確認精確欄位——候選：`allPurchasedProductIdentifiers` 是否含該 group 的 product、或 `entitlements.all[...]` 歷史含 inactive）。RevenueCat `customerInfo` 是真實購買紀錄，sandbox 也準。

### 4.2 促銷 / 舊客戶

邏輯不動（已用事實清單 `eligiblePromotionalOffers` / `eligibleWinBackOffers`）。本專案任務 = sandbox/真機**實測驗證**在 paywall 正確顯示。win-back 記錄限制：僅 iOS 18+。

### 4.3 可驗證性

- 沿用並強化現有 `[SubscriptionRepositoryImpl]` fetchOfferings 的 diagnostic log：印出每個 package 各種 offer 的來源、customerInfo 判斷結果、是否列入顯示——讓 sandbox 測試能從 log 確認決策。
- 移除預測閘門後，sandbox 新帳號（無購買歷史）→ intro 顯示 → 開發者終於能在 sandbox 驗證 intro。

## 5. 元件 / 檔案

- `Havital/Features/Subscription/Data/Repositories/SubscriptionRepositoryImpl.swift`
  - 移除 `shouldDisplayIntroDiscount(status:)` 與 `introEligibility(for:)`（T-0236 引入）
  - intro 分支（約 line 120–130）改為 customerInfo-based 判斷
  - 更新 diagnostic log（line ~138）
- `HavitalTests/Features/Subscription/Data/SubscriptionIntroEligibilityTests.swift`
  - 改寫：測「曾訂閱該 group → 隱藏」「新客無歷史 → 顯示」「customerInfo 取得失敗 → 顯示(傾向顯示)」，mock `customerInfo` 而非 eligibility status
- 促銷 / 舊客戶：無 code 改動；新增 sandbox 驗證步驟（手動或 Maestro）

## 6. 資料流

`fetchOfferings` → 每個 package：
- `introductoryDiscount` 存在? → 查 `customerInfo` 是否曾訂閱該 group → 否則列入候選
- promotional：`eligiblePromotionalOffers()`（不變）
- win-back：`eligibleWinBackOffers()` iOS 18+（不變）
- `selectDisplayOffer` 從候選挑一個顯示（不變）

## 7. 錯誤處理

- `customerInfo` 取得失敗（網路/逾時）→ fallback 顯示 intro（傾向顯示，資格交 Apple）。
- 這是刻意的設計選擇，與 T-0236 相反：不確定時**顯示**而非隱藏。

## 8. 測試

- 單元：customerInfo 有/無該 group 歷史 → 隱藏/顯示；customerInfo 錯誤 → 顯示。
- Sandbox 實測：全新帳號 paywall 看得到 intro；促銷、舊客戶顯示；（可選）曾訂閱帳號不看到 intro。

## 9. 驗收準則

- [ ] 全新 sandbox 帳號在 paywall 看得到 intro 特價（修好 regression）
- [ ] 促銷、舊客戶優惠在 sandbox 正確顯示（各一次實測 + 截圖/log）
- [ ] diagnostic log 能讓開發者從 log 確認每種 offer 的顯示決策
- [ ] 曾訂閱該 group 的帳號不顯示 intro（方案 B 的保護）
- [ ] 單元測試覆蓋 customerInfo 判斷 + 失敗 fallback
- [ ] clean build 通過

## 10. 非目標 / 風險

- 不改促銷/舊客戶的顯示邏輯（僅驗證）。
- 不做優惠碼（已完成）。
- 風險：iOS 18 以下無 win-back（Apple 限制，非 bug，記錄之）。
- 風險：「曾訂閱該 group」的精確 customerInfo 欄位需實作時以真機/sandbox 坐實，避免又用錯資料源。
