# Training v2 API Integration 指南

完整的 Training v2 API 文檔，涵蓋 Overview、Weekly Plan、Weekly Summary 三大核心端點。

---

## 📋 快速導覽

- **Overview API**: 生成訓練計畫概覽，支援多種目標類型
- **Weekly Plan API**: 生成週課表
- **Weekly Summary API**: 生成週訓練摘要與建議

---

## 1️⃣ Overview API (計畫概覽)

### 端點

```
POST /v2/plan/overview
GET /v2/plan/overview
PUT /v2/plan/overview/<overview_id>
POST /v2/plan/overview/preview
```

### 功能

生成新的訓練計畫概覽，支援三種模式：
- **賽事模式** (race_run)：基於賽事目標的完整計畫
- **初心者模式** (beginner)：完成 10K 訓練
- **維持模式** (maintenance)：有氧/平衡訓練

### 1.1 建立計畫概覽 - `POST /v2/plan/overview`

#### Request Body

**模式 1: 賽事模式 (race_run)**

```json
{
    "target_id": "xxx",              // 必填：目標 ID
    "start_from_stage": "base"       // 可選，預設 "base"
}
```

**模式 2: 非賽事模式 (beginner/maintenance)**

```json
{
    "target_type": "beginner",       // 必填：目標類型
    "training_weeks": 8,             // 必填：訓練週數
    "available_days": 5,             // 可選：每週可訓練天數，預設 5
    "methodology_id": "complete_10k",// 可選：方法論 ID
    "start_from_stage": "base"       // 可選，預設 "base"
}
```

#### Response

**Status**: 200 OK

**Data Model**: `PlanOverviewV2`
- **Pydantic 路徑**: `data_models/plan_overview_v2.py:119`

**核心欄位**:

```
- id: str                              計畫 ID
- target_id: Optional[str]             目標 ID（race_run 必填）
- target_type: str                     目標類型 (race_run, beginner, maintenance)
- target_description: Optional[str]    目標描述（非賽事目標使用）
- methodology_id: str                  方法論 ID (paceriz, complete_10k, ...)
- total_weeks: int                     總訓練週數

# ⭐ V2.0 新增：嵌入的 Target 核心字段
- race_date: Optional[int]             比賽日期（UTC timestamp）
- distance_km: Optional[float]         賽事距離
- target_pace: Optional[str]           目標配速 (MM:SS 格式)
- target_time: Optional[int]           目標時間（秒）
- is_main_race: Optional[bool]         是否為主要賽事
- target_name: Optional[str]           目標/賽事名稱

# 方法論和評估
- methodology_overview: Optional[MethodologyOverview]  方法論概覽
- target_evaluate: str                 對目標的評估
- approach_summary: str                如何達到目標的概要（≤200 字）
- training_stages: List[TrainingStage] 訓練階段列表
- milestones: List[Milestone]          里程碑列表
- weekly_preview: List[WeeklyPreview]  週訓練預覽

# Metadata
- created_at: Optional[datetime]       創建時間
- methodology_version: str             方法論版本
- start_from_stage: str                開始階段
```

**Response 範例**:

```json
{
    "success": true,
    "data": {
        "id": "overview_xyz_20250101",
        "target_id": "target_123",
        "target_type": "race_run",
        "methodology_id": "paceriz",
        "total_weeks": 12,
        "race_date": 1704067200,
        "distance_km": 21.1,
        "target_pace": "4:30",
        "target_time": 5670,
        "methodology_overview": {
            "name": "Paceriz 訓練方法論",
            "philosophy": "科學配速訓練",
            "intensity_style": "polarized",
            "intensity_description": "75% 低強度 / 20% 中強度 / 5% 高強度"
        },
        "target_evaluate": "基於目前能力...",
        "approach_summary": "透過 12 週的漸進式訓練...",
        "training_stages": [
            {
                "stage_id": "base",
                "stage_name": "基礎期",
                "week_start": 1,
                "week_end": 4,
                "training_focus": "建立有氧基礎",
                "target_weekly_km_range": { "low": 30, "high": 45 }
            }
        ],
        "milestones": [...],
        "weekly_preview": [...],
        "created_at": "2025-01-01T00:00:00Z"
    }
}
```

### 1.2 獲取計畫概覽 - `GET /v2/plan/overview`

#### Request

```
GET /v2/plan/overview
```

#### Response

返回用戶當前的 active 計畫概覽，格式同上。

**Status Codes**:
- `200 OK`: 成功
- `404 Not Found`: 無 active 訓練計畫

### 1.3 更新計畫概覽 - `PUT /v2/plan/overview/<overview_id>`

#### Request Body

```json
{
    "start_from_stage": "base"       // 可選，預設 "base"
}
```

**用途**: 當用戶修改目標賽事（日期、配速等）時，重新生成概覽。原始 `created_at` 保留作為週數計算基準。

#### Response

返回更新後的 `PlanOverviewV2`，同上。

### 1.4 預覽 Prompt - `POST /v2/plan/overview/preview`

#### Request Body

```json
{
    "training_weeks": 12,
    "target_type": "race_run",
    "methodology_id": "paceriz"
}
```

#### Response

```json
{
    "success": true,
    "data": {
        "prompt": "完整的 LLM prompt 內容...",
        "context": {
            "target_type": "race_run",
            "methodology_id": "paceriz",
            "training_weeks": 12
        }
    }
}
```

**用途**: Debug 用，查看傳送給 LLM 的確切 prompt。

---

## 2️⃣ Weekly Plan API (週課表)

### 端點

```
POST /v2/plan/weekly
```

### 功能

生成指定週次的週訓練課表。

### Request Body

```json
{
    "week_of_training": 5,           // 必填：週次（1-based）
    "force_generate": false,         // 可選：強制重新生成，預設 False
    "prompt_version": "v2",          // 可選：prompt 版本，預設 "v2"
    "methodology": "paceriz"         // 可選：方法論，預設 "paceriz"
}
```

### Response

**Status**: 200 OK

**Data Model**: `WeeklyPlanV2Response`
- **Pydantic 路徑**: `data_models/weekly_plan_v2_response.py:11`
- **基於**: `WeeklyTrainingPlan` (繼承所有欄位)

**Response 格式** (完整 WeeklyTrainingPlan + plan_id):

```json
{
    "success": true,
    "data": {
        "plan_id": "overview_xyz_week_5",
        "week_of_training": 5,

        // ✅ 完整的 WeeklyTrainingPlan 欄位
        "purpose": "第 5 週：建立有氧基礎，增加耐力",
        "days": [
            {
                "day_index": 1,
                "training_type": "easy_run",
                "day_target": "輕鬆跑恢復",
                "reason": "週一輕鬆跑幫助身體恢復",
                "training_details": {
                    "distance_km": 6.0,
                    "time_minutes": 36,
                    "pace": "6:00",
                    "description": "6公里輕鬆跑"
                }
            }
        ],
        "total_distance_km": 45,
        "total_distance_reason": "比上週增加3公里",
        "design_reason": ["循序漸進增加跑量"],
        "intensity_total_minutes": {
            "low": 144,
            "medium": 44,
            "high": 12
        },

        // 🔮 預留擴展欄位（未來版本）
        "training_load_analysis": null,      // v2.1+ 預留
        "personalized_recommendations": null, // v2.2+ 預留
        "real_time_adjustments": null,       // v2.3+ 預留

        // 版本信息
        "_api_version": "2.0"
    }
}
```

**核心欄位**（WeeklyPlanV2Response - 繼承自 WeeklyTrainingPlan）:

```
// 核心訓練計畫欄位
- plan_id: str                           週課表 ID (格式: {overview_id}_{week_number})
- purpose: str                           當週具體的訓練目的
- days: List[DayDetail]                  訓練日陣列（7 天完整資料）
- total_distance_km: int/float           週跑量
- total_distance_reason: str             當週跑量決定方式說明
- design_reason: List[str]               安排理由列表
- intensity_total_minutes: IntensityMinutes  強度分鐘數分布 {low, medium, high}
- week_of_plan: Optional[int]            當前週數
- total_weeks: Optional[int]             總訓練週數

// 🔮 預留擴展欄位（未來版本可啟用）
- training_load_analysis: Optional[Dict]  訓練負荷分析（v2.1+ 預留）
- personalized_recommendations: Optional[Dict]  個性化建議（v2.2+ 預留）
- real_time_adjustments: Optional[Dict]   實時調整建議（v2.3+ 預留）
- _api_version: str                       API 回應版本 (默認 "2.0")
```

### Status Codes

- `200 OK`: 成功
- `400 Bad Request`: 參數錯誤
- `500 Internal Server Error`: 服務錯誤

---

## 3️⃣ Weekly Summary API (週摘要)

### 端點

```
POST /v2/summary/weekly
GET /v2/summary/weekly
POST /v2/summary/weekly/preview
POST /v2/summary/confirm-recommendation
POST /v2/summary/apply-recommendations-via-coordinator
```

### 功能

生成週訓練摘要、分析、建議等，並支援建議客製化。

### 3.1 建立週摘要 - `POST /v2/summary/weekly`

#### Request Body

```json
{
    "week_of_plan": 8,               // 必填：第幾週
    "force_update": false            // 可選：強制更新，預設 False
}
```

#### Response

**Status**: 200 OK

**Data Model**: `WeeklySummaryV2`
- **Pydantic 路徑**: `data_models/weekly_summary_v2.py:513`

**核心欄位**:

```
- id: str                                        週摘要 ID
- uid: str                                       用戶 ID
- weekly_plan_id: str                            關聯的週課表 ID
- training_overview_id: str                      關聯的計畫 ID
- week_of_training: int                          訓練週次

# 計畫上下文 (PlanContextSummary)
- plan_context:
    - target_type: str                           目標類型
    - methodology_id: str                        方法論 ID
    - methodology_name: str                      方法論名稱
    - current_phase: str                         當前訓練階段
    - phase_week: int                            當前階段第幾週
    - weeks_remaining: int                       剩餘週數
    - upcoming_milestone: Optional[MilestoneRef] 即將到來的里程碑

# 訓練完成度 (TrainingCompletionV2)
- training_completion:
    - percentage: float                          完成百分比 (0-100+)
    - planned_km: float                          計畫公里數
    - completed_km: float                        完成公里數
    - planned_sessions: int                      計畫課次
    - completed_sessions: int                    完成課次
    - evaluation: str                            綜合評估

# 訓練分析 (TrainingAnalysisV2)
- training_analysis:
    - heart_rate: Optional[HeartRateAnalysisV2]      心率分析
    - pace: Optional[PaceAnalysisV2]                 配速分析
    - distance: Optional[DistanceAnalysisV2]         距離分析
    - intensity_distribution: Optional[...]          強度分布分析

# Readiness 指標 (ReadinessSummary)
- readiness_summary:  # 根據 target_type 選擇性填充
    - speed: Optional[SpeedSummary]                  配速分析 (race_run, maintenance)
    - endurance: Optional[EnduranceSummary]          耐力分析 (race_run, maintenance)
    - training_load: Optional[TrainingLoadSummary]   訓練負荷 (race_run only)
    - race_fitness: Optional[RaceFitnessSummary]     賽事適應度 (race_run only)
    - mileage: Optional[MileageSummary]              跑量完成度 (beginner only)
    - overall_readiness_score: Optional[float]       綜合 readiness 分數
    - overall_status: Optional[str]                  綜合狀態
    - flags: List[ReadinessFlag]                     警示旗標

# 能力進展 (CapabilityProgression)
- capability_progression:
    - vdot_progression: Optional[VdotProgression]    VDOT 進展 (race_run)
    - speed_progression: Optional[MetricProgression] 配速進展
    - endurance_progression: Optional[...]           耐力進展
    - overall_trend: str                             整體趨勢
    - evaluation: str                                評估說明

# 里程碑進度 (MilestoneProgress)
- milestone_progress:
    - achieved_milestones: List[MilestoneRef]       已達成里程碑
    - upcoming_milestones: List[MilestoneRef]       即將到來的里程碑
    - current_phase_completion: float                當前階段完成度

# 歷史對比 (HistoricalComparisonSummary)
- historical_comparison:
    - has_comparison_data: bool                      是否有對比數據
    - comparison_week: Optional[int]                 對比週次
    - speed_change: Optional[float]                  配速變化百分比
    - endurance_change: Optional[float]              耐力變化百分比
    - vdot_change: Optional[float]                   VDOT 變化
    - mileage_change: Optional[float]                跑量變化百分比
    - environmental_comparison: Optional[...]        環境因素對比

# 週亮點 (WeeklyHighlightsV2)
- weekly_highlights:
    - highlights: List[str]                          當週亮點
    - achievements: List[str]                        成就
    - areas_for_improvement: List[str]               改進空間

# 賽事評估 (race_run only)
- upcoming_race_evaluation: Optional[UpcomingRaceEvaluationV2]
    - race_name: str                                 賽事名稱
    - race_date: str                                 賽事日期
    - days_remaining: int                            距離賽事天數
    - readiness_score: float                         準備度分數 (0-100)
    - readiness_assessment: str                      準備度評估
    - predicted_time: Optional[str]                  預測成績
    - target_time: Optional[str]                     目標成績
    - key_concerns: List[str]                        主要關注

# 下週調整建議 (NextWeekAdjustmentsV2)
- next_week_adjustments:
    - items: List[AdjustmentItemV2]                  調整項目
        - content: str                               調整內容
        - category: str                              分類 (volume, intensity, recovery, general)
        - apply: bool                                是否套用
        - reason: str                                原因
        - impact: str                                影響
        - priority: str                              優先級
    - summary: str                                   總結
    - customization_recommendations: List[...]       客製化建議 (FRD-04-01)
        - recommendation_type: str                   建議類型 (training_type, volume, intensity, recovery, rest_week)
        - slot_type: Optional[str]                   Slot 類型 (training_type)
        - original_type: Optional[str]               原始類型
        - recommended_type: Optional[str]            建議類型
        - current_value: Optional[str]               當前值
        - recommended_value: Optional[str]           建議值
        - adjustment_percentage: Optional[float]     調整百分比
        - reason: str                                原因
        - confidence: float                          信心度 (0-1)

# 休息週建議
- rest_week_recommendation: Optional[RestWeekAssessment]
    - recommended: bool                              是否推薦休息週
    - reason: Optional[str]                          原因
    - fatigue_indicators: List[str]                  疲勞指標

# 最終訓練回顧 (最終週次時填充)
- final_training_review: Optional[FinalTrainingReview]
    - journey_summary: str                           訓練旅程總結
    - capability_growth: str                         能力提升總結
    - key_milestones: List[str]                      關鍵里程碑
    - race_performance_evaluation: str               賽事表現評估
    - encouragement: str                             鼓勵語句
    - next_steps_guidance: str                       下一步建議
```

**Response 範例**:

```json
{
    "success": true,
    "data": {
        "id": "week_8_paceriz",
        "uid": "user_123",
        "week_of_training": 8,
        "plan_context": {
            "target_type": "race_run",
            "methodology_id": "paceriz",
            "current_phase": "build",
            "weeks_remaining": 4
        },
        "training_completion": {
            "percentage": 105,
            "planned_km": 50,
            "completed_km": 52.5,
            "planned_sessions": 5,
            "completed_sessions": 5,
            "evaluation": "超額完成，訓練積極度高"
        },
        "readiness_summary": {
            "speed": {
                "score": 85,
                "trend": "improving",
                "evaluation": "配速穩定進步"
            },
            "race_fitness": {
                "score": 88,
                "current_vdot": 52.5,
                "target_vdot": 54.0,
                "progress_percentage": 97,
                "estimated_race_time": "1:54:30"
            }
        },
        "next_week_adjustments": {
            "items": [...],
            "customization_recommendations": [
                {
                    "recommendation_type": "training_type",
                    "slot_type": "interval",
                    "original_type": "track_intervals",
                    "recommended_type": "fartlek",
                    "reason": "多次無法完成操場間歇，建議改為 Fartlek",
                    "confidence": 0.85
                }
            ]
        }
    }
}
```

### 3.2 獲取週摘要 - `GET /v2/summary/weekly`

#### Request

```
GET /v2/summary/weekly?week_of_plan=8
```

#### Response

返回指定週次的摘要，格式同上。

**Query Parameters**:
- `week_of_plan` (required): 第幾週

**Status Codes**:
- `200 OK`: 成功
- `400 Bad Request`: week_of_plan 缺失或無效
- `404 Not Found`: 摘要不存在

### 3.3 預覽 Summary Prompt - `POST /v2/summary/weekly/preview`

#### Request Body

```json
{
    "week_of_plan": 8
}
```

#### Response

```json
{
    "success": true,
    "data": {
        "prompt": "完整的 LLM prompt...",
        "prompt_length": 4500,
        "builder_id": "summary_builder_race_run",
        "target_type": "race_run",
        "methodology_id": "paceriz",
        "context": {
            "uid": "user_123",
            "week_of_training": 8,
            "has_readiness_metrics": true,
            "has_weekly_training": true
        }
    }
}
```

### 3.4 確認建議 - `POST /v2/summary/confirm-recommendation`

#### 功能

當用戶接受 Weekly Summary 中的 customization_recommendations 時調用此 API，建議會被保存到 CustomizationService，並在下週課表生成時自動應用。

#### Request Body - 訓練類型建議

```json
{
    "recommendation_type": "training_type",
    "slot_type": "interval",
    "original_type": "track_intervals",
    "recommended_type": "fartlek",
    "reason": "用戶多次無法完成操場間歇",
    "source": "weekly_summary"
}
```

#### Request Body - 跑量調整

```json
{
    "recommendation_type": "volume",
    "adjustment_percentage": -10,
    "reason": "訓練負荷過高",
    "source": "weekly_summary"
}
```

#### Request Body - 強度調整

```json
{
    "recommendation_type": "intensity",
    "adjustment_percentage": -5,
    "target_zones": ["zone3", "zone4"],
    "reason": "需要更多恢復",
    "source": "weekly_summary"
}
```

#### Request Body - 恢復調整

```json
{
    "recommendation_type": "recovery",
    "preferred_recovery_days": [2, 5],
    "min_recovery_hours": 48,
    "reason": "工作日較難恢復",
    "source": "weekly_summary"
}
```

#### Request Body - 休息週調整

```json
{
    "recommendation_type": "rest_week",
    "frequency_weeks": 4,
    "volume_reduction": 0.6,
    "reason": "需要更頻繁的休息",
    "source": "weekly_summary"
}
```

#### Response

```json
{
    "success": true,
    "message": "Customization saved successfully",
    "customization": {
        "methodology_id": "paceriz",
        "training_type_preferences": {...},
        "updated_by": "weekly_summary_recommendation"
    }
}
```

### 3.5 Coordinator 應用建議 - `POST /v2/summary/apply-recommendations-via-coordinator`

#### 功能

透過 Conflict Coordinator 應用建議到 Customization。這是 Summary → Customization 整合的核心端點。

#### Request Body

```json
{
    "week_of_plan": 8,                           // 必填
    "user_input": "我想減少長距離跑，增加間歇訓練",  // 可選
    "apply_summary_recommendations": true,       // 可選
    "lang": "zh-TW"                              // 可選
}
```

**注意**: `user_input` 和 `apply_summary_recommendations` 至少要提供一個

#### Response

```json
{
    "success": true,
    "decision": {
        "conflict_analysis": {
            "has_conflict": false,
            "conflicts": []
        },
        "final_decision": {
            "training_type_adjustments": [
                {
                    "slot_type": "interval",
                    "action": "replace",
                    "new_type": "fartlek",
                    "reason": "適合目前訓練階段"
                }
            ],
            "volume_adjustment": {
                "action": "keep",
                "reason": "當前跑量適中"
            }
        },
        "user_message": {
            "summary": "已根據您的偏好調整訓練計畫",
            "explanation": "將間歇訓練從操場間歇改為 Fartlek...",
            "rejected_requests": [],
            "alternatives": []
        }
    },
    "customization": {
        "methodology_id": "paceriz",
        "training_type_preferences": {...},
        "updated_by": "coordinator_adjustment"
    }
}
```

---

## 🎯 ReadinessSummary 根據 target_type 選擇性填充

### race_run 類型

包含以下 Readiness 指標：
- **speed** → `SpeedSummary`
  - `score`: 配速分數 (0-100)
  - `achievement_rate`: 配速達成率
  - `trend`: 趨勢 (improving, stable, declining)
  - `evaluation`: 評估說明

- **endurance** → `EnduranceSummary`
  - `score`: 耐力分數
  - `avg_esc`: Endurance Stability Coefficient
  - `long_run_completion`: 長跑完成率
  - `volume_consistency`: 跑量一致性

- **training_load** → `TrainingLoadSummary`（race_run only）
  - `score`: 訓練負荷分數
  - `current_tsb`: 當前 TSB (Training Stress Balance)
  - `ctl`: Chronic Training Load
  - `atl`: Acute Training Load
  - `is_in_optimal_range`: 是否在最佳範圍

- **race_fitness** → `RaceFitnessSummary`（race_run only）
  - `score`: 賽事適應度分數
  - `current_vdot`: 當前 VDOT
  - `target_vdot`: 目標 VDOT
  - `progress_percentage`: 進度百分比
  - `estimated_race_time`: 預估比賽時間

### beginner 類型

包含以下 Readiness 指標：
- **mileage** → `MileageSummary`
  - `planned_km`: 計畫公里數
  - `completed_km`: 完成公里數
  - `completion_rate`: 完成率 (0-100%)
  - `streak_weeks`: 連續達標週數

- **speed** → `SpeedSummary`
  - 同上

### maintenance 類型

包含以下 Readiness 指標：
- **endurance** → `EnduranceSummary`
  - 同上

- **speed** → `SpeedSummary`（如果使用 speed_endurance 方法論）
  - 同上

---

## 📦 重要 Model 路徑對照表

| 用途 | Pydantic Model 路徑 | 主類名稱 |
|------|-------------------|---------|
| Plan Overview V2 | [data_models/plan_overview_v2.py](../../data_models/plan_overview_v2.py) | `PlanOverviewV2` |
| Weekly Plan V2 (API Response) | [data_models/weekly_plan_v2_response.py](../../data_models/weekly_plan_v2_response.py) | `WeeklyPlanV2Response` |
| Weekly Plan V2 (Storage) | [data_models/weekly_plan_v2.py](../../data_models/weekly_plan_v2.py) | `WeeklyPlanV2` |
| Weekly Summary V2 | [data_models/weekly_summary_v2.py](../../data_models/weekly_summary_v2.py) | `WeeklySummaryV2` |
| Plan Enums | [data_models/plan_enums.py](../../data_models/plan_enums.py) | `StageType`, `MilestoneType` |
| Methodology Customization | [data_models/methodology_customization.py](../../data_models/methodology_customization.py) | `TrainingTypePreference`, `VolumeAdjustment` 等 |
| Conflict Coordinator Models | [data_models/conflict_coordinator_models.py](../../data_models/conflict_coordinator_models.py) | `ConflictCoordinatorDecision` |

---

## 📐 V2 API 設計說明

### 回應格式設計原則

**方案：完整格式 + 預留擴展欄位**

V2 API 返回格式採用以下設計：

1. **核心：完整的 WeeklyTrainingPlan 資料**
   - 與 V1 API 相容的欄位結構
   - 包含所有訓練詳情 (`days`, `purpose`, `design_reason` 等)
   - 便於客戶端統一處理

2. **擴展：預留可選欄位**
   - `training_load_analysis` (v2.1+ 預留)
   - `personalized_recommendations` (v2.2+ 預留)
   - `real_time_adjustments` (v2.3+ 預留)
   - 目前都為 `null`，未來版本啟用時會填充資料

3. **版本追蹤：`_api_version` 欄位**
   - 當前值：`"2.0"`
   - 便於客戶端檢測 API 版本
   - 未來升級時更新版本號

### 未來擴展計劃

| 版本 | 功能 | 欄位 | 狀態 |
|------|------|------|------|
| 2.0 | 基礎週課表 | `days`, `purpose` 等 | ✅ 已實現 |
| 2.1 | 訓練負荷分析 | `training_load_analysis` | 🔮 規劃中 |
| 2.2 | 個性化建議 | `personalized_recommendations` | 🔮 規劃中 |
| 2.3 | 實時調整 | `real_time_adjustments` | 🔮 規劃中 |

### 向下相容性

- ✅ 客戶端可以忽略預留欄位（都是 `null`）
- ✅ 現有程式碼無需修改
- ✅ 新欄位在啟用時自動填充

### Model 位置

Pydantic Model 位置：[data_models/weekly_plan_v2_response.py](../../data_models/weekly_plan_v2_response.py)

---

## 🔄 API 端點完整列表

| 方法 | 端點 | 功能 | 回應 Model |
|------|------|------|-----------|
| POST | `/v2/plan/overview` | 創建計畫概覽 | `PlanOverviewV2` |
| GET | `/v2/plan/overview` | 獲取 active 計畫 | `PlanOverviewV2` |
| PUT | `/v2/plan/overview/<id>` | 更新計畫概覽 | `PlanOverviewV2` |
| POST | `/v2/plan/overview/preview` | 預覽 prompt | JSON (prompt + context) |
| POST | `/v2/plan/weekly` | 生成週課表 | `WeeklyPlanV2Response` |
| POST | `/v2/summary/weekly` | 生成週摘要 | `WeeklySummaryV2` |
| GET | `/v2/summary/weekly` | 獲取週摘要 | `WeeklySummaryV2` |
| POST | `/v2/summary/weekly/preview` | 預覽 Summary prompt | JSON (prompt + context) |
| POST | `/v2/summary/confirm-recommendation` | 確認客製化建議 | Success message |
| POST | `/v2/summary/apply-recommendations-via-coordinator` | Coordinator 應用建議 | Decision + Customization |

---

## 💾 Firestore 數據存儲位置

| 資料類型 | 路徑 |
|---------|------|
| Plan Overview V2 | `users/{uid}/plan_overviews_v2/{overview_id}` |
| Weekly Plan V2 | `users/{uid}/weekly_plans_v2/{plan_id}` |
| Weekly Summary V2 | `users/{uid}/weekly_summaries_v2/{summary_id}` |
| Methodology Customization | `users/{uid}/methodology_customizations/{methodology_id}` |

---

## 🛠️ 關鍵特性

✅ **Dual-Dimensional Model**: target_type + methodology_id 雙維度支援
✅ **自動 LLM Output 驗證**: 內建 type fixing 機制，自動修正 LLM 生成的類型錯誤
✅ **選擇性欄位填充**: 根據 target_type 決定包含哪些 Readiness 指標
✅ **事件驅動架構**: 通過 Milestones 連接 Overview ↔ Weekly Plan ↔ Summary
✅ **客製化整合**: CustomizationRecommendation 支援 5 種調整類型 (training_type, volume, intensity, recovery, rest_week)
✅ **Conflict Resolution**: Coordinator 自動分析衝突並生成決策

---

## 📖 相關文檔

- [FRD-04-weekly-summary-v2.md](../../04-frds/)
- [COMPLETE_REFACTOR_SUMMARY.md](../../architecture/)
- [LAZY_SINGLETON_QUICK_REF.md](../../guides/)
- [TESTING_GUIDELINES.md](../../03-testing/)

---

**最後更新**: 2025-01-17
