---
type: SPEC
id: SPEC-workout-post-actions-and-share-card
status: Draft
ontology_entity: workout-post-actions-share-card
created: 2026-04-15
updated: 2026-04-15
---

# Feature Spec: Workout 詳情後續操作與 Share Card

## 背景與動機

`WorkoutDetailViewV2` 不只是讀取詳情，還已經承擔多個高價值後續操作：編輯訓練心得、重新上傳 Apple Health workout、刪除紀錄、分享長截圖與產生照片分享卡。這些行為目前主要存在 code 中，尚未被正式文件化。

## 相容性

- 訓練紀錄列表與詳情入口遵循 `Docs/specs/SPEC-training-record-and-workout-detail.md`

## 需求

### AC-WORKOUT-ACTION-01: Workout 詳情必須提供兩種分享路徑

Given 使用者位於單次訓練詳情，  
When 點擊右上角分享按鈕，  
Then 系統必須提供「照片分享卡」與「長截圖」兩條分享路徑，而不是只有單一輸出格式。

### AC-WORKOUT-ACTION-02: Share card sheet 必須支援照片、版型與文字自訂

Given 使用者打開分享卡 sheet，  
When 編輯分享卡，  
Then 系統必須支援加入照片、切換長寬比與版型、調整標題或鼓勵文字，並可匯出為可分享圖片。

### AC-WORKOUT-ACTION-03: 訓練心得編輯器必須有字數限制與明確的 save 狀態

Given 使用者打開訓練心得編輯器，  
When 輸入或儲存心得，  
Then 畫面必須顯示目前字數與上限、在儲存中顯示 loading，且只有在字數合法時才允許儲存。

### AC-WORKOUT-ACTION-04: 成功更新訓練心得後必須立即反映在當前畫面

Given 使用者成功儲存訓練心得，  
When editor 關閉後回到詳情頁，  
Then 畫面必須立即顯示最新內容，且相關 workouts cache 需被刷新。

### AC-WORKOUT-ACTION-05: 重新上傳只允許 Apple Health 資料，且要先做心率檢查

Given 使用者嘗試重新上傳 workout，  
When 該 workout 不是 Apple Health 來源，  
Then 系統必須拒絕此操作；若是 Apple Health，則需先檢查匹配 workout 與心率資料，再回報成功、心率不足或失敗結果。

### AC-WORKOUT-ACTION-06: 刪除 workout 必須走破壞性確認流程

Given 使用者在詳情頁選擇刪除 workout，  
When 系統執行該操作，  
Then 必須先經過 destructive confirmation；成功後需關閉詳情或更新列表，失敗則保留當前上下文並回報結果。

## 明確不包含

- Share card 視覺設計細節與品牌字級數值
- Workout 詳情圖表本身的資料模型與演算法
- Weekly summary 與 training plan 的其他分享流程
