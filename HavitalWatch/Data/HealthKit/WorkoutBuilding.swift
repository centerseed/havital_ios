import Foundation

protocol WorkoutBuilding: AnyObject {
    var onMetrics: ((_ meters: Double, _ seconds: Int, _ hr: Double, _ recentSpeedMps: Double) -> Void)? { get set }

    func start(indoor: Bool) throws
    func pause()
    func resume()
    func markSegment(start: Date, end: Date, distanceMeters: Double?)
    func finish(rpe: Int?, completion: @escaping (Bool) -> Void)
}

#if DEBUG
final class DebugSimulatedWorkoutBuilder: WorkoutBuilding {
    struct Sample {
        let meters: Double
        let seconds: Int
        let heartRate: Double
        let recentSpeedMps: Double
    }

    var onMetrics: ((_ meters: Double, _ seconds: Int, _ hr: Double, _ recentSpeedMps: Double) -> Void)?

    private let samples: [Sample]
    private let intervalNanoseconds: UInt64
    private var task: Task<Void, Never>?
    private var sampleIndex = 0
    private var paused = false

    init(samples: [Sample], intervalNanoseconds: UInt64 = 400_000_000) {
        self.samples = samples
        self.intervalNanoseconds = intervalNanoseconds
    }

    func start(indoor: Bool) throws {
        task?.cancel()
        sampleIndex = 0
        paused = false
        task = Task { [weak self] in
            while let self, self.sampleIndex < self.samples.count {
                try? await Task.sleep(nanoseconds: self.intervalNanoseconds)
                guard !Task.isCancelled else { return }
                guard !self.paused else { continue }

                let sample = self.samples[self.sampleIndex]
                self.sampleIndex += 1
                self.onMetrics?(
                    sample.meters,
                    sample.seconds,
                    sample.heartRate,
                    sample.recentSpeedMps
                )
            }
        }
    }

    func pause() {
        paused = true
    }

    func resume() {
        paused = false
    }

    func markSegment(start: Date, end: Date, distanceMeters: Double?) {}

    func finish(rpe: Int?, completion: @escaping (Bool) -> Void) {
        task?.cancel()
        completion(true)
    }
}
#endif
