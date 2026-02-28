//
//  PlanVerificationHelper.swift
//  HavitalUITests
//
//  API verification helper for E2E tests
//  Directly calls GET APIs to verify plan data after onboarding
//

import XCTest
import Foundation

class PlanVerificationHelper {
    static let devBaseURL = "https://api-service-364865009192.asia-east1.run.app"

    // MARK: - API Verification

    /// Verify plan overview via API
    static func verifyPlanOverview(
        token: String,
        expectedTargetType: String,
        expectedMethodology: String? = nil,
        expectedTotalWeeks: Int? = nil
    ) async throws {
        let url = URL(string: "\(devBaseURL)/v2/plan/overview")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        XCTAssertEqual(httpResponse.statusCode, 200, "GET /v2/plan/overview should return 200")

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let targetType = json["target_type"] as? String {
                XCTAssertEqual(targetType, expectedTargetType,
                              "Target type should be '\(expectedTargetType)'")
            }

            if let expectedMethodology = expectedMethodology,
               let methodology = json["methodology"] as? [String: Any],
               let methodologyId = methodology["id"] as? String {
                XCTAssertEqual(methodologyId, expectedMethodology,
                              "Methodology should be '\(expectedMethodology)'")
            }

            if let expectedWeeks = expectedTotalWeeks,
               let totalWeeks = json["total_weeks"] as? Int {
                XCTAssertEqual(totalWeeks, expectedWeeks,
                              "Total weeks should be \(expectedWeeks)")
            }
        }
    }

    /// Verify plan status via API
    static func verifyPlanStatus(token: String) async throws {
        let url = URL(string: "\(devBaseURL)/v2/plan/status")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        XCTAssertEqual(httpResponse.statusCode, 200, "GET /v2/plan/status should return 200")

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let nextAction = json["next_action"] as? String {
            XCTAssertEqual(nextAction, "view_plan",
                          "After onboarding, next_action should be 'view_plan'")
        }
    }

    /// Verify weekly plan via API
    static func verifyWeeklyPlan(
        token: String,
        planId: String,
        expectedTrainingDays: Int
    ) async throws {
        let url = URL(string: "\(devBaseURL)/v2/plan/weekly/\(planId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        XCTAssertEqual(httpResponse.statusCode, 200, "GET /v2/plan/weekly should return 200")

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let sessions = json["sessions"] as? [[String: Any]] {
            XCTAssertGreaterThan(sessions.count, 0,
                               "Weekly plan should have at least 1 session")
            // Verify training day count matches
            let uniqueDays = Set(sessions.compactMap { $0["day_of_week"] as? Int })
            XCTAssertEqual(uniqueDays.count, expectedTrainingDays,
                          "Training days should match configuration (\(expectedTrainingDays))")
        }
    }
}
