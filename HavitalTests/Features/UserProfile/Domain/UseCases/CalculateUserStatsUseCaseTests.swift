import XCTest
@testable import paceriz_dev

final class CalculateUserStatsUseCaseTests: XCTestCase {

    func testExecuteReturnsOutputWhenRepositoryProvidesStatistics() async {
        let repository = MockUserProfileRepository()
        repository.userToReturn = UserProfileTestFixtures.testUser
        repository.targetsToReturn = UserProfileTestFixtures.testTargets
        let sut = CalculateUserStatsUseCase(repository: repository)

        let output = await sut.execute()

        XCTAssertEqual(repository.calculateStatisticsCallCount, 1)
        XCTAssertEqual(output?.statistics.targetCount, repository.targetsToReturn.count)
        XCTAssertEqual(output?.statistics.heartRateZoneCount, 5)
    }

    func testExecuteReturnsNilWhenRepositoryHasNoStatistics() async {
        let repository = NilStatsUserProfileRepository()
        let sut = CalculateUserStatsUseCase(repository: repository)

        let output = await sut.execute()

        XCTAssertEqual(repository.calculateStatisticsCallCount, 1)
        XCTAssertNil(output)
    }
}

private final class NilStatsUserProfileRepository: UserProfileRepository {
    var calculateStatisticsCallCount = 0

    func getUserProfile() async throws -> User { fatalError("Not used") }
    func refreshUserProfile() async throws -> User { fatalError("Not used") }
    func updateUserProfile(_ updates: [String: Any]) async throws -> User { fatalError("Not used") }
    func deleteAccount(userId: String) async throws { fatalError("Not used") }
    func updateDataSource(_ dataSource: String) async throws { fatalError("Not used") }
    func getHeartRateZones() async throws -> [HeartRateZone] { fatalError("Not used") }
    func updateHeartRateZones(maxHR: Int, restingHR: Int) async throws -> [HeartRateZone] { fatalError("Not used") }
    func syncHeartRateData(from user: User) async { fatalError("Not used") }
    func getTargets() async throws -> [Target] { fatalError("Not used") }
    func createTarget(_ target: Target) async throws { fatalError("Not used") }

    func calculateStatistics() async -> UserStatistics? {
        calculateStatisticsCallCount += 1
        return nil
    }

    func updatePersonalBest(distanceKm: Double, completeTime: Int) async throws { fatalError("Not used") }
    func detectPersonalBestUpdates(
        oldData: [String : [PersonalBestRecordV2]]?,
        newData: [String : [PersonalBestRecordV2]]?
    ) async { fatalError("Not used") }

    func getPendingCelebrationUpdate() -> PersonalBestUpdate? { fatalError("Not used") }
    func markCelebrationAsShown() { fatalError("Not used") }
    func clearCache() async { fatalError("Not used") }
    func isCacheExpired() -> Bool { fatalError("Not used") }
}
