//
//  TrainingPlanTestFixtures.swift
//  HavitalTests
//
//  Test fixtures for TrainingPlan module unit tests - uses JSON decoding
//

import Foundation
@testable import paceriz_dev

/// Test fixtures for TrainingPlan module
enum TrainingPlanTestFixtures {

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // d.keyDecodingStrategy = .convertFromSnakeCase // Conflicts with explicit CodingKeys
        return d
    }()

    // MARK: - WeeklyPlan Fixtures

    static var weeklyPlan1: WeeklyPlan {
        let json = """
        {
            "id": "plan_123_1",
            "purpose": "Base building week",
            "week_of_plan": 1,
            "total_weeks": 12,
            "total_distance_km": 30.0,
            "days": [
                {
                    "day_index": "1",
                    "day_target": "Easy 5km run",
                    "training_type": "easy_run",
                    "training_details": {
                        "description": "Easy pace run",
                        "distance_km": 5.0,
                        "pace": "6:00/km"
                    }
                }
            ]
        }
        """
        return try! decoder.decode(WeeklyPlan.self, from: json.data(using: .utf8)!)
    }

    static var weeklyPlan2: WeeklyPlan {
        let json = """
        {
            "id": "plan_123_2",
            "purpose": "Building week",
            "week_of_plan": 2,
            "total_weeks": 12,
            "total_distance_km": 35.0,
            "days": [
                {
                    "day_index": "1",
                    "day_target": "Easy 6km run",
                    "training_type": "easy_run"
                }
            ]
        }
        """
        return try! decoder.decode(WeeklyPlan.self, from: json.data(using: .utf8)!)
    }

    // MARK: - TrainingPlanOverview Fixtures

    static var trainingOverview: TrainingPlanOverview {
        let json = """
        {
            "id": "plan_123",
            "main_race_id": "race_456",
            "target_evaluate": "Complete half marathon",
            "total_weeks": 12,
            "training_hightlight": "Focus on aerobic base",
            "training_plan_name": "Half Marathon Plan",
            "training_stage_discription": [],
            "created_at": "2024-01-15T10:00:00Z"
        }
        """
        return try! decoder.decode(TrainingPlanOverview.self, from: json.data(using: .utf8)!)
    }

    // MARK: - PlanStatusResponse Fixtures

    static var planStatusWithPlan: PlanStatusResponse {
        let json = """
        {
            "current_week": 1,
            "total_weeks": 12,
            "next_action": "view_plan",
            "can_generate_next_week": false,
            "current_week_plan_id": "plan_123_1",
            "metadata": {
                "training_start_date": "2024-01-15",
                "current_week_start_date": "2024-01-15",
                "current_week_end_date": "2024-01-21",
                "user_timezone": "Asia/Taipei",
                "server_time": "2024-01-16T08:00:00Z"
            }
        }
        """
        return try! decoder.decode(PlanStatusResponse.self, from: json.data(using: .utf8)!)
    }

    static var planStatusNeedCreate: PlanStatusResponse {
        let json = """
        {
            "current_week": 2,
            "total_weeks": 12,
            "next_action": "create_plan",
            "can_generate_next_week": false,
            "metadata": {
                "training_start_date": "2024-01-15",
                "current_week_start_date": "2024-01-22",
                "current_week_end_date": "2024-01-28",
                "user_timezone": "Asia/Taipei",
                "server_time": "2024-01-23T08:00:00Z"
            }
        }
        """
        return try! decoder.decode(PlanStatusResponse.self, from: json.data(using: .utf8)!)
    }

    // MARK: - JSON Data for API Response

    static func weeklyPlanAPIResponseData(_ plan: WeeklyPlan? = nil) -> Data {
        let p = plan ?? weeklyPlan1
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let planData = try! encoder.encode(p)
        let planJson = String(data: planData, encoding: .utf8)!
        return "{\"success\":true,\"data\":\(planJson)}".data(using: .utf8)!
    }

    static func overviewAPIResponseData(_ overview: TrainingPlanOverview? = nil) -> Data {
        let o = overview ?? trainingOverview
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try! encoder.encode(o)
        let json = String(data: data, encoding: .utf8)!
        return "{\"success\":true,\"data\":\(json)}".data(using: .utf8)!
    }

    static func planStatusAPIResponseData(_ status: PlanStatusResponse? = nil) -> Data {
        let s = status ?? planStatusWithPlan
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try! encoder.encode(s)
        let json = String(data: data, encoding: .utf8)!
        return "{\"success\":true,\"data\":\(json)}".data(using: .utf8)!
    }
}

// MARK: - Encodable Extensions

extension TrainingPlanOverview: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(mainRaceId, forKey: .mainRaceId)
        try container.encode(targetEvaluate, forKey: .targetEvaluate)
        try container.encode(totalWeeks, forKey: .totalWeeks)
        try container.encode(trainingHighlight, forKey: .trainingHighlight)
        try container.encode(trainingPlanName, forKey: .trainingPlanName)
        try container.encode(trainingStageDescription, forKey: .trainingStageDescription)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

extension TrainingStage: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(stageName, forKey: .stageName)
        try container.encode(stageId, forKey: .stageId)
        try container.encode(stageDescription, forKey: .stageDescription)
        try container.encode(trainingFocus, forKey: .trainingFocus)
        try container.encode(weekStart, forKey: .weekStart)
        try container.encodeIfPresent(weekEnd, forKey: .weekEnd)
        try container.encodeIfPresent(targetPace, forKey: .targetPace)
    }
}

extension PlanStatusResponse: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentWeek, forKey: .currentWeek)
        try container.encode(totalWeeks, forKey: .totalWeeks)
        try container.encode(nextAction, forKey: .nextAction)
        try container.encode(canGenerateNextWeek, forKey: .canGenerateNextWeek)
        try container.encodeIfPresent(currentWeekPlanId, forKey: .currentWeekPlanId)
        try container.encodeIfPresent(previousWeekSummaryId, forKey: .previousWeekSummaryId)
        try container.encodeIfPresent(nextWeekInfo, forKey: .nextWeekInfo)
        try container.encode(metadata, forKey: .metadata)
    }
}

extension NextWeekInfo: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(weekNumber, forKey: .weekNumber)
        try container.encode(hasPlan, forKey: .hasPlan)
        try container.encode(canGenerate, forKey: .canGenerate)
        try container.encode(requiresCurrentWeekSummary, forKey: .requiresCurrentWeekSummary)
        try container.encode(nextAction, forKey: .nextAction)
    }
}

extension PlanStatusMetadata: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(trainingStartDate, forKey: .trainingStartDate)
        try container.encode(currentWeekStartDate, forKey: .currentWeekStartDate)
        try container.encode(currentWeekEndDate, forKey: .currentWeekEndDate)
        try container.encode(userTimezone, forKey: .userTimezone)
        try container.encode(serverTime, forKey: .serverTime)
    }
}

// MARK: - WeeklySummary Fixtures

extension TrainingPlanTestFixtures {

    /// 創建測試用 WeeklySummary
    static func createWeeklySummary(
        id: String = "summary_test_1",
        adjustments: NextWeekAdjustments? = nil
    ) throws -> WeeklyTrainingSummary {
        let defaultAdjustments = NextWeekAdjustments(
            status: "no_adjustment_needed",
            modifications: nil,
            adjustmentReason: nil,
            items: nil
        )

        return WeeklyTrainingSummary(
            id: id,
            trainingCompletion: TrainingCompletion(
                percentage: 85.0,
                evaluation: "Good progress this week"
            ),
            trainingAnalysis: TrainingAnalysis(
                heartRate: HeartRateAnalysis(
                    average: 145.0,
                    max: 175.0,
                    evaluation: "Heart rate within target zones"
                ),
                pace: PaceAnalysis(
                    average: "5:30/km",
                    trend: "Improving",
                    evaluation: "Pace is on track"
                ),
                distance: DistanceAnalysis(
                    total: 32.5,
                    comparisonToPlan: "105% of planned distance",
                    evaluation: "Slightly exceeded plan"
                )
            ),
            nextWeekSuggestions: NextWeekSuggestions(
                focus: "Build endurance",
                recommendations: [
                    "Maintain current pace for easy runs",
                    "Add one interval session"
                ]
            ),
            nextWeekAdjustments: adjustments ?? defaultAdjustments
        )
    }
}
