---
type: SPEC
id: SPEC-onboarding-race-selection
status: Draft
ontology_entity: onboarding-race-selection
created: 2026-04-15
updated: 2026-04-15
---

# Feature Spec: Onboarding 賽事選擇

## 背景與動機

目前 onboarding 的 `raceSetup` 仍偏向手動輸入，使用者需要自行整理賽事名稱、日期、距離與目標時間。後端已提供 `/v2/races` 與 `/v2/races/{race_id}`，產品上應把「找賽事」變成 onboarding 的正式能力，而不是額外負擔。

## 相容性

- 本文件是 `SPEC-onboarding-redesign.md` 的子規格，補充其 P0-10 的詳細行為
- 不改 onboarding 完成條件
- 不重定義 race sync、catalog 建模與後端 adapter

## 明確不包含

- 具體 UI 元件切法與 cache 策略
- 非賽事型目標的 UX 改版
- 賽事詳情頁的完整資訊架構

## 需求

### AC-ONB-RACE-01: 賽事型目標必須同時提供清單選擇與手動輸入

Given 使用者在 onboarding 選擇賽事型目標，  
When 進入賽事設定步驟，  
Then 系統必須提供「從賽事資料庫選擇」與「手動輸入」兩個入口。

### AC-ONB-RACE-02: 賽事清單必須支援 onboarding 決策所需的基本查找

Given 使用者進入賽事清單，  
When 尚未輸入搜尋條件，  
Then 系統必須顯示預設區域的近期賽事列表，並允許以關鍵字、距離、地區切換縮小結果。

### AC-ONB-RACE-03: 多距離賽事必須讓使用者完成距離選擇

Given 單一賽事包含多個可選距離，  
When 使用者點選該賽事，  
Then 系統必須要求使用者先選定距離，該距離才可成為後續 target 的正式輸入。

### AC-ONB-RACE-04: 選定賽事後必須自動回填核心欄位

Given 使用者完成賽事與距離選擇，  
When 返回賽事設定步驟，  
Then 系統必須自動帶入賽事名稱、日期、距離，並保留使用者只需補完目標完賽時間的流程。

### AC-ONB-RACE-05: 系統必須顯示與賽事日期相關的立即回饋

Given 使用者已選定賽事，  
When 畫面顯示帶回的賽事資訊，  
Then 系統必須顯示距離賽事還有幾天的倒數資訊；若時間明顯不足以完成完整計畫，需同時提示會採用調整後的訓練安排。

### AC-ONB-RACE-06: 賽事列表中的資訊密度必須足以支援選擇

Given 使用者瀏覽賽事列表，  
When 尚未進入詳情，  
Then 每筆賽事至少必須顯示名稱、城市或地區、日期、可選距離與報名狀態。

### AC-ONB-RACE-07: API 失敗或空結果不得阻塞 onboarding

Given 賽事 API 失敗、回空、或提交前資料失效，  
When 使用者仍想完成 onboarding，  
Then 系統必須提供清楚的 fallback，讓使用者可重新查詢或改走手動輸入，而不是卡死在 race flow。

### AC-ONB-RACE-08: Re-onboarding 必須沿用同一套賽事選擇能力

Given 使用者從主 app 觸發 re-onboarding，  
When 進入賽事設定步驟，  
Then 系統必須提供與首次 onboarding 相同的賽事清單選擇與回填能力。

## 開放問題

1. 預設區域應優先依裝置語系、帳號國家或最近一次選擇判斷。
2. `entry_status = closed` 的賽事應在預設列表中保留到什麼程度。
3. 若使用者已有同名 future target，系統應採重用、合併或建立新目標。

