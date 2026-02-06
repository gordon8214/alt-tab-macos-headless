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
