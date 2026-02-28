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
