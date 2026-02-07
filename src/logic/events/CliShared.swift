import CoreGraphics
import Foundation

enum CliCommand: Equatable {
    case list
    case detailedList
    case focus(CGWindowID)
    case focusUsingLastFocusOrder(Int)
    case show(Int)
    case help
}

enum CliClientMode: Equatable {
    case daemon
    case help
    case sendCommand(String)
    case unsupported(String)
    case invalid
}

struct CliCommandSupport {
    let supportsFocus: Bool
    let supportsFocusUsingLastFocusOrder: Bool
    let supportsShow: Bool
    let supportsHelp: Bool

    static let guiServer = CliCommandSupport(
        supportsFocus: true,
        supportsFocusUsingLastFocusOrder: true,
        supportsShow: true,
        supportsHelp: false
    )

    static let guiClient = CliCommandSupport(
        supportsFocus: true,
        supportsFocusUsingLastFocusOrder: true,
        supportsShow: true,
        supportsHelp: false
    )

    static let headlessServer = CliCommandSupport(
        supportsFocus: false,
        supportsFocusUsingLastFocusOrder: false,
        supportsShow: false,
        supportsHelp: false
    )

    static let headlessClient = CliCommandSupport(
        supportsFocus: false,
        supportsFocusUsingLastFocusOrder: false,
        supportsShow: false,
        supportsHelp: true
    )
}

enum CliServerCode: String, Codable {
    case error
    case noOutput
    case unsupported
    case warmingUpTimeout
}

enum CliShared {
    private static let listCommand = "--list"
    private static let detailedListCommand = "--detailed-list"
    private static let helpCommand = "--help"
    private static let focusPrefix = "--focus="
    private static let focusUsingLastFocusOrderPrefix = "--focusUsingLastFocusOrder="
    private static let showPrefix = "--show="
    private static let logsPrefix = "--logs="

    private static let ignoredInjectedFlags = Set([
        "-NSDocumentRevisionsDebugMode",
        "-ApplePersistenceIgnoreState",
        "-AppleLanguages",
        "-AppleLocale",
    ])

    static func normalizedArguments(_ argv: [String], ignoreInjectedFlags: Bool = true) -> [String] {
        let args = Array(argv.dropFirst())
        var filteredArgs = [String]()
        var idx = args.startIndex

        while idx < args.endIndex {
            let arg = args[idx]
            if arg.starts(with: logsPrefix) {
                idx = args.index(after: idx)
                continue
            }
            if ignoreInjectedFlags,
               shouldIgnoreInjectedFlag(arg) {
                idx = indexAfterSkippingInjectedValue(args, currentIndex: idx)
                continue
            }
            filteredArgs.append(arg)
            idx = args.index(after: idx)
        }
        return filteredArgs
    }

    static func detectClientMode(arguments: [String], support: CliCommandSupport) -> CliClientMode {
        let args = normalizedArguments(arguments)
        if args.isEmpty {
            return .daemon
        }
        if args.count != 1 {
            return .invalid
        }

        let arg = args[0]
        if arg == helpCommand {
            return support.supportsHelp ? .help : .invalid
        }

        if isSendableCommand(arg, support: support) {
            return .sendCommand(arg)
        }

        if isUnsupportedCommand(arg, support: support) {
            return .unsupported(arg)
        }

        return .invalid
    }

    static func parseServerCommand(_ rawValue: String, support: CliCommandSupport) -> CliCommand? {
        guard let command = parseCommand(rawValue) else {
            return nil
        }

        switch command {
        case .focus:
            return support.supportsFocus ? command : nil
        case .focusUsingLastFocusOrder:
            return support.supportsFocusUsingLastFocusOrder ? command : nil
        case .show:
            return support.supportsShow ? command : nil
        case .help:
            return support.supportsHelp ? command : nil
        case .list, .detailedList:
            return command
        }
    }

    static func isUnsupportedCommand(_ rawValue: String, support: CliCommandSupport) -> Bool {
        if rawValue.hasPrefix(focusPrefix), !support.supportsFocus {
            return true
        }
        if rawValue.hasPrefix(focusUsingLastFocusOrderPrefix), !support.supportsFocusUsingLastFocusOrder {
            return true
        }
        if rawValue.hasPrefix(showPrefix), !support.supportsShow {
            return true
        }
        return false
    }

    static func shouldWaitForReadiness(_ rawValue: String) -> Bool {
        rawValue == listCommand || rawValue == detailedListCommand
    }

    private static func parseCommand(_ rawValue: String) -> CliCommand? {
        if rawValue == listCommand {
            return .list
        }

        if rawValue == detailedListCommand {
            return .detailedList
        }

        if rawValue == helpCommand {
            return .help
        }

        if rawValue.hasPrefix(focusPrefix),
           let id = CGWindowID(rawValue.dropFirst(focusPrefix.count)) {
            return .focus(id)
        }

        if rawValue.hasPrefix(focusUsingLastFocusOrderPrefix),
           let lastFocusOrder = Int(rawValue.dropFirst(focusUsingLastFocusOrderPrefix.count)) {
            return .focusUsingLastFocusOrder(lastFocusOrder)
        }

        if rawValue.hasPrefix(showPrefix),
           let shortcutIndex = Int(rawValue.dropFirst(showPrefix.count)),
           (0...3).contains(shortcutIndex) {
            return .show(shortcutIndex)
        }

        return nil
    }

    private static func isSendableCommand(_ arg: String, support: CliCommandSupport) -> Bool {
        if arg == listCommand || arg == detailedListCommand {
            return true
        }
        if arg.hasPrefix(focusPrefix) {
            return support.supportsFocus
        }
        if arg.hasPrefix(focusUsingLastFocusOrderPrefix) {
            return support.supportsFocusUsingLastFocusOrder
        }
        if arg.hasPrefix(showPrefix) {
            return support.supportsShow
        }
        return false
    }

    private static func shouldIgnoreInjectedFlag(_ arg: String) -> Bool {
        if arg.hasPrefix("--") {
            return false
        }
        return ignoredInjectedFlags.contains(arg) || arg.hasPrefix("-psn_") || arg.hasPrefix("-")
    }

    private static func indexAfterSkippingInjectedValue(_ args: [String], currentIndex: Int) -> Int {
        let nextIndex = args.index(after: currentIndex)
        guard shouldIgnoreInjectedFlag(args[currentIndex]),
              nextIndex < args.endIndex,
              !args[nextIndex].starts(with: "-") else {
            return nextIndex
        }
        return args.index(after: nextIndex)
    }
}
