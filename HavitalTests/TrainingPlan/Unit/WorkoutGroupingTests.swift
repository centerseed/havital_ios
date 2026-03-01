//
//  WorkoutGroupingTests.swift
//  HavitalTests
//
//  单元测试：验证 WeekDateService 使用 selectedWeek 计算正确的日期范围
//

import XCTest
@testable import paceriz_dev

@MainActor
final class WorkoutGroupingTests: XCTestCase {

    /// 测试：验证不同 weekNumber 产生不同的 weekInfo
    func testWeekDateService_DifferentWeeks_ProduceDifferentDateRanges() throws {
        // Given: 创建基准日期
        let createdAt = "2024-01-01T00:00:00Z"  // 2024年1月1日

        // When: 计算第1周和第3周的 weekInfo
        guard let week1Info = WeekDateService.weekDateInfo(createdAt: createdAt, weekNumber: 1),
              let week3Info = WeekDateService.weekDateInfo(createdAt: createdAt, weekNumber: 3) else {
            XCTFail("无法计算 weekInfo")
            return
        }

        // Then: 验证两个周的日期范围不同
        XCTAssertNotEqual(
            week1Info.startDate,
            week3Info.startDate,
            "第1周和第3周的开始日期应该不同"
        )

        XCTAssertNotEqual(
            week1Info.endDate,
            week3Info.endDate,
            "第1周和第3周的结束日期应该不同"
        )

        // 验证两周的 daysMap[1] 不同
        let week1Day1 = week1Info.daysMap[1]
        let week3Day1 = week3Info.daysMap[1]

        XCTAssertNotNil(week1Day1, "第1周的第1天应该存在")
        XCTAssertNotNil(week3Day1, "第3周的第1天应该存在")
        XCTAssertNotEqual(week1Day1, week3Day1, "不同周的同一 dayIndex 应该对应不同日期")

        print("✅ 第1周范围: \(week1Info.startDate) ~ \(week1Info.endDate)")
        print("✅ 第3周范围: \(week3Info.startDate) ~ \(week3Info.endDate)")
        print("✅ 第1周第1天: \(week1Day1!)")
        print("✅ 第3周第1天: \(week3Day1!)")
    }

    /// 测试：验证相邻两周的日期相差7天
    func testWeekDateService_AdjacentWeeks_DifferBy7Days() throws {
        // Given: 创建基准日期
        let createdAt = "2024-01-01T00:00:00Z"

        // When: 计算第1周和第2周
        guard let week1Info = WeekDateService.weekDateInfo(createdAt: createdAt, weekNumber: 1),
              let week2Info = WeekDateService.weekDateInfo(createdAt: createdAt, weekNumber: 2) else {
            XCTFail("无法计算 weekInfo")
            return
        }

        // Then: 验证相差7天
        let calendar = Calendar.current
        let week1Day1 = week1Info.daysMap[1]!
        let week2Day1 = week2Info.daysMap[1]!

        let daysDiff = calendar.dateComponents([.day], from: week1Day1, to: week2Day1).day ?? 0
        XCTAssertEqual(daysDiff, 7, "相邻两周的同一天应该相差7天")

        print("✅ 第1周第1天: \(week1Day1)")
        print("✅ 第2周第1天: \(week2Day1)")
        print("✅ 相差天数: \(daysDiff)")
    }

    /// 测试：验证 daysMap 包含7天数据
    func testWeekDateService_DaysMap_Contains7Days() throws {
        // Given: 创建基准日期
        let createdAt = "2024-01-01T00:00:00Z"

        // When: 计算第1周
        guard let weekInfo = WeekDateService.weekDateInfo(createdAt: createdAt, weekNumber: 1) else {
            XCTFail("无法计算 weekInfo")
            return
        }

        // Then: 验证有7天数据
        XCTAssertEqual(weekInfo.daysMap.count, 7, "daysMap 应该包含7天")

        // 验证每一天都存在
        for dayIndex in 1...7 {
            XCTAssertNotNil(weekInfo.daysMap[dayIndex], "第 \(dayIndex) 天应该存在")
        }

        print("✅ daysMap 包含 \(weekInfo.daysMap.count) 天")
    }

    /// 测试：验证 workout 能匹配到正确的 dayIndex
    func testWorkoutMatching_FindsCorrectDayIndex() throws {
        // Given: 创建基准日期和 weekInfo
        let createdAt = "2024-01-01T00:00:00Z"
        guard let weekInfo = WeekDateService.weekDateInfo(createdAt: createdAt, weekNumber: 1) else {
            XCTFail("无法计算 weekInfo")
            return
        }

        // When: 模拟一个 workout 的日期（第1周的第3天）
        let targetDate = weekInfo.daysMap[3]!
        let calendar = Calendar.current

        // 使用 weekInfo.daysMap 查找 dayIndex
        var foundDayIndex: Int?
        for (index, dateInWeek) in weekInfo.daysMap {
            if calendar.isDate(targetDate, inSameDayAs: dateInWeek) {
                foundDayIndex = index
                break
            }
        }

        // Then: 验证找到了正确的 dayIndex
        XCTAssertNotNil(foundDayIndex, "应该能找到 dayIndex")
        XCTAssertEqual(foundDayIndex, 3, "应该匹配到第3天")

        print("✅ 目标日期: \(targetDate)")
        print("✅ 匹配到 dayIndex: \(foundDayIndex!)")
    }

    /// 测试：验证后备方案（使用 Calendar.weekday）
    func testFallbackMethod_CalculatesDayIndex() throws {
        // Given: 创建一个日期
        let calendar = Calendar.current
        let testDate = Date()

        // When: 使用后备方案计算 dayIndex
        let weekday = calendar.component(.weekday, from: testDate)
        let dayIndex = weekday == 1 ? 7 : weekday - 1  // 周日=7, 周一=1

        // Then: 验证 dayIndex 在合理范围
        XCTAssertGreaterThanOrEqual(dayIndex, 1, "dayIndex 应该 >= 1")
        XCTAssertLessThanOrEqual(dayIndex, 7, "dayIndex 应该 <= 7")

        print("✅ 测试日期: \(testDate)")
        print("✅ weekday: \(weekday)")
        print("✅ dayIndex: \(dayIndex)")
    }
}
