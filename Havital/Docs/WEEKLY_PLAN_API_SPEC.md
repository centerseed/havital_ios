# Weekly Training Plan API 規格

## 概述

此文檔定義了週訓練計畫 (Weekly Training Plan) 的完整資料結構，包括必填和選填欄位的詳細說明。

## 主要模型結構

### WeeklyTrainingPlan (週訓練計畫)

#### 必填欄位 (Required)
| 欄位名稱 | 類型 | 描述 | 驗證規則 |
|---------|------|------|---------|
| `purpose` | string | 當週具體的訓練目的 | 必填 |
| `days` | Array\<DayDetail\> | 7天訓練日陣列 | 必填，長度=7 |
| `total_distance_reason` | string | 當週跑量決定方式說明 | 必填 |
| `total_distance_km` | number | 週跑量（公里） | 必填，≥0 |
| `design_reason` | Array\<string\> | 安排理由陣列 | 必填 |
| `intensity_total_minutes` | IntensityMinutes | 週總強度分鐘數 | 必填 |

#### 選填欄位 (Optional)
| 欄位名稱 | 類型 | 描述 | 預設值 |
|---------|------|------|-------|
| `week_of_plan` | number | 當前週數 | null |
| `total_weeks` | number | 總訓練週數 | null |

---

### DayDetail (每日訓練詳情)

#### 必填欄位
| 欄位名稱 | 類型 | 描述 | 驗證規則 |
|---------|------|------|---------|
| `day_index` | number | 星期幾 | 1-7 (1=週一, 7=週日) |
| `training_type` | TrainingType | 訓練類型 | 見下方列舉值 |
| `day_target` | string | 當日訓練目標 | 必填 |
| `reason` | string | 為何今天安排這樣的訓練課表 | 必填 |
| `training_details` | Union\<TrainingDetails\> | 訓練詳情 | 必填，類型依 training_type 而定 |

#### 選填欄位
| 欄位名稱 | 類型 | 描述 | 預設值 |
|---------|------|------|-------|
| `tips` | string | 注意事項 | null |

---

### TrainingType (訓練類型列舉)

```typescript
enum TrainingType {
  "recovery_run"    // 恢復跑
  "easy_run"        // 輕鬆跑
  "lsd"            // 長距離慢跑
  "interval"       // 間歇跑
  "tempo"          // 節奏跑
  "long_run"       // 長跑
  "threshold"      // 閾值跑
  "progression"    // 漸速跑
  "race"           // 賽事
  "rest"           // 休息
}
```

---

### TrainingDetails (訓練詳情聯合類型)

根據 `training_type` 的不同，`training_details` 會是以下類型之一：

## 1. RestTraining (休息)
**適用於**: `training_type = "rest"`

#### 必填欄位
| 欄位名稱 | 類型 | 描述 |
|---------|------|------|
| `description` | string | 休息提示 |

## 2. GeneralTraining (一般訓練)
**適用於**: `easy_run`, `recovery_run`, `lsd`, `long_run`, `tempo`, `threshold`

#### 必填欄位
| 欄位名稱 | 類型 | 描述 | 驗證規則 |
|---------|------|------|---------|
| `distance_km` | number | 訓練距離（公里） | ≥0 |
| `time_minutes` | number | 預計訓練時間（分鐘） | ≥0 |
| `heart_rate_range` | HeartRateRange | 訓練的目標心率區間 | 必填 |
| `description` | string | 說明 | 必填 |

#### 選填欄位
| 欄位名稱 | 類型 | 描述 | 格式 |
|---------|------|------|------|
| `pace` | string | 配速 | "mm:ss" 格式 |

## 3. RaceTraining (賽事)
**適用於**: `training_type = "race"`

#### 必填欄位
| 欄位名稱 | 類型 | 描述 | 驗證規則 |
|---------|------|------|---------|
| `distance_km` | number | 賽事距離（公里） | ≥0 |
| `time_minutes` | number | 預計訓練時間（分鐘） | ≥0 |
| `pace` | string | 配速 | "mm:ss" 格式 |
| `description` | string | 說明 | 必填 |

## 4. IntervalTraining (間歇訓練)
**適用於**: `training_type = "interval"`

#### 必填欄位
| 欄位名稱 | 類型 | 描述 |
|---------|------|------|
| `repeats` | number | 重複次數 |
| `work` | IntervalWork | 高強度部分 |
| `recovery` | IntervalRecovery | 恢復部分 |

### IntervalWork (間歇訓練-工作段)
#### 必填欄位
| 欄位名稱 | 類型 | 描述 | 驗證規則 |
|---------|------|------|---------|
| `distance_km` | number | 距離（公里） | ≥0 |
| `pace` | string | 配速 | "mm:ss" 格式 |
| `description` | string | 說明 | 必填 |

#### 選填欄位
| 欄位名稱 | 類型 | 描述 | 驗證規則 |
|---------|------|------|---------|
| `distance_m` | number | 距離（公尺） | ≥0 |
| `time_minutes` | number | 時間（分鐘） | ≥0 |

### IntervalRecovery (間歇訓練-恢復段)
#### 必填欄位
| 欄位名稱 | 類型 | 描述 |
|---------|------|------|
| `description` | string | 說明 |

#### 選填欄位
| 欄位名稱 | 類型 | 描述 | 特殊說明 |
|---------|------|------|---------|
| `distance_km` | number \| null | 距離（公里） | **null 或 0 表示完全靜止休息** |
| `distance_m` | number | 距離（公尺） | ≥0 |
| `time_minutes` | number | 恢復時間（分鐘） | **靜止休息時可省略** |
| `pace` | string | 配速 | "mm:ss" 格式，**靜止休息時應為 null** |
| `heart_rate_range` | HeartRateRange | 目標心率區間 | 選填 |

## 5. SegmentTraining (分段訓練)
**適用於**: `training_type = "progression"`

#### 必填欄位
| 欄位名稱 | 類型 | 描述 |
|---------|------|------|
| `segments` | Array\<SegmentDetail\> | 分段配速陣列 |
| `total_distance_km` | number | 總距離（公里） |
| `description` | string | 說明 |

### SegmentDetail (分段詳情)
#### 必填欄位
| 欄位名稱 | 類型 | 描述 | 驗證規則 |
|---------|------|------|---------|
| `distance_km` | number | 距離（公里） | ≥0 |
| `pace` | string | 配速 | "mm:ss" 格式 |

#### 選填欄位
| 欄位名稱 | 類型 | 描述 |
|---------|------|------|
| `description` | string | 說明 |

---

### IntensityMinutes (強度分鐘數)

#### 必填欄位
| 欄位名稱 | 類型 | 描述 |
|---------|------|------|
| `low` | number | 低強度分鐘數 |
| `medium` | number | 中強度分鐘數 |
| `high` | number | 高強度分鐘數 |

---

### HeartRateRange (心率區間)

#### 必填欄位
| 欄位名稱 | 類型 | 描述 |
|---------|------|------|
| `min` | number | 最小心率 |
| `max` | number | 最大心率 |

---

## 重要注意事項

### 間歇訓練恢復段
1. **慢跑恢復**: `distance_km` 有數值，通常還會有 `pace`
2. **完全靜止休息**: `distance_km` 為 `null` 或 0，`pace` 應為 `null`
3. 恢復段的 `time_minutes` 是選填的，適用於"3分鐘全休"這類描述

### 配速格式
所有配速欄位都使用 `"mm:ss"` 格式，例如：
- `"4:30"` (4分30秒/公里)
- `"6:15"` (6分15秒/公里)

### 訓練類型對應
- `GeneralTraining` 用於大部分基礎訓練類型
- `IntervalTraining` 專用於間歇訓練
- `SegmentTraining` 專用於分段變速跑
- `RaceTraining` 專用於賽事
- `RestTraining` 專用於休息日

### 週跑量計算
系統會自動計算 `total_distance_km`，計算邏輯：
- 一般訓練：使用 `distance_km`
- 間歇訓練：`(work.distance_km + recovery.distance_km) × repeats`
- 恢復段 `distance_km` 為 `null` 時不計入總距離
- 分段訓練：使用 `total_distance_km` 或所有 segments 的距離總和

### 前端顯示建議
1. **間歇訓練顯示格式**:
   - 慢跑恢復: `"6 × (400m快跑 + 200m慢跑恢復)"`
   - 靜止休息: `"6 × (400m快跑 + 3分鐘全休)"`

2. **欄位驗證**:
   - 所有必填欄位需要前端驗證
   - 配速格式需要正規表達式驗證
   - 數值欄位需要範圍驗證

3. **條件性欄位**:
   - 根據 `training_type` 動態顯示對應的 `training_details` 結構
   - 間歇訓練的 `recovery.distance_km` 為 `null` 時隱藏配速輸入框