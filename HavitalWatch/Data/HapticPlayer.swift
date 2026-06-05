import WatchKit

enum HapticPlayer {
    static func segmentCue() {
        WKInterfaceDevice.current().play(.notification)
    }

    static func start() {
        WKInterfaceDevice.current().play(.start)
    }

    static func stop() {
        WKInterfaceDevice.current().play(.stop)
    }
}
