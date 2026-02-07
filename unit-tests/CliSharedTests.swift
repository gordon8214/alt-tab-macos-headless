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

    func testDetectClientModeForHeadlessSupportedFocusCommand() {
        let mode = CliShared.detectClientMode(arguments: ["AltTabHeadless", "--focus=123"], support: .headlessClient)

        XCTAssertEqual(mode, .sendCommand("--focus=123"))
    }

    func testDetectClientModeForHeadlessSupportedFocusUsingLastFocusOrderCommand() {
        let mode = CliShared.detectClientMode(arguments: ["AltTabHeadless", "--focusUsingLastFocusOrder=1"], support: .headlessClient)

        XCTAssertEqual(mode, .sendCommand("--focusUsingLastFocusOrder=1"))
    }

    func testDetectClientModeForHeadlessSupportedShowCommand() {
        let mode = CliShared.detectClientMode(arguments: ["AltTabHeadless", "--show=0"], support: .headlessClient)

        XCTAssertEqual(mode, .sendCommand("--show=0"))
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

    func testDetectClientModeForHeadlessTreatsUnexpectedPositionalArgumentAsDaemon() {
        let mode = CliShared.detectClientMode(arguments: ["AltTabHeadless", "FinderLaunchToken"], support: .headlessClient)

        XCTAssertEqual(mode, .daemon)
    }

    func testDetectClientModeForHeadlessTreatsOnlyNonCliArgumentsAsDaemon() {
        let mode = CliShared.detectClientMode(arguments: [
            "AltTabHeadless",
            "FinderLaunchToken",
            "AnotherNonCliValue",
        ], support: .headlessClient)

        XCTAssertEqual(mode, .daemon)
    }

    func testDetectClientModeForHeadlessStillRejectsUnknownDoubleDashArgument() {
        let mode = CliShared.detectClientMode(arguments: ["AltTabHeadless", "--unknown"], support: .headlessClient)

        XCTAssertEqual(mode, .invalid)
    }

    func testDetectClientModeForGuiAllowsFocusPrefixEvenWithInvalidValue() {
        let mode = CliShared.detectClientMode(arguments: ["AltTab", "--focus=not-a-number"], support: .guiClient)

        XCTAssertEqual(mode, .sendCommand("--focus=not-a-number"))
    }

    func testParseServerCommandParsesFocusForGuiSupport() {
        XCTAssertEqual(CliShared.parseServerCommand("--focus=123", support: .guiServer), .focus(123))
    }

    func testParseServerCommandParsesFocusForHeadlessSupport() {
        XCTAssertEqual(CliShared.parseServerCommand("--focus=123", support: .headlessServer), .focus(123))
    }

    func testParseServerCommandParsesFocusUsingLastFocusOrderForHeadlessSupport() {
        XCTAssertEqual(CliShared.parseServerCommand("--focusUsingLastFocusOrder=1", support: .headlessServer), .focusUsingLastFocusOrder(1))
    }

    func testParseServerCommandParsesShowForHeadlessSupport() {
        XCTAssertEqual(CliShared.parseServerCommand("--show=0", support: .headlessServer), .show(0))
    }

    func testParseServerCommandRejectsOutOfRangeShowCommand() {
        XCTAssertNil(CliShared.parseServerCommand("--show=4", support: .guiServer))
    }

    func testShouldWaitForReadinessForFocusAndShowCommands() {
        XCTAssertTrue(CliShared.shouldWaitForReadiness("--focus=123"))
        XCTAssertTrue(CliShared.shouldWaitForReadiness("--focusUsingLastFocusOrder=1"))
        XCTAssertTrue(CliShared.shouldWaitForReadiness("--show=0"))
    }

    func testShouldWaitForReadinessRejectsMalformedOrHelpCommands() {
        XCTAssertFalse(CliShared.shouldWaitForReadiness("--focus=abc"))
        XCTAssertFalse(CliShared.shouldWaitForReadiness("--show=9"))
        XCTAssertFalse(CliShared.shouldWaitForReadiness("--help"))
    }
}
