# 資料載入
## onboarding完首次載入：
1. 用戶資料
2. target(目標賽事)
3. 訓練總覽 planoverview
4. 週課表 weeklyplan
5. 訓練紀錄
6. 更新運動紀錄到dailyTrainingCard，更新週里程和訓練強度分布

## App每次開啟時載入：
1. 週課表 weeklyplan
2. 訓練紀錄 （get v2/workouts）
3. 更新運動紀錄到dailyTrainingCard，更新週里程和訓練強度分布

## 手動刷新週課表：
1. get 週課表 weeklyplan
2. 更新運動紀錄到dailyTrainingCard，更新週里程和訓練強度分布

## 手動刷新trainingrecordview
1. 按照當前分頁機制更新資料
2. 更新更新運動紀錄到dailyTrainingCard，更新週里程和訓練強度分布

## 如果當週的週課表是404(無當週週課表)
1. 如果當前週數不大於訓練總週數：顯示“取得週回顧”按鈕
2. 如果當前週數大於訓練總週數：顯示設設定目標按鈕

## 如果從訓練暨進度清單中選擇之前的課表
1. get 對應週數的週課表
2. 更新更新運動紀錄到dailyTrainingCard，更新週里程和訓練強度分布

## 所有的資料都使用雙軌模式，優先顯示本地緩存，然後當API有更新再更新一次UI
