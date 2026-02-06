import XCTest

final class HeadlessReadinessGateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ReadinessGate.resetForTesting()
    }

    func testWaitTimesOutWhenNotReady() {
        let start = Date()
        let isReady = ReadinessGate.waitUntilReady(timeout: 0.05)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertFalse(isReady)
        XCTAssertGreaterThanOrEqual(elapsed, 0.04)
    }

    func testWaitSucceedsWhenMarkedReadyFromBackgroundQueue() {
        let waiterDone = expectation(description: "waiter returns after markReady")
        var waiterResult = false

        DispatchQueue.global().async {
            waiterResult = ReadinessGate.waitUntilReady(timeout: 1.0)
            waiterDone.fulfill()
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            ReadinessGate.markReady()
        }

        wait(for: [waiterDone], timeout: 2.0)
        XCTAssertTrue(waiterResult)
    }
}
