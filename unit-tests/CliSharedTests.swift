import XCTest

final class CliSharedTests: XCTestCase {
    func testNormalizedArgumentsFiltersLogsAndInjectedFlags() {
        let args = [
            "AltTabHeadless",
            "--logs=/tmp/headless.log",
            "-AppleLanguages",
            "en-US",
            "-psn_0_12345",
            "--list",
        ]

        XCTAssertEqual(CliShared.normalizedArguments(args), ["--list"])
    }

    func testNormalizedArgumentsCanKeepInjectedFlags() {
        let args = [
            "AltTabHeadless",
            "--logs=/tmp/headless.log",
            "-AppleLanguages",
            "en-US",
            "--list",
        ]

        XCTAssertEqual(CliShared.normalizedArguments(args, ignoreInjectedFlags: false), ["-AppleLanguages", "en-US", "--list"])
    }

    func testDetectClientModeForHeadlessSupportedListCommand() {
        let mode = CliShared.detectClientMode(arguments: ["AltTabHeadless", "--list"], support: .headlessClient)

        XCTAssertEqual(mode, .sendCommand("--list"))
    }

    func testDetectClientModeForHeadlessUnsupportedFocusCommand() {
        let mode = CliShared.detectClientMode(arguments: ["AltTabHeadless", "--focus=123"], support: .headlessClient)

        XCTAssertEqual(mode, .unsupported("--focus=123"))
    }

    func testDetectClientModeForHeadlessHelpCommand() {
        let mode = CliShared.detectClientMode(arguments: ["AltTabHeadless", "--help"], support: .headlessClient)

        XCTAssertEqual(mode, .help)
    }

    func testDetectClientModeForHeadlessIgnoresInjectedFlagsWithCommand() {
        let mode = CliShared.detectClientMode(arguments: [
            "AltTabHeadless",
            "-ApplePersistenceIgnoreState",
            "YES",
            "--detailed-list",
        ], support: .headlessClient)

        XCTAssertEqual(mode, .sendCommand("--detailed-list"))
    }

    func testDetectClientModeForHeadlessIgnoresUnknownSingleDashInjectedFlags() {
        let mode = CliShared.detectClientMode(arguments: [
            "AltTabHeadless",
            "-NSQuitAlwaysKeepsWindows",
            "NO",
            "--list",
        ], support: .headlessClient)

        XCTAssertEqual(mode, .sendCommand("--list"))
    }

    func testDetectClientModeForHeadlessTreatsInjectedLaunchFlagsOnlyAsDaemon() {
        let mode = CliShared.detectClientMode(arguments: [
            "AltTabHeadless",
            "-NSQuitAlwaysKeepsWindows",
            "NO",
        ], support: .headlessClient)

        XCTAssertEqual(mode, .daemon)
    }

    func testDetectClientModeForGuiAllowsFocusPrefixEvenWithInvalidValue() {
        let mode = CliShared.detectClientMode(arguments: ["AltTab", "--focus=not-a-number"], support: .guiClient)

        XCTAssertEqual(mode, .sendCommand("--focus=not-a-number"))
    }

    func testParseServerCommandParsesFocusForGuiSupport() {
        XCTAssertEqual(CliShared.parseServerCommand("--focus=123", support: .guiServer), .focus(123))
    }

    func testParseServerCommandRejectsFocusForHeadlessSupport() {
        XCTAssertNil(CliShared.parseServerCommand("--focus=123", support: .headlessServer))
    }

    func testParseServerCommandRejectsOutOfRangeShowCommand() {
        XCTAssertNil(CliShared.parseServerCommand("--show=4", support: .guiServer))
    }
}
