//
//  TargetDecodingTests.swift
//  HavitalTests
//

import XCTest
@testable import paceriz_dev

final class TargetDecodingTests: XCTestCase {
    func testDecodeTargetAcceptsFractionalRaceDistanceFromAPI() throws {
        let json = """
        {
            "id": "marathon_support",
            "type": "race_run",
            "name": "Marathon Support",
            "distance_km": 42.195,
            "target_time": 14400,
            "target_pace": "5:41",
            "race_date": 1786060800,
            "is_main_race": false,
            "training_weeks": 14,
            "timezone": "Asia/Taipei",
            "race_id": null
        }
        """.data(using: .utf8)!

        let target = try JSONDecoder().decode(Target.self, from: json)

        XCTAssertEqual(target.id, "marathon_support")
        XCTAssertEqual(target.distanceKm, 42)
        XCTAssertFalse(target.isMainRace)
    }

    func testDecodeTargetsArrayDoesNotFailWhenOneTargetUsesFractionalDistance() throws {
        let json = """
        [
            {
                "id": "main_half",
                "type": "race_run",
                "name": "Main Half",
                "distance_km": 21,
                "target_time": 7200,
                "target_pace": "5:41",
                "race_date": 1780790400,
                "is_main_race": true,
                "training_weeks": 4,
                "timezone": "Asia/Taipei"
            },
            {
                "id": "support_full",
                "type": "race_run",
                "name": "Support Full",
                "distance_km": 42.195,
                "target_time": 14400,
                "target_pace": "5:41",
                "race_date": 1786060800,
                "is_main_race": false,
                "training_weeks": 14,
                "timezone": "Asia/Taipei"
            }
        ]
        """.data(using: .utf8)!

        let targets = try JSONDecoder().decode([Target].self, from: json)

        XCTAssertEqual(targets.map(\.id), ["main_half", "support_full"])
        XCTAssertEqual(targets[1].distanceKm, 42)
    }
    func testCreateTargetPreservesBackendEnvelopeAdvisoryThroughRemoteDataSource() async throws {
        let json = """
        {
            "success": true,
            "data": {"id":"main_race","type":"race_run","name":"Nagano Marathon","distance_km":42.195,"target_time":14400,"target_pace":"5:41","race_date":1786060800,"is_main_race":true,"training_weeks":40,"timezone":"Asia/Tokyo"},
            "message": "Consider using maintenance training first."
        }
        """.data(using: .utf8)!
        let http = MockHTTPClient()
        http.setResponse(for: "/user/targets", method: .POST, data: json)
        let result = try await TargetRemoteDataSource(httpClient: http).createTarget(
            Target(type: "race_run", name: "Nagano Marathon", distanceKm: 42, targetTime: 14_400, targetPace: "5:41", raceDate: 1_786_060_800, isMainRace: true, trainingWeeks: 40, timezone: "Asia/Tokyo")
        )

        XCTAssertEqual(result.target.id, "main_race")
        XCTAssertEqual(result.message, "Consider using maintenance training first.")
    }

    func testUpdateTargetEnvelopeWithoutAdvisoryHasNoMessage() async throws {
        let json = """
        {"success":true,"data":{"id":"main_race","type":"race_run","name":"Nagano Marathon","distance_km":42,"target_time":14400,"target_pace":"5:41","race_date":1786060800,"is_main_race":true,"training_weeks":40,"timezone":"Asia/Tokyo"}}
        """.data(using: .utf8)!
        let http = MockHTTPClient()
        http.setResponse(for: "/user/targets/main_race", method: .PUT, data: json)
        let result = try await TargetRemoteDataSource(httpClient: http).updateTarget(
            id: "main_race",
            target: Target(id: "main_race", type: "race_run", name: "Nagano Marathon", distanceKm: 42, targetTime: 14_400, targetPace: "5:41", raceDate: 1_786_060_800, isMainRace: true, trainingWeeks: 40, timezone: "Asia/Tokyo")
        )

        XCTAssertNil(result.message)
    }

}
