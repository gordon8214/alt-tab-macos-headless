import Foundation

class CliEvents {
    static let portName = "com.lwouis.alt-tab-macos.headless.cli"

    static func observe() {
        var context = CFMessagePortContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        if let messagePort = CFMessagePortCreateLocal(nil, portName as CFString, handleEvent, &context, nil),
           let source = CFMessagePortCreateRunLoopSource(nil, messagePort, 0) {
            CFRunLoopAddSource(BackgroundWork.cliEventsThread.runLoop, source, .commonModes)
        } else {
            Logger.error { "Can't listen on message port. Is another headless daemon already running?" }
        }
    }

    private static let handleEvent: CFMessagePortCallBack = { (_: CFMessagePort?, _: Int32, _ data: CFData?, _: UnsafeMutableRawPointer?) in
        if let data,
           let message = String(data: data as Data, encoding: .utf8) {
            Logger.info { message }
            let output = CliServer.executeCommandAndSendResponse(message)
            if let responseData = try? CliServer.jsonEncoder.encode(output) as CFData {
                return Unmanaged.passRetained(responseData)
            }
        }
        Logger.error { "Failed to decode message" }
        return nil
    }
}

class CliServer {
    static let jsonEncoder = JSONEncoder()
    static let error = "error"
    static let noOutput = "noOutput"
    static let unsupported = "unsupported"
    static let warmingUpTimeout = "warmingUpTimeout"
    private static let readinessWaitSeconds = 5.0

    static func executeCommandAndSendResponse(_ rawValue: String) -> Codable {
        if rawValue == "--list" || rawValue == "--detailed-list" {
            guard ReadinessGate.waitUntilReady(timeout: readinessWaitSeconds) else {
                return warmingUpTimeout
            }
        }
        var output: Codable = ""
        DispatchQueue.main.sync {
            output = executeCommandAndSendResponse_(rawValue)
        }
        return output
    }

    private static func executeCommandAndSendResponse_(_ rawValue: String) -> Codable {
        if rawValue == "--list" {
            return JsonWindowList(windows: Windows.list
                .filter { !$0.isWindowlessApp }
                .map { JsonWindow(id: $0.cgWindowId, title: $0.title) }
            )
        }
        if rawValue == "--detailed-list" {
            return JsonWindowFullList(windows: Windows.list
                .filter { !$0.isWindowlessApp }
                .map {
                    JsonWindowFull(
                        id: $0.cgWindowId,
                        title: $0.title,
                        appName: $0.application.localizedName,
                        appBundleId: $0.application.bundleIdentifier,
                        spaceIndexes: $0.spaceIndexes,
                        lastFocusOrder: $0.lastFocusOrder,
                        creationOrder: $0.creationOrder,
                        isTabbed: $0.isTabbed,
                        isHidden: $0.isHidden,
                        isFullscreen: $0.isFullscreen,
                        isMinimized: $0.isMinimized,
                        isOnAllSpaces: $0.isOnAllSpaces,
                        position: $0.position,
                        size: $0.size
                    )
                }
            )
        }
        if rawValue.hasPrefix("--focus=") || rawValue.hasPrefix("--focusUsingLastFocusOrder=") || rawValue.hasPrefix("--show=") {
            return unsupported
        }
        return error
    }

    private struct JsonWindowList: Codable {
        var windows: [JsonWindow]
    }

    private struct JsonWindow: Codable {
        var id: CGWindowID?
        var title: String
    }

    private struct JsonWindowFullList: Codable {
        var windows: [JsonWindowFull]
    }

    private struct JsonWindowFull: Codable {
        var id: CGWindowID?
        var title: String
        var appName: String?
        var appBundleId: String?
        var spaceIndexes: [SpaceIndex]
        var lastFocusOrder: Int
        var creationOrder: Int
        var isTabbed: Bool
        var isHidden: Bool
        var isFullscreen: Bool
        var isMinimized: Bool
        var isOnAllSpaces: Bool
        var position: CGPoint?
        var size: CGSize?
    }
}

enum CliClientMode {
    case daemon
    case help
    case sendCommand(String)
    case unsupported(String)
    case invalid
}

class CliClient {
    private static let logsFlag = "--logs="

    static func detectMode() -> CliClientMode {
        let args = CommandLine.arguments
        if args.count == 1 {
            return .daemon
        }
        if args.count == 2 {
            let arg = args[1]
            if arg.starts(with: logsFlag) {
                return .daemon
            }
            if arg == "--help" {
                return .help
            }
            if arg == "--list" || arg == "--detailed-list" {
                return .sendCommand(arg)
            }
            if arg.hasPrefix("--focus=") || arg.hasPrefix("--focusUsingLastFocusOrder=") || arg.hasPrefix("--show=") {
                return .unsupported(arg)
            }
            return .invalid
        }
        return .invalid
    }

    static func printHelp() {
        print("Usage: AltTabHeadless [--list | --detailed-list | --help]")
        print("Run with no arguments to start the headless daemon.")
    }

    static func sendCommandAndProcessResponse(_ command: String) {
        do {
            let serverPortClient = try CFMessagePortCreateRemote(nil, CliEvents.portName as CFString).unwrapOrThrow()
            let data = try command.data(using: .utf8).unwrapOrThrow()
            var returnData: Unmanaged<CFData>?
            let _ = CFMessagePortSendRequest(serverPortClient, 0, data as CFData, 7, 7, CFRunLoopMode.defaultMode.rawValue, &returnData)
            let responseData = try returnData.unwrapOrThrow().takeRetainedValue()
            if let response = String(data: responseData as Data, encoding: .utf8) {
                if response == "\"\(CliServer.error)\"" {
                    print("Couldn't execute command. Is it correct?")
                    exit(1)
                }
                if response == "\"\(CliServer.unsupported)\"" {
                    print("Unsupported command in headless mode. Supported: --list, --detailed-list, --help")
                    exit(1)
                }
                if response == "\"\(CliServer.warmingUpTimeout)\"" {
                    print("Headless daemon is still warming up. Try again in a few seconds.")
                    exit(1)
                }
                if response != "\"\(CliServer.noOutput)\"" {
                    print(response)
                }
                exit(0)
            }
            print("Failed to decode command response")
            exit(1)
        } catch {
            print("AltTabHeadless daemon needs to be running for CLI commands to work")
            exit(1)
        }
    }
}
