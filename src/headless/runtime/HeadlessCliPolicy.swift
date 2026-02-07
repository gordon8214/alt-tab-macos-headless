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

struct HeadlessShowSelectionPreferences {
    var appsToShow: HeadlessShowAppsToShow
    var spacesToShow: HeadlessShowSpacesToShow
    var screensToShow: HeadlessShowScreensToShow
    var showMinimizedWindows: HeadlessShowHow
    var showHiddenWindows: HeadlessShowHow
    var showFullscreenWindows: HeadlessShowHow
    var showWindowlessApps: HeadlessShowHow
    var windowOrder: HeadlessWindowOrder
    var showTabsAsWindows: Bool
    var onlyShowApplications: Bool
    var blacklist: [HeadlessShowBlacklistEntry]
}

struct HeadlessShowSelectionWindow {
    var windowListIndex: Int
    var windowId: String
    var cgWindowId: CGWindowID?
    var title: String
    var appName: String?
    var appBundleId: String?
    var appPid: pid_t
    var spaceIds: [UInt64]
    var spaceIndexes: [Int]
    var lastFocusOrder: Int
    var creationOrder: Int
    var isTabbed: Bool
    var isHidden: Bool
    var isFullscreen: Bool
    var isMinimized: Bool
    var isOnAllSpaces: Bool
    var isWindowlessApp: Bool
    var isOnPreferredScreen: Bool
}

enum HeadlessShowAppsToShow {
    case all
    case active
    case nonActive
}

enum HeadlessShowSpacesToShow {
    case all
    case visible
}

enum HeadlessShowScreensToShow {
    case all
    case showingAltTab
}

enum HeadlessShowHow {
    case hide
    case show
    case showAtTheEnd
}

enum HeadlessWindowOrder {
    case recentlyFocused
    case recentlyCreated
    case alphabetical
    case space
}

enum HeadlessShowBlacklistHide {
    case always
    case whenWindowless
    case none
}

struct HeadlessShowBlacklistEntry {
    var bundleIdentifier: String
    var hide: HeadlessShowBlacklistHide
}

enum HeadlessShowSelection {
    static func selectWindowListIndex(
        from windows: [HeadlessShowSelectionWindow],
        preferences: HeadlessShowSelectionPreferences,
        frontmostPid: pid_t?,
        visibleSpaces: [UInt64]
    ) -> Int? {
        let eligibleWindows = windows.filter {
            isEligible($0, preferences: preferences, frontmostPid: frontmostPid, visibleSpaces: visibleSpaces)
        }
        let windowsToEvaluate = windowsToEvaluate(eligibleWindows, preferences: preferences)
        guard !windowsToEvaluate.isEmpty else {
            return nil
        }
        let sorted = windowsToEvaluate.sorted {
            compare($0, $1, preferences: preferences)
        }
        if let nextWindow = sorted.first(where: { $0.lastFocusOrder > 0 }) {
            return nextWindow.windowListIndex
        }
        return sorted.first?.windowListIndex
    }

    private static func windowsToEvaluate(
        _ windows: [HeadlessShowSelectionWindow],
        preferences: HeadlessShowSelectionPreferences
    ) -> [HeadlessShowSelectionWindow] {
        guard preferences.onlyShowApplications else {
            return windows
        }
        let groupedByApplication = Dictionary(grouping: windows, by: \.appPid)
        return groupedByApplication.compactMap { _, appWindows in
            appWindows.min {
                if $0.lastFocusOrder == $1.lastFocusOrder {
                    return $1.creationOrder < $0.creationOrder
                }
                return $0.lastFocusOrder < $1.lastFocusOrder
            }
        }
    }

    private static func isEligible(
        _ window: HeadlessShowSelectionWindow,
        preferences: HeadlessShowSelectionPreferences,
        frontmostPid: pid_t?,
        visibleSpaces: [UInt64]
    ) -> Bool {
        if isHiddenByBlacklist(window, preferences.blacklist) {
            return false
        }
        if preferences.appsToShow == .active && window.appPid != frontmostPid {
            return false
        }
        if preferences.appsToShow == .nonActive && window.appPid == frontmostPid {
            return false
        }
        if preferences.showHiddenWindows == .hide && window.isHidden {
            return false
        }
        if window.isWindowlessApp {
            return preferences.showWindowlessApps != .hide
        }
        if preferences.showFullscreenWindows == .hide && window.isFullscreen {
            return false
        }
        if preferences.showMinimizedWindows == .hide && window.isMinimized {
            return false
        }
        if preferences.spacesToShow == .visible && !isInVisibleSpace(window, visibleSpaces) {
            return false
        }
        if preferences.screensToShow == .showingAltTab && !window.isOnPreferredScreen {
            return false
        }
        if !preferences.showTabsAsWindows && window.isTabbed {
            return false
        }
        return true
    }

    private static func isHiddenByBlacklist(_ window: HeadlessShowSelectionWindow, _ blacklist: [HeadlessShowBlacklistEntry]) -> Bool {
        guard let bundleId = window.appBundleId else {
            return false
        }
        return blacklist.contains {
            bundleId.hasPrefix($0.bundleIdentifier) &&
                ($0.hide == .always || (window.isWindowlessApp && $0.hide != .none))
        }
    }

    private static func isInVisibleSpace(_ window: HeadlessShowSelectionWindow, _ visibleSpaces: [UInt64]) -> Bool {
        visibleSpaces.contains { visibleSpace in
            window.spaceIds.contains { $0 == visibleSpace }
        }
    }

    private static func compare(
        _ window1: HeadlessShowSelectionWindow,
        _ window2: HeadlessShowSelectionWindow,
        preferences: HeadlessShowSelectionPreferences
    ) -> Bool {
        if preferences.showWindowlessApps == .showAtTheEnd && window1.isWindowlessApp != window2.isWindowlessApp {
            return window2.isWindowlessApp
        }
        if preferences.showHiddenWindows == .showAtTheEnd && window1.isHidden != window2.isHidden {
            return window2.isHidden
        }
        if preferences.showMinimizedWindows == .showAtTheEnd && window1.isMinimized != window2.isMinimized {
            return window2.isMinimized
        }

        var order = ComparisonResult.orderedSame
        switch preferences.windowOrder {
        case .recentlyFocused:
            order = compareInts(window1.lastFocusOrder, window2.lastFocusOrder)
        case .recentlyCreated:
            order = compareInts(window2.creationOrder, window1.creationOrder)
        case .alphabetical:
            order = compareByAppNameThenWindowTitle(window1, window2)
        case .space:
            if window1.isOnAllSpaces && window2.isOnAllSpaces {
                order = .orderedSame
            } else if window1.isOnAllSpaces {
                order = .orderedAscending
            } else if window2.isOnAllSpaces {
                order = .orderedDescending
            } else if let spaceIndex1 = window1.spaceIndexes.first, let spaceIndex2 = window2.spaceIndexes.first {
                order = compareInts(spaceIndex1, spaceIndex2)
            }
            if order == .orderedSame {
                order = compareByAppNameThenWindowTitle(window1, window2)
            }
        }

        if order == .orderedSame {
            order = compareInts(window1.lastFocusOrder, window2.lastFocusOrder)
        }
        return order == .orderedAscending
    }

    private static func compareInts(_ lhs: Int, _ rhs: Int) -> ComparisonResult {
        if lhs < rhs {
            return .orderedAscending
        }
        if lhs > rhs {
            return .orderedDescending
        }
        return .orderedSame
    }

    private static func compareByAppNameThenWindowTitle(
        _ window1: HeadlessShowSelectionWindow,
        _ window2: HeadlessShowSelectionWindow
    ) -> ComparisonResult {
        let appNameOrder = (window1.appName ?? "").localizedStandardCompare(window2.appName ?? "")
        if appNameOrder == .orderedSame {
            return window1.title.localizedStandardCompare(window2.title)
        }
        return appNameOrder
    }
}

enum HeadlessCliCommandResolver {
    static func resolveWindowListIndex(
        for command: CliCommand,
        windows: [HeadlessShowSelectionWindow],
        showPreferences: HeadlessShowSelectionPreferences? = nil,
        frontmostPid: pid_t? = nil,
        visibleSpaces: [UInt64] = []
    ) -> Int? {
        switch command {
        case .focus(let windowId):
            return windows.first(where: { $0.cgWindowId == windowId })?.windowListIndex
        case .focusUsingLastFocusOrder(let lastFocusOrder):
            return windows.first(where: { $0.lastFocusOrder == lastFocusOrder })?.windowListIndex
        case .show:
            guard let showPreferences else {
                return nil
            }
            return HeadlessShowSelection.selectWindowListIndex(
                from: windows,
                preferences: showPreferences,
                frontmostPid: frontmostPid,
                visibleSpaces: visibleSpaces
            )
        case .list, .detailedList, .help:
            return nil
        }
    }
}
