---
type: SPEC
id: SPEC-training-hub-and-weekly-plan-lifecycle
status: Approved
layer: product
ontology_entity: training-hub-lifecycle
created: 2026-04-15
updated: 2026-09-07
---

# Feature Spec: 訓練首頁與週課表生命週期

## 背景與動機

`TrainingPlanV2View` 已是主 app 的核心入口，但目前缺少一份產品規格定義不同課表狀態下應顯示什麼、用戶何時可以切週、何時可以產生本週或下週課表，以及哪些入口應由訓練首頁負責提供。

## 相容性

- 週骨架預覽遵循 `SPEC-weekly-preview-ui.md`
- 編輯課表遵循 `SPEC-training-v2-edit-schedule-screen.md`
- 付費牆與閘門規則遵循 IAP / Subscription 相關 spec

## 需求

### AC-TRAIN-HUB-01: 訓練首頁必須依 plan 狀態顯示對應主內容

Given 使用者進入訓練首頁，  
When `planStatus` 為 `ready`、`noWeeklyPlan`、`needsWeeklySummary`、`noPlan`、`completed`、`loading` 或 `error`，  
Then 系統必須顯示對應的單一主狀態畫面，不得同時混出多種主流程 CTA。

### AC-TRAIN-HUB-02: `ready` 狀態必須呈現本週執行所需的三個核心區塊

Given `planStatus == ready`，  
When 畫面載入完成，  
Then 系統必須顯示訓練進度、週總覽、週時間軸三個區塊，作為本週訓練的主要工作台。

### AC-TRAIN-HUB-03: 缺本週課表或缺上週摘要時必須提供正確 CTA

Given 使用者尚無本週課表或尚未完成產生上週摘要的前置條件，  
When 進入訓練首頁，  
Then 系統必須顯示對應的產生 CTA，且 CTA 只能觸發當前狀態所需的下一步。

### AC-TRAIN-HUB-04: 使用者切換歷史週次後必須可一鍵回到本週

Given 使用者正在查看非本週的週次，  
When 畫面底部顯示回到本週入口，  
Then 點擊後必須切回目前週次，且本週成為重新整理與後續操作的預設上下文。

### AC-TRAIN-HUB-05: 訓練首頁必須支援 refresh 與 retry

Given 使用者下拉刷新或從錯誤畫面點擊 retry，  
When 重新載入流程開始，  
Then 系統必須嘗試刷新最新課表狀態，並以同一套狀態機結果更新頁面。

### AC-TRAIN-HUB-06: 只有在條件滿足時才可產生下週課表

Given 使用者位於本週且 `nextWeekInfo.canGenerate == true` 且 `hasPlan == false`，  
When 訓練首頁評估下週 CTA，  
Then 系統才可顯示產生下週課表按鈕；不符合條件時不得顯示誤導性入口。

### AC-TRAIN-HUB-09: 週回顧頁必須提供前進「規劃下週」的 CTA（2026-08-31 使用者裁決）

Given 使用者位於週回顧（回顧本週）頁，  
When 捲到頁面底部，  
Then 系統必須顯示「下一步：規劃下週」CTA，點擊進入規劃下週分頁。

### AC-TRAIN-HUB-10: 規劃下週頁必須能實際產生下週課表（2026-08-31 使用者裁決，P0）

Given 使用者位於規劃下週分頁，  
When footer 依後端 `next_action`、`current_week_plan_id`、`next_week_info` 以純函式 `nextWeekAction` 三態分流（可產生／只能套用建議／不顯示），  
Then 「可產生」態必須提供產生課表 CTA，點擊後**先送採納（apply-items）再呼 `POST /v2/plan/weekly`**（順序不可反）；下週已有課表時 CTA 不得顯示。同一條判準同時涵蓋週日流程（目標＝下週）與平日流程（目標＝本週）。無建議項不得成為零出口（footer 不得被 `!suggestions.isEmpty` 之類條件整體隱藏）。

And Then 週日流程（這一頁回顧的目標週就是本週）**不得一開頁就把回顧產出來**，要停在「還沒產生」的空態，
由使用者按「產生回顧」，先跳一個確認框問「本週訓練是否皆已完成」，按確認才產、按取消什麼都不做
（T-0409，2026-09-03 使用者裁決）。平日流程回顧的是已經過完的上一週，維持開頁就產、沒有確認框。
文案沿用 1.x 既有的 `training.confirm_training_completed_title`／`_message` 與 `common.cancel`／`common.confirm`，
不新開字串。驗法：`App2WeeklyReviewViewModel.autoGeneratesOnLoad` 在目標週＝本週時為 false（開頁不送生成請求），
`App2WeeklyReviewView.needsCompletionConfirm(isCurrentWeek:isReadOnly:)` 只有「本週且非唯讀」為真。

### AC-TRAIN-HUB-12: 規劃下週分頁必須走 decision-chain 的逐條清單：run → 逐條表態 → 產生（2026-09-02 使用者裁決）

Given 使用者位於規劃下週分頁且 `nextWeekAction == .generate(week)`（歷史週／唯讀／`applyOnly`／`none` 態不適用），
When 分頁載入，
Then 系統必須呼叫 `POST /v2/decision-chain/week/{as_of}/run?week_of_training={week}`（`as_of` ＝ 使用者當地今天；時區權威是 `/v2/plan/status` 的 `metadata.user_timezone`，不看裝置時區），與 `/v2/summary/weekly` 生成並行，期間規劃分頁顯示生成中區塊（AC-TRAIN-HUB-11 同形態）；`generated` 與 `already_exists` 皆視為成功。
And Then 成功後必須讀 `GET /v2/decision-chain/week/{as_of}/checklist`，把 `items[]` 畫成一張清單，每條顯示後端翻好的 `title` 與 `reason`（app 不重組也不解讀旋鈕），並提供**逐條**三個動作：接受（`accepted`）、不要（`declined`）、調整（`adjusted`）。「調整」只在該條的 `proposed` 是數值時提供，值由既有輪盤 sheet 選；離散代號（如 `rest_ratio`、`recovery_kind`）只有接受／不要。點下去即送 `POST /v2/decision-chain/week/{as_of}/checklist/{item_id}`，UI 以回應的 `item.status` 為準；送不出去時該條必須退回原狀並提示，不得靜默當成已接受。沒點的條目維持 `proposed` ＝不生效。`items[]` 為空是合法狀態，不得當成失敗。
And Then 清單一條的 `current`／`proposed`／`adjusted_value` 可以是數、字串、布林或陣列（例如 Rizo 記下「下週三不跑」那一條的 `proposed` 是 `[3]`，休息週提案那一條是 `current: false`／`proposed: true`）；app 一律照原樣收、照原樣送回去，**不解讀內容**，認不得的形狀不得讓整張清單消失。非數值的條目不提供「調整」。
And Then 清單頂端必須顯示 `GET /v2/decision-chain/intent/active` 的**唯讀說明**：`expression.pursuing`、`expression.rationale`；`expression.maintaining`／`abandoning` 非 null 才顯示該列；其後列 `hypotheses[]` 的 `intervention.description`／`prediction.description`。`data == null` 時不畫說明區。**這一區沒有任何動作按鈕**——接受與否只在清單上逐條做，app 不呼 `POST .../intent/{revision}/confirm`（意圖 lifecycle 由清單推導）。
And Then 同一分頁**不得並列 apply-items 建議清單**；走 decision-chain 時產生課表 CTA 直接呼 `POST /v2/plan/weekly`，**不呼 apply-items**，且不得因清單還沒答完而停用。
And Then 分頁的 Rizo 討論入口維持既有 `weekly_situation` 情境；Rizo 回覆結束後必須重讀 checklist（Rizo 記下的修正會以清單上新的一條回來）。**討論入口在清單上方**，而 **Rizo 記下的那幾條（`source == "rizo"`）自成一組、緊接在討論框下方，並標示來源「Rizo 提出」**，與意圖旋鈕那一組分開（2026-09-05 使用者裁決）——混在同一張清單裡，使用者答「要／不要」時分不出這一條是系統提的還是自己剛剛講的。兩組加起來必須等於整張清單：認不得的 `source` 落在意圖那一組，不得整條消失。
驗法：`HavitalTests/Features/App2/App2PlanningWeekGroupingTests.swift`。
And Then `run` 的 client 逾時必須容得下真 LLM 的一次生成（dev 實測 43.7s，量到的範圍 45–130s）：這一支單獨用 180 秒，不沿用其他端點的共用 60 秒——60 秒會把一次**正常的** run 判成逾時，使用者看到的是「決策鏈壞了」，其實只是還沒算完。
And Given `run` 回 4xx／5xx／逾時，或 `GET .../checklist` 讀不到（404 或其他錯誤），
Then 分頁必須回到 AC-TRAIN-HUB-10 的既有內容與路徑（apply-items → `POST /v2/plan/weekly`），不得擋產生（fail-open）。
And 付費閘門與 Rizo 配額判準同 AC-PAYWALL-26：擋生成的條件同樣擋 `run`。

And Then 這條路徑有**兩個入口**，走的是同一頁：首頁的週回顧入口，以及課表頁未產生態的主鈕
（`App2PlanView` 的 `App2_PlanGenerateWeek`／`App2_PlanCompleteReviewFirst`）。課表頁那顆鈕**不自己產生課表**
（2026-09-03 使用者裁決，T-0405）：按下去打開第 `current_week − 1` 週的週回顧（非唯讀），
`next_action == create_summary` 時停在回顧分頁（先把缺的回顧做出來），其餘未產生態直接停在規劃分頁走這一條清單。
`current_week == 1` 時沒有上一週可回顧，回顧週落在 0、規劃分頁規劃第 1 週，同樣不得退回直接產生。
產生的唯一出口是規劃分頁的產生 CTA。

And Then 週次的相對詞按使用者當地的星期定：**週一到週六，週回顧看的是上一週、週課表是當週**
（所以規劃分頁規劃的是當週）；**週日產生的是這一週的週回顧與下一週的課表**。這是既有
`nextWeekAction`／`isGenerationWindowOpen` 判準的白話版，不是新規則。

**未決（2026-09-03）**：「調整」輪盤的可選值域沒有規格來源——`checklist` 的一條只帶 `current`／`proposed`，
不帶那顆旋鈕的合法範圍，後端在這條路徑上也不驗值域（`cloud/api_service/domains/decision_chain/checklist.py:62`
`check_status_value` 只驗「`adjusted` 有沒有帶值」）。目前 app 用一條**與欄位無關**的規則從該條自己的兩個數
推出範圍（`App2DecisionChainAdjustRange`），屬暫定；正解是後端把值域放進清單條目，或使用者裁一組值域。

行為契約與端點形狀：root `docs/designs/DESIGN-app2-decision-chain-api.md` §4.1／§4.1b；裁決：root `STATUS/decisions.md` 2026-09-02「三條基本能力」。

### AC-TRAIN-HUB-13: 首頁 Rizo 對話 sheet 必須帶回當天那一段對話，並提供新對話與歷史入口（2026-09-05 使用者裁決）

Given 使用者在 2.0 首頁點任一個 Rizo 入口開對話 sheet，
When sheet 出現，
Then 系統必須先讀 `GET /v2/agent/history`，取最新的一個 session；**該 session 的第一輪發生在使用者當地的今天**時，把那一段對話畫回來並沿用它的 `session_id` 續聊（不重送任何舊訊息，因此不重複扣額度、不重跑任何動作）。不是今天、讀不到歷史、或沒有可畫的輪次時，開空白對話並用本機組好的開場白起頭。
（今日卡的產生時間目前不在 `/v2/state/today` 的回應裡；「同一個使用者當地日」是本條採用的判準——跨日即是新的一天、新的今日卡。）
And Then sheet 頂部必須有「新對話」與「歷史」兩個入口（a11y id `App2_RizoNewChat`、`App2_RizoHistory`）。「新對話」清空對話並忘掉 `session_id`，下一句開新的 session；「歷史」開既有的 Rizo 歷史清單，從某一輪續聊走既有的 fork。
And Then sheet **不得顯示寫死的追問 chips**：那三句每一輪回覆後都出現、與剛講的內容無關（2026-09-05 使用者裁決直接拿掉）。
And Then 還原**只沿用那一段的 `session_id`，不接管這個入口的 scenario**：`GET /v2/agent/history` 不分 scenario 回全部輪次，最新那一段可能來自週回顧；sheet 的 scenario 仍是入口自己的（`card.rizoScenario`）。
And Then **已經用完後端每-session 輪數預算的那一段不還原**，改開新的一段。後端對今日卡情境有 20 輪的軟上限（`cloud/api_service/application/rizo.py` 的 `_SESSION_SOFT_CAP`），到了上限只會回罐頭收尾、不進教練模型；本條之前 sheet 每次開都是新 session，這個上限碰不到，帶回當日 session 之後同一天共用同一份預算——不擋掉用完的那一段，使用者一開 sheet 就卡在收尾語。輪數的 SSOT 在後端，app 端的門檻是保守下界。
And Then 還原沿用同一個 `session_id`，**因此不另扣免費教練額度**——那份額度是月配額、以 `session_id` 去重（`cloud/api_service/core/policies/rizo_quota.py` 的 `DEFAULT_RIZO_FREE_COACH_LIMIT`），所以同一天的多次開啟只扣一次；按「新對話」開新 session ＝扣一次。免費月上限因此是「有聊天的日子」而不是「對話段數」；模型呼叫的月上限不變（每段仍受 20 輪軟上限）。訂閱者不受額度影響。裁決與代價：`STATUS/decisions.md` 2026-09-06「T-0434 免費額度口徑」。
驗法：`HavitalTests/Features/Rizo/RizoSheetSessionRestoreTests.swift`。

### AC-TRAIN-HUB-11: 週回顧生成期間必須顯示生成中動畫與文案（2026-08-31 使用者裁決）

Given 使用者在週回顧頁觸發生成、內容尚未回來，
When 該頁還沒有可顯示的 `WeeklySummaryV2`（畫面處於載入／生成中），
Then 系統必須在該頁的內容區顯示**生成中動畫＋輪播文案**（沿用 1.4 生成動畫的跑鞋彈跳、
輪播文案與進度條語彙，文案取既有的 `training.loading.analyzing_training_data`／
`evaluating_progress`／`preparing_review` 三語字串），不得只顯示通用 spinner。
形態不要求恢復 1.4 的全螢幕蓋版；2.0 的等待態屬於該頁自己。生成失敗態不在本條範圍。
iOS 與 Android 形態與文案一致。

### AC-TRAIN-HUB-07: 工具列與選單入口必須反映目前狀態

Given 使用者位於訓練首頁，  
When 打開工具列或右上角選單，  
Then 系統必須提供計畫概覽、個人資料、週摘要、切換週數等入口；編輯週課表僅在 `ready` 狀態可見。

### AC-TRAIN-HUB-08: 訓練完成後必須提供重新設定目標入口

Given 訓練計畫已完成，  
When 使用者進入訓練首頁，  
Then 系統必須顯示完成狀態與重新設定目標的入口，並把該入口導向 re-onboarding。

### AC-TRAIN-HUB-14: 下週課表已產生時，課表頁必須能往前翻到那一週（2026-09-06 prod 缺陷）

Given 後端的 plan status 回 `next_week_info.has_plan == true`（下週課表已經產生），
When 使用者在課表頁看本週，
Then 週次切換器的右箭頭必須可按，按下去顯示第 `current_week + 1` 週的週次標與日卡
（走既有的 `GET /v2/plan/weekly/{overview_id}_{week}`，不新開端點）；在那一週按左箭頭回到本週，右箭頭停用。
And Then 產生下週課表成功之後，課表頁必須重讀 plan status，右箭頭立刻可按，不必等冷啟。
And Then `next_week_info` 缺席或 `has_plan == false` 時，右箭頭維持停用。

週日是這條的實際場景：週日在使用者時區仍屬第 N 週，`current_week` 還是 N，
但週回顧產出的是第 N+1 週；上限若只認當週，剛產好的那一週整個週日都看不到
（2026-09-06 創辦人帳號 `f30fed2f03ab_11`）。
**那一週目前唯讀**——編輯入口（`App2PlanEditGate`）沒有週次參數，開在下週會改到當週那一份。

驗法：`HavitalTests/Features/App2/App2PlanNextWeekBrowsingTests.swift`。

### AC-TRAIN-HUB-15: 週日回顧已產生但下週課表未產時，首頁必須保留回顧入口（2026-09-06 prod P0）

Given 使用者當地是週日、本週回顧已經產生（`summary` 存在），且 `next_week_info.has_plan == false`（等價地 `can_generate == true`），
When 首頁評估週回顧時機卡，
Then 卡必須留著，狀態是「查看回顧」（`App2WeekReviewState.available`，目標週＝`current_week`）；
點進去到週回顧頁，該頁的「規劃下週」分頁必須能走到產生下週課表（判準同 AC-TRAIN-HUB-10 的 `nextWeekAction`）。
And Then `next_week_info.has_plan == true`（下週課表已產）時卡照舊收掉，`next_week_info` 缺席（計畫最後一週的週日）也收掉；平日的判準完全不變。

「產生下週課表」的唯一入口住在週回顧頁的規劃分頁，而週日的週回顧入口只有首頁這張卡。
2026-09-01 裁決「回顧已存在就不出卡」的本意是不做第二個入口，但在「回顧產了、下週課表沒產」
（生成失敗或被刪掉重來）這一格，它收掉的是**唯一**的入口：2026-09-06 創辦人實機
（prod，`current_week=10`／`f30fed2f03ab_10`／`next_week_info.has_plan=false`）首頁既看不到回顧也看不到產生下週課表，
使用者原話「只要課表產生失敗，流程就卡死了」。

驗法：`HavitalTests/Features/App2/App2HomeProjectionTests.swift` 的
`test_weekReview_row6b_sundayWithSummaryButNoNextWeekPlanKeepsEntry`、
`test_weekReview_row6b_entryLeadsToWorkingGenerateCTA`、
`test_weekReview_row6_sundayWithSummaryAndNextWeekPlanHidesCard`。

### AC-TRAIN-HUB-16: 訓練完成後課表頁週跑量必須在同一 session 更新

Given 使用者已在課表頁，且系統收到新訓練紀錄已同步／處理完成的 workouts 變更事件，
When App 重新讀取既有 `GET /v2/workouts` 資料成功，
Then 課表頁的實跑週量與完成比例必須在同一個 app session 重新計算並顯示最新值，
不需要關閉重開 app，也不需要使用者手動下拉刷新。
And Then 重新讀取失敗時必須保留目前已顯示的週量，等待下一次既有 refresh／變更事件重試；
實跑週量仍只來自既有 workout repository，不新增第二份快取或另一條資料來源。

驗法：`HavitalTests/Features/App2/App2PlanWorkoutRefreshTests.swift`。

## AC ID Index

本 spec 已採用穩定 AC-ID；以下索引作為派工、review 與測試引用入口。

| AC ID | 對應需求 |
|------|----------|
| AC-TRAIN-HUB-01 | 訓練首頁依 plan 狀態顯示單一主內容 |
| AC-TRAIN-HUB-02 | `ready` 狀態顯示進度 / 週總覽 / 週時間軸 |
| AC-TRAIN-HUB-03 | 缺本週課表或缺摘要時顯示正確 CTA |
| AC-TRAIN-HUB-04 | 切到歷史週後可一鍵回到本週 |
| AC-TRAIN-HUB-05 | 首頁支援 refresh 與 retry |
| AC-TRAIN-HUB-06 | 僅在條件滿足時顯示產生下週課表入口 |
| AC-TRAIN-HUB-07 | 工具列與選單入口反映目前狀態 |
| AC-TRAIN-HUB-08 | 訓練完成後提供 re-onboarding 入口 |
| AC-TRAIN-HUB-09 | 週回顧頁底部提供前進規劃下週的 CTA |
| AC-TRAIN-HUB-10 | 規劃下週頁三態分流並可實際產生下週課表 |
| AC-TRAIN-HUB-11 | 週回顧生成期間顯示生成中動畫與輪播文案 |
| AC-TRAIN-HUB-12 | 規劃下週分頁走 decision-chain：run → 逐條清單表態 → 產生；討論入口在清單上方，Rizo 條目自成一組 |
| AC-TRAIN-HUB-13 | 首頁 Rizo sheet 帶回當天那一段對話，並有新對話／歷史入口，無寫死追問 chips |
| AC-TRAIN-HUB-14 | 下週課表已產生時課表頁可往前翻到那一週；產完即刻可翻 |
| AC-TRAIN-HUB-15 | 週日回顧已產但下週課表未產時，首頁保留回顧入口（通往產生下週課表的唯一路） |
| AC-TRAIN-HUB-16 | 訓練完成事件後課表頁在同一 session 更新實跑週量 |
