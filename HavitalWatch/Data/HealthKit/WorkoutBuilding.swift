import Foundation

protocol WorkoutBuilding: AnyObject {
    var onMetrics: ((_ meters: Double, _ seconds: Int, _ hr: Double, _ recentSpeedMps: Double) -> Void)? { get set }

    func start(indoor: Bool) throws
    func pause()
    func resume()
    func markSegment(start: Date, end: Date, distanceMeters: Double?)
    func finish(rpe: Int?, completion: @escaping (Bool) -> Void)
}
