# Garmin 整合設計計畫

本文件旨在規劃將 Garmin Connect 整合為 App 的新數據來源所需的前端改動。

## 1. 使用者面向的改動

### 設定/個人檔案畫面

- **新增「數據來源」區塊**：
    - 在使用者設定或個人檔案頁面，新增一個名為「數據來源」的管理區塊。
    - 此區塊將並列顯示「Apple HealthKit」與「Garmin」兩個選項。

- **連接狀態與操作**：
    - **Garmin**：
        - **未連接時**：顯示「連接」按鈕，點擊後啟動 OAuth 授權流程。
        - **已連接時**：顯示「已連接」狀態，並提供「中斷連接」的選項。
    - **Apple HealthKit**：
        - 顯示 HealthKit 的授權狀態（已授權/未授權）。
        - 如果未授權，提供按鈕引導使用者至系統設定開啟權限。

- **主要數據來源選擇**：
    - 使用者可以明確選擇一個主要數據來源（Apple HealthKit 或 Garmin）。
    - 此選擇將決定 App 從何處獲取健身紀錄（Workout）數據。
    - 這個偏好設定將儲存在 `UserPreferenceManager` 中，以便 App 其他部分取用。

## 2. Garmin 連接流程

此流程將嚴格遵循 `frontend_integration_guide.md` 文件中的 OAuth 2.0 PKCE 規範。

- **`GarminManager.swift`**：
    - 創建一個新的 `GarminManager` 來封裝所有與 Garmin 連接相關的邏輯。
    - **職責**：
        1.  產生 `code_verifier` 和 `code_challenge`。
        2.  儲存 `code_verifier` 和 `state` 字串以供後續驗證。
        3.  建構 Garmin 授權 URL。
        4.  調用 `SFSafariViewController` 或類似的瀏覽器視圖，載入授權 URL 讓使用者登入並授權。

- **處理回調 (Callback)**：
    - App 需要註冊並處理自定義的 URL Scheme (`havital://callback/garmin`)。
    - 當 Garmin 授權成功並重導向回 App 時，從回調 URL 中：
        1.  驗證 `state` 參數以防止 CSRF 攻擊。
        2.  提取 `authorization_code`。

- **完成連接**：
    - `GarminManager` 在獲取到 `authorization_code` 後，將呼叫後端 API `POST /connect/garmin/callback`。
    - 請求中需包含 `authorization_code` 和之前儲存的 `code_verifier`。
    - 請求成功後，更新 App 內的狀態（例如 `UserPreferenceManager`），並通知 UI 刷新。

## 3. 數據獲取與同步邏輯的調整

這是本次整合的核心，目標是確保數據來源的唯一性，避免數據重複或衝突。

- **`UserPreferenceManager.swift`**：
    - 新增一個枚舉（Enum）型別 `DataSourceType`，包含 `.appleHealth` 和 `.garmin` 兩個成員。
    - 新增一個屬性 `vardataSourcePreference: DataSourceType` 來儲存使用者的選擇。

- **停用現有的 HealthKit 觀察者**：
    - **`WorkoutBackgroundManager.swift`** 和 **`TrainingRecordViewModel.swift`** 目前都使用了 `HKObserverQuery` 來監聽 HealthKit 的數據變化。
    - 這些觀察者的啟動邏輯需要修改：
        - 在啟動觀察者之前，檢查 `UserPreferenceManager.shared.dataSourcePreference`。
        - **只有當數據來源為 `.appleHealth` 時，才啟動 HealthKit 的觀察者。**
        - 如果數據來源為 `.garmin`，則**不應**啟動這些觀察者，從而停止從 HealthKit 自動同步數據。

- **從後端獲取 Garmin 數據**：
    - 根據需求，當數據來源為 Garmin 時，App 不再上傳數據，而是改為從後端拉取已經處理好的健身紀錄。
    - **`WorkoutService.swift`**：
        - 新增一個方法，例如 `fetchWorkoutsFromBackend(from: Date, to: Date) async throws -> [WorkoutSummary]`。
        - 此方法將呼叫一個新的後端 API 端點來獲取指定時間範圍內的健身紀錄列表。
    - **`TrainingRecordViewModel.swift`**：
        - 其 `refreshWorkouts` 方法需要重構：
            - 根據 `dataSourcePreference` 的值，決定是從 `HealthKitManager` 獲取數據，還是從 `WorkoutService.fetchWorkoutsFromBackend` 獲取數據。

## 4. 數據模型

- 從後端獲取的 Garmin 健身紀錄，其數據結構可能與 HealthKit 的 `HKWorkout` 不同。
- 後端 API 應回傳一個標準化的數據結構（例如，類似現有的 `WorkoutSummary` 模型）。
- `WorkoutService` 將負責將後端回傳的 JSON 數據解碼為 App 內可以使用的數據模型。如有必要，可以擴充現有模型或創建新模型以容納 Garmin 特有的數據（例如，Body Battery™）。

## 5. 中斷 Garmin 連接

- 在「數據來源」設定中，為已連接的 Garmin 提供「中斷連接」按鈕。
- 點擊後，App 將執行以下操作：
    1.  呼叫後端 API（例如 `POST /disconnect/garmin`）以在後端移除授權。
    2.  清除 App 本地儲存的 Garmin 相關狀態（例如，在 `UserPreferenceManager` 中）。
    3.  可以選擇將數據來源自動切換回 Apple HealthKit（如果使用者已授權）。
    4.  更新 UI，將 Garmin 狀態顯示為「未連接」。

## 6. 首次執行的情境

- 對於首次安裝或更新後第一次開啟 App 的使用者：
    - 在 Onboarding 流程中應**新增一個專門的頁面**，讓使用者選擇他們偏好的數據來源（Apple HealthKit 或 Garmin）。
    - 這個頁面應該簡要說明兩種來源的區別（例如：HealthKit 依賴 iPhone 和 Apple Watch 的數據，Garmin 則同步您 Garmin 帳號的所有活動）。
    - 根據使用者的選擇，引導他們完成相應的授權流程。

## 7. 擴充性考量

為了應對未來可能接入更多第三方數據來源（例如：Suunto, Polar 等），架構設計應具備良好的擴充性。

- **抽象化連接流程**：
    - 建立一個通用的 `DataSourceConnectable` 協定（protocol），而不是寫死的 `GarminManager`。
    - `GarminManager` 和未來的 `SuuntoManager` 等都可以遵循此協定。
    - 這個協定可以定義 `connect()`、`disconnect()`、`handleCallback(url: URL)` 等通用方法。

- **通用化數據獲取**：
    - 後端 API `POST /connect/{provider}/callback` 的 `{provider}` 參數已經為此提供了基礎。
    - 前端在 `WorkoutService` 中的數據獲取方法也應設計成可傳入不同 `provider` 的形式，而不是針對特定廠商寫死。

## 8. 數據計算與切換邏輯

當使用者在不同數據來源之間切換時，必須確保數據的一致性和正確性。

- **觸發數據刷新**：
    - 當 `UserPreferenceManager.shared.dataSourcePreference` 的值發生改變時（例如，從 `.appleHealth` 切換到 `.garmin`），App 必須觸發一個**全局的數據刷新事件**。

- **重算核心指標**：
    - 此事件應通知所有相關的 ViewModel（如 `TrainingPlanViewModel`, `WeeklySummaryViewModel` 等）重新從新的數據來源獲取數據。
    - 依賴健身紀錄的計算，例如**週跑量、強度分佈、VDOT、訓練負荷**等，都必須被清除快取並使用新來源的數據重新計算。
    - 顯示歷史訓練記錄的列表也需要完全刷新。

- **避免數據混用**：
    - 嚴格禁止將來自不同來源的數據混合計算。例如，不能將 HealthKit 的一筆跑步紀錄和從後端獲取的 Garmin 紀錄加總來計算週跑量。在任何時間點，App 的計算都應該只基於使用者選擇的**單一**數據來源。 