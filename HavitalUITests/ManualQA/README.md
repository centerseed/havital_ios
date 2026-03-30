# ManualQA — iOS Simulator MCP UI 驗證測試

本資料夾存放透過 Claude Code + iOS Simulator MCP 執行的手動 QA 測試計劃與報告。

## 與 E2E 測試的差異

| | E2E (XCUITest) | ManualQA (MCP) |
|---|---|---|
| 執行方式 | `xcodebuild test` 自動化 | Claude + iOS Simulator MCP 互動式 |
| 驗證範圍 | 流程是否跑通、元素是否存在 | UI 內容合理性、視覺正確性 |
| 適合場景 | 回歸測試、CI/CD | 新功能驗收、課表合理性審查 |
| 截圖 | XCTAttachment | MCP `screenshot` / `ui_view` |

## 資料夾結構

```
ManualQA/
├── README.md                          # 本文件
├── TestPlans/                         # 測試計劃
│   └── TrainingPlanMatrix.md          # 訓練方案組合矩陣
├── Reports/                           # 測試報告
│   └── YYYY-MM-DD_TestName.md         # 單次測試報告
└── Screenshots/                       # 截圖存放
    └── YYYY-MM-DD/                    # 按日期分類
```

## 如何使用

1. 從 `TestPlans/` 選擇測試計劃
2. 讓 Claude 用 iOS Simulator MCP 工具逐步執行
3. Claude 產出報告到 `Reports/`
4. 截圖存放到 `Screenshots/` 對應日期

## 執行指令

告訴 Claude：
```
按照 HavitalUITests/ManualQA/TestPlans/TrainingPlanMatrix.md 執行測試 T1
```

---

## 測試案例總覽

### T1-T6：Onboarding 訓練方案組合

詳見 `TestPlans/TrainingPlanMatrix.md`

### W1：週課表顯示驗證

驗證當週課表在主頁正確顯示，包含訓練類型、配速、距離等資訊。

### E1-E3：編輯課表

| ID | 說明 |
|----|------|
| E1 | 進入編輯課表頁面，確認可正常開啟與關閉 |
| E2 | 修改訓練類型（如輕鬆跑 → 間歇訓練），確認儲存後主頁更新 |
| E3 | 修改配速，確認儲存後主頁配速顯示更新 |

### S1：產生週回顧

1. 確保當週所有訓練日已有資料
2. 觸發週回顧產生（手動或等待排程）
3. 驗證回顧摘要正確顯示（總跑量、總時間、訓練分析）

### R1：刪除課表 + 回顧 → 重新產生

1. 從設定刪除當週課表與回顧（Firestore 操作）
2. 回到 app，確認課表消失或顯示空狀態
3. 重新觸發課表產生
4. 驗證新課表正確建立

---

## iOS 26 Simulator 限制（已知）

- `ui_describe_all` / `ui_describe_point` 在 iOS 26 返回空結果（accessibility layer 故障）
- `idb ui describe-all` 同樣無效
- **可用方法**：`xcrun simctl io booted screenshot` + Read 截圖分析 + `ui_tap` / `ui_swipe` 座標操作
- SwiftUI Toggle 無法透過任何程式化點擊觸發（iOS 26 限制）
- 座標系統：iPhone 17 為 402×874 logical points，Dynamic Island status bar 高度約 81pt

## 已知 Bug 記錄

| Bug | 狀態 | 說明 |
|-----|------|------|
| 力量訓練無法編輯 | 已修復 (2026-03-29) | `simpleTrainingControls` 對 strength 無 inline 控制項；gear sheet 顯示錯誤的距離選項。修復：`SimpleEditorV2` 排除非跑步類型的距離欄位；`toMutableTrainingDay` 對 strength/crossTraining/yoga 等類型儲存 `distanceKm: nil` |
