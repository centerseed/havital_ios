# 前端起始階段推薦演算法

## 概述

提供前端（iOS/Android/Web）可直接使用的起始階段推薦演算法，與後端邏輯保持一致。

## 方案比較

| 方案 | 優點 | 缺點 | 使用場景 |
|------|------|------|----------|
| **後端 API** | ✅ 權威來源<br>✅ 邏輯統一<br>✅ 易於更新 | ❌ 需要網路請求<br>❌ 響應延遲 | 創建訓練計劃時 |
| **前端演算法** | ✅ 即時計算<br>✅ 無網路依賴<br>✅ 流暢體驗 | ❌ 需要同步更新<br>❌ 可能不一致 | UI 即時預覽 |

**建議**: 結合使用
- UI 預覽：使用前端演算法（即時響應）
- 最終提交：呼叫後端 API（確保一致性）

---

## TypeScript/JavaScript 實現

```typescript
/**
 * 訓練起始階段類型
 */
type StartStage = 'conversion' | 'base' | 'build' | 'peak' | 'taper';

/**
 * 風險等級
 */
type RiskLevel = 'low' | 'medium' | 'high';

/**
 * 推薦結果介面
 */
interface StartStageRecommendation {
  recommendedStage: StartStage;
  stageName: string;
  reason: string;
  riskLevel: RiskLevel;
  weeksRemaining: number;
  alternatives: Array<{
    stage: StartStage;
    stageName: string;
    suitableFor: string;
    riskLevel: RiskLevel;
    description: string;
  }>;
  trainingDistribution: {
    conversionWeeks: number;
    baseWeeks: number;
    buildWeeks: number;
    peakWeeks: number;
    taperWeeks: number;
  };
  isFullMarathon: boolean;
}

/**
 * 階段名稱映射
 */
const stageNames: Record<StartStage, string> = {
  conversion: '轉換期',
  base: '基礎期',
  build: '增強期',
  peak: '巔峰期',
  taper: '減量期'
};

/**
 * 計算訓練階段週數分配
 *
 * @param trainingWeeks 總訓練週數
 * @param targetDistanceKm 目標距離（公里）
 * @param startFromStage 起始階段
 * @returns 各階段週數分配
 */
function calculateTrainingPeriods(
  trainingWeeks: number,
  targetDistanceKm: number,
  startFromStage: StartStage = 'base'
): {
  conversionWeeks: number;
  baseWeeks: number;
  buildWeeks: number;
  peakWeeks: number;
  taperWeeks: number;
} {
  const isFullMarathon = targetDistanceKm > 21.1;

  // 這裡簡化實現，完整邏輯參考後端
  let conversionWeeks = 0;
  let baseWeeks = 0;
  let buildWeeks = 0;
  let peakWeeks = 0;
  let taperWeeks = isFullMarathon ? 2 : 1;

  // 根據起始階段調整
  const remainingWeeks = trainingWeeks - taperWeeks;

  if (startFromStage === 'build') {
    // 從增強期開始：平均分配 build 和 peak
    buildWeeks = Math.min(6, Math.round(remainingWeeks / 2));
    peakWeeks = remainingWeeks - buildWeeks;
  } else if (startFromStage === 'peak') {
    // 從巔峰期開始：全部給 peak
    peakWeeks = remainingWeeks;
  } else if (startFromStage === 'base') {
    // 從基礎期開始：預設分配
    if (trainingWeeks <= 8) {
      baseWeeks = 2;
      buildWeeks = 3;
      peakWeeks = 2;
    } else {
      // 簡化：按比例分配
      baseWeeks = Math.floor(remainingWeeks * 0.4);
      buildWeeks = Math.floor(remainingWeeks * 0.3);
      peakWeeks = remainingWeeks - baseWeeks - buildWeeks;
    }
  }

  return {
    conversionWeeks,
    baseWeeks,
    buildWeeks,
    peakWeeks,
    taperWeeks
  };
}

/**
 * 推薦訓練起始階段
 *
 * @param weeksRemaining 距離比賽剩餘週數
 * @param targetDistanceKm 目標距離（公里）
 * @returns 推薦結果
 */
export function recommendStartStage(
  weeksRemaining: number,
  targetDistanceKm: number = 21.1
): StartStageRecommendation {
  // 推薦邏輯
  let recommendedStage: StartStage;
  let riskLevel: RiskLevel;
  let reason: string;

  if (weeksRemaining <= 4) {
    recommendedStage = 'peak';
    riskLevel = 'high';
    reason = `您只有 ${weeksRemaining} 週時間準備比賽，建議直接進入巔峰期，專注於高強度比賽準備訓練。注意：這需要您已具備良好的訓練基礎。`;
  } else if (weeksRemaining <= 8) {
    recommendedStage = 'build';
    riskLevel = 'medium';
    reason = `您有 ${weeksRemaining} 週時間準備比賽，建議從增強期開始，這樣可以平衡速度發展和比賽準備，是最理想的選擇。`;
  } else if (weeksRemaining <= 12) {
    recommendedStage = 'build';
    riskLevel = 'low';
    reason = `您有 ${weeksRemaining} 週的準備時間，建議從增強期開始。如果您是初跑者或需要建立有氧基礎，也可以考慮從基礎期開始。`;
  } else {
    recommendedStage = 'base';
    riskLevel = 'low';
    reason = `您有充足的 ${weeksRemaining} 週準備時間，建議從基礎期開始完整的訓練週期，循序漸進地建立有氧基礎、發展速度和進行比賽準備。`;
  }

  // 計算週數分配
  const distribution = calculateTrainingPeriods(
    weeksRemaining,
    targetDistanceKm,
    recommendedStage
  );

  // 生成替代選項
  const alternatives: Array<{
    stage: StartStage;
    stageName: string;
    suitableFor: string;
    riskLevel: RiskLevel;
    description: string;
  }> = [];

  if (recommendedStage === 'build') {
    alternatives.push({
      stage: 'peak',
      stageName: stageNames['peak'],
      suitableFor: '訓練充分的資深跑者',
      riskLevel: 'high',
      description: '適合每週跑量 40km+ 且近期有比賽經驗的跑者'
    });

    if (weeksRemaining >= 10) {
      alternatives.push({
        stage: 'base',
        stageName: stageNames['base'],
        suitableFor: '初跑者或需要建立基礎的跑者',
        riskLevel: 'low',
        description: '從頭開始建立有氧基礎和跑量'
      });
    }
  } else if (recommendedStage === 'peak') {
    alternatives.push({
      stage: 'build',
      stageName: stageNames['build'],
      suitableFor: '有訓練基礎的跑者',
      riskLevel: 'low',
      description: '更安全的選擇，可以有時間發展速度能力'
    });
  } else if (recommendedStage === 'base') {
    alternatives.push({
      stage: 'build',
      stageName: stageNames['build'],
      suitableFor: '有訓練基礎的跑者',
      riskLevel: 'medium',
      description: '如果您已經有週跑量 20-30km，可以跳過基礎期'
    });
  }

  return {
    recommendedStage,
    stageName: stageNames[recommendedStage],
    reason,
    riskLevel,
    weeksRemaining,
    alternatives,
    trainingDistribution: {
      conversionWeeks: distribution.conversionWeeks,
      baseWeeks: distribution.baseWeeks,
      buildWeeks: distribution.buildWeeks,
      peakWeeks: distribution.peakWeeks,
      taperWeeks: distribution.taperWeeks
    },
    isFullMarathon: targetDistanceKm > 21.1
  };
}

// 使用範例
const recommendation = recommendStartStage(9, 21.1);
console.log(recommendation);
/*
輸出:
{
  recommendedStage: 'build',
  stageName: '增強期',
  reason: '您有 9 週時間準備比賽，建議從增強期開始...',
  riskLevel: 'medium',
  weeksRemaining: 9,
  alternatives: [...],
  trainingDistribution: {
    buildWeeks: 4,
    peakWeeks: 4,
    taperWeeks: 1,
    ...
  },
  isFullMarathon: false
}
*/
```

---

## Swift (iOS) 實現

```swift
import Foundation

/// 訓練起始階段
enum StartStage: String, Codable {
    case conversion
    case base
    case build
    case peak
    case taper

    var displayName: String {
        switch self {
        case .conversion: return "轉換期"
        case .base: return "基礎期"
        case .build: return "增強期"
        case .peak: return "巔峰期"
        case .taper: return "減量期"
        }
    }
}

/// 風險等級
enum RiskLevel: String, Codable {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
}

/// 訓練週數分配
struct TrainingDistribution: Codable {
    let conversionWeeks: Int
    let baseWeeks: Int
    let buildWeeks: Int
    let peakWeeks: Int
    let taperWeeks: Int
}

/// 替代選項
struct StageAlternative: Codable {
    let stage: StartStage
    let stageName: String
    let suitableFor: String
    let riskLevel: RiskLevel
    let description: String
}

/// 推薦結果
struct StartStageRecommendation: Codable {
    let recommendedStage: StartStage
    let stageName: String
    let reason: String
    let riskLevel: RiskLevel
    let weeksRemaining: Int
    let alternatives: [StageAlternative]
    let trainingDistribution: TrainingDistribution
    let isFullMarathon: Bool
}

/// 訓練起始階段推薦器
class StartStageRecommender {

    /// 計算訓練階段週數分配
    static func calculateTrainingPeriods(
        trainingWeeks: Int,
        targetDistanceKm: Double,
        startFromStage: StartStage = .base
    ) -> TrainingDistribution {
        let isFullMarathon = targetDistanceKm > 21.1
        let taperWeeks = isFullMarathon ? 2 : 1
        let remainingWeeks = trainingWeeks - taperWeeks

        var conversionWeeks = 0
        var baseWeeks = 0
        var buildWeeks = 0
        var peakWeeks = 0

        switch startFromStage {
        case .build:
            // 從增強期開始：平均分配 build 和 peak
            buildWeeks = min(6, Int(round(Double(remainingWeeks) / 2.0)))
            peakWeeks = remainingWeeks - buildWeeks

        case .peak:
            // 從巔峰期開始：全部給 peak
            peakWeeks = remainingWeeks

        case .base:
            // 從基礎期開始：預設分配
            if trainingWeeks <= 8 {
                baseWeeks = 2
                buildWeeks = 3
                peakWeeks = 2
            } else {
                baseWeeks = Int(Double(remainingWeeks) * 0.4)
                buildWeeks = Int(Double(remainingWeeks) * 0.3)
                peakWeeks = remainingWeeks - baseWeeks - buildWeeks
            }

        default:
            break
        }

        return TrainingDistribution(
            conversionWeeks: conversionWeeks,
            baseWeeks: baseWeeks,
            buildWeeks: buildWeeks,
            peakWeeks: peakWeeks,
            taperWeeks: taperWeeks
        )
    }

    /// 推薦訓練起始階段
    static func recommend(
        weeksRemaining: Int,
        targetDistanceKm: Double = 21.1
    ) -> StartStageRecommendation {
        // 推薦邏輯
        let (recommendedStage, riskLevel, reason): (StartStage, RiskLevel, String)

        if weeksRemaining <= 4 {
            recommendedStage = .peak
            riskLevel = .high
            reason = "您只有 \(weeksRemaining) 週時間準備比賽，建議直接進入巔峰期，專注於高強度比賽準備訓練。注意：這需要您已具備良好的訓練基礎。"
        } else if weeksRemaining <= 8 {
            recommendedStage = .build
            riskLevel = .medium
            reason = "您有 \(weeksRemaining) 週時間準備比賽，建議從增強期開始，這樣可以平衡速度發展和比賽準備，是最理想的選擇。"
        } else if weeksRemaining <= 12 {
            recommendedStage = .build
            riskLevel = .low
            reason = "您有 \(weeksRemaining) 週的準備時間，建議從增強期開始。如果您是初跑者或需要建立有氧基礎，也可以考慮從基礎期開始。"
        } else {
            recommendedStage = .base
            riskLevel = .low
            reason = "您有充足的 \(weeksRemaining) 週準備時間，建議從基礎期開始完整的訓練週期，循序漸進地建立有氧基礎、發展速度和進行比賽準備。"
        }

        // 計算週數分配
        let distribution = calculateTrainingPeriods(
            trainingWeeks: weeksRemaining,
            targetDistanceKm: targetDistanceKm,
            startFromStage: recommendedStage
        )

        // 生成替代選項
        var alternatives: [StageAlternative] = []

        if recommendedStage == .build {
            alternatives.append(StageAlternative(
                stage: .peak,
                stageName: StartStage.peak.displayName,
                suitableFor: "訓練充分的資深跑者",
                riskLevel: .high,
                description: "適合每週跑量 40km+ 且近期有比賽經驗的跑者"
            ))

            if weeksRemaining >= 10 {
                alternatives.append(StageAlternative(
                    stage: .base,
                    stageName: StartStage.base.displayName,
                    suitableFor: "初跑者或需要建立基礎的跑者",
                    riskLevel: .low,
                    description: "從頭開始建立有氧基礎和跑量"
                ))
            }
        } else if recommendedStage == .peak {
            alternatives.append(StageAlternative(
                stage: .build,
                stageName: StartStage.build.displayName,
                suitableFor: "有訓練基礎的跑者",
                riskLevel: .low,
                description: "更安全的選擇，可以有時間發展速度能力"
            ))
        } else if recommendedStage == .base {
            alternatives.append(StageAlternative(
                stage: .build,
                stageName: StartStage.build.displayName,
                suitableFor: "有訓練基礎的跑者",
                riskLevel: .medium,
                description: "如果您已經有週跑量 20-30km，可以跳過基礎期"
            ))
        }

        return StartStageRecommendation(
            recommendedStage: recommendedStage,
            stageName: recommendedStage.displayName,
            reason: reason,
            riskLevel: riskLevel,
            weeksRemaining: weeksRemaining,
            alternatives: alternatives,
            trainingDistribution: distribution,
            isFullMarathon: targetDistanceKm > 21.1
        )
    }
}

// 使用範例
let recommendation = StartStageRecommender.recommend(
    weeksRemaining: 9,
    targetDistanceKm: 21.1
)

print("推薦階段: \(recommendation.stageName)")
print("原因: \(recommendation.reason)")
print("風險等級: \(recommendation.riskLevel.displayName)")
```

---

## React/React Native 使用範例

```tsx
import React, { useState, useEffect } from 'react';
import { recommendStartStage, StartStageRecommendation } from './startStageRecommender';

interface TrainingStageSelectionProps {
  weeksRemaining: number;
  targetDistanceKm: number;
  onStageSelected: (stage: string) => void;
}

export const TrainingStageSelection: React.FC<TrainingStageSelectionProps> = ({
  weeksRemaining,
  targetDistanceKm,
  onStageSelected
}) => {
  const [recommendation, setRecommendation] = useState<StartStageRecommendation | null>(null);
  const [selectedStage, setSelectedStage] = useState<string | null>(null);

  useEffect(() => {
    // 即時計算推薦
    const result = recommendStartStage(weeksRemaining, targetDistanceKm);
    setRecommendation(result);
    setSelectedStage(result.recommendedStage);
  }, [weeksRemaining, targetDistanceKm]);

  if (!recommendation) return null;

  const riskColors = {
    low: 'green',
    medium: 'orange',
    high: 'red'
  };

  return (
    <div className="training-stage-selection">
      <h2>選擇訓練起始階段</h2>

      {/* 推薦選項 */}
      <div className={`recommended-option ${selectedStage === recommendation.recommendedStage ? 'selected' : ''}`}>
        <div className="badge recommended">推薦</div>
        <h3>{recommendation.stageName}</h3>
        <p className="reason">{recommendation.reason}</p>
        <div className={`risk-badge ${riskColors[recommendation.riskLevel]}`}>
          風險等級: {recommendation.riskLevel}
        </div>

        {/* 週數分配預覽 */}
        <div className="distribution-preview">
          <div className="week-bar">
            {recommendation.trainingDistribution.buildWeeks > 0 && (
              <div
                className="build-weeks"
                style={{ width: `${(recommendation.trainingDistribution.buildWeeks / weeksRemaining) * 100}%` }}
              >
                增強 {recommendation.trainingDistribution.buildWeeks}週
              </div>
            )}
            {recommendation.trainingDistribution.peakWeeks > 0 && (
              <div
                className="peak-weeks"
                style={{ width: `${(recommendation.trainingDistribution.peakWeeks / weeksRemaining) * 100}%` }}
              >
                巔峰 {recommendation.trainingDistribution.peakWeeks}週
              </div>
            )}
            <div
              className="taper-weeks"
              style={{ width: `${(recommendation.trainingDistribution.taperWeeks / weeksRemaining) * 100}%` }}
            >
              減量 {recommendation.trainingDistribution.taperWeeks}週
            </div>
          </div>
        </div>

        <button
          onClick={() => {
            setSelectedStage(recommendation.recommendedStage);
            onStageSelected(recommendation.recommendedStage);
          }}
        >
          選擇此階段
        </button>
      </div>

      {/* 替代選項 */}
      {recommendation.alternatives.length > 0 && (
        <div className="alternatives">
          <h4>其他選項</h4>
          {recommendation.alternatives.map((alt) => (
            <div
              key={alt.stage}
              className={`alternative-option ${selectedStage === alt.stage ? 'selected' : ''}`}
            >
              <h5>{alt.stageName}</h5>
              <p className="suitable-for">{alt.suitableFor}</p>
              <p className="description">{alt.description}</p>
              <div className={`risk-badge ${riskColors[alt.riskLevel]}`}>
                風險等級: {alt.riskLevel}
              </div>
              <button
                onClick={() => {
                  setSelectedStage(alt.stage);
                  onStageSelected(alt.stage);
                }}
              >
                選擇此階段
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
```

---

## 最佳實踐

### 1. 即時預覽使用前端演算法

```typescript
// 用戶調整比賽日期時，即時更新推薦
const handleRaceDateChange = (raceDate: Date) => {
  const weeksRemaining = calculateWeeksRemaining(raceDate);
  const recommendation = recommendStartStage(weeksRemaining, targetDistance);

  // 立即更新 UI（無需等待 API）
  setRecommendation(recommendation);
};
```

### 2. 提交時呼叫後端 API 驗證

```typescript
const handleSubmit = async () => {
  // 使用後端 API 獲取權威推薦
  const apiRecommendation = await fetch(
    `/api/v1/plan/race_run/start-stage/recommend?weeks_remaining=${weeksRemaining}`
  ).then(res => res.json());

  // 使用後端推薦創建計劃
  await createTrainingPlan({
    start_from_stage: apiRecommendation.data.recommended_stage
  });
};
```

### 3. 定期同步演算法

**重要**：當後端邏輯更新時，需要同步更新前端演算法。

建議在 CI/CD 中添加測試，確保前後端推薦一致：

```typescript
// test/startStageRecommender.test.ts
describe('Start Stage Recommender', () => {
  it('should match backend recommendation', async () => {
    const weeksRemaining = 9;

    // 前端計算
    const frontendResult = recommendStartStage(weeksRemaining);

    // 後端 API
    const backendResult = await fetch(
      `/api/v1/plan/race_run/start-stage/recommend?weeks_remaining=${weeksRemaining}`
    ).then(res => res.json());

    // 確保一致
    expect(frontendResult.recommendedStage).toBe(
      backendResult.data.recommended_stage
    );
  });
});
```

---

## API Endpoint

### GET /api/v1/plan/race_run/start-stage/recommend

**Query Parameters**:
- `weeks_remaining` (int, required): 距離比賽剩餘週數

**Response Example**:
```json
{
  "success": true,
  "data": {
    "recommended_stage": "build",
    "stage_name": "增強期",
    "reason": "您有 9 週時間準備比賽，建議從增強期開始...",
    "risk_level": "medium",
    "weeks_remaining": 9,
    "alternatives": [
      {
        "stage": "peak",
        "stage_name": "巔峰期",
        "suitable_for": "訓練充分的資深跑者",
        "risk_level": "high",
        "description": "適合每週跑量 40km+ 且近期有比賽經驗的跑者"
      }
    ],
    "training_distribution": {
      "conversion_weeks": 0,
      "base_weeks": 0,
      "build_weeks": 4,
      "peak_weeks": 4,
      "taper_weeks": 1
    },
    "is_full_marathon": false
  }
}
```

---

## 總結

### 推薦使用方式

| 場景 | 使用方案 | 原因 |
|------|----------|------|
| 用戶調整比賽日期 | 前端演算法 | 即時響應，流暢體驗 |
| 顯示週數分配預覽 | 前端演算法 | 無需網路請求 |
| 創建訓練計劃 | 後端 API | 確保一致性和權威性 |
| A/B 測試 | 後端 API | 易於調整推薦邏輯 |

### 維護注意事項

1. ✅ **保持同步**：後端邏輯變更時，同步更新前端
2. ✅ **版本標記**：在代碼中註明演算法版本
3. ✅ **自動化測試**：確保前後端推薦一致
4. ✅ **文檔更新**：演算法變更時更新本文檔
