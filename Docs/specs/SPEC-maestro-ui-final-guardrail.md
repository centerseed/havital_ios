---
doc_id: SPEC-maestro-ui-final-guardrail
title: 功能規格：Maestro UI 最後防線測試
type: SPEC
ontology_entity: 訓練計畫系統
status: approved
version: "1.0"
date: 2026-04-10
supersedes: null
---

# Feature Spec: Maestro UI 最後防線測試

## 背景與動機

Havital 目前同時存在三種測試來源：

- 後端 / domain 測試：驗證方法論規則、schema、資料約束
- 原生 iOS XCTest / E2E：驗證 app flow、mapper、view model 與部分 API 整合
- Maestro UI 測試：從使用者視角操作真實畫面

Maestro 不應重複承擔後端已保證的訓練演算法正確性，也不應退化成只驗「畫面有打開」的 smoke test。
它的定位必須是：

- 從真實 UI 驗證 backend/native 測試漏掉的風險
- 驗證使用者最終看到的課表，是否仍像專業教練會接受的課表
- 驗證 app 沒有把正確資料在畫面層綁錯、排錯、翻錯、渲染壞

本文件定義 Maestro 測試的目標、範圍、矩陣與最低驗收標準。

## 目標

### P0

- 將 Maestro 定位為訓練計畫 UI 的最後防線
- 明確定義 Maestro 必測的 UI-only 風險
- 建立可執行的測試矩陣，覆蓋關鍵方法論與邊界組合
- 將「教練合理性」檢查納入 UI 驗證，而不是只檢查文字存在

### P1

- 建立共享 subflow / helper 規格，避免各 flow 各自寫一套
- 讓多語系下的訓練計畫核心體驗也可驗證

## 非目標

- 不用 Maestro 重新驗證完整方法論公式
- 不要求 Maestro 取代後端 unit/domain tests
- 不要求 Maestro 覆蓋所有手勢型互動
- 不把系統層 out-of-process UI 視為 P0 自動化範圍

## 測試定位

### 後端 / domain 測試負責

- 方法論 hard rules
- 訓練型態生成規則
- 配速公式與負荷分布公式
- schema、解碼、mapper 正確性

### 原生 XCTest / E2E 負責

- 特定頁面流程
- 參數化矩陣
- view model / repository / API 整合行為

### Maestro 負責

- 真實 UI 分支是否走對
- 使用者輸入是否被正確呈現與保存
- Overview 與 Weekly Plan 是否一致
- 每日卡片是否被正確渲染
- 多語系下關鍵訓練資訊是否仍可辨識
- 從教練視角看是否「明顯不合理」

## UI-Only 風險模型

Maestro 必須優先捕捉以下風險：

1. Onboarding branch correctness
2. Preference persistence and long-run-day binding
3. Overview-to-weekly data consistency
4. Weekly state transition and cache refresh correctness
5. Workout card rendering integrity
6. Localization parity for training-plan UI
7. Boundary plan shape rendering
8. Coach-sanity presentation checks

## P0 測試類別

### 1. Onboarding Flow Integrity

目的：確認不同 goal type / methodology / stage 的頁面分支正確出現或正確跳過。

最低驗證：

- goal type 選擇頁必須出現
- 應出現的方法論頁必須出現，不應出現的不得被 optional 掩蓋
- training weeks / race setup / start stage 分支必須依目標類型正確進入
- training preference 頁必須成功到達

### 2. Preference Persistence

目的：確認訓練天數、長跑日等使用者輸入真的影響最終 UI。

最低驗證：

- 選定的訓練日數量與實際週課表的跑步日數相符
- 長跑日出現在使用者所選 weekday
- 2-day、3-day、7-day 方案都能正確顯示

### 3. Plan Overview Integrity

目的：確認總覽頁不是只有「標題有出來」，而是關鍵資訊一致。

最低驗證：

- 顯示總週數
- 顯示階段順序與名稱
- 顯示目標 / 方法論對應文案
- Overview 與 Weekly Plan 的 methodology、week count、current phase 不互相矛盾

### 4. Weekly Plan Rendering Integrity

目的：確認第一週與重生後週課表的真實呈現正確。

最低驗證：

- 7 天完整可見
- 有休息日
- 每日卡片展開後資訊完整
- workout label 沒有被渲染錯位、截斷或映射錯誤
- refresh / regenerate 後不殘留舊資料

### 5. Coach-Sanity UI Checks

目的：從使用者看到的畫面判斷，課表是否仍像專業教練會接受的版本。

最低驗證：

- LSD 距離通常大於平日 easy run
- 長間歇配速慢於短間歇配速
- recovery pace 慢於主課 rep pace
- warmup / main / cooldown 結構順序正確
- 高強度日之間至少隔一天 easy/rest
- recovery / easy day 不得比主課更重
- 週總跑量與每日距離加總不得明顯矛盾

### 6. Localization Parity

目的：避免訓練計畫在英文 / 日文下僅能切語言，卻失去可用性。

最低驗證：

- 主要訓練頁 title 正確切換
- workout card 關鍵訓練類型仍可辨識
- plan overview / profile / settings 核心入口仍可互動
- 多語系下 methodology-specific 驗證不能只依賴繁中文字串

## 測試矩陣

### Layer A: Smoke Gate

每次 PR 必跑。

| Case | 目標 | 方法論 | 形狀 | 目的 |
|------|------|--------|------|------|
| A1 | race_run | paceriz | 預設 | 基準 happy path |
| A2 | beginner | default | 預設 | 非賽事分支 |
| A3 | maintenance | aerobic_endurance | 預設 | maintenance 分支 |
| A4 | settings/profile | n/a | n/a | 基本設定頁存活 |

### Layer B: Boundary UI Matrix

每日或 release 前必跑。

| Case | 目標 | 方法論 | 邊界 | UI 風險 |
|------|------|--------|------|--------|
| B1 | race_run | paceriz | 7 training days | 密集課表排序與休息日邏輯 |
| B2 | race_run | paceriz | 2 training days | 稀疏課表與 long-run day 綁定 |
| B3 | beginner | default | 24 weeks / 7 days | 極端長週期 UI 顯示 |
| B4 | maintenance | default | 4 weeks / 2 days | 最小週數與簡化課表 UI |
| B5 | race_run | norwegian | default | threshold 風格呈現 |
| B6 | race_run | polarized | default | zone 2 排除與比例顯示 |
| B7 | race_run | hansons | default | 非傳統 LSD 呈現 |
| B8 | race_run | paceriz | start from build | quality-heavy 起始週 |

### Layer C: Stateful Recovery

release 前必跑。

| Case | Flow | 目的 |
|------|------|------|
| C1 | delete weekly summary -> regenerate | state transition 正確 |
| C2 | delete weekly plan -> regenerate | no-plan -> generated 正確 |
| C3 | reopen app after generation | cache 與 refresh 正確 |
| C4 | navigate overview <-> weekly plan | 資料一致 |

### Layer D: Localization

至少 release 前必跑。

| Case | 語言 | 目的 |
|------|------|------|
| D1 | English | 核心訓練 UI 文字與流程可用 |
| D2 | Japanese | 核心訓練 UI 文字與流程可用 |

## Flow 設計規則

### Rule 1. 不允許用 `optional` 掩蓋核心分支

以下節點不得以「可有可無」方式跳過：

- GoalType page
- Methodology page（當該 target 應出現）
- RaceSetup page（race_run）
- TrainingWeeks page（non-race when required）
- StartStage page（當應出現）
- TrainingPreference page

若流程設計上某頁可能不存在，必須先 assert 前一頁狀態，再明確判定「跳過是合理」。

### Rule 2. 不只驗靜態文字存在

所有方法論 flow 除了檢查 label 存在，也必須檢查至少一個相對關係：

- 距離相對關係
- 配速相對關係
- 週內排序關係
- 結構完整性

### Rule 3. Viewport 驗證要掃完整週

`assertNotVisible` 不得只在頂部 viewport 做結論。
若要驗「本週不存在某類型訓練」，必須先掃完整週卡片後再下判斷。

### Rule 4. 方法論驗證要做 UI mapping 檢查

驗證的不是 backend enum 本身，而是 UI 顯示名稱、卡片類型、細節結構是否合理。

### Rule 5. 多語系 flow 不得只驗 home/profile

i18n flow 必須至少覆蓋一次訓練計畫核心區：

- weekly plan page
- at least one workout card
- overview entry or methodology label

## Coach-Sanity 驗收規則

以下規則屬於 UI 最後防線，若畫面呈現違反，視為 P0 failure：

### Week Structure

- 有長跑日的週，長跑距離不得短於所有 easy run
- 若只有 2 training days，long run 應明顯是較長的那一天
- 高強度日不可連續相鄰
- rest day / easy day 必須存在於高強度週

### Pace Ordering

- short interval pace < long interval pace < tempo / threshold 上限 < easy / LSD
- recovery pace > rep pace
- cool-down pace 不得快於 main set pace
- 顯示出的 pace 不得落在離譜區間

### Workout Card Integrity

- interval 類課表需有 warmup、repetition、recovery、cooldown
- easy / LSD 類課表不得被渲染成 interval 結構
- rest card 不得顯示距離與配速主課資訊

### Weekly Consistency

- 週總跑量要與日課距離總和近似
- current week 的階段語意要和 overview 一致
- regenerate 後不得保留上一份課表的殘影或錯誤 label

## 建議共用 Subflows / Helpers

P0 必須抽出共享能力：

- `assert-onboarding-branch.yaml`
- `assert-preference-persistence.yaml`
- `assert-plan-overview-integrity.yaml`
- `assert-weekly-plan-7days.yaml`
- `assert-workout-card-structure.yaml`
- `assert-coach-sanity-relationships.yaml`
- `assert-weekly-state-transition.yaml`
- `assert-training-plan-i18n.yaml`

## 驗收標準

### PR Gate

- Layer A 全綠
- 新增或修改 onboarding / weekly plan / overview / settings / i18n 相關 UI 時，需補對應 Layer B 或 D

### Release Gate

- Layer A + B + C 全綠
- D 至少 English 與 Japanese 各跑一次
- 任一 P0 coach-sanity 失敗，不可放行

## 實作要求

### P0

- 將現有 README 中的測試承諾對齊實際 flow
- 補齊邊界矩陣中缺失的 2-day / 7-day / min/max week cases
- 將方法論驗證從「文字存在」提升為「完整週掃描 + 相對關係驗證」
- 補一條 overview-to-weekly consistency flow
- 補一條 localized weekly-plan flow

### P1

- 建立 screenshot / artifact 規則，失敗時保留 overview 與 weekly plan 證據
- 將 coach-sanity 檢查下沉為可重用 helper

## 開放問題

- Maestro 是否需要讀取 debug-export JSON 輔助比對 UI 顯示與資料來源
- 某些 pace / distance 細節若目前無 accessibility identifier，是否需先補 UI instrumentation
- 多語系下 workout label 應採文字比對、id 比對、或 hybrid 策略
