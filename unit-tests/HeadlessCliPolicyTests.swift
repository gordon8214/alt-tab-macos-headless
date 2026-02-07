import CoreGraphics
import XCTest

final class HeadlessCliPolicyTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ReadinessGate.resetForTesting()
        HeadlessListingState.resetHooksForTesting()
    }

    override func tearDown() {
        HeadlessListingState.resetHooksForTesting()
        super.tearDown()
    }

    func testMalformedFocusCommandDoesNotWaitForReadiness() {
        let result = HeadlessCliPolicy.preflightCode(for: "--focus=abc")

        XCTAssertNil(result)
    }

    func testListCommandReturnsWarmupTimeoutWhenNotReady() {
        let result = HeadlessCliPolicy.preflightCode(for: "--list", readinessWaitSeconds: 0.01)

        XCTAssertEqual(result, .warmingUpTimeout)
    }

    func testFocusCommandReturnsWarmupTimeoutWhenNotReady() {
        let result = HeadlessCliPolicy.preflightCode(for: "--focus=123", readinessWaitSeconds: 0.01)

        XCTAssertEqual(result, .warmingUpTimeout)
    }

    func testFocusUsingLastFocusOrderCommandReturnsWarmupTimeoutWhenNotReady() {
        let result = HeadlessCliPolicy.preflightCode(for: "--focusUsingLastFocusOrder=1", readinessWaitSeconds: 0.01)

        XCTAssertEqual(result, .warmingUpTimeout)
    }

    func testShowCommandReturnsWarmupTimeoutWhenNotReady() {
        let result = HeadlessCliPolicy.preflightCode(for: "--show=0", readinessWaitSeconds: 0.01)

        XCTAssertEqual(result, .warmingUpTimeout)
    }

    func testListCommandPassesWhenReady() {
        ReadinessGate.markReady()

        let result = HeadlessCliPolicy.preflightCode(for: "--list", readinessWaitSeconds: 0.01)

        XCTAssertNil(result)
    }

    func testFocusCommandPassesWhenReady() {
        ReadinessGate.markReady()

        let result = HeadlessCliPolicy.preflightCode(for: "--focus=123", readinessWaitSeconds: 0.01)

        XCTAssertNil(result)
    }

    func testFocusUsingLastFocusOrderCommandPassesWhenReady() {
        ReadinessGate.markReady()

        let result = HeadlessCliPolicy.preflightCode(for: "--focusUsingLastFocusOrder=1", readinessWaitSeconds: 0.01)

        XCTAssertNil(result)
    }

    func testShowCommandPassesWhenReady() {
        ReadinessGate.markReady()

        let result = HeadlessCliPolicy.preflightCode(for: "--show=0", readinessWaitSeconds: 0.01)

        XCTAssertNil(result)
    }

    func testConflictingGuiAltTabPidsDetectsActiveGuiAltTab() {
        let result = HeadlessCliPolicy.conflictingGuiAltTabPids(
            runningApps: [
                HeadlessRunningAppSnapshot(pid: 111, bundleIdentifier: "com.lwouis.alt-tab-macos", isTerminated: false),
                HeadlessRunningAppSnapshot(pid: 222, bundleIdentifier: "com.example.other", isTerminated: false),
            ],
            currentPid: 999
        )

        XCTAssertEqual(result, [111])
    }

    func testConflictingGuiAltTabPidsIgnoresCurrentProcess() {
        let result = HeadlessCliPolicy.conflictingGuiAltTabPids(
            runningApps: [
                HeadlessRunningAppSnapshot(pid: 777, bundleIdentifier: "com.lwouis.alt-tab-macos", isTerminated: false),
            ],
            currentPid: 777
        )

        XCTAssertEqual(result, [])
    }

    func testConflictingGuiAltTabPidsIgnoresTerminatedProcesses() {
        let result = HeadlessCliPolicy.conflictingGuiAltTabPids(
            runningApps: [
                HeadlessRunningAppSnapshot(pid: 888, bundleIdentifier: "com.lwouis.alt-tab-macos", isTerminated: true),
            ],
            currentPid: 999
        )

        XCTAssertEqual(result, [])
    }

    func testConflictingGuiAltTabPidsIgnoresNonGuiBundleIdentifiers() {
        let result = HeadlessCliPolicy.conflictingGuiAltTabPids(
            runningApps: [
                HeadlessRunningAppSnapshot(pid: 10, bundleIdentifier: nil, isTerminated: false),
                HeadlessRunningAppSnapshot(pid: 20, bundleIdentifier: "com.lwouis.alt-tab-macos.headless", isTerminated: false),
                HeadlessRunningAppSnapshot(pid: 30, bundleIdentifier: "com.example.other", isTerminated: false),
            ],
            currentPid: 999
        )

        XCTAssertEqual(result, [])
    }

    func testStartupConflictGuardPresentsAlertThenFailsFastOnConflict() {
        var events = [String]()
        var alertPids = [pid_t]()
        var failureMessage: String?

        let didConflict = HeadlessStartupConflictGuard.enforceNoGuiAltTabRunning(
            runningAppsProvider: {
                [
                    HeadlessRunningAppSnapshot(pid: 300, bundleIdentifier: "com.lwouis.alt-tab-macos", isTerminated: false),
                    HeadlessRunningAppSnapshot(pid: 100, bundleIdentifier: "com.example.app", isTerminated: false),
                    HeadlessRunningAppSnapshot(pid: 200, bundleIdentifier: "com.lwouis.alt-tab-macos", isTerminated: false),
                ]
            },
            currentPidProvider: { 999 },
            presentConflictAlert: { pids in
                events.append("alert")
                alertPids = pids
            },
            failFast: { message in
                events.append("failFast")
                failureMessage = message
            }
        )

        XCTAssertTrue(didConflict)
        XCTAssertEqual(events, ["alert", "failFast"])
        XCTAssertEqual(alertPids, [200, 300])
        XCTAssertEqual(
            failureMessage,
            "AltTab GUI app is already running (bundle: com.lwouis.alt-tab-macos, pids: 200,300). Quit AltTab before launching AltTabHeadless."
        )
    }

    func testStartupConflictGuardDoesNothingWithoutConflict() {
        var didPresentAlert = false
        var didFailFast = false

        let didConflict = HeadlessStartupConflictGuard.enforceNoGuiAltTabRunning(
            runningAppsProvider: {
                [
                    HeadlessRunningAppSnapshot(pid: 100, bundleIdentifier: "com.example.app", isTerminated: false),
                    HeadlessRunningAppSnapshot(pid: 101, bundleIdentifier: "com.lwouis.alt-tab-macos", isTerminated: true),
                    HeadlessRunningAppSnapshot(pid: 102, bundleIdentifier: "com.lwouis.alt-tab-macos", isTerminated: false),
                ]
            },
            currentPidProvider: { 102 },
            presentConflictAlert: { _ in didPresentAlert = true },
            failFast: { _ in didFailFast = true }
        )

        XCTAssertFalse(didConflict)
        XCTAssertFalse(didPresentAlert)
        XCTAssertFalse(didFailFast)
    }

    func testRefreshedVisibleSnapshotsRefreshesStateBeforeReadingSpaceIndexes() {
        var simulatedSpaceIndexes = [1]

        HeadlessListingState.refreshStateForListing = {
            simulatedSpaceIndexes = [3, 5]
        }
        HeadlessListingState.windowSnapshotsProvider = {
            [
                HeadlessWindowSnapshot(
                    id: 42,
                    title: "Window",
                    appName: "App",
                    appBundleId: "com.example.app",
                    spaceIndexes: simulatedSpaceIndexes,
                    lastFocusOrder: 0,
                    creationOrder: 0,
                    isTabbed: false,
                    isHidden: false,
                    isFullscreen: false,
                    isMinimized: false,
                    isOnAllSpaces: false,
                    position: nil,
                    size: nil,
                    isWindowlessApp: false
                ),
            ]
        }

        let windows = HeadlessListingState.refreshedVisibleSnapshots()
        let firstWindow = windows.first

        XCTAssertEqual(firstWindow?.spaceIndexes, [3, 5])
    }

    func testRefreshedVisibleSnapshotsFiltersWindowlessEntries() {
        var refreshCount = 0
        HeadlessListingState.refreshStateForListing = { refreshCount += 1 }
        HeadlessListingState.windowSnapshotsProvider = {
            [
                HeadlessWindowSnapshot(
                    id: nil,
                    title: "windowless",
                    appName: "App",
                    appBundleId: "com.example.windowless",
                    spaceIndexes: [],
                    lastFocusOrder: 0,
                    creationOrder: 0,
                    isTabbed: false,
                    isHidden: false,
                    isFullscreen: false,
                    isMinimized: false,
                    isOnAllSpaces: false,
                    position: nil,
                    size: nil,
                    isWindowlessApp: true
                ),
                HeadlessWindowSnapshot(
                    id: 11,
                    title: "window",
                    appName: "App",
                    appBundleId: "com.example.window",
                    spaceIndexes: [1],
                    lastFocusOrder: 0,
                    creationOrder: 0,
                    isTabbed: false,
                    isHidden: false,
                    isFullscreen: false,
                    isMinimized: false,
                    isOnAllSpaces: false,
                    position: nil,
                    size: nil,
                    isWindowlessApp: false
                ),
            ]
        }

        let windows = HeadlessListingState.refreshedVisibleSnapshots()

        XCTAssertEqual(refreshCount, 1)
        XCTAssertEqual(windows.map(\.title), ["window"])
    }

    func testHeadlessShowSelectionChoosesNextWindowUsingLastFocusOrder() {
        let preferences = defaultShowPreferences()
        let windows = [
            makeShowWindow(windowListIndex: 0, windowId: "focused", appPid: 10, lastFocusOrder: 0),
            makeShowWindow(windowListIndex: 1, windowId: "next", appPid: 10, lastFocusOrder: 1),
        ]

        let selectedWindowIndex = HeadlessShowSelection.selectWindowListIndex(
            from: windows,
            preferences: preferences,
            frontmostPid: 10,
            visibleSpaces: [1]
        )

        XCTAssertEqual(selectedWindowIndex, 1)
    }

    func testHeadlessShowSelectionFallsBackToFirstWindowWhenNoNextWindowExists() {
        let preferences = defaultShowPreferences()
        let windows = [
            makeShowWindow(windowListIndex: 0, windowId: "only", appPid: 10, lastFocusOrder: 0),
        ]

        let selectedWindowIndex = HeadlessShowSelection.selectWindowListIndex(
            from: windows,
            preferences: preferences,
            frontmostPid: 10,
            visibleSpaces: [1]
        )

        XCTAssertEqual(selectedWindowIndex, 0)
    }

    func testHeadlessShowSelectionRespectsActiveAppPreference() {
        let preferences = defaultShowPreferences(appsToShow: .active)
        let windows = [
            makeShowWindow(windowListIndex: 0, windowId: "active", appPid: 10, lastFocusOrder: 1),
            makeShowWindow(windowListIndex: 1, windowId: "other", appPid: 20, lastFocusOrder: 2),
        ]

        let selectedWindowIndex = HeadlessShowSelection.selectWindowListIndex(
            from: windows,
            preferences: preferences,
            frontmostPid: 10,
            visibleSpaces: [1]
        )

        XCTAssertEqual(selectedWindowIndex, 0)
    }

    func testHeadlessShowSelectionRespectsNonActiveAppPreference() {
        let preferences = defaultShowPreferences(appsToShow: .nonActive)
        let windows = [
            makeShowWindow(windowListIndex: 0, windowId: "active", appPid: 10, lastFocusOrder: 1),
            makeShowWindow(windowListIndex: 1, windowId: "other", appPid: 20, lastFocusOrder: 2),
        ]

        let selectedWindowIndex = HeadlessShowSelection.selectWindowListIndex(
            from: windows,
            preferences: preferences,
            frontmostPid: 10,
            visibleSpaces: [1]
        )

        XCTAssertEqual(selectedWindowIndex, 1)
    }

    func testHeadlessShowSelectionReturnsNilWhenNoWindowsAreEligible() {
        let preferences = defaultShowPreferences(showHiddenWindows: .hide)
        let windows = [
            makeShowWindow(windowListIndex: 0, windowId: "hidden", appPid: 10, lastFocusOrder: 1, isHidden: true),
        ]

        let selectedWindowIndex = HeadlessShowSelection.selectWindowListIndex(
            from: windows,
            preferences: preferences,
            frontmostPid: 10,
            visibleSpaces: [1]
        )

        XCTAssertNil(selectedWindowIndex)
    }

    func testHeadlessShowSelectionFiltersBeforeOnlyShowApplicationsCollapse() {
        let preferences = defaultShowPreferences(showHiddenWindows: .hide, onlyShowApplications: true)
        let windows = [
            makeShowWindow(windowListIndex: 0, windowId: "hidden-first", appPid: 10, lastFocusOrder: 0, isHidden: true),
            makeShowWindow(windowListIndex: 1, windowId: "visible-second", appPid: 10, lastFocusOrder: 1),
        ]

        let selectedWindowIndex = HeadlessShowSelection.selectWindowListIndex(
            from: windows,
            preferences: preferences,
            frontmostPid: 10,
            visibleSpaces: [1]
        )

        XCTAssertEqual(selectedWindowIndex, 1)
    }

    func testHeadlessCliCommandResolverResolvesFocusByWindowId() {
        let windows = [
            makeShowWindow(windowListIndex: 0, windowId: "windowless", cgWindowId: nil, appPid: 10, lastFocusOrder: 0),
            makeShowWindow(windowListIndex: 1, windowId: "focused", cgWindowId: 99, appPid: 10, lastFocusOrder: 1),
        ]

        let selectedWindowIndex = HeadlessCliCommandResolver.resolveWindowListIndex(
            for: .focus(99),
            windows: windows
        )

        XCTAssertEqual(selectedWindowIndex, 1)
    }

    func testHeadlessCliCommandResolverResolvesFocusUsingLastFocusOrder() {
        let windows = [
            makeShowWindow(windowListIndex: 0, windowId: "w0", appPid: 10, lastFocusOrder: 2),
            makeShowWindow(windowListIndex: 1, windowId: "w1", appPid: 10, lastFocusOrder: 0),
        ]

        let selectedWindowIndex = HeadlessCliCommandResolver.resolveWindowListIndex(
            for: .focusUsingLastFocusOrder(2),
            windows: windows
        )

        XCTAssertEqual(selectedWindowIndex, 0)
    }

    func testHeadlessCliCommandResolverResolvesShowWithDuplicateWindowIdsByUniqueIndex() {
        let preferences = defaultShowPreferences()
        let windows = [
            makeShowWindow(windowListIndex: 0, windowId: "42", appPid: 10, lastFocusOrder: 0),
            makeShowWindow(windowListIndex: 1, windowId: "42", appPid: 20, lastFocusOrder: 1),
        ]

        let selectedWindowIndex = HeadlessCliCommandResolver.resolveWindowListIndex(
            for: .show(0),
            windows: windows,
            showPreferences: preferences,
            frontmostPid: 10,
            visibleSpaces: [1]
        )

        XCTAssertEqual(selectedWindowIndex, 1)
    }

    private func defaultShowPreferences(
        appsToShow: HeadlessShowAppsToShow = .all,
        showHiddenWindows: HeadlessShowHow = .show,
        onlyShowApplications: Bool = false
    ) -> HeadlessShowSelectionPreferences {
        HeadlessShowSelectionPreferences(
            appsToShow: appsToShow,
            spacesToShow: .all,
            screensToShow: .all,
            showMinimizedWindows: .show,
            showHiddenWindows: showHiddenWindows,
            showFullscreenWindows: .show,
            showWindowlessApps: .showAtTheEnd,
            windowOrder: .recentlyFocused,
            showTabsAsWindows: true,
            onlyShowApplications: onlyShowApplications,
            blacklist: []
        )
    }

    private func makeShowWindow(
        windowListIndex: Int,
        windowId: String,
        cgWindowId: CGWindowID? = nil,
        appPid: pid_t,
        lastFocusOrder: Int,
        isHidden: Bool = false
    ) -> HeadlessShowSelectionWindow {
        HeadlessShowSelectionWindow(
            windowListIndex: windowListIndex,
            windowId: windowId,
            cgWindowId: cgWindowId,
            title: windowId,
            appName: "App",
            appBundleId: "com.example.app",
            appPid: appPid,
            spaceIds: [1],
            spaceIndexes: [1],
            lastFocusOrder: lastFocusOrder,
            creationOrder: 1,
            isTabbed: false,
            isHidden: isHidden,
            isFullscreen: false,
            isMinimized: false,
            isOnAllSpaces: false,
            isWindowlessApp: false,
            isOnPreferredScreen: true
        )
    }
}
