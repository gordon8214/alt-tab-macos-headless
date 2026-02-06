import XCTest

final class HeadlessCliPolicyTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ReadinessGate.resetForTesting()
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
}
