# 404流程測試驗證

## 測試目的
確保改進的網路錯誤處理不會影響當前的404流程，即API回傳404時仍能正確顯示當週回顧按鈕。

## 關鍵流程確認

### 1. 404錯誤處理流程
```swift
// APIClient.swift - 404錯誤仍保持原始NSError格式
case 404:
    return NSError(domain: "APIClient", code: statusCode, userInfo: [NSLocalizedDescriptionKey: responseBody])

// TrainingPlanService.swift - 404錯誤轉換為WeeklyPlanError.notFound
catch let error as NSError where error.code == 404 {
    throw WeeklyPlanError.notFound
}

// TrainingPlanViewModel.swift - 404錯誤觸發.noPlan狀態
catch let error as TrainingPlanService.WeeklyPlanError where error == .notFound {
    await updateWeeklyPlanUI(plan: nil, status: .noPlan)
}
```

### 2. 當週回顧按鈕顯示條件
```swift
// TrainingPlanViewModel.swift
var isNewWeekPromptNeeded: Bool {
    if planStatus == .loading {
        return false
    }
    return weeklyPlan == nil && selectedWeek == currentWeek
}

// TrainingPlanView.swift
} else if viewModel.isNewWeekPromptNeeded {
    NewWeekPromptView(viewModel: viewModel, currentTrainingWeek: current)
```

### 3. 網路錯誤vs404錯誤的區別
- **404錯誤**: 保持原有流程，顯示當週回顧按鈕
- **網路錯誤**: 顯示網路錯誤Alert，提供重試選項

## 測試場景

### 場景1: API回傳404 - 正常流程
1. 當週無課表
2. API回傳404狀態碼
3. 應該顯示："取得訓練回顧"按鈕
4. **預期結果**: 不受影響，按鈕正常顯示

### 場景2: 網路連接問題
1. 網路斷開或連接不穩
2. 應該顯示網路錯誤Alert
3. **預期結果**: 顯示"網路連接問題"提示

### 場景3: 伺服器5xx錯誤
1. 伺服器內部錯誤
2. 應該顯示網路錯誤Alert
3. **預期結果**: 顯示"伺服器錯誤"提示

## 驗證方法

### 1. 代碼審查
- ✅ 確認404錯誤路徑未被修改
- ✅ 確認WeeklyPlanError.notFound仍正確處理
- ✅ 確認網路錯誤處理只處理真正的網路問題

### 2. 測試建議
1. 模擬404回應，確認顯示回顧按鈕
2. 模擬網路斷開，確認顯示網路錯誤
3. 模擬伺服器錯誤，確認顯示相應提示

## 風險評估

### 低風險改動
- 只新增了網路錯誤處理
- 404處理路徑完全未修改
- 使用了額外的錯誤檢查，不影響現有邏輯

### 關鍵保護措施
1. 404錯誤仍返回原始NSError格式
2. WeeklyPlanError.notFound處理不變
3. 網路錯誤處理是額外的，不會攔截404

## 結論
此改進方案是**安全的**，因為：
1. 404錯誤處理完全不受影響
2. 網路錯誤處理是額外功能，不會干擾現有流程
3. 改進只針對真正的網路連接問題
4. 用戶體驗得到改善，同時保持核心功能穩定