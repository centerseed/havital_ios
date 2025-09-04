# 國際化代辦事項 (Internationalization TODO)

## 概述
此文件列出所有需要進行國際化處理的 View 組件，按優先級排序。

## 優先級分類

### 🔴 高優先級 - 核心 UI 組件
這些組件在整個應用程式中被廣泛使用，優先處理：

#### Components/
- [x] **CircularProgressView.swift** - "週" ✅ 完成
- [x] **WorkoutRowView.swift** - "今天", "已同步", "未同步", "距離", "時間", "卡路里" ✅ 完成
- [x] **TargetRaceCard.swift** - "目標完賽時間", "目標配速" ✅ 完成
- [x] **TrainingStageCard.swift** - "第X-X週", "第X週開始", "重點訓練:" ✅ 完成
- [x] **LapAnalysisView.swift** - "圈速分析", "無圈速數據", "圈", "距離", "時間", "配速", "心率" ✅ 完成
- [x] **AppLoadingView.swift** - "應用程式初始化失敗", "請確認網路連線正常，然後重新嘗試", "重新啟動" ✅ 完成
- [x] **SupportingRacesCard.swift** - "暫無支援賽事", "之前的賽事", "剩餘 X 天" ✅ 完成
- [x] **GarminReconnectionAlert.swift** - "重新綁定 Garmin", "稍後提醒" ✅ 完成
- [x] **ClickableCircularProgressView.swift** - "週" ✅ 完成

### 🟡 中優先級 - 用戶認證與設定
用戶初次使用時會接觸到的功能：

#### 認證相關
- [x] **RegisterEmailView.swift** - "註冊", "註冊帳號", "註冊失敗", "註冊成功", "驗證提示訊息" ✅ 完成
- [x] **VerifyEmailView.swift** - "驗證 Email", "驗證碼", "驗證失敗", "驗證成功" ✅ 完成
- [x] **CalendarSyncSetupView.swift** - "將訓練日同步到你的行事曆，幫助你更好地安排時間", "全天活動", "指定時間", "訓練時間", "開始時間", "結束時間", "你可以之後在行事曆中調整時間", "同步至行事曆" ✅ 完成

### 🟢 中低優先級 - 編輯功能
用戶主動使用的編輯功能：

#### EditView/
- [x] **EditTargetView.swift** - "賽事資訊", "距離比賽還有 X 週", "比賽距離", "目標完賽時間", "時", "分", "平均配速：X /公里", "編輯賽事目標" ✅ 完成
- [x] **AddSupportingTargetView.swift** - "賽事資訊", "比賽距離", "目標完賽時間", "時", "分", "平均配速：X /公里", "添加支援賽事" ✅ 完成
- [x] **EditSupportingTargetView.swift** - "賽事資訊", "比賽距離", "目標完賽時間", "時", "分", "平均配速：X /公里", "確定要刪除這個支援賽事嗎？此操作無法復原", "編輯支援賽事" ✅ 完成
- [x] **WeeklyDistanceEditorView.swift** - "週跑量：X 公里", "當週跑量的修改會在下一週的課表生效", "編輯週跑量" ✅ 完成

### 🔵 中低優先級 - 訓練與分析功能
訓練計劃相關的功能組件：

#### Training/
- [x] **TrainingPlanView.swift** - "訓練週期已完成", "恭喜您完成這個訓練週期！", "課表載入中..." ✅ 完成
- [ ] **TrainingProgressView.swift** - "回顧", "課表", "產生課表"
- [x] **TrainingPlanOverviewView.swift** - "訓練計劃總覽", "目標評估", "訓練方法", "訓練階段", "產生第X週訓練計劃" ✅ 完成
- [x] **TrainingItemDetailView.swift** - "無法找到該運動項目的說明" ✅ 完成
- [x] **NextWeekPlanningView.swift** - "本週訓練感受（0-最差，5-最佳）", "整體感受：", "對於下週的訓練期望，Vita會依據實際情況做出調整，也可以自由的編輯新產生的運動計畫", "難度調整", "運動天數調整", "運動項目變化調整", "開始產生下次計劃", "請稍候", "下週計劃設定" ✅ 完成
- [x] **WeeklySummaryView.swift** - "訓練完成度", "訓練分析" ✅ 完成
- [x] **WorkoutSummaryRow.swift** - "心率計算中..." ✅ 完成

#### Training/Components/
- [x] **WeekSelectorSheet.swift** - "第 X 週", "回顧", "課表", "關閉" ✅ 完成
- [x] **PaceChartView.swift** - "配速變化", "請稍後再試", "無法獲取此次訓練的配速數據", "最快:", "最慢:" ✅ 完成
- [x] **HeartRateChartView.swift** - "心率變化", "請稍後再試", "無法獲取此次訓練的心率數據" ✅ 完成
- [x] **GaitAnalysisChartView.swift** - "步態分析", "請稍後再試", "無法獲取此次訓練的步態分析數據" ✅ 完成

### 🟣 低優先級 - 健康數據與圖表
專業運動員或進階用戶使用的功能：

#### Health/
- [ ] **SleepHeartRateChartView.swift** - "睡眠靜息心率"
- [ ] **HeartRateZoneInfoView.swift** - "最大心率", "靜息心率"
- [ ] **HRVTrendChartView.swift** - "心率變異性 (HRV) 趨勢"
- [ ] **PerformanceChartView.swift** - "沒有足夠的訓練資料", "近三個月訓練表現", "訓練日"


## 實施計劃

### 階段 1: 核心組件 (預估時間: 2-3小時)
優先處理 Components/ 下的核心 UI 組件，這些組件影響最廣泛。

### 階段 2: 用戶認證 (預估時間: 1小時)  
處理用戶初次使用時接觸的認證相關頁面。

### 階段 3: 編輯功能 (預估時間: 1.5小時)
處理各種編輯功能的國際化。

### 階段 4: 訓練功能 (預估時間: 2-3小時)
處理訓練計劃相關的複雜功能組件。

### 階段 5: 健康數據 (預估時間: 1小時)
處理健康數據和圖表相關組件。

### 階段 6: 調試功能 (可選)
根據需要處理調試相關功能。

## 注意事項
- 每個組件處理完成後，在對應項目前標記 ✅
- 添加新的 localization keys 到 LocalizationKeys.swift
- 更新所有三種語言的 .strings 文件 (en, ja, zh-Hant)
- 測試確保沒有編譯錯誤
- 確保目標賽事提示：英文用 Boston Marathon，日文用東京マラソン，中文用台北馬拉松

## 進度追蹤
- 開始日期: 2025-01-21
- 預計完成日期: TBD
- 當前階段: 階段 4 - 訓練功能 ✅ 完成
- 完成進度: 21/總計約60個組件

### 已完成的組件 (2025-01-21 至 2025-01-22)
#### 階段 1: 核心組件 (9/9 完成)
1. ✅ **WorkoutRowView.swift** - 國際化 6 個字符串 (今天, 已同步, 未同步, 距離, 時間, 卡路里)
2. ✅ **CircularProgressView.swift** - 國際化 1 個字符串 (週)
3. ✅ **TargetRaceCard.swift** - 國際化 3 個字符串 (目標完賽時間, 目標配速, /公里)
4. ✅ **TrainingStageCard.swift** - 國際化 4 個字符串 (第X-X週, 第X週開始, 重點訓練:)
5. ✅ **LapAnalysisView.swift** - 國際化 7 個字符串 (圈速分析, 無圈速數據, 圈, 距離, 時間, 配速, 心率)
6. ✅ **AppLoadingView.swift** - 國際化 3 個字符串 (應用程式初始化失敗, 請確認網路連線正常，然後重新嘗試, 重新啟動)
7. ✅ **SupportingRacesCard.swift** - 國際化 3 個字符串 (暫無支援賽事, 之前的賽事, 剩餘 X 天)
8. ✅ **GarminReconnectionAlert.swift** - 國際化 2 個字符串 (重新綁定 Garmin, 稍後提醒)
9. ✅ **ClickableCircularProgressView.swift** - 國際化 1 個字符串 (週)

#### 階段 2: 用戶認證與設定 (3/3 完成)
10. ✅ **RegisterEmailView.swift** - 國際化 8 個字符串 (註冊, 註冊帳號, 註冊失敗, 註冊成功, 驗證提示訊息等)
11. ✅ **VerifyEmailView.swift** - 國際化 6 個字符串 (驗證 Email, 驗證碼, 驗證失敗, 驗證成功等)
12. ✅ **CalendarSyncSetupView.swift** - 國際化 8 個字符串 (訓練日同步說明, 全天活動, 指定時間等)

#### 階段 3: 編輯功能 (4/4 完成)
13. ✅ **EditTargetView.swift** - 國際化 9 個字符串 (賽事資訊, 距離比賽還有 X 週, 比賽距離等)
14. ✅ **AddSupportingTargetView.swift** - 國際化 8 個字符串 (賽事資訊, 比賽距離, 目標完賽時間等)
15. ✅ **EditSupportingTargetView.swift** - 國際化 9 個字符串 (賽事資訊, 確定要刪除這個支援賽事嗎？等)
16. ✅ **WeeklyDistanceEditorView.swift** - 國際化 3 個字符串 (週跑量, 當週跑量的修改會在下一週的課表生效等)

#### 階段 4: 訓練與分析功能 (5/5 完成)
17. ✅ **TrainingPlanView.swift** - 國際化 3 個字符串 (訓練週期已完成, 恭喜您完成這個訓練週期！, 課表載入中...)
18. ✅ **TrainingPlanOverviewView.swift** - 國際化 10 個字符串 (訓練計劃總覽, 目標評估, 訓練方法等)
19. ✅ **TrainingItemDetailView.swift** - 國際化 4 個字符串 (目的, 效果, 實行方式, 注意事項)
20. ✅ **NextWeekPlanningView.swift** - 國際化 20+ 個字符串 (訓練感受, 難度調整, 運動天數調整等)
21. ✅ **WeeklySummaryView.swift** - 國際化 2 個字符串 (訓練完成度, 訓練分析)

#### 階段 4 子組件 (5/5 完成)
22. ✅ **WeekSelectorSheet.swift** - 國際化 4 個字符串 (第 X 週, 回顧, 課表, 關閉)
23. ✅ **PaceChartView.swift** - 國際化 6 個字符串 (配速變化, 請稍後再試, 無法獲取此次訓練的配速數據等)
24. ✅ **HeartRateChartView.swift** - 國際化 4 個字符串 (心率變化, 請稍後再試, 無法獲取此次訓練的心率數據)
25. ✅ **GaitAnalysisChartView.swift** - 國際化 10+ 個字符串 (步態分析, 觸地時間, 移動效率等)
26. ✅ **WorkoutSummaryRow.swift** - 國際化 1 個字符串 (心率計算中...)

### 新增的本地化 Keys
- `workout_row.*` - 運動記錄行組件
- `circular_progress.*` - 圓形進度組件
- `target_race_card.*` - 目標賽事卡片組件
- `training_stage_card.*` - 訓練階段卡片組件
- `lap_analysis.*` - 圈速分析組件
- `app_loading.*` - 應用載入組件
- `supporting_races_card.*` - 支援賽事卡片組件
- `garmin_reconnection.*` - Garmin 重新綁定組件
- `register_email.*` - 註冊郵件組件
- `verify_email.*` - 驗證郵件組件
- `calendar_sync.*` - 行事曆同步組件
- `edit_target.*` - 編輯目標組件
- `add_supporting_target.*` - 添加支援目標組件
- `edit_supporting_target.*` - 編輯支援目標組件
- `weekly_distance_editor.*` - 週跑量編輯組件
- `training_plan.*` - 訓練計劃組件
- `training_plan_overview.*` - 訓練計劃總覽組件
- `training_item_detail.*` - 訓練項目詳情組件
- `next_week_planning.*` - 下週計劃組件
- `week_selector.*` - 週選擇器組件
- `pace_chart.*` - 配速圖表組件
- `heart_rate_chart.*` - 心率圖表組件
- `gait_analysis_chart.*` - 步態分析圖表組件
- `workout_summary_row.*` - 運動摘要行組件
- `training_progress.*` - 訓練進度組件
- `onboarding.target_race_example` - 目標賽事範例 (波士頓馬拉松/東京マラソン/台北馬拉松)