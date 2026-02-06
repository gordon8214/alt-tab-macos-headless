import XCTest
import Darwin

final class HeadlessSignalExitPolicyTests: XCTestCase {
    func testSigtermIsGraceful() {
        XCTAssertFalse(SignalExitPolicy.shouldEmergencyExit(for: SIGTERM))
        XCTAssertEqual(SignalExitPolicy.exitCode(for: SIGTERM), 0)
    }

    func testSigtrapIsEmergency() {
        XCTAssertTrue(SignalExitPolicy.shouldEmergencyExit(for: SIGTRAP))
        XCTAssertEqual(SignalExitPolicy.exitCode(for: SIGTRAP), 1)
    }
}
