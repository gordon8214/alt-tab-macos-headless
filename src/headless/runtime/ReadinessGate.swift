import Foundation

final class ReadinessGate {
    private static let condition = NSCondition()
    private static var ready = false

    static func markReady() {
        condition.lock()
        ready = true
        condition.broadcast()
        condition.unlock()
    }

    static func waitUntilReady(timeout: TimeInterval) -> Bool {
        condition.lock()
        defer { condition.unlock() }

        if ready {
            return true
        }

        let deadline = Date().addingTimeInterval(timeout)
        while !ready {
            if !condition.wait(until: deadline) {
                break
            }
        }
        return ready
    }

    static func resetForTesting() {
        condition.lock()
        ready = false
        condition.unlock()
    }
}
