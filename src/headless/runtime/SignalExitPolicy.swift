import Darwin

enum SignalExitPolicy {
    static func shouldEmergencyExit(for signal: Int32) -> Bool {
        signal != SIGTERM
    }

    static func exitCode(for signal: Int32) -> Int32 {
        shouldEmergencyExit(for: signal) ? 1 : 0
    }
}
