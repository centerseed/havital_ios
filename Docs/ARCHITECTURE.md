# Havital App 架構文件

## 1. 簡介

本文件旨在提供 Havital iOS App 的完整架構概覽，幫助新進開發者快速理解專案的設計理念、程式碼結構與核心流程。

App 主要目標是根據使用者的體能狀況與目標，提供個人化的馬拉松訓練計畫。它整合了 Apple HealthKit 來追蹤實際運動數據，並透過後端 API 同步訓練計畫與使用者資料。

專案採用業界主流的 **MVVM (Model-View-ViewModel)** 架構模式，並大量運用 SwiftUI、Combine 與 Swift Concurrency (`async/await`) 等現代技術，以實現一個響應式、可維護且高效能的應用程式。

---

## 2. 專案結構

專案的目錄結構清晰地反映了 MVVM 的分層思想。以下是主要目錄及其職責：

-   **/Havital**: App 主要原始碼目錄。
    -   **`HavitalApp.swift`**: App 的進入點，負責初始化設定與根視圖。
    -   **/Models**: 定義 App 所需的資料模型（Data Models），例如 `User`, `WeeklyPlan`, `Workout` 等。這些模型通常是 `Codable` 的，用於解析 API 回應。
    -   **/Views**: 包含所有 SwiftUI 視圖。每個視圖都盡可能保持輕量，只負責 UI 的呈現與使用者互動的傳遞。
        -   **/Components**: 可在多個視圖中重複使用的通用 UI 元件。
        -   **/Training**, **/Onboarding**, etc.: 按功能模組組織的特定視圖。
    -   **/ViewModels**: 視圖模型層，是 View 和 Model 之間的橋樑。它負責處理業務邏輯、資料加工、狀態管理，並將準備好的資料暴露給 View 使用。
    -   **/Services**: 服務層，封裝了與外部世界的互動，如網路請求、資料庫存取、硬體互動（HealthKit）等。
        -   `APIClient.swift`: 一個基於 `Actor` 的通用網路請求客戶端，負責所有與後端 API 的通訊，並自動處理認證 Token。
        -   `AuthenticationService.swift`: 處理使用者登入、登出、註冊及身份驗證狀態管理。
        -   `TrainingPlanService.swift`: 負責獲取、更新和管理使用者的訓練計畫。
        -   `HealthKitManager.swift`: 封裝所有與 Apple HealthKit 的互動，如權限請求、讀取 `HKWorkout` 資料等。
    -   **/Managers**: 管理器層，通常用於處理一些橫跨多個模組的特定功能或狀態。
        -   `TrainingIntensityManager.swift`: 管理訓練強度相關的計算與邏輯。
    -   **/Utils**: 包含各種工具類別，如日期處理、字串格式化等。
    -   **/Storage**: 負責本地資料快取，將從網路獲取的資料儲存在裝置上，以提升效能和離線體驗。

---

## 3. App 啟動流程與全域狀態

App 的生命週期由 **`HavitalApp.swift`** 管理。啟動時會執行以下關鍵任務：

1.  **環境設定**: 根據 `DEBUG` 或 `PROD` 環境，載入對應的 `GoogleService-Info.plist` 以初始化 Firebase。
2.  **全域服務初始化**:
    *   `AuthenticationService.shared`: 作為單例，在 App 啟動時即被建立，用於檢查使用者先前的登入狀態。
    *   `HealthKitManager()`: 初始化 HealthKit 管理器。
    *   `AppViewModel()`: 管理全域 UI 狀態，如顯示全域彈窗、處理 HealthKit 權限提示等。
3.  **根視圖 (Root View)**:
    *   `ContentView` 是 App 的根視圖。
    *   它使用 `@StateObject` 創建 `AuthenticationService` 和 `AppViewModel` 的實例，並透過 `.environmentObject()` 將它們注入到整個 App 的視圖層級中。這使得任何子視圖都能輕易地存取這些全域服務與狀態。
4.  **深度連結 (Deep Linking)**:
    *   整合了 `onOpenURL` 來處理來自外部的 URL，主要用於 Garmin 的 OAuth 認證回調。

---

## 4. 核心組件詳解

### 4.1. Service 層

Service 層是 App 的骨幹，負責所有資料的來源與處理。

-   **`APIClient`**:
    *   這是一個 `Actor`，保證了所有網路請求的線程安全。
    *   它提供了一個通用的 `request<T: Decodable>(endpoint: Endpoint)` 方法，封裝了 URL 組裝、HTTP 方法、Header 設定（自動附加 Firebase ID Token）和 JSON 解碼。
    *   統一的錯誤處理機制，將網路或解碼錯誤轉換為自定義的 `APIError`。

-   **`AuthenticationService`**:
    *   管理使用者的完整生命週期：登入（Google/Apple）、登出、註冊、刪除帳號。
    *   使用 `Combine` 的 `@Published` 屬性 `userSession` 來發布當前使用者狀態，讓 App 的 UI 能響應式地更新。
    *   處理 Onboarding 流程，判斷使用者是否需要填寫初始資料。
    *   登出時，負責清理所有本地快取、Keychain 中的憑證，確保資料安全。

### 4.2. ViewModel 層

ViewModel 是 MVVM 的核心，它驅動著 View 的顯示。

-   **`AppViewModel`**:
    *   作為全域 ViewModel，處理跨模組的 UI 狀態。
    *   監聽 `NotificationCenter` 的通知，例如 `showHealthKitPermissionAlert`，並觸發全域的 `Alert`。
    *   管理 Garmin 資料來源不一致時的提示。

-   **`TrainingPlanViewModel`**:
    *   這是 App 中最複雜的 ViewModel，負責整個「訓練計畫」頁面的所有邏輯。
    *   **狀態管理**: 使用 `PlanStatus` enum (`.loading`, `.noPlan`, `.ready`, `.completed`, `.error`) 來精確管理 UI 狀態，避免使用多個布林值造成的混亂。
    *   **資料整合**:
        1.  從 `TrainingPlanService` 獲取後端訓練計畫。
        2.  從 `HealthKitManager` 讀取 `HKWorkout` 健身記錄。
        3.  從 `TrainingPlanStorage` 讀寫本地快取。
    *   **業務邏輯**: 包含產生新週課表、計算週數、顯示訓練回顧、處理使用者互動等複雜邏輯。

### 4.3. View 層

View 層完全由 SwiftUI 構建。

-   **`TrainingPlanView.swift`**:
    *   使用 `@StateObject` 持有 `TrainingPlanViewModel`。
    *   其 `body` 內容完全由 ViewModel 的狀態驅動。`switch viewModel.planStatus` 的結構清晰地展示了不同狀態下應顯示的 UI。
    *   將複雜的 UI 拆分為多個子視圖（`WeekPlanContentView`, `NewWeekPromptView`），提高了程式碼的可讀性和可重用性。
    *   使用者互動（如按鈕點擊、下拉刷新）會直接呼叫 ViewModel 對應的方法，例如 `viewModel.generateNextWeekPlan()`。

---

## 5. 資料流 (Data Flow)

graph TD
    A[TrainingProgressView] --> B[TrainingPlanViewModel]
    B --> C[UnifiedWorkoutManager]
    C --> D{數據來源}
    D -->|Apple Health 用戶| E[V2 API]
    D -->|Garmin 用戶| F[V2 API]
    E --> G[本地快取]
    F --> G
    
    H[App 生命週期] --> I[AppViewModel]
    I --> C
    
    J[手動刷新] --> I

Havital 的資料流遵循單向流動的原則，確保了狀態的可預測性。

1.  **資料來源**: 後端 API (透過 `APIClient`) 或 Apple HealthKit (透過 `HealthKitManager`)。
2.  **Service 層**: 獲取原始資料，並進行初步處理（如 JSON 解碼）。
3.  **ViewModel 層**:
    *   向 Service 層請求資料。
    *   將獲取到的 Model 資料進行加工、組合，轉換成 View 所需的格式。
    *   管理與該資料相關的 UI 狀態（如 `isLoading`）。
4.  **View 層**:
    *   訂閱 ViewModel 的 `@Published` 屬性。
    *   當 ViewModel 的資料更新時，SwiftUI 自動重新渲染 UI。
    *   使用者的操作會觸發 ViewModel 的方法，啟動新一輪的資料流循環。

**快取策略**: Service 層獲取到資料後，會先存入本地的 Storage（如 `TrainingPlanStorage`），ViewModel 會優先從 Storage 讀取資料以加快顯示速度，同時再非同步地從網路更新資料。

---

## 6. 關鍵設計模式

-   **MVVM**: 清晰的分層架構，分離了 UI、業務邏輯和資料模型。
-   **Swift Concurrency**: 大量使用 `async/await` 來處理非同步任務，使程式碼更簡潔、易讀。使用 `Actor` (`APIClient`) 確保線程安全。
-   **Combine Framework**: 用於響應式程式設計，特別是在 `AuthenticationService` 中監控使用者狀態的變化。
-   **Dependency Injection (依賴注入)**: 主要透過 `.environmentObject()` 將全域服務注入到 SwiftUI 的環境中，方便各個 View 存取。
-   **Singleton (單例模式)**: `AuthenticationService` 和 `APIClient` 等核心服務被設計為單例，確保在 App 中只有一個實例。
-   **Repository/Storage Pattern**: 透過 Storage 層將資料來源（網路或本地）的細節對 ViewModel 隱藏，實現了資料來源的抽象化。

---

## 7. Onboarding 與身份驗證流程

1.  **首次啟動**: `AuthenticationService` 檢查到無使用者登入，`ContentView` 會顯示 `LoginView`。
2.  **登入**: 使用者透過 Google 或 Apple 成功登入後，`AuthenticationService` 會從 Firebase 獲取 `UserCredential`，並向後端 API 註冊或登入使用者，取得 `User` 模型。
3.  **Onboarding 檢查**: `AuthenticationService` 檢查 `User` 物件的 `status` 或 `hasCompletedOnboarding` 屬性。
4.  **進入 Onboarding**: 如果使用者尚未完成初始設定，App 會引導至 Onboarding 流程，收集必要的個人資訊（如目標、訓練天數等）。
5.  **完成 Onboarding**: 完成後，狀態被儲存到後端，`hasCompletedOnboarding` 在本地被設為 `true`。
6.  **進入主畫面**: `ContentView` 偵測到使用者已登入且已完成 Onboarding，顯示 `TrainingPlanView`。
