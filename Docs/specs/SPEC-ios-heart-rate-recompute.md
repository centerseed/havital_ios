---
doc_id: SPEC-ios-heart-rate-recompute
title: iOS 心率設定頁：改心率後重算、自動更新開關、手錶偏差提醒
type: SPEC
status: Draft
layer: product
date: 2026-09-29
---

# iOS 心率設定頁：重算與提醒

行為與數字的來源是 root `docs/specs/SPEC-heart-rate-and-training-readiness-surfaces.md` 的 AC-HR-07～13，後端規則在
`cloud/api_service/docs/01-specs/decision-chain/0-inputs/raw/SPEC-hr-zones.md` §5.5、§5.7、§5.8。本檔只寫 iOS 2.0 設定頁（`App2HeartRateZoneSettingsView`）看得到的做法，不重講規則。

1. **存完問一次（AC-HR-07）**：存下心率後，只看後端 `PUT /user` 回應的 `heart_rate.changed`；為真才跳選單「不重算／最近 14／30／60 天」，預設「不重算」，說明寫「更早的課維持原值」。值沒變就照舊收頁。App 不自己比存前存後。onboarding 的心率步驟不走這一頁，不問。
   驗法：後端回 `changed: true` 出現選單；回 `false` 或沒有 `heart_rate` 區塊不出現（`HeartRateRecomputeRepositoryTests`、`App2HeartRateRecomputeViewModelTests::test_promptOnlyWhenBackendSaysChanged`）。
2. **進度與結果（AC-HR-08）**：選了範圍就 `POST /user/heart-rate/recompute`，之後輪詢 `GET` 到結束；顯示進度條與後端 `message`（排隊中／重算中 n/N／完成：重算 x、跳過 y、失敗 z、失敗）。失敗顯示「重試」；進行中選單按鈕停用，後端回 409 就接上進行中的那一個，不開第二個。「這段時間沒有可重算的課」直接顯示後端那句，不輪詢。API 失敗照實顯示，不拼假資料。
   驗法：`test_queuedJobIsPolledToCompletion…`、`test_failedJobIsShownAsFailedAndCanBeRetried`、`test_alreadyRunningAdopts…`、`test_cannotStartWhileAJobIsActive`。
3. **存永遠先成功、頁面有重算入口（AC-HR-09）**：選不重算、關掉或失敗，新心率照樣生效；頁面另有「用目前的心率重算過去的跑力」，走同一組選項。進頁時若後端有進行中的工作就接上，跑完很久的舊結果不顯示。
4. **完成後各處同一個新值（AC-HR-10）**：只有「完成」才發既有的 `.dataChanged(.vdot)`／`.dataChanged(.workouts)` 快取失效事件（指標詳情快取與首頁已訂閱）；失敗不發。已產生的課表與回顧 App 不動。
5. **自動更新最大心率開關（AC-HR-11）**：一個開關，切換即 `PUT /user {auto_update_max_hr}`，不出現重算選單；失敗回滾並顯示錯誤。顯示 `auto_update_max_hr == true`（沒設過顯示為關）。
6. **手錶偏差提醒（AC-HR-12、13）**：進頁 `GET /user/heart-rate/watch-check`，有 `reminder` 才顯示「你的手錶最大心率是 X，和設定的 Y 差了 Z%，要不要更新？」，按鈕把最大心率改成手錶值並走一般儲存（於是同樣進第 1 條）；沒有就什麼都不顯示，讀不到也不顯示。Apple Watch／無 Garmin 資料的使用者後端不會回提醒。

## 還沒做
- 模擬器手動走查沒做（`iPhone 17 Pro` 是使用者登入中的機器，不能跑測試或清狀態）；UI 只有編譯與 ViewModel／Repository 單元測試證據。
- Rizo／能力中心「你改了心率所以數字變了」那一句：後端文案已備，iOS 尚未渲染。
