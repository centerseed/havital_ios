# Manager 驗證工具 - 快速上手

## 🎯 目標

自動化驗證 Manager 重構，無需手動測試。

## 🚀 三步驟驗證

### 第一步: 代碼檢查 (必做)

```bash
cd /Users/wubaizong/havital/apps/ios/Havital

# 快速檢查 (~10秒)
./Scripts/validate_managers.sh --quick
```

**檢查內容**: 10 項靜態檢查 + 編譯驗證

### 第二步: 緩存測試 (重構後必做)

```bash
# 方式 1: 一鍵測試 (推薦)
./Scripts/test_with_cache_clear.sh
# 會自動清空緩存、啟動 Simulator、並提示你接下來的步驟

# 方式 2: 手動測試
./Scripts/clear_simulator_cache.sh  # 清空緩存
# 然後在 Xcode 運行 App，查看日誌
```

**驗證目標**: 確保無緩存時 API 層正常工作

**預期日誌**:
- ✅ 第一次打開: `📡 API 調用` → `✅ API End 200`
- ✅ 下拉刷新: `🔄 背景刷新開始` → `✅ 背景刷新完成`
- ✅ 第二次打開: `✅ 緩存命中` + `🔄 背景刷新`

### 第三步: 單元測試 (確保質量)

```bash
# 運行單元測試
./Scripts/run_tests.sh

# 如果遇到 TEST_HOST 錯誤，運行修復腳本
./Scripts/fix_test_config.sh
```

**測試內容**:
- ✅ 雙軌緩存邏輯
- ✅ API 調用流程
- ✅ 錯誤處理
- ✅ 任務取消
- ✅ 並發控制
- ✅ 內存洩漏

### 第四步: 設置自動化 (可選)

```bash
# 安裝 Git Hooks，之後每次 commit/push 自動檢查
./Scripts/setup_git_hooks.sh
```

## ✅ 驗證通過標準

### 代碼檢查
- ✅ 0 個錯誤
- ⚠️ 警告數量 < 5 個

### 緩存測試
- ✅ 無緩存時: 看到 "📡 API 調用"
- ✅ 有緩存時: 看到 "✅ 緩存命中" + "🔄 背景刷新"
- ✅ 下拉刷新: 觸發背景更新

## 📊 工具對比

| 工具 | 用途 | 耗時 | 何時使用 |
|------|------|------|----------|
| `validate_managers.sh --quick` | 靜態檢查 | 10秒 | 每次重構後 |
| `validate_managers.sh` | 完整檢查 | 5分鐘 | Push 前 |
| `clear_simulator_cache.sh` | 清空緩存 | 5秒 | 測試 API 層 |
| `setup_git_hooks.sh` | 自動化 | 1次 | 初始設置 |

## 🐛 常見問題

**Q: 快速檢查有警告，要修嗎？**
A: 不強制，但建議修復以提高代碼質量

**Q: 清空緩存後 App 崩潰？**
A: 檢查初始化順序，確保等待用戶認證完成

**Q: 看不到 "📡 API 調用" 日誌？**
A: 確認 Xcode Console 過濾器設置為 "All Output"

## 📝 重構後檢查清單

- [ ] 運行 `./Scripts/validate_managers.sh --quick`
- [ ] 0 個錯誤
- [ ] 運行 `./Scripts/clear_simulator_cache.sh`
- [ ] 啟動 App，確認看到 API 調用日誌
- [ ] 下拉刷新，確認背景更新正常
- [ ] Commit 代碼

## 🎓 下一步

詳細文檔: [Scripts/README.md](README.md)
