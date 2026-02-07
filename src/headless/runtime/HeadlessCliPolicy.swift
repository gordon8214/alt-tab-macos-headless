import CoreGraphics
import Foundation

struct HeadlessRunningAppSnapshot {
    var pid: pid_t
    var bundleIdentifier: String?
    var isTerminated: Bool
}

enum HeadlessCliPolicy {
    static let readinessWaitSeconds = 5.0
    static let guiAltTabBundleIdentifier = "com.lwouis.alt-tab-macos"

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

    static func conflictingGuiAltTabPids(runningApps: [HeadlessRunningAppSnapshot], currentPid: pid_t) -> [pid_t] {
        runningApps.compactMap {
            guard !$0.isTerminated else { return nil }
            guard $0.pid != currentPid else { return nil }
            guard $0.bundleIdentifier == guiAltTabBundleIdentifier else { return nil }
            return $0.pid
        }
    }
}

enum HeadlessStartupConflictGuard {
    @discardableResult
    static func enforceNoGuiAltTabRunning(
        runningAppsProvider: () -> [HeadlessRunningAppSnapshot],
        currentPidProvider: () -> pid_t,
        presentConflictAlert: ([pid_t]) -> Void,
        failFast: (String) -> Void
    ) -> Bool {
        let conflictingPids = HeadlessCliPolicy
            .conflictingGuiAltTabPids(runningApps: runningAppsProvider(), currentPid: currentPidProvider())
            .sorted()
        guard !conflictingPids.isEmpty else { return false }

        presentConflictAlert(conflictingPids)
        let pidList = conflictingPids.map(String.init).joined(separator: ",")
        failFast("AltTab GUI app is already running (bundle: \(HeadlessCliPolicy.guiAltTabBundleIdentifier), pids: \(pidList)). Quit AltTab before launching AltTabHeadless.")
        return true
    }
}

struct HeadlessWindowSnapshot {
    var id: UInt32?
    var title: String
    var appName: String?
    var appBundleId: String?
    var spaceIndexes: [Int]
    var lastFocusOrder: Int
    var creationOrder: Int
    var isTabbed: Bool
    var isHidden: Bool
    var isFullscreen: Bool
    var isMinimized: Bool
    var isOnAllSpaces: Bool
    var position: CGPoint?
    var size: CGSize?
    var isWindowlessApp: Bool
}

enum HeadlessListingState {
    static var refreshStateForListing: () -> Void = {}
    static var windowSnapshotsProvider: () -> [HeadlessWindowSnapshot] = { [] }

    static func refreshedVisibleSnapshots() -> [HeadlessWindowSnapshot] {
        refreshStateForListing()
        return windowSnapshotsProvider().filter { !$0.isWindowlessApp }
    }

    static func resetHooksForTesting() {
        refreshStateForListing = {}
        windowSnapshotsProvider = { [] }
    }
}
