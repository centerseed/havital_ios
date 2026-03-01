//
//  TargetTestFixtures.swift
//  HavitalTests
//
//  Sample data for Target module unit tests
//

import Foundation
@testable import paceriz_dev

struct TargetTestFixtures {
    
    static var mainTarget: Target {
        Target(
            id: "target_main_123",
            type: "race_run",
            name: "Taipei Marathon",
            distanceKm: 42,
            targetTime: 14400, // 4 hours
            targetPace: "05:41",
            raceDate: 1734825600, // 2024-12-22
            isMainRace: true,
            trainingWeeks: 16,
            timezone: "Asia/Taipei"
        )
    }
    
    static var supportingTarget: Target {
        Target(
            id: "target_support_456",
            type: "race_run",
            name: "Half Marathon Warmup",
            distanceKm: 21,
            targetTime: 7200, // 2 hours
            targetPace: "05:41",
            raceDate: 1732147200, // 2024-11-21
            isMainRace: false,
            trainingWeeks: 0,
            timezone: "Asia/Taipei"
        )
    }
    
    static var targetsList: [Target] {
        [mainTarget, supportingTarget]
    }
    
    static func targetAPIResponseData(_ target: Target) -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        let apiResponse = [
            "status": "success",
            "data": target
        ] as [String : Any]
        
        // Note: Simple manual JSON creation to ensure snake_case for the outer wrapper 
        // while the inner target uses the encoder's strategy.
        // Actually, let's just use a dictionary and JSONSerialization for the wrapper.
        
        let targetData = try! encoder.encode(target)
        let targetJson = try! JSONSerialization.jsonObject(with: targetData, options: [])
        
        let wrapper: [String: Any] = [
            "status": "success",
            "data": targetJson
        ]
        
        return try! JSONSerialization.data(withJSONObject: wrapper, options: [])
    }
    
    static func targetsListAPIResponseData(_ targets: [Target]) -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        let targetsData = try! encoder.encode(targets)
        let targetsJson = try! JSONSerialization.jsonObject(with: targetsData, options: [])
        
        let wrapper: [String: Any] = [
            "status": "success",
            "data": targetsJson
        ]
        
        return try! JSONSerialization.data(withJSONObject: wrapper, options: [])
    }
}
