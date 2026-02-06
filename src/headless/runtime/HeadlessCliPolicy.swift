import Foundation

enum HeadlessCliPolicy {
    static let readinessWaitSeconds = 5.0

    static func preflightCode(for rawValue: String, readinessWaitSeconds: TimeInterval = readinessWaitSeconds) -> CliServerCode? {
        if CliShared.isUnsupportedCommand(rawValue, support: .headlessServer) {
            return .unsupported
        }
        if CliShared.shouldWaitForReadiness(rawValue) {
            guard ReadinessGate.waitUntilReady(timeout: readinessWaitSeconds) else {
                return .warmingUpTimeout
            }
        }
        return nil
    }
}
