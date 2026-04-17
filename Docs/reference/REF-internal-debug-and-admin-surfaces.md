---
type: REF
id: REF-internal-debug-and-admin-surfaces
status: Draft
ontology_entity: internal-debug-admin-surfaces
created: 2026-04-15
updated: 2026-04-15
---

# Internal Debug / Admin Surfaces Map

## 結論

以下功能屬於 internal debug、admin 或 UI test control plane，**不是產品 SSOT**。
它們應保留在 codebase，但文件上只應出現在 `REFERENCE` / `TEST` / `DECISION`，不應混入產品 spec。

## Surface Matrix

| Surface | 檔案 | 角色 | 文件定位 |
|---------|------|------|----------|
| IAP Test Console | `Havital/Features/Subscription/Presentation/Views/IAPTestConsoleView.swift` | 內部訂閱狀態測試台 | internal REFERENCE |
| Debug Failed Workouts | `Havital/Views/Settings/DebugFailedWorkoutsView.swift` | 失敗 workout 診斷工具 | internal REFERENCE |
| Workout Sync Debug | `Havital/Views/Debug/WorkoutSyncDebugView.swift` | HealthKit / sync 手動測試面板 | internal REFERENCE |
| UITest Onboarding Harness | `Havital/Features/Onboarding/Debug/UITestOnboardingHarness.swift` | onboarding 測試注入與狀態控制 | TEST / internal REFERENCE |
| UITest Paywall Host | `Havital/Features/Subscription/Debug/UITestPaywallHostView.swift` | paywall UI test host | TEST |
| UITest TrainingPlanV2 Gate Host | `Havital/Features/Subscription/Debug/UITestTrainingPlanV2GateHostView.swift` | V2 gate / entitlement host | TEST |
| Maestro Final Guardrail | `Docs/specs/SPEC-maestro-ui-final-guardrail.md` | UI guardrail 規格 | 保留，屬 QA spec 非產品 spec |
| IAP UI Test Harness ADR | `Docs/decisions/ADR-004-iap-ui-state-test-harness.md` | 控制平面決策 | 保留，屬 DECISION |

## 顯示邊界

- `IAPTestConsoleView`、`DebugFailedWorkoutsView` 應只透過 debug 條件或受控入口顯示。
- `UITest*HostView` / harness 應只服務測試流程，不得成為一般使用者路徑。
- 這些 surface 的變更，不應要求更新產品 spec；應更新：
  - `REFERENCE`：若是工具盤點或使用說明
  - `TEST`：若是驗收矩陣或測試場景
  - `DECISION`：若是控制平面或安全邊界改變

## 與產品 SSOT 的關係

### 會影響產品 spec 的情況

- 若某 internal surface 變成正式使用者入口
- 若 debug / admin 狀態覆寫開始影響 production 邏輯
- 若測試 host 的控制能力需要產品 guardrail 配合

### 不應影響產品 spec 的情況

- 純 debug 按鈕位置調整
- 測試 host 新增欄位
- iap / workout sync 的內部診斷資訊擴充

## 維護規則

1. 新增 internal 工具時，先判定它是不是產品功能；若不是，不要開產品 SPEC。
2. 若工具需要長期維護，至少補一份 `REFERENCE`，說明入口、用途、限制。
3. 若工具承擔自動化驗收責任，補 `TEST` 或 `ADR`，不要把它包裝成產品規格。
