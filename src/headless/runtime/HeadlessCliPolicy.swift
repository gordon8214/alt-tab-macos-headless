import CoreGraphics
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
