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

    func testUnsupportedCommandReturnsUnsupportedCode() {
        let result = HeadlessCliPolicy.preflightCode(for: "--focus=abc")

        XCTAssertEqual(result, .unsupported)
    }

    func testListCommandReturnsWarmupTimeoutWhenNotReady() {
        let result = HeadlessCliPolicy.preflightCode(for: "--list", readinessWaitSeconds: 0.01)

        XCTAssertEqual(result, .warmingUpTimeout)
    }

    func testListCommandPassesWhenReady() {
        ReadinessGate.markReady()

        let result = HeadlessCliPolicy.preflightCode(for: "--list", readinessWaitSeconds: 0.01)

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
}
