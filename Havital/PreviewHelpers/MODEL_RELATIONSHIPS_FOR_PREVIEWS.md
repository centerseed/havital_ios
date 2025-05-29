# Model Relationships for Previews

This document outlines the structure and initialization details of key models used in the Havital iOS app, specifically for aiding the creation of mock data for SwiftUI Previews.

## Core Models

### 1. `TrainingPlanOverview.swift`

**`TrainingStage`**
- **Properties**:
  - `stageName: String`
  - `stageId: String`
  - `stageDescription: String`
  - `trainingFocus: String`
  - `weekStart: Int`
  - `weekEnd: Int?`
- **Initialization**: `Codable`. Swift provides an internal memberwise initializer.
  ```swift
  // Example for mock data
  TrainingStage(stageName: "Base Building", stageId: "s1", stageDescription: "Focus on aerobic base.", trainingFocus: "Endurance", weekStart: 1, weekEnd: 4)
  ```

**`TrainingPlanOverview`**
- **Properties**:
  - `id: String`
  - `mainRaceId: String`
  - `targetEvaluate: String`
  - `totalWeeks: Int`
  - `trainingHighlight: String`
  - `trainingPlanName: String`
  - `trainingStageDescription: [TrainingStage]`
  - `createdAt: String`
- **Initialization**: `Codable`. Swift provides an internal memberwise initializer.
  ```swift
  // Example for mock data
  TrainingPlanOverview(id: "plan123", mainRaceId: "race456", targetEvaluate: "Achieve PR", totalWeeks: 12, trainingHighlight: "Includes varied workouts", trainingPlanName: "Marathon Prep", trainingStageDescription: [/* mock TrainingStage array */], createdAt: "2024-05-27T00:00:00Z")
  ```

### 2. `WeeklyPlan.swift`

**`IntensityTotalMinutes`** (Nested in `WeeklyPlan`)
- **Properties**:
  - `low: Int`
  - `medium: Int`
  - `high: Int`
- **Initialization**: `Codable`. Swift provides an internal memberwise initializer.
  ```swift
  // Example for mock data
  WeeklyPlan.IntensityTotalMinutes(low: 120, medium: 60, high: 30)
  ```

**`WeeklyPlan`**
- **Properties**:
  - `id: String`
  - `purpose: String`
  - `weekOfPlan: Int`
  - `totalWeeks: Int`
  - `totalDistance: Double`
  - `designReason: [String]?`
  - `days: [TrainingDay]`
  - `intensityTotalMinutes: IntensityTotalMinutes?`
  - `createdAtString: String?` (Private, `createdAt: Date?` is computed)
- **Initialization**: `Codable` (with custom `init(from: Decoder)`). 
  **Crucially, has a public memberwise initializer for previews:**
  ```swift
  init(id: String, purpose: String, weekOfPlan: Int, totalWeeks: Int, totalDistance: Double, designReason: [String]?, days: [TrainingDay], intensityTotalMinutes: IntensityTotalMinutes? = nil)
  // Example for mock data
  WeeklyPlan(id: "week1", purpose: "Build endurance", weekOfPlan: 1, totalWeeks: 12, totalDistance: 50.0, designReason: ["Focus on Z2"], days: [/* mock TrainingDay array */], intensityTotalMinutes: mockIntensity)
  ```

**`TrainingDay`**
- **Properties**:
  - `dayIndex: String` (ID is computed from this)
  - `dayTarget: String`
  - `reason: String?`
  - `tips: String?`
  - `trainingType: String` (Used to derive `DayType`)
  - `trainingDetails: TrainingDetails?`
- **Initialization**: `Codable` (with custom `init(from: Decoder)`).
  **Recommendation**: Add a memberwise initializer for easier preview mocking.
  ```swift
  // Proposed initializer (to be added to the model)
  // init(dayIndex: String, dayTarget: String, reason: String?, tips: String?, trainingType: String, trainingDetails: TrainingDetails?)
  
  // Example for mock data (assuming initializer exists or properties are set manually)
  // TrainingDay(dayIndex: "1", dayTarget: "Easy Run", reason: "Recovery", tips: "Keep HR low", trainingType: "easy_run", trainingDetails: mockDetails)
  ```

**`HeartRateRange`**
- **Properties**:
  - `min: Int`
  - `max: Int`
- **Initialization**: `Codable`. Swift provides an internal memberwise initializer.
  ```swift
  // Example for mock data
  HeartRateRange(min: 130, max: 145)
  ```

**`TrainingDetails`**
- **Properties**:
  - `description: String?`
  - `distanceKm: Double?`
  - `totalDistanceKm: Double?` (e.g., for progression runs)
  - `pace: String?`
  - `work: WorkoutSegment?`
  - `recovery: WorkoutSegment?`
  - `repeats: Int?`
  - `heartRateRange: HeartRateRange?`
  - `segments: [ProgressionSegment]?`
- **Initialization**: `Codable`. Swift provides an internal memberwise initializer.
  ```swift
  // Example for mock data (easy run)
  TrainingDetails(description: "30 min Z2 run", distanceKm: 5.0, totalDistanceKm: nil, pace: "6:00/km", work: nil, recovery: nil, repeats: nil, heartRateRange: mockHrRange, segments: nil)
  // Example for mock data (interval)
  TrainingDetails(description: "Interval session", distanceKm: nil, totalDistanceKm: 8.0, pace: nil, work: mockWorkSegment, recovery: mockRecoverySegment, repeats: 5, heartRateRange: nil, segments: nil)
  ```

**`WorkoutSegment`**
- **Properties**:
  - `description: String`
  - `distanceKm: Double`
  - `pace: String?`
- **Initialization**: `Codable`. Swift provides an internal memberwise initializer.
  ```swift
  // Example for mock data
  WorkoutSegment(description: "400m hard", distanceKm: 0.4, pace: "4:00/km")
  ```

**`ProgressionSegment`**
- **Properties**:
  - `distanceKm: Double`
  - `pace: String`
  - `description: String?`
- **Initialization**: `Codable`. Swift provides an internal memberwise initializer.
  ```swift
  // Example for mock data
  ProgressionSegment(distanceKm: 2.0, pace: "5:30/km", description: "Warm-up pace")
  ```

**`DayType`** (Enum)
- **Raw Value**: `String`
- **Cases**: `easyRun`, `easy`, `interval`, `tempo`, `longRun`, `lsd`, `progression`, `race`, `rest`, `recovery_run`, `crossTraining`, `threshold`, `hiking`, `strength`, `yoga`, `cycling`
- **Initialization**: `Codable`. Can be initialized with its raw value.
  ```swift
  // Example
  let type = DayType(rawValue: "easy_run") ?? .rest
  ```

**`WeeklyTrainingItem`** (Not `Codable` directly, used for UI)
- **Properties**:
  - `id: UUID` (Auto-generated)
  - `name: String`
  - `runDetails: String`
  - `durationMinutes: Int?`
  - `goals: TrainingGoals`
- **Initialization**: Swift provides an internal memberwise initializer.
  ```swift
  // Example for mock data
  WeeklyTrainingItem(name: "Easy Run", runDetails: "5km at Z2", durationMinutes: 30, goals: mockTrainingGoals)
  ```

**`TrainingGoals`** (Not `Codable` directly, used for UI)
- **Properties**:
  - `pace: String?`
  - `distanceKm: Double?`
  - `heartRateRange: HeartRateRange?`
  - `heartRate: String?`
  - `times: Int?`
- **Initialization**: Has a public memberwise initializer.
  ```swift
  // Example for mock data
  TrainingGoals(pace: "6:00/km", distanceKm: 5.0, heartRateRange: mockHrRange, heartRate: nil, times: nil)
  ```

### 3. `WeeklySummary.swift`

**`TrainingCompletion`**
- **Properties**:
  - `percentage: Double`
  - `evaluation: String`
- **Initialization**: `Codable`. Swift provides an internal memberwise initializer.
  ```swift
  // Example for mock data
  TrainingCompletion(percentage: 0.85, evaluation: "Good effort!")
  ```

**`HeartRateAnalysis`**
- **Properties**:
  - `average: Double`
  - `max: Double`
  - `evaluation: String`
- **Initialization**: `Codable`. Swift provides an internal memberwise initializer.
  ```swift
  // Example for mock data
  HeartRateAnalysis(average: 140.0, max: 165.0, evaluation: "Mainly in target zone.")
  ```

**`PaceAnalysis`**
- **Properties**:
  - `average: String`
  - `trend: String`
  - `evaluation: String`
- **Initialization**: `Codable`. Swift provides an internal memberwise initializer.
  ```swift
  // Example for mock data
  PaceAnalysis(average: "5:50/km", trend: "Consistent", evaluation: "Good pacing.")
  ```

**`DistanceAnalysis`**
- **Properties**:
  - `total: Double`
  - `comparisonToPlan: String`
  - `evaluation: String`
- **Initialization**: `Codable`. Swift provides an internal memberwise initializer.
  ```swift
  // Example for mock data
  DistanceAnalysis(total: 45.0, comparisonToPlan: "Met target", evaluation: "Solid week.")
  ```

**`TrainingAnalysis`**
- **Properties**:
  - `heartRate: HeartRateAnalysis`
  - `pace: PaceAnalysis`
  - `distance: DistanceAnalysis`
- **Initialization**: `Codable`. Swift provides an internal memberwise initializer.
  ```swift
  // Example for mock data
  TrainingAnalysis(heartRate: mockHrAnalysis, pace: mockPaceAnalysis, distance: mockDistanceAnalysis)
  ```

**`NextWeekSuggestions`**
- **Properties**:
  - `focus: String`
  - `recommendations: [String]`
- **Initialization**: `Codable`. Swift provides an internal memberwise initializer.
  ```swift
  // Example for mock data
  NextWeekSuggestions(focus: "Recovery and light intensity", recommendations: ["Prioritize sleep", "Consider a cross-training day"])
  ```

**`TrainingModification`**
- **Properties**:
  - `original: String`
  - `adjusted: String`
- **Initialization**: `Codable`. Swift provides an internal memberwise initializer.
  ```swift
  // Example for mock data
  TrainingModification(original: "5x800m interval", adjusted: "4x800m interval due to fatigue")
  ```

**`Modifications`**
- **Properties**:
  - `intervalTraining: TrainingModification?`
  - `longRun: TrainingModification?`
- **Initialization**: `Codable`. Swift provides an internal memberwise initializer.
  ```swift
  // Example for mock data
  Modifications(intervalTraining: mockIntervalModification, longRun: nil)
  ```

**`NextWeekAdjustments`**
- **Properties**:
  - `status: String`
  - `modifications: Modifications?`
  - `adjustmentReason: String`
- **Initialization**: `Codable`. Swift provides an internal memberwise initializer.
  ```swift
  // Example for mock data
  NextWeekAdjustments(status: "Adjusted", modifications: mockModifications, adjustmentReason: "User reported high fatigue levels.")
  ```

**`WeeklyTrainingSummary`**
- **Properties**:
  - `trainingCompletion: TrainingCompletion`
  - `trainingAnalysis: TrainingAnalysis`
  - `nextWeekSuggestions: NextWeekSuggestions`
  - `nextWeekAdjustments: NextWeekAdjustments`
- **Initialization**: `Codable`. Swift provides an internal memberwise initializer.
  ```swift
  // Example for mock data
  WeeklyTrainingSummary(trainingCompletion: mockCompletion, trainingAnalysis: mockAnalysis, nextWeekSuggestions: mockSuggestions, nextWeekAdjustments: mockAdjustments)
  ```

This document should serve as a reference for creating accurate mock data for previews. Remember to add the suggested memberwise initializer to `TrainingDay` for easier mocking.
