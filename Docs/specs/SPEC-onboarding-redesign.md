---
type: SPEC
id: SPEC-onboarding-redesign
status: Approved
ontology_entity: TBD
created: 2026-04-15
updated: 2026-04-15
decisions_closed: 2026-04-15
---

# Feature Spec: Onboarding 流程重新設計

## 背景與動機

Paceriz 的 onboarding 流程目前有 14 個步驟，存在以下核心問題：

1. **佈局一致性缺失**：5 種不同的底部按鈕模式、水平 padding 混亂（16/24/32/40pt）、CTA cornerRadius 混用（10/12pt）、標題字型不一致。用戶在流程中會感受到明顯的視覺跳變，削弱專業感和信任度。

2. **Critical UX 缺陷**：按鈕被推出螢幕外、底部 CTA 和 toolbar 按鈕功能重複、slider 精度不足（0-180km 範圍新手難以精確設定）、picker 佔滿螢幕。

3. **資訊架構問題**：14 步無進度指示、教學頁打斷設定心流。

4. **架構問題**：每個步驟各自建新的 ViewModel 實例，導致跨步驟資料不共享。

5. **新功能需求**：後台已準備賽事資料庫，需要在 onboarding 中提供「選擇既有賽事」功能，讓用戶可以一站式選擇賽事（含距離和日期），而不需手動輸入所有資訊。

## 目標用戶

- **新用戶**：第一次使用 Paceriz，需要完成完整 onboarding 設定訓練計畫。
- **Re-onboarding 用戶**：已有帳戶，重新設定訓練目標（從 PersonalBest 步驟開始）。

## 用戶確認事項

- 步驟順序（PB/WeeklyDistance 在 GoalType 之前）已確認合理，不需要改動。理由：當前週跑量跟目標設定沒有明確關係，先收集現狀再設定目標是合理的。

---

## 需求

### Must Have (P0)

#### P0-1: 統一佈局規範

- **描述**：整個 onboarding 流程中所有頁面必須遵循統一的佈局規範，消除視覺跳變。目前存在 5 種不同的底部按鈕模式、不一致的間距和圓角。具體數值由 Designer 在 Design Doc 中定義。
- **Acceptance Criteria**：
  - Given 用戶進入 onboarding 流程，When 用戶從第一步走到最後一步，Then 所有頁面的 CTA 按鈕位置、大小、圓角、底部間距、水平間距視覺上完全一致。
  - Given 任何一個 onboarding 頁面，When 頁面內容不足以填滿螢幕或內容超出螢幕，Then CTA 按鈕始終固定在螢幕底部可見位置，不會被推出螢幕外或隨內容捲動。
  - Given 所有 onboarding 頁面，When 逐頁檢視，Then 標題字型、水平間距、CTA 按鈕樣式（圓角、底部間距）在所有頁面保持一致。

#### P0-2: 修復按鈕被推出螢幕外的問題 (C1)

- **描述**：OnboardingIntroView 底部的 Spacer 會把 CTA 按鈕推到螢幕外，導致用戶看不到「開始設定」按鈕。
- **Acceptance Criteria**：
  - Given 用戶在 OnboardingIntroView 頁面，When 頁面載入完成，Then「開始設定」按鈕始終在螢幕可見範圍內，無需任何捲動即可看到。
  - Given 不同螢幕尺寸的裝置（iPhone SE 到 iPhone Pro Max），When 頁面載入完成，Then CTA 按鈕在所有尺寸下都不會超出螢幕可見區域。

#### P0-3: 消除重複的操作入口 (C2)

- **描述**：部分頁面同時有底部 CTA 按鈕和 toolbar 右上角按鈕執行相同功能（如 PersonalBestView、WeeklyDistanceSetupView、OnboardingView），造成用戶困惑。每個頁面只應有一個主要操作入口。
- **Acceptance Criteria**：
  - Given 任何一個 onboarding 頁面，When 頁面顯示完成，Then 只有一個「下一步」操作入口（統一為底部固定 CTA 按鈕），不存在同功能的 toolbar 按鈕。
  - Given WeeklyDistanceSetupView 頁面，When 用戶想要跳過此步驟，Then 提供一個視覺上次要的「跳過」按鈕（例如 text button），與主要 CTA「下一步」區分，但不在 toolbar 重複放置。

#### P0-4: 改善每週跑量輸入精度 (C3)

- **描述**：WeeklyDistance slider 範圍 0-180km，對於週跑量 10-30km 的新手來說精度極差（每個像素代表太多公里）。需要讓用戶能精確且直覺地輸入自己的每週跑量。
- **Acceptance Criteria**：
  - Given 用戶在每週跑量設定頁面，When 用戶嘗試設定 15km 的週跑量，Then 用戶能在 3 秒內精確設定到 15km，無需反覆微調。
  - Given 週跑量設定，When 用戶操作輸入控制元件，Then 每一次操作步進不超過 5km（即不會出現「想設 15km 卻跳到 25km」的情況）。

#### P0-5: 修復距離與時間編輯器佔滿螢幕問題 (C4)

- **描述**：RaceDistanceTimeEditorSheet 的 wheel picker 佔滿整個螢幕，導致用戶體驗差。需要讓 picker 佔用合理的空間。
- **Acceptance Criteria**：
  - Given 用戶在賽事設定頁面點擊編輯距離與時間，When 編輯器彈出，Then picker 佔用螢幕不超過 60%，用戶能同時看到距離選擇和時間設定。
  - Given 編輯器彈出後，When 用戶完成選擇，Then 用戶能一鍵確認退出，不需要多次操作。

#### P0-6: 統一導航模式 (M1)

- **描述**：部分頁面隱藏 navigation bar（如 IntroView、DataSourceSelectionView），其他頁面顯示。這導致用戶無法預期返回按鈕是否存在，破壞心理模型。
- **Acceptance Criteria**：
  - Given 用戶在 onboarding 流程的任何非首頁步驟，When 用戶想返回上一步，Then 始終有可見的返回按鈕（navigation bar back button），且位置一致。
  - Given DataSourceSelectionView 頁面，When 頁面載入完成，Then 有可見的返回方式（navigation bar 或自訂返回按鈕），用戶不會被困住無法返回。

#### P0-7: 修復 DataSourceSelectionView 無法返回問題 (M2)

- **描述**：DataSourceSelectionView 隱藏了 navigation bar，導致用戶選錯資料來源時無法返回上一步重新選擇。
- **Acceptance Criteria**：
  - Given 用戶在 DataSourceSelectionView，When 用戶想返回到 IntroView，Then 有明確的返回入口可以使用，且返回後狀態正確（可以重新選擇資料來源）。

#### P0-8: 硬編碼中文走 i18n (M4)

- **描述**：RaceDistanceTimeEditorSheet 的「參考時間」section 中的文字（如「精英跑者」「進階跑者」「休閒跑者」）硬編碼中文，未使用 NSLocalizedString。
- **Acceptance Criteria**：
  - Given app 語言設定為英文，When 用戶進入 RaceDistanceTimeEditorSheet，Then 所有文字顯示為英文，無任何中文殘留。
  - Given app 語言設定為繁體中文，When 用戶進入 RaceDistanceTimeEditorSheet，Then 所有文字正確顯示繁體中文。

#### P0-9: 跨步驟資料共享 (M6)

- **描述**：目前每個 onboarding 步驟各自建立新的 ViewModel 實例，導致步驟之間的資料不共享、返回時狀態丟失、以及不必要的重複 API 呼叫。需要確保整個 onboarding 流程中用戶輸入的資料跨步驟保持一致。具體技術方案由 Architect 決定。
- **Acceptance Criteria**：
  - Given 用戶在 PersonalBestView 輸入了 PB 數據，When 用戶前進到後續步驟再返回到 PersonalBestView，Then 之前輸入的 PB 數據仍然保留，不會被重置。
  - Given 用戶在 GoalTypeSelectionView 選擇了目標類型，When 用戶在後續步驟（MethodologySelectionView）中需要讀取目標類型，Then 能正確讀取到之前選擇的目標類型，而不需要重新從 API 載入。
  - Given 用戶從步驟 A 前進到步驟 B，When 步驟 B 載入，Then 不應對已經在步驟 A 取得的資料再次發送 API 請求。

#### P0-10: 賽事選擇功能（Race Event Selection）

- **描述**：當用戶選擇目標類型為「賽事」後，除了手動輸入賽事資訊外，還要能從賽事資料庫中選擇既有賽事。選擇既有賽事後，距離和日期自動帶入，用戶只需設定預計完賽時間。選完賽事後立即顯示倒數天數，讓用戶有緊迫感和明確感。

- **API 參考**：後台已提供 `GET /v2/races`（列表）和 `GET /v2/races/{race_id}`（詳情），完整規格見附錄 B。

- **用戶流程**：
  1. 在 GoalTypeSelectionView 選擇「賽事」目標類型
  2. 進入賽事設定頁面，看到兩個選項：
     - 「從賽事資料庫選擇」（主要路徑，推薦）
     - 「手動輸入賽事資訊」（備用路徑）
  3. 若選擇「從賽事資料庫選擇」：
     - 顯示賽事列表，預設顯示精選賽事
     - 支援按距離篩選、關鍵字搜尋
     - 一個賽事可能有多個距離，用戶選擇賽事後需再選擇距離
     - 選完後自動帶入：賽事名稱、距離、日期
     - 立即顯示「距離賽事還有 X 天」（基於 `event_date` 計算）
     - 用戶只需設定預計完賽時間
  4. 若選擇「手動輸入」：維持現有流程（輸入名稱、日期、距離、時間）

- **Acceptance Criteria**：
  - Given 用戶選擇目標類型為「賽事」，When 進入賽事設定頁面，Then 看到「從賽事資料庫選擇」和「手動輸入」兩個入口。
  - Given 用戶點選「從賽事資料庫選擇」，When 賽事列表載入完成，Then 顯示精選賽事列表，每項顯示賽事名稱、城市、日期、可選距離。
  - Given 賽事列表顯示中，When 用戶輸入搜尋關鍵字，Then 列表即時過濾，只顯示名稱包含關鍵字的賽事。
  - Given 賽事列表顯示中，When 用戶選擇距離篩選條件（如「半馬」），Then 列表只顯示包含該距離的賽事。
  - Given 賽事列表頁面，When 用戶想切換地區（台灣/日本），Then 頁面頂部提供顯式地區切換器（如 Segmented Control），用戶需主動切換，不依賴裝置語系自動判斷。
  - Given 一個賽事有多個距離（如台北馬拉松有全馬和半馬），When 用戶點選該賽事，Then 以 Dialog（Sheet）方式彈出距離選擇，不跳轉至新頁面，用戶選完即回到列表。
  - Given 用戶選擇了賽事和距離，When 選擇完成回到設定頁面，Then 賽事名稱、距離、日期已自動填入，且顯示「距離賽事還有 X 天」的倒數資訊。
  - Given 倒數天數不足以完成完整訓練計畫（例如少於 4 週），When 顯示倒數天數，Then 同時顯示提示訊息告知用戶時間較緊，系統會自動調整訓練計畫。
  - Given 用戶選擇了賽事且看到倒數天數，When 用戶設定預計完賽時間後按下一步，Then 流程正常進入後續步驟（方法論選擇或訓練日設定）。
  - Given 賽事列表中的賽事，When 顯示篩選結果，Then 只隱藏 `event_date` 已過期的賽事（今天之前）；報名已截止（`entry_status=closed`）的賽事仍顯示，讓用戶可以看到賽事資訊。
  - Given 後台賽事 API 不可用或回傳空列表，When 用戶進入賽事設定頁面，Then 不顯示「從賽事資料庫選擇」入口，直接顯示手動輸入表單（graceful degradation）。
  - Given 用戶選擇了距離後的賽事，When 進入完賽時間設定，Then 顯示該距離的常見完賽時間參考（與現有功能一致）。

### Should Have (P1)

#### P1-1: 進度指示器

- **描述**：onboarding 流程有多個步驟（根據分支 7-14 步不等），但用戶完全不知道自己在流程中的位置，也不知道還要多久才能完成。需要提供進度指示，降低用戶的焦慮感和放棄率。
- **行為規則**：進度指示器只進不退。用戶返回上一步時，進度條維持在最高到達位置，不回退。理由：分支路徑會導致步數重算，回退會產生「倒退」的負面感知。
- **Acceptance Criteria**：
  - Given 用戶在 onboarding 流程的任何步驟，When 頁面顯示完成，Then 可以看到當前步驟在整體流程中的大致進度。
  - Given 用戶在不同的流程分支（如 race_run vs beginner vs maintenance），When 進度指示器顯示，Then 進度反映的是該分支的實際步驟比例，而非固定的 14 步。
  - Given 用戶返回上一步，When 進度指示器更新，Then 進度維持在最高到達位置，不會回退。

#### P1-2: 提升 Disabled 按鈕的可辨識度 (M5)

- **描述**：GoalTypeSelectionView 中，未選擇目標類型時「下一步」按鈕的 disabled 狀態與 enabled 狀態的視覺對比度不足，用戶可能不清楚為什麼按鈕按不動。
- **Acceptance Criteria**：
  - Given GoalTypeSelectionView 頁面，When 用戶尚未選擇任何目標類型，Then disabled 按鈕與 enabled 按鈕的視覺差異明顯（顏色、透明度明顯不同），用戶一眼就能看出按鈕處於不可操作狀態。
  - Given 用戶選擇了一個目標類型，When 按鈕從 disabled 變為 enabled，Then 有明顯的視覺反饋（如顏色變化動畫），用戶能清楚感知到操作已經就緒。

#### P1-3: 心率區間設定頁優化

- **描述**：HeartRateZoneInfoView 目前作為教學頁插在 DataSource 和 PersonalBest 之間。這一步很重要——最大心率和靜息心率直接影響訓練強度計算的準確度。但對新手而言，這兩個數值很難準確填寫。應提供合理的預設值讓用戶可以快速通過，同時引導用戶日後更新以獲得更精確的訓練建議。
- **設計方向**：
  - 保留此步驟（不移除、不跳過），但降低新手的認知門檻
  - 提供基於年齡/性別的預設值（如最大心率 = 220 - 年齡）
  - 明確告知用戶「先用預設值即可，之後可以隨時更新」
  - 在後續使用中（例如 Profile 或設定頁面）提供更新入口和教學提示
- **Acceptance Criteria**：
  - Given 新手用戶進入心率區間設定頁，When 頁面載入完成，Then 最大心率和靜息心率已有基於用戶基本資料的預設值，用戶無需自行計算。
  - Given 用戶不確定自己的心率數據，When 用戶看到預設值，Then 頁面上有明確的說明文字，告知「可先使用預設值，日後連接心率裝置或進行體能測試後再更新，以獲得更精準的訓練建議」。
  - Given 用戶使用預設值按下一步，When 進入後續步驟，Then 預設值被正確儲存，訓練計畫基於此值計算（不會因為是預設值而跳過心率區間計算）。
  - Given 用戶知道自己的實際心率數據，When 用戶手動修改最大心率或靜息心率，Then 修改後的值被採用，頁面上不再顯示「使用預設值」的提示。
  - Given 用戶在 onboarding 使用了預設值，When 用戶日後在 Profile/設定中查看心率區間，Then 有提示引導用戶更新心率數據以獲得更準確的訓練建議。

#### P1-4: 賽事選擇列表體驗優化

- **描述**：賽事列表的瀏覽和選擇體驗應足夠流暢，讓用戶能快速找到目標賽事。
- **Acceptance Criteria**：
  - Given 賽事列表超過 20 筆，When 用戶向下捲動，Then 列表捲動流暢，無卡頓。
  - Given 用戶搜尋賽事，When 輸入關鍵字，Then 搜尋結果在 300ms 內更新顯示（本地搜尋）或 1 秒內顯示結果（遠端搜尋）。
  - Given 賽事列表中有多個距離分類，When 列表顯示，Then 賽事按日期排序（最近的在前），讓用戶優先看到即將舉辦的賽事。

### Nice to Have (P2)

#### P2-1: 個人最佳成績輸入優化

- **描述**：PersonalBestView 目前使用 wheel picker 讓用戶輸入時、分、秒，picker 佔用大量螢幕空間且操作效率低。可考慮更直覺的輸入方式。
- **Acceptance Criteria**：
  - Given 用戶在 PersonalBest 頁面，When 用戶設定個人最佳成績，Then 輸入控制元件佔用螢幕空間不超過頁面的 40%。
  - Given 用戶要輸入 5K PB 為 25 分 30 秒，When 用戶操作輸入控制元件，Then 能在 5 秒內完成設定。

#### P2-2: 步驟間過場動畫

- **描述**：步驟之間的切換目前是系統預設的 push 動畫，可考慮加入更符合品牌調性的轉場效果，增強流暢感。
- **Acceptance Criteria**：
  - Given 用戶在 onboarding 流程中，When 從一個步驟進入下一個步驟，Then 轉場動畫流暢（無掉幀），且動畫時長不超過 350ms。

---

## Spec 相容性

- 本 spec 是 onboarding 流程的唯一 SSOT（Single Source of Truth）。
- 與 `SPEC-iap-paywall-pricing-and-trial-protection.md` 無衝突（IAP paywall 在 onboarding 完成後觸發）。
- 與 `SPEC-subscription-management-and-status-ui.md` 無衝突（訂閱管理在主 app 內，非 onboarding 範圍）。
- Race Selection 功能完整定義在本 spec P0-10，不另建獨立 spec。

## 明確不包含

- **步驟順序調整**：不改動步驟順序（PB/WeeklyDistance 在 GoalType 之前已確認合理）。
- **新增步驟**：不新增任何 onboarding 步驟，只改善現有步驟和新增賽事選擇功能。
- **後台 API 設計**：賽事資料庫 API 的設計不在本 spec 範圍內，本 spec 只定義前端需要什麼資料和行為。
- **Re-onboarding 流程變更**：Re-onboarding 的起始步驟和結束行為不改動。
- **V1 流程移除**：V1 legacy fallback 邏輯暫時保留，不在本次移除。

## 技術約束（給 Architect 參考）

- **賽事 API 已就緒**：完整規格見附錄 B。前端仍需 graceful degradation 機制（API 失敗時隱藏入口，回退到手動輸入）。注意：一個賽事可能有多個距離，UI 需處理距離選擇。
- **ViewModel 共享（M6）**：目前每個步驟各自建立新的 ViewModel 實例。具體技術方案由 Architect 決定。
- **進度指示器需處理分支**：不同目標類型走不同步驟路徑（race_run: 7-10 步, beginner: 5-7 步, maintenance: 7-9 步），進度指示器需要動態計算。
- **佈局統一涉及所有 View 檔案**：約 15 個 View 檔案都需要調整佈局，工作量需考慮。

## 開放問題

全部已解決。

1. ~~**賽事 API 格式**~~ ✅ 已確認：`GET /v2/races`（列表）+ `GET /v2/races/{race_id}`（詳情），完整參數和回傳格式見 P0-10。
2. ~~**心率區間教學頁的處置**~~ ✅ 已確認：保留此步驟，提供基於年齡的預設值，引導用戶日後更新。見 P1-3。
3. ~~**進度指示器的形式**~~ ✅ Designer 決策：連續式 Progress Bar。見下方「設計決策」。
4. ~~**「跳過」按鈕的位置**~~ ✅ Designer 決策：主 CTA 下方純文字 link。見下方「設計決策」。
5. ~~**賽事列表預設地區邏輯**~~ ✅ 已確認：頁面頂部提供顯式地區切換器，用戶主動切換，不依賴裝置語系自動判斷。見 P0-10。
6. ~~**多距離賽事的距離選擇位置**~~ ✅ 已確認：以 Dialog（Sheet）彈出，不跳轉新頁面。見 P0-10。
7. ~~**已截止報名的賽事是否顯示**~~ ✅ 已確認：`entry_status=closed` 仍顯示；只隱藏 `event_date` 已過期的賽事。見 P0-10。

## 設計決策摘要

設計決策的完整視覺規格（間距、字型、顏色等數值）由 Designer 在 Design Doc 中定義，此處僅記錄產品層級的決策結論：

- **D1: 進度指示器**：採用連續式 Progress Bar（非圓點/步數文字），隱藏分支導致的步數不確定性。GoalType 選擇前的步驟佔前半段進度，選擇後根據實際路徑均分後半段。進度條只進不退。
- **D2:「跳過」按鈕**：放在主 CTA 按鈕下方，以低視覺權重的文字連結呈現。「跳過」是逃生口不是推薦動作，視覺上應明確次於主 CTA。

---

## 附錄 A：當前 Onboarding 步驟清單

以下為 `OnboardingCoordinator.Step` 定義的完整步驟：

| # | Step | 顯示條件 | 目的 |
|---|------|---------|------|
| 1 | intro | 新用戶 | 歡迎頁、產品介紹 |
| 2 | dataSource | 新用戶 | 選擇資料來源（Apple Health / Garmin / Strava） |
| 3 | heartRateZone | 新用戶 | 心率區間教學與設定 |
| 4 | backfillPrompt | 條件顯示（目前跳過） | 是否回填 14 天資料 |
| 5 | personalBest | 所有用戶 | 輸入/選擇個人最佳成績 |
| 6 | weeklyDistance | 所有用戶 | 設定當前每週跑量 |
| 7 | goalType | 所有用戶 | 選擇訓練目標類型（race_run / beginner / maintenance） |
| 8 | raceSetup | race_run only | 設定賽事資訊（名稱、日期、距離、目標時間） |
| 9 | startStage | race_run + 時間不足 | 選擇起始訓練階段 |
| 10 | methodologySelection | race_run (V2) / non-race 多方法論 | 選擇訓練方法論 |
| 11 | trainingWeeksSetup | 非 race_run 目標 | 設定訓練週數 |
| 12 | maintenanceRaceDistance | maintenance only | 預計目標賽事距離 |
| 13 | trainingDays | 所有用戶 | 設定每週訓練日與長跑日 |
| 14 | trainingOverview | 所有用戶 | 訓練計畫概覽、確認並開始 |

## 附錄 B：賽事 API 規格

### 列表查詢 `GET /v2/races`

需 Firebase Auth token（`Authorization: Bearer <token>`）。

| 參數 | 類型 | 預設 | 說明 |
|------|------|------|------|
| region | string | 全部 | tw 或 jp |
| distance_km | float | - | 精準距離（誤差 < 0.01km） |
| distance_min | float | - | 距離下限 |
| distance_max | float | - | 距離上限 |
| date_from | string | 今天 | YYYY-MM-DD |
| date_to | string | - | YYYY-MM-DD |
| q | string | - | 賽事名稱關鍵字搜尋 |
| curated_only | bool | false | 只回傳精選賽事 |
| limit | int | 50 | 1–200 |
| offset | int | 0 | 分頁 |

回傳格式：
```json
{
  "success": true,
  "data": {
    "races": [{
      "race_id": "tw_2026_台北馬拉松",
      "name": "台北馬拉松",
      "region": "tw",
      "event_date": "2026-12-20",
      "city": "台北市",
      "location": "市政府廣場",
      "distances": [
        { "distance_km": 42.195, "name": "全程馬拉松" }
      ],
      "entry_status": "open",
      "is_curated": true,
      "course_type": "road",
      "tags": ["AIMS認證", "波馬資格賽"]
    }],
    "total": 25, "limit": 10, "offset": 0
  }
}
```

### 詳情查詢 `GET /v2/races/{race_id}`

額外回傳欄位：`elevation_gain_m`、`avg_temperature_c`（low/high）、`race_scale`、`description`。

race_id 格式：`{region}_{year}_{賽事名稱}`
