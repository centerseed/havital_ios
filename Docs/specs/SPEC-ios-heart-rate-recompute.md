---
doc_id: SPEC-ios-heart-rate-recompute
title: iOS 心率設定頁：改心率後重算、自動更新開關、手錶偏差提醒
type: SPEC
status: Draft
layer: product
date: 2026-09-29
---

# iOS 心率設定頁：重算與提醒

行為與數字的來源是已提交的 root `docs/specs/SPEC-heart-rate-and-training-readiness-surfaces.md` AC-HR-07～13、AC-HR-15；後端計算規則在已提交的
`cloud/api_service/docs/01-specs/decision-chain/0-inputs/raw/SPEC-hr-zones.md` §5.5、§5.7、§5.8。HZ-INV-02 只管計算來源，App 缺少來源時顯示「未記錄來源」由 root AC-HR-15 與本檔共同定義。本檔只寫 iOS 2.0 設定頁（`App2HeartRateZoneSettingsView`）看得到的做法，不重講規則。
本條裁決的具名記錄見 root `STATUS/decisions.md` 的 2026-10-01 T-0843 條目。

1. **存完問一次（AC-HR-07）**：存下心率後，只看後端 `PUT /user` 回應的 `heart_rate.changed`；為真才跳選單，選項由上到下是「最近 14 天／最近 30 天／最近 60 天／不重算」，「不重算」是一顆看得見的一般按鈕（不用 cancel 角色——iPhone 的 confirmationDialog 會把 cancel 藏起來），選了只存心率、不開工作；說明寫「更早的課維持原值」。
   驗法：`test_promptListsTheThreeRangesThenAVisibleSkipChoice`、`test_choosingTheSkipChoiceSavesOnlyAndStartsNothing`。值沒變就照舊收頁。App 不自己比存前存後。onboarding 的心率步驟不走這一頁，不問。
   驗法：後端回 `changed: true` 出現選單；回 `false` 或沒有 `heart_rate` 區塊不出現（`HeartRateRecomputeRepositoryTests`、`App2HeartRateRecomputeViewModelTests::test_promptOnlyWhenBackendSaysChanged`）。
2. **進度與結果（AC-HR-08）**：選了範圍就 `POST /user/heart-rate/recompute`，之後輪詢 `GET` 到結束；顯示進度條與後端 `message`（排隊中／重算中 n/N／能力值更新中／完成：重算 x、跳過 y、失敗 z、失敗）。後端只有在 series refresh 寫完並讀回能力基準確認後才回完成；失敗顯示「重試」；進行中選單按鈕停用，後端回 409 就接上進行中的那一個，不開第二個。「這段時間沒有可重算的課」直接顯示後端那句，不輪詢。API 失敗照實顯示，不拼假資料。
   驗法：`test_queuedJobIsPolledToCompletion…`、`test_failedJobIsShownAsFailedAndCanBeRetried`、`test_alreadyRunningAdopts…`、`test_cannotStartWhileAJobIsActive`。
3. **存永遠先成功、頁面有重算入口（AC-HR-09）**：選不重算、關掉或失敗，新心率照樣生效；頁面另有「用目前的心率重算過去的跑力」，走同一組選項。進頁時若後端有進行中的工作就接上，跑完很久的舊結果不顯示。
4. **完成後各處同一個新值（AC-HR-10）**：只有「完成」才發既有的 `.dataChanged(.vdot)`／`.dataChanged(.workouts)` 快取失效事件；VDOTManager 會重抓，首頁、能力基準／指標詳情、完賽預估與訓練紀錄會各自重抓。若首頁或訓練紀錄原本就在刷新，完成事件不能被略過；原請求回來後要再抓一次，且事件前開始的舊回應不得覆蓋新列或寫回快照。失敗不發事件；已產生的課表與回顧 App 不動。
   驗法：能力基準頁在空 VDOT 歷史時仍以首頁值和 30 天前基準算出一致的比較；完成事件在首頁請求飛行中抵達時，放行舊請求後再抓新列與完賽預估；紀錄頁首載與刷新期間收到完成事件時皆保留新 VDOT（`test_capabilityVM_compareUsesSeriesPointThirtyDaysBeforeAsof`、`test_homeVM_vdotCompletionDuringActiveRefreshRunsFollowupAndPublishesFreshRowsAndEstimates`、`test_completionDuringFirstLoadStartsFreshRecordsRead`、`test_completionRefreshWinsWhenOlderRecordsRequestReturnsLast`）。
5. **自動更新最大心率開關（AC-HR-11）**：一個開關，切換即 `PUT /user {auto_update_max_hr}`，不出現重算選單；失敗回滾並顯示錯誤。顯示 `auto_update_max_hr == true`（沒設過顯示為關；後端沒設過就是關，2026-09-29 裁決）。
6. **手錶偏差提醒（AC-HR-12、13）**：進頁 `GET /user/heart-rate/watch-check`，有 `reminder` 才顯示「你的手錶最大心率是 X，和設定的 Y 差了 Z%，要不要更新？」，按鈕把最大心率改成手錶值並走一般儲存（於是同樣進第 1 條）；沒有就什麼都不顯示，讀不到也不顯示。Apple Watch／無 Garmin 資料的使用者後端不會回提醒。
   提醒旁多一個「先不用」：按下呼叫 `POST /user/heart-rate/watch-check/dismiss`，後端記下後兩週內不再出現、兩週後偏差還在就再提醒一次（HZ-INV-19）。呼叫失敗卡片留著，不假裝已忽略。
   驗法：`test_dismissHidesTheReminderAtOnceAndTellsTheBackend`、`test_dismissFailureKeepsTheReminderSoItComesBackHonestly`、`test_dismissPostsToTheDismissPath`。
7. **手錶自動更新後的說明與重算入口（HZ-INV-18）**：`watch-check` 回 `auto_update` 時，設定頁多一張卡寫「手錶於 YYYY-MM-DD 自動更新為 193」（日期是後端依使用者時區算好的，App 原樣顯示），卡片裡有「用目前的心率重算過去的跑力」按鈕，開的是第 1 條同一個 14／30／60 天選單與第 2 條同一套進度，不另做一套。自動更新本身不會重算，也不跳選單。使用者自己改過最大心率後後端不再回 `auto_update`，卡片消失。
   驗法：`test_autoUpdateNoteIsLoadedAndKeptApartFromTheReminder`、`test_watchCheckDecodesReminderAndAutoUpdateNote`。
8. **最大心率的來源文字（root AC-HR-15、HZ-INV-02）**：來源小字放在各自數字卡「內」、數字下方（不是兩張卡之間），最大心率卡依 `GET /user` 的 `max_hr_source`：`user_set`「你在 Paceriz 設定」、`watch`「手錶自動設定」、`observed`「由跑步紀錄推算」、只有後端明確回 `system_default` 才顯示「系統預設」（en：Set by you in Paceriz／Set automatically by your watch／Estimated from your runs／System default；ja：Paceriz で設定／時計が自動設定／ランニング記録から推定／システム既定）。最大心率沒有這個欄位或值不認得時顯示「未記錄來源」，不猜成系統預設、不 crash，也不回寫舊資料。安靜心率卡同樣在數字下方顯示 `relaxing_hr_source`；後端沒送或不認得這欄就顯示「未記錄來源」。
   驗法：`test_sourceParsesTheFourValuesAndTreatsMissingOrUnknownAsUnrecorded`、`test_userProfileDecodesMissingMaxHrSourceAsUnrecorded`、`test_userProfileDecodesRelaxingHrSourceOnlyWhenTheBackendSendsIt`。

## 還沒做
- Rizo／能力基準「你改了心率所以數字變了」那一句：後端文案已備，iOS 尚未渲染。
