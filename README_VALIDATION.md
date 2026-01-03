# Manager 自動化驗證工具

## 快速開始

### 1. 設置 Git Hooks (推薦)

```bash
cd /Users/wubaizong/havital/apps/ios/Havital
chmod +x Scripts/setup_git_hooks.sh
./Scripts/setup_git_hooks.sh
```

完成後，每次 commit 和 push 都會自動驗證代碼。

### 2. 手動運行驗證

```bash
# 完整驗證 (包括編譯和測試，約 5-10 分鐘)
./Scripts/validate_managers.sh

# 快速驗證 (僅靜態檢查，約 10 秒)
./Scripts/validate_managers.sh --quick

# 跳過編譯 (保留靜態檢查和測試)
./Scripts/validate_managers.sh --skip-build

# 跳過測試 (保留靜態檢查和編譯)
./Scripts/validate_managers.sh --skip-tests
```

## 驗證內容

### 靜態檢查 (自動化)
- ✅ Dictionary 安全性 (禁止 Date 作為 key)
- ✅ TaskManageable 實現完整性
- ✅ 任務取消錯誤處理
- ✅ weak self 使用
- ✅ SwiftLint 檢查
- ✅ 日誌覆蓋率
- ✅ API 調用追蹤覆蓋率
- ✅ 雙軌緩存模式檢查
- ✅ 初始化順序控制

### 編譯檢查 (自動化)
- ✅ Xcode 編譯是否通過

### 單元測試 (自動化)
- ✅ 運行所有 HavitalTests

## 驗證結果

驗證完成後會生成報告: `validation_report_YYYYMMDD_HHMMSS.txt`

### 退出碼
- `0`: 驗證通過 (可能有警告)
- `1`: 驗證失敗 (有錯誤)

## Git Hooks 說明

### Pre-commit Hook
- 每次 `git commit` 時自動觸發
- 運行快速靜態檢查 (約 10 秒)
- 如需跳過: `git commit --no-verify`

### Pre-push Hook
- 每次 `git push` 時自動觸發
- 運行完整驗證 (包括編譯和測試)
- 如需跳過: `git push --no-verify`

## 開發者工具

安裝開發者工具後可以在 App 中清空緩存進行測試:

```swift
// 已創建: Havital/Utils/DeveloperTools.swift

// 使用方法:
#if DEBUG
NavigationLink("🔧 開發者工具") {
    DeveloperToolsView()
}
#endif
```

功能:
- 🗑️ 清空所有緩存
- 🔄 強制 API 刷新
- ⚠️ 模擬網路錯誤
- 🐌 模擬慢速網路
- 🔧 並發測試
- 🔍 內存洩漏測試

## 常見問題

### Q: 驗證太慢怎麼辦？
A: 使用 `--quick` 模式跳過編譯和測試

### Q: 如何禁用 Git Hooks？
A: 刪除 `.git/hooks/pre-commit` 和 `.git/hooks/pre-push`

### Q: 如何只驗證特定 Manager？
A: 目前腳本驗證所有 Manager，未來可以添加參數支持

### Q: 如何測試緩存刷新邏輯？
A: 使用開發者工具清空緩存，然後手動觸發數據載入

## 工具文件

- `Scripts/validate_managers.sh` - 主驗證腳本
- `Scripts/setup_git_hooks.sh` - Git Hooks 安裝腳本
- `Havital/Utils/DeveloperTools.swift` - 開發者調試工具

## 架構規範

詳見 [CLAUDE.md](CLAUDE.md) 中的架構原則。
